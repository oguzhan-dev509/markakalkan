import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_review_task_presentation_labels.dart';

abstract interface class CaseReviewTaskRepository {
  Future<CaseReviewTaskListResult> list();
  Future<CaseReviewTaskDetail> detail(String taskId);
  Future<CaseReviewTaskMutation> create(Map<String, dynamic> request);
  Future<CaseReviewTaskMutation> append(Map<String, dynamic> request);
}

class CallableCaseReviewTaskRepository implements CaseReviewTaskRepository {
  CallableCaseReviewTaskRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
  final FirebaseFunctions _functions;

  @override
  Future<CaseReviewTaskListResult> list() async =>
      CaseReviewTaskListResult.fromMap(
        _map(
          _normalize(
            (await _functions.httpsCallable('listCaseReviewTasks').call({
              'contractVersion': 'case-review-task-list-request-v1',
            })).data,
          ),
        ),
      );
  @override
  Future<CaseReviewTaskDetail> detail(String taskId) async =>
      CaseReviewTaskDetail.fromMap(
        _map(
          _normalize(
            (await _functions.httpsCallable('getCaseReviewTaskDetail').call({
              'contractVersion': 'case-review-task-detail-request-v1',
              'taskId': taskId,
            })).data,
          ),
        ),
      );
  @override
  Future<CaseReviewTaskMutation> create(Map<String, dynamic> request) async =>
      CaseReviewTaskMutation.fromMap(
        _map(
          _normalize(
            (await _functions
                    .httpsCallable('createCaseReviewTask')
                    .call(request))
                .data,
          ),
        ),
      );
  @override
  Future<CaseReviewTaskMutation> append(Map<String, dynamic> request) async =>
      CaseReviewTaskMutation.fromMap(
        _map(
          _normalize(
            (await _functions
                    .httpsCallable('appendCaseReviewTaskEvent')
                    .call(request))
                .data,
          ),
        ),
      );
}

class CaseReviewTaskItem {
  const CaseReviewTaskItem(this.data);
  final Map<String, dynamic> data;
  String get id => _string(data, 'taskId');
  String get number => _string(data, 'taskNumber');
  String get title => _string(data, 'title');
  String get status => _string(data, 'status');
  String get priority => _string(data, 'priority');
  String get type => _string(data, 'taskType');
}

class CaseReviewTaskListResult {
  const CaseReviewTaskListResult({required this.stats, required this.items});
  final Map<String, int> stats;
  final List<CaseReviewTaskItem> items;
  factory CaseReviewTaskListResult.fromMap(Map<String, dynamic> map) {
    if (map['contractVersion'] != 'case-review-task-list-v1' ||
        map['readOnly'] != true ||
        map['writesPerformed'] != 0) {
      throw const FormatException('Geçersiz görev listesi.');
    }
    return CaseReviewTaskListResult(
      stats: _map(
        map['stats'],
      ).map((key, value) => MapEntry(key, (value as num).toInt())),
      items: _list(
        map['items'],
      ).map((item) => CaseReviewTaskItem(_map(item))).toList(),
    );
  }
}

class CaseReviewTaskDetail {
  const CaseReviewTaskDetail({
    required this.task,
    required this.events,
    required this.allowedActions,
  });
  final CaseReviewTaskItem task;
  final List<Map<String, dynamic>> events;
  final List<String> allowedActions;
  factory CaseReviewTaskDetail.fromMap(Map<String, dynamic> map) {
    if (map['contractVersion'] != 'case-review-task-detail-v1' ||
        map['readOnly'] != true ||
        map['writesPerformed'] != 0) {
      throw const FormatException('Geçersiz görev ayrıntısı.');
    }
    return CaseReviewTaskDetail(
      task: CaseReviewTaskItem(_map(map['task'])),
      events: _list(map['timelineEvents']).map(_map).toList(),
      allowedActions: _list(map['allowedActions']).cast<String>(),
    );
  }
}

