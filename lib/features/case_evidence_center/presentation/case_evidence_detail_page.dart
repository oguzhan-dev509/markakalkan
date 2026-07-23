import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_presentation_labels.dart';

abstract interface class CaseEvidenceDetailRepository {
  Future<CaseEvidenceDetail> load(String caseId);
}

class CallableCaseEvidenceDetailRepository
    implements CaseEvidenceDetailRepository {
  CallableCaseEvidenceDetailRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
  final FirebaseFunctions _functions;

  @override
  Future<CaseEvidenceDetail> load(String caseId) async {
    final result = await _functions.httpsCallable('getCaseEvidenceDetail').call(
      {'contractVersion': 'case-evidence-detail-request-v1', 'caseId': caseId},
    );
    return CaseEvidenceDetail.fromMap(
      _detailMap(_detailNormalize(result.data)),
    );
  }
}

class CaseEvidenceDetail {
  const CaseEvidenceDetail({
    required this.caseCode,
    required this.title,
    required this.summary,
    required this.status,
    required this.priority,
    required this.sourceType,
    required this.sourceReference,
    required this.evidence,
    required this.events,
    required this.audits,
  });
  final String caseCode;
  final String title;
  final String summary;
  final String status;
  final String priority;
  final String sourceType;
  final String sourceReference;
  final List<Map<String, dynamic>> evidence;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> audits;

  factory CaseEvidenceDetail.fromMap(Map<String, dynamic> map) {
    if (map['contractVersion'] != 'case-evidence-detail-v1' ||
        map['readOnly'] != true ||
        map['writesPerformed'] != 0) {
      throw const FormatException('Geçersiz vaka ayrıntısı yanıtı.');
    }
    final item = _detailMap(map['case']);
    return CaseEvidenceDetail(
      caseCode: _detailString(item, 'caseCode'),
      title: _detailString(item, 'title'),
      summary: _detailString(item, 'summary'),
      status: _detailString(item, 'status'),
      priority: _detailString(item, 'priority'),
      sourceType: _detailString(item, 'sourceType'),
      sourceReference: _detailString(item, 'sourceReference'),
      evidence: _detailList(
        map['evidenceReferences'],
      ).map(_detailMap).toList(growable: false),
      events: _detailList(
        map['timelineEvents'],
      ).map(_detailMap).toList(growable: false),
      audits: _detailList(
        map['auditSummary'],
      ).map(_detailMap).toList(growable: false),
    );
  }
}

class CaseEvidenceDetailPage extends StatefulWidget {
  const CaseEvidenceDetailPage({
    super.key,
    required this.caseId,
    this.repository,
    this.evidenceDetailOpener,
  });
  final String caseId;
  final CaseEvidenceDetailRepository? repository;
  final Future<void> Function(BuildContext context, String evidenceRefId)?
  evidenceDetailOpener;
  @override
  State<CaseEvidenceDetailPage> createState() => _CaseEvidenceDetailPageState();
}

