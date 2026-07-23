import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:markakalkan/app/router.dart';
import 'package:markakalkan/features/case_evidence_center/presentation/case_evidence_chain_presentation_labels.dart';

abstract interface class CaseEvidenceVaultRepository {
  Future<EvidenceVaultResult> loadVault();
  Future<EvidenceItemDetail> loadDetail(String evidenceRefId);
  Future<EvidenceAppendResult> append(
    String evidenceRefId,
    String eventType,
    String note,
    String requestId,
  );
}

class CallableCaseEvidenceVaultRepository
    implements CaseEvidenceVaultRepository {
  CallableCaseEvidenceVaultRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
  final FirebaseFunctions _functions;
  @override
  Future<EvidenceVaultResult> loadVault() async => EvidenceVaultResult.fromMap(
    _map(
      _normalize(
        (await _functions.httpsCallable('listCaseEvidenceVault').call({
          'contractVersion': 'case-evidence-vault-list-request-v1',
        })).data,
      ),
    ),
  );
  @override
  Future<EvidenceItemDetail> loadDetail(String id) async =>
      EvidenceItemDetail.fromMap(
        _map(
          _normalize(
            (await _functions.httpsCallable('getCaseEvidenceItemDetail').call({
              'contractVersion': 'case-evidence-item-detail-request-v1',
              'evidenceRefId': id,
            })).data,
          ),
        ),
      );
  @override
  Future<EvidenceAppendResult> append(
    String id,
    String type,
    String note,
    String requestId,
  ) async => EvidenceAppendResult.fromMap(
    _map(
      _normalize(
        (await _functions.httpsCallable('appendCaseEvidenceChainEvent').call({
          'contractVersion': 'case-evidence-chain-event-request-v1',
          'evidenceRefId': id,
          'eventType': type,
          'note': note,
          'requestId': requestId,
        })).data,
      ),
    ),
  );
}

class EvidenceVaultResult {
  EvidenceVaultResult({required this.stats, required this.items});
  final Map<String, int> stats;
  final List<EvidenceItem> items;
  factory EvidenceVaultResult.fromMap(Map<String, dynamic> map) {
    if (map['contractVersion'] != 'case-evidence-vault-list-v1' ||
        map['readOnly'] != true ||
        map['writesPerformed'] != 0) {
      throw const FormatException('Geçersiz delil kasası yanıtı.');
    }
    return EvidenceVaultResult(
      stats: _map(map['stats']).map((k, v) => MapEntry(k, (v as num).toInt())),
      items: _list(
        map['items'],
      ).map((e) => EvidenceItem.fromMap(_map(e))).toList(),
    );
  }
}

class EvidenceItem {
  EvidenceItem({
    required this.id,
    required this.caseNumber,
    required this.caseTitle,
    required this.label,
    required this.type,
    required this.source,
    required this.review,
    required this.custody,
    required this.integrity,
    required this.count,
    this.lastAt,
  });
  final String id,
      caseNumber,
      caseTitle,
      label,
      type,
      source,
      review,
      custody,
      integrity;
  final int count;
  final String? lastAt;
  factory EvidenceItem.fromMap(Map<String, dynamic> m) => EvidenceItem(
    id: _s(m, 'evidenceRefId'),
    caseNumber: _s(m, 'caseNumber'),
    caseTitle: _s(m, 'caseTitle'),
    label: _s(m, 'evidenceLabel'),
    type: _s(m, 'evidenceType'),
    source: _s(m, 'sourceLabel'),
    review: _s(m, 'reviewStatus'),
    custody: _s(m, 'custodyStatus'),
    integrity: _s(m, 'integrityStatus'),
    count: (m['chainEventCount'] as num).toInt(),
    lastAt: m['lastChainEventAt'] as String?,
  );
}

class EvidenceItemDetail {
  EvidenceItemDetail({
    required this.evidence,
    required this.events,
    required this.allowed,
  });
  final EvidenceItem evidence;
  final List<Map<String, dynamic>> events;
  final List<String> allowed;
  factory EvidenceItemDetail.fromMap(Map<String, dynamic> m) {
    if (m['contractVersion'] != 'case-evidence-item-detail-v1' ||
        m['readOnly'] != true ||
        m['writesPerformed'] != 0) {
      throw const FormatException('Geçersiz delil ayrıntısı.');
    }
    return EvidenceItemDetail(
      evidence: EvidenceItem.fromMap(_map(m['evidence'])),
      events: _list(m['chainEvents']).map(_map).toList(),
      allowed: _list(m['allowedActions']).cast<String>(),
    );
  }
}

class EvidenceAppendResult {
  EvidenceAppendResult({required this.duplicate});
  final bool duplicate;
  factory EvidenceAppendResult.fromMap(Map<String, dynamic> m) =>
      EvidenceAppendResult(duplicate: m['duplicate'] == true);
}

class CaseEvidenceVaultPage extends StatefulWidget {
  const CaseEvidenceVaultPage({super.key, this.repository, this.detailOpener});
  final CaseEvidenceVaultRepository? repository;
  final Future<void> Function(BuildContext, String)? detailOpener;
  @override
  State<CaseEvidenceVaultPage> createState() => _CaseEvidenceVaultPageState();
}

class _CaseEvidenceVaultPageState extends State<CaseEvidenceVaultPage> {
  late final CaseEvidenceVaultRepository repository =
      widget.repository ?? CallableCaseEvidenceVaultRepository();
  EvidenceVaultResult? result;
  Object? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await repository.loadVault();
      if (mounted) setState(() => result = value);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delil Kasası ve Delil Zinciri')),
    body: result == null
        ? error == null
              ? const Center(
                  key: ValueKey('evidence-vault-loading'),
                  child: CircularProgressIndicator(),
                )
              : const Center(child: Text('Delil kasası yüklenemedi.'))
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _Stats(result!.stats),
              if (result!.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Henüz delil kaydı bulunmuyor.'),
                )
              else
                ...result!.items.map(
                  (item) => Card(
                    child: ListTile(
                      key: ValueKey('evidence-${item.id}'),
                      onTap: () =>
                          widget.detailOpener?.call(context, item.id) ??
                          AppRouter.openCaseEvidenceItemDetail(
                            context,
                            evidenceRefId: item.id,
                          ),
                      title: Text(item.label),
                      subtitle: Text(
                        '${item.caseNumber} · ${item.caseTitle}\n${evidenceReviewLabel(item.review)} · ${evidenceCustodyLabel(item.custody)} · ${evidenceIntegrityLabel(item.integrity)}\nSon zincir işlemi: ${item.lastAt ?? 'Henüz yok'}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );
}

class _Stats extends StatelessWidget {
  const _Stats(this.stats);
  final Map<String, int> stats;
  @override
  Widget build(BuildContext context) {
    const labels = {
      'totalEvidence': 'Toplam Delil',
      'awaitingReview': 'İnceleme Bekliyor',
      'underReview': 'İncelemede',
      'verified': 'Doğrulandı',
      'sealed': 'Mühürlü',
      'chainNotStarted': 'Zinciri Başlatılmamış',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.entries
          .map((e) => Chip(label: Text('${e.value}: ${stats[e.key] ?? 0}')))
          .toList(),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  throw const FormatException('Nesne bekleniyordu.');
}

List<dynamic> _list(Object? value) {
  if (value is List) return value;
  throw const FormatException('Liste bekleniyordu.');
}

String _s(Map<String, dynamic> m, String key) {
  final value = m[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key geçersiz.');
}

Object? _normalize(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _normalize(v)));
  }
  if (value is List) return value.map(_normalize).toList();
  return value;
}
