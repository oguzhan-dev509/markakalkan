import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_review_task_presentation_labels.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_review_tasks_page.dart';

class CaseReviewTaskDetailPage extends StatefulWidget {
  const CaseReviewTaskDetailPage({
    super.key,
    required this.taskId,
    this.repository,
    this.caseOpener,
    this.evidenceOpener,
  });
  final String taskId;
  final CaseReviewTaskRepository? repository;
  final Future<void> Function(BuildContext, String)? caseOpener;
  final Future<void> Function(BuildContext, String)? evidenceOpener;
  @override
  State<CaseReviewTaskDetailPage> createState() =>
      _CaseReviewTaskDetailPageState();
}

class _CaseReviewTaskDetailPageState extends State<CaseReviewTaskDetailPage> {
  late final CaseReviewTaskRepository _repository =
      widget.repository ?? CallableCaseReviewTaskRepository();
  CaseReviewTaskDetail? _detail;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _repository.detail(widget.taskId);
      if (mounted) setState(() => _detail = value);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'generic');
    }
  }

  Future<void> _act(String action) async {
    final note = TextEditingController();
    final extra = TextEditingController();
    var outcome = 'confirmed';
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(reviewTaskActionLabel(action)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (action == 'complete_review') ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('completion-outcome'),
                  initialValue: outcome,
                  items: const [
                    DropdownMenuItem(
                      value: 'confirmed',
                      child: Text('Bulgular doğrulandı'),
                    ),
                    DropdownMenuItem(
                      value: 'inconclusive',
                      child: Text('Kesin sonuca ulaşılamadı'),
                    ),
                    DropdownMenuItem(
                      value: 'not_confirmed',
                      child: Text('Bulgular doğrulanmadı'),
                    ),
                    DropdownMenuItem(
                      value: 'action_required',
                      child: Text('Ek işlem gerekli'),
                    ),
                  ],
                  onChanged: (value) => outcome = value!,
                ),
                TextField(
                  key: const ValueKey('result-summary'),
                  controller: extra,
                  decoration: const InputDecoration(labelText: 'Sonuç özeti'),
                ),
              ],
              if (action == 'change_due_date')
                TextField(
                  key: const ValueKey('new-due-at'),
                  controller: extra,
                  decoration: const InputDecoration(
                    labelText: 'Yeni son tarih (gg.aa.yyyy ss:dd)',
                  ),
                ),
              if (action == 'assign' || action == 'change_assignment')
                TextField(
                  key: const ValueKey('assignee-name'),
                  controller: extra,
                  decoration: const InputDecoration(labelText: 'Dış uzman adı'),
                ),
              TextField(
                key: const ValueKey('task-event-note'),
                controller: note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'İşlem notu'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Geri dön'),
            ),
            FilledButton(
              onPressed: () {
                if (note.text.trim().length < 3 ||
                    (action == 'complete_review' &&
                        extra.text.trim().length < 10) ||
                    ([
                          'change_due_date',
                          'assign',
                          'change_assignment',
                        ].contains(action) &&
                        extra.text.trim().isEmpty) ||
                    (action == 'change_due_date' &&
                        reviewTaskDueInputToIso(extra.text) == null)) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Onayla'),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _submitting = true);
    final eventType = {
      'assign': 'assignment_set',
      'change_assignment': 'assignment_changed',
      'start_review': 'review_started',
      'add_note': 'note_added',
      'change_due_date': 'due_date_changed',
      'complete_review': 'review_completed',
      'cancel_task': 'task_cancelled',
    }[action]!;
    final request = <String, dynamic>{
      'contractVersion': 'case-review-task-event-request-v1',
      'taskId': widget.taskId,
      'eventType': eventType,
      'note': note.text.trim(),
      'requestId': reviewTaskRequestId(),
      if (action == 'change_due_date')
        'dueAt': reviewTaskDueInputToIso(extra.text),
      if (action == 'assign' || action == 'change_assignment')
        'assignee': {
          'type': 'external_expert',
          'displayLabel': extra.text.trim(),
          'expertiseArea': 'Vaka incelemesi',
        },
      if (action == 'complete_review') ...{
        'resultOutcome': outcome,
        'resultSummary': extra.text.trim(),
      },
    };
    try {
      final result = await _repository.append(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? 'Bu işlem daha önce kaydedildi.'
                : 'Görev işlemi kaydedildi.',
          ),
        ),
      );
      await _load();
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'permission-denied'
                  ? 'Bu işlem için yeterli yetkiniz bulunmuyor.'
                  : 'Görev işlemi tamamlanamadı.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      note.dispose();
      extra.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('İnceleme Görevi Ayrıntısı')),
    body: _detail == null
        ? _error == null
              ? const Center(
                  key: ValueKey('review-task-detail-loading'),
                  child: CircularProgressIndicator(),
                )
              : Center(
                  child: Text(
                    _error == 'not-found'
                        ? 'İnceleme görevi bulunamadı.'
                        : _error == 'permission-denied'
                        ? 'Bu görevi görüntüleme yetkiniz bulunmuyor.'
                        : 'Görev ayrıntısı yüklenemedi.',
                  ),
                )
        : ListView(
            padding: const EdgeInsets.all(24),
            children: _content(_detail!),
          ),
  );

  List<Widget> _content(CaseReviewTaskDetail detail) {
    final task = detail.task.data;
    final evidenceId = _optional(task['evidenceRefId']);
    return [
      Text(
        '${task['taskNumber']}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        '${task['title']}',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text('${task['description']}'),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () =>
            widget.caseOpener?.call(context, '${task['caseId']}') ??
            AppRouter.openCaseEvidenceDetail(
              context,
              caseId: '${task['caseId']}',
            ),
        child: Text('${task['caseNumber']} · ${task['caseTitle']}'),
      ),
      if (evidenceId != null)
        TextButton(
          onPressed: () =>
              widget.evidenceOpener?.call(context, evidenceId) ??
              AppRouter.openCaseEvidenceItemDetail(
                context,
                evidenceRefId: evidenceId,
              ),
          child: Text('${task['evidenceLabel']}'),
        ),
      Wrap(
        spacing: 8,
        children: [
          Chip(label: Text(reviewTaskTypeLabel('${task['taskType']}'))),
          Chip(label: Text(reviewTaskPriorityLabel('${task['priority']}'))),
          Chip(label: Text(reviewTaskStatusLabel('${task['status']}'))),
          if (task['isOverdue'] == true)
            const Chip(label: Text('Süresi geçti')),
        ],
      ),
      Text(
        'Atanan: ${_optional(task['assigneeLabel']) ?? reviewTaskAssigneeLabel('${task['assigneeType']}')}',
      ),
      if (_optional(task['assigneeOrganization']) != null)
        Text('Kurum: ${task['assigneeOrganization']}'),
      if (_optional(task['expertiseArea']) != null)
        Text('Uzmanlık alanı: ${task['expertiseArea']}'),
      Text(
        'Son tarih: ${task['dueAt'] == null ? 'Tarih bilgisi yok' : reviewTaskDateLabel(task['dueAt'])}',
      ),
      Text('Oluşturulma: ${reviewTaskDateLabel(task['createdAt'])}'),
      if (task['startedAt'] != null)
        Text('Başlatılma: ${reviewTaskDateLabel(task['startedAt'])}'),
      if (task['completedAt'] != null)
        Text('Tamamlanma: ${reviewTaskDateLabel(task['completedAt'])}'),
      if (task['cancelledAt'] != null)
        Text('İptal: ${reviewTaskDateLabel(task['cancelledAt'])}'),
      if (task['resultOutcome'] != null)
        Text('Sonuç: ${reviewTaskOutcomeLabel('${task['resultOutcome']}')}'),
      if (_optional(task['resultSummary']) != null)
        Text('Sonuç özeti: ${task['resultSummary']}'),
      const SizedBox(height: 20),
      const Text(
        'Görev Zaman Çizelgesi',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      ...detail.events.map(
        (event) => ListTile(
          leading: CircleAvatar(child: Text('${event['sequence']}')),
          title: Text(reviewTaskEventLabel('${event['eventType']}')),
          subtitle: Text(
            '${event['note']}\n${event['actorLabel']} · '
            '${reviewTaskDateLabel(event['recordedAt'])}',
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: detail.allowedActions
            .map(
              (action) => FilledButton(
                key: ValueKey('task-action-$action'),
                onPressed: _submitting ? null : () => _act(action),
                child: Text(reviewTaskActionLabel(action)),
              ),
            )
            .toList(),
      ),
      if (detail.allowedActions.isEmpty)
        const Text('Bu görev için kullanılabilir işlem bulunmuyor.'),
    ];
  }
}

String? _optional(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

String reviewTaskRequestId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final padded = now.padRight(32, '0').substring(0, 32);
  return '${padded.substring(0, 8)}-${padded.substring(8, 12)}-'
      '4${padded.substring(13, 16)}-'
      '8${padded.substring(17, 20)}-${padded.substring(20, 32)}';
}