class CaseReviewTaskMutation {
  const CaseReviewTaskMutation({required this.taskId, required this.duplicate});
  final String taskId;
  final bool duplicate;
  factory CaseReviewTaskMutation.fromMap(Map<String, dynamic> map) =>
      CaseReviewTaskMutation(
        taskId: _string(map, 'taskId'),
        duplicate: map['duplicate'] == true,
      );
}

class CaseReviewTasksPage extends StatefulWidget {
  const CaseReviewTasksPage({super.key, this.repository, this.detailOpener});
  final CaseReviewTaskRepository? repository;
  final Future<void> Function(BuildContext, String)? detailOpener;
  @override
  State<CaseReviewTasksPage> createState() => _CaseReviewTasksPageState();
}

class _CaseReviewTasksPageState extends State<CaseReviewTasksPage> {
  late final CaseReviewTaskRepository _repository =
      widget.repository ?? CallableCaseReviewTaskRepository();
  CaseReviewTaskListResult? _result;
  Object? _error;
  String _status = '';
  String _priority = '';
  String _type = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _repository.list();
      if (mounted) setState(() => _result = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  List<CaseReviewTaskItem> get _items => (_result?.items ?? [])
      .where(
        (item) =>
            (_status.isEmpty || item.status == _status) &&
            (_priority.isEmpty || item.priority == _priority) &&
            (_type.isEmpty || item.type == _type),
      )
      .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Görevler, Uzmanlar ve İncelemeler')),
    body: _result == null
        ? _error == null
              ? const Center(
                  key: ValueKey('review-tasks-loading'),
                  child: CircularProgressIndicator(),
                )
              : const Center(child: Text('İnceleme görevleri yüklenemedi.'))
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _TaskStats(_result!.stats),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  _filter(
                    'task-status-filter',
                    'Durum',
                    _status,
                    const {
                      '': 'Tümü',
                      'open': 'Açık',
                      'assigned': 'Atandı',
                      'in_review': 'İncelemede',
                      'completed': 'Tamamlandı',
                      'cancelled': 'İptal edildi',
                    },
                    (value) => setState(() => _status = value),
                  ),
                  _filter(
                    'task-priority-filter',
                    'Öncelik',
                    _priority,
                    const {
                      '': 'Tümü',
                      'low': 'Düşük',
                      'medium': 'Orta',
                      'high': 'Yüksek',
                      'critical': 'Kritik',
                    },
                    (value) => setState(() => _priority = value),
                  ),
                  _filter(
                    'task-type-filter',
                    'Görev türü',
                    _type,
                    const {
                      '': 'Tümü',
                      'evidence_review': 'Delil incelemesi',
                      'source_verification': 'Kaynak doğrulama',
                      'technical_analysis': 'Teknik analiz',
                      'laboratory_analysis': 'Laboratuvar analizi',
                    },
                    (value) => setState(() => _type = value),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_result!.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Henüz inceleme görevi bulunmuyor.'),
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Seçilen filtrelere uygun görev bulunmuyor.'),
                )
              else
                ..._items.map(
                  (item) => Card(
                    child: ListTile(
                      key: ValueKey('review-task-${item.id}'),
                      onTap: () =>
                          widget.detailOpener?.call(context, item.id) ??
                          AppRouter.openCaseReviewTaskDetail(
                            context,
                            taskId: item.id,
                          ),
                      title: Text('${item.number} · ${item.title}'),
                      subtitle: Text(_summary(item.data)),
                      trailing: item.data['isOverdue'] == true
                          ? const Chip(label: Text('Süresi geçti'))
                          : null,
                    ),
                  ),
                ),
            ],
          ),
  );

  Widget _filter(
    String key,
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> changed,
  ) => DropdownButton<String>(
    key: ValueKey(key),
    value: value,
    hint: Text(label),
    items: values.entries
        .map(
          (entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        )
        .toList(),
    onChanged: (next) => changed(next ?? ''),
  );

  String _summary(Map<String, dynamic> item) {
    final evidence = _nullable(item['evidenceLabel']);
    final due = item['dueAt'] == null
        ? 'Son tarih yok'
        : 'Son tarih: ${reviewTaskDateLabel(item['dueAt'])}';
    final last = item['lastEventAt'] == null
        ? 'Son hareket yok'
        : 'Son hareket: ${reviewTaskDateLabel(item['lastEventAt'])}';
    return '${_string(item, 'caseNumber')} · ${_string(item, 'caseTitle')}'
        '${evidence == null ? '' : '\n$evidence'}'
        '\n${reviewTaskTypeLabel(_string(item, 'taskType'))} · '
        '${reviewTaskPriorityLabel(_string(item, 'priority'))} · '
        '${reviewTaskStatusLabel(_string(item, 'status'))}'
        '\n${_nullable(item['assigneeLabel']) ?? reviewTaskAssigneeLabel(_string(item, 'assigneeType'))}'
        '${_nullable(item['expertiseArea']) == null ? '' : ' · ${item['expertiseArea']}'}'
        '\n$due · $last';
  }
}