class _CaseEvidenceDetailPageState extends State<CaseEvidenceDetailPage> {
  late final CaseEvidenceDetailRepository _repository =
      widget.repository ?? CallableCaseEvidenceDetailRepository();
  CaseEvidenceDetail? _detail;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final detail = await _repository.load(widget.caseId);
      if (mounted) setState(() => _detail = detail);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'generic');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MarkaKalkanTheme.background,
    appBar: AppBar(title: const Text('Vaka Ayrıntısı')),
    body: _detail == null
        ? _error == null
              ? const Center(
                  key: ValueKey('case-detail-loading'),
                  child: CircularProgressIndicator(),
                )
              : _ErrorState(code: _error!, retry: _load)
        : ListView(
            padding: const EdgeInsets.all(24),
            children: _content(_detail!),
          ),
  );

  List<Widget> _content(CaseEvidenceDetail detail) => [
    Text(
      detail.caseCode,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF116149),
      ),
    ),
    const SizedBox(height: 8),
    Text(
      detail.title,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    Text(caseEvidenceSignalLabel(detail.summary)),
    const SizedBox(height: 16),
    Wrap(
      spacing: 8,
      children: [
        Chip(label: Text(_status(detail.status))),
        Chip(label: Text(_priority(detail.priority))),
        Chip(label: Text(_source(detail.sourceType))),
      ],
    ),
    const SizedBox(height: 8),
    Text('Kaynak risk: ${detail.sourceReference}'),
    const SizedBox(height: 28),
    ..._section(
      'Delil Referansları',
      detail.evidence,
      'Henüz delil referansı bulunmuyor.',
      (item) => ListTile(
        key: ValueKey('case-evidence-${item['evidenceRefId']}'),
        leading: const Icon(Icons.link),
        title: Text(_safe(item, 'title')),
        subtitle: Text(
          '${_source(_safe(item, 'sourceType'))} · ${_review(_safe(item, 'reviewStatus'))}',
        ),
        onTap: _evidenceRefId(item) == null
            ? null
            : () {
                final evidenceRefId = _evidenceRefId(item)!;
                final opener = widget.evidenceDetailOpener;
                if (opener != null) {
                  opener(context, evidenceRefId);
                } else {
                  AppRouter.openCaseEvidenceItemDetail(
                    context,
                    evidenceRefId: evidenceRefId,
                  );
                }
              },
      ),
    ),
    const SizedBox(height: 20),
    ..._section(
      'Olay Zaman Çizelgesi',
      detail.events,
      'Henüz zaman çizelgesi olayı bulunmuyor.',
      (item) => ListTile(
        leading: const Icon(Icons.timeline),
        title: Text(_safe(item, 'summary')),
        subtitle: Text(_date(item['occurredAt'])),
      ),
    ),
    const SizedBox(height: 20),
    ..._section(
      'Denetim Özeti',
      detail.audits,
      'Henüz denetim özeti bulunmuyor.',
      (item) => ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: Text(_audit(_safe(item, 'action'))),
        subtitle: Text(_date(item['occurredAt'])),
      ),
    ),
  ];

  String? _evidenceRefId(Map<String, dynamic> item) {
    final value = item['evidenceRefId'];
    return value is String && value.isNotEmpty ? value : null;
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.code, required this.retry});
  final String code;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) {
    final message = switch (code) {
      'not-found' => 'Vaka dosyası bulunamadı.',
      'permission-denied' =>
        'Bu vaka dosyasını görüntüleme yetkiniz bulunmuyor.',
      _ => 'Vaka ayrıntısı yüklenemedi.',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          TextButton(onPressed: retry, child: const Text('Yeniden dene')),
        ],
      ),
    );
  }
}

List<Widget> _section(
  String title,
  List<Map<String, dynamic>> items,
  String empty,
  Widget Function(Map<String, dynamic>) builder,
) => [
  Text(
    title,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
  ),
  if (items.isEmpty)
    Padding(padding: const EdgeInsets.only(top: 10), child: Text(empty))
  else
    ...items.map(builder),
];
String _status(String value) => switch (value) {
  'open' => 'Açık',
  'in_review' => 'İncelemede',
  'closed' => 'Kapalı',
  'archived' => 'Arşivlendi',
  _ => 'İlk inceleme',
};
String _priority(String value) => switch (value) {
  'critical' => 'Kritik öncelik',
  'high' => 'Yüksek öncelik',
  'medium' => 'Orta öncelik',
  _ => 'Düşük öncelik',
};
String _source(String value) => switch (value) {
  'monitoring' => 'İzleme',
  'traceability' => 'İzlenebilirlik',
  'digital_detective' => 'Dijital Dedektif',
  'shared_risk' => 'Ortak Risk',
  _ => 'Diğer kaynak',
};
String _review(String value) => value == 'pending'
    ? 'İnceleme bekliyor'
    : value == 'approved'
    ? 'Onaylandı'
    : 'İncelendi';
String _audit(String value) => value == 'case.created_from_risk'
    ? 'Vaka risk kaydından oluşturuldu'
    : 'Vaka kaydı denetlendi';
String _date(Object? value) {
  final date = DateTime.tryParse(value is String ? value : '')?.toLocal();
  return date == null
      ? 'Tarih bilgisi yok'
      : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _safe(Map<String, dynamic> map, String key) =>
    map[key] is String && (map[key] as String).isNotEmpty
    ? map[key] as String
    : 'Bilgi yok';
Map<String, dynamic> _detailMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const FormatException('Nesne bekleniyordu.');
}

List<dynamic> _detailList(Object? value) {
  if (value is List) return value;
  throw const FormatException('Liste bekleniyordu.');
}

String _detailString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key geçersiz.');
}

Object? _detailNormalize(Object? value) {
  if (value is Map) {
    return value.map(
      (key, nested) => MapEntry(key.toString(), _detailNormalize(nested)),
    );
  }
  if (value is List) return value.map(_detailNormalize).toList(growable: false);
  return value;
}