class _TaskStats extends StatelessWidget {
  const _TaskStats(this.stats);
  final Map<String, int> stats;
  @override
  Widget build(BuildContext context) {
    const labels = {
      'totalTasks': 'Toplam Görev',
      'openTasks': 'Açık',
      'assignedTasks': 'Atandı',
      'inReviewTasks': 'İncelemede',
      'overdueTasks': 'Süresi Geçen',
      'completedTasks': 'Tamamlandı',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.entries
          .map(
            (entry) =>
                Chip(label: Text('${entry.value}: ${stats[entry.key] ?? 0}')),
          )
          .toList(),
    );
  }
}

Future<CaseReviewTaskMutation?> showCaseReviewTaskForm(
  BuildContext context, {
  required String caseId,
  String? evidenceRefId,
  String? initialTitle,
  CaseReviewTaskRepository? repository,
  Future<void> Function(BuildContext, String)? detailOpener,
}) async {
  final service = repository ?? CallableCaseReviewTaskRepository();
  final title = TextEditingController(text: initialTitle);
  final description = TextEditingController();
  final label = TextEditingController();
  final organization = TextEditingController();
  final expertise = TextEditingController();
  final dueAt = TextEditingController();
  var type = evidenceRefId == null ? 'source_verification' : 'evidence_review';
  var priority = 'medium';
  var assigneeType = 'unassigned';
  var submitting = false;
  final result = await showDialog<CaseReviewTaskMutation>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('İnceleme görevi oluştur'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('task-title'),
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Görev başlığı'),
                ),
                TextField(
                  key: const ValueKey('task-description'),
                  controller: description,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('task-type'),
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(
                      value: 'evidence_review',
                      child: Text('Delil incelemesi'),
                    ),
                    DropdownMenuItem(
                      value: 'source_verification',
                      child: Text('Kaynak doğrulama'),
                    ),
                    DropdownMenuItem(
                      value: 'technical_analysis',
                      child: Text('Teknik analiz'),
                    ),
                    DropdownMenuItem(
                      value: 'laboratory_analysis',
                      child: Text('Laboratuvar analizi'),
                    ),
                  ],
                  onChanged: (value) => type = value!,
                ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('task-priority'),
                  initialValue: priority,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Düşük')),
                    DropdownMenuItem(value: 'medium', child: Text('Orta')),
                    DropdownMenuItem(value: 'high', child: Text('Yüksek')),
                    DropdownMenuItem(value: 'critical', child: Text('Kritik')),
                  ],
                  onChanged: (value) => priority = value!,
                ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('assignee-type'),
                  initialValue: assigneeType,
                  items: const [
                    DropdownMenuItem(
                      value: 'unassigned',
                      child: Text('Henüz atanmadı'),
                    ),
                    DropdownMenuItem(
                      value: 'external_expert',
                      child: Text('Dış uzman'),
                    ),
                    DropdownMenuItem(
                      value: 'laboratory',
                      child: Text('Laboratuvar'),
                    ),
                  ],
                  onChanged: (value) => setState(() => assigneeType = value!),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'İç kullanıcı seçimi için güvenli üye dizini henüz bulunmuyor.',
                  ),
                ),
                if (assigneeType != 'unassigned') ...[
                  TextField(
                    key: const ValueKey('assignee-label'),
                    controller: label,
                    decoration: InputDecoration(
                      labelText: assigneeType == 'laboratory'
                          ? 'Laboratuvar adı'
                          : 'Uzman adı',
                    ),
                  ),
                  TextField(
                    key: const ValueKey('expertise-area'),
                    controller: expertise,
                    decoration: const InputDecoration(
                      labelText: 'Uzmanlık alanı',
                    ),
                  ),
                  TextField(
                    key: const ValueKey('assignee-organization'),
                    controller: organization,
                    decoration: const InputDecoration(labelText: 'Kurum'),
                  ),
                ],
                TextField(
                  key: const ValueKey('task-due-at'),
                  controller: dueAt,
                  decoration: const InputDecoration(
                    labelText: 'Son tarih (gg.aa.yyyy ss:dd, isteğe bağlı)',
                  ),
                ),
                const Text('Bağlı vaka güvenli biçimde seçildi.'),
                if (evidenceRefId != null)
                  const Text('Bağlı delil güvenli biçimde seçildi.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(dialogContext),
            child: const Text('Geri dön'),
          ),
          FilledButton(
            key: const ValueKey('create-review-task'),
            onPressed: submitting
                ? null
                : () async {
                    final dueAtIso = dueAt.text.trim().isEmpty
                        ? null
                        : reviewTaskDueInputToIso(dueAt.text);
                    if (title.text.trim().length < 5 ||
                        description.text.trim().length < 10 ||
                        (dueAt.text.trim().isNotEmpty && dueAtIso == null) ||
                        (assigneeType != 'unassigned' &&
                            (label.text.trim().isEmpty ||
                                expertise.text.trim().isEmpty))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Görev alanlarını eksiksiz doldurun.'),
                        ),
                      );
                      return;
                    }
                    setState(() => submitting = true);
                    try {
                      final assignee = <String, dynamic>{'type': assigneeType};
                      if (assigneeType != 'unassigned') {
                        assignee['displayLabel'] = label.text.trim();
                        assignee['expertiseArea'] = expertise.text.trim();
                        if (organization.text.trim().isNotEmpty) {
                          assignee['organization'] = organization.text.trim();
                        }
                      }
                      final request = <String, dynamic>{
                        'contractVersion': 'case-review-task-create-request-v1',
                        'caseId': caseId,
                        ...evidenceRefId == null
                            ? const <String, dynamic>{}
                            : {'evidenceRefId': evidenceRefId},
                        'title': title.text.trim(),
                        'description': description.text.trim(),
                        'taskType': type,
                        'priority': priority,
                        'assignee': assignee,
                        ...dueAtIso == null
                            ? const <String, dynamic>{}
                            : {'dueAt': dueAtIso},
                        'requestId': _uuid(),
                      };
                      final created = await service.create(request);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, created);
                      }
                    } on FirebaseFunctionsException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.code == 'permission-denied'
                                  ? 'Bu işlem için yeterli yetkiniz bulunmuyor.'
                                  : 'İnceleme görevi oluşturulamadı.',
                            ),
                          ),
                        );
                      }
                      setState(() => submitting = false);
                    }
                  },
            child: const Text('Görev oluştur'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  title.dispose();
  description.dispose();
  label.dispose();
  organization.dispose();
  expertise.dispose();
  dueAt.dispose();
  if (result != null && context.mounted) {
    if (result.duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu işlem daha önce kaydedildi.')),
      );
    }
    if (detailOpener != null) {
      await detailOpener(context, result.taskId);
    } else {
      await AppRouter.openCaseReviewTaskDetail(context, taskId: result.taskId);
    }
  }
  return result;
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value = bytes
      .map((part) => part.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Nesne bekleniyordu.');
}

List<dynamic> _list(Object? value) {
  if (value is List) return value;
  throw const FormatException('Liste bekleniyordu.');
}

String _string(Map<String, dynamic> value, String key) {
  final item = value[key];
  if (item is String && item.isNotEmpty) return item;
  throw FormatException('$key geçersiz.');
}

String? _nullable(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Object? _normalize(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), _normalize(item)));
  }
  if (value is List) return value.map(_normalize).toList();
  return value;
}
