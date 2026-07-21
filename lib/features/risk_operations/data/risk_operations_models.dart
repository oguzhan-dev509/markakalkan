enum RiskOperationsLoadState {
  loading,
  ready,
  empty,
  error,
  permissionDenied,
  noActiveTenant,
}

class EvidenceQualityProjection {
  const EvidenceQualityProjection({
    required this.level,
    required this.reasonCodes,
    required this.evaluatorVersion,
  });
  final String level;
  final List<String> reasonCodes;
  final String evaluatorVersion;
  factory EvidenceQualityProjection.fromMap(Map<String, dynamic> map) =>
      EvidenceQualityProjection(
        level: _string(map['level'], 'unavailable'),
        reasonCodes: _strings(map['reasonCodes']),
        evaluatorVersion: _string(map['evaluatorVersion']),
      );
}

class CaseCandidacyProjection {
  const CaseCandidacyProjection({
    required this.status,
    required this.reasonCodes,
    required this.evaluatedAt,
    required this.evaluatorVersion,
    required this.requiresHumanReview,
  });
  final String status;
  final List<String> reasonCodes;
  final DateTime? evaluatedAt;
  final String evaluatorVersion;
  final bool requiresHumanReview;
  factory CaseCandidacyProjection.fromMap(Map<String, dynamic> map) =>
      CaseCandidacyProjection(
        status: _string(map['status'], 'not_candidate'),
        reasonCodes: _strings(map['reasonCodes']),
        evaluatedAt: _date(map['evaluatedAt']),
        evaluatorVersion: _string(map['evaluatorVersion']),
        requiresHumanReview: map['requiresHumanReview'] == true,
      );
}

class RiskTimelineEvent {
  const RiskTimelineEvent({
    required this.eventId,
    required this.eventType,
    required this.occurredAt,
    required this.occurredAtStatus,
    required this.sourceSystem,
    required this.summary,
    required this.evidenceReferenceCount,
  });
  final String eventId;
  final String eventType;
  final DateTime? occurredAt;
  final String occurredAtStatus;
  final String sourceSystem;
  final String summary;
  final int evidenceReferenceCount;
  factory RiskTimelineEvent.fromMap(Map<String, dynamic> map) =>
      RiskTimelineEvent(
        eventId: _string(map['eventId']),
        eventType: _string(map['eventType']),
        occurredAt: _date(map['occurredAt']),
        occurredAtStatus: _string(map['occurredAtStatus'], 'unknown'),
        sourceSystem: _string(map['sourceSystem']),
        summary: _string(map['summary']),
        evidenceReferenceCount: _integer(map['evidenceReferenceCount']),
      );
}

class RiskRelationshipNode {
  const RiskRelationshipNode({
    required this.canonicalId,
    required this.type,
    required this.maskedLabel,
    required this.sourceSystem,
    required this.confidence,
    required this.evidenceQuality,
  });
  final String canonicalId;
  final String type;
  final String maskedLabel;
  final String sourceSystem;
  final double? confidence;
  final String evidenceQuality;
  factory RiskRelationshipNode.fromMap(Map<String, dynamic> map) =>
      RiskRelationshipNode(
        canonicalId: _string(map['canonicalId']),
        type: _string(map['type']),
        maskedLabel: _string(map['maskedLabel'], '***'),
        sourceSystem: _string(map['sourceSystem']),
        confidence: _double(map['confidence']),
        evidenceQuality: _string(map['evidenceQuality'], 'unavailable'),
      );
}

class RiskOperationItem {
  const RiskOperationItem({
    required this.signalId,
    required this.sourceSystem,
    required this.sourceRecordId,
    required this.sourceRecordVersion,
    required this.tenantId,
    required this.canonicalBrandId,
    required this.canonicalSubjectId,
    required this.subjectType,
    required this.title,
    required this.summary,
    required this.occurredAt,
    required this.currentStatus,
    required this.riskClass,
    required this.severity,
    required this.confidence,
    required this.evidenceQuality,
    required this.caseCandidacy,
    required this.timeline,
    required this.relationshipNodes,
    required this.adapterVersion,
  });
  final String signalId;
  final String sourceSystem;
  final String sourceRecordId;
  final String sourceRecordVersion;
  final String tenantId;
  final String canonicalBrandId;
  final String canonicalSubjectId;
  final String subjectType;
  final String title;
  final String summary;
  final DateTime? occurredAt;
  final String currentStatus;
  final String riskClass;
  final String severity;
  final double? confidence;
  final EvidenceQualityProjection evidenceQuality;
  final CaseCandidacyProjection caseCandidacy;
  final List<RiskTimelineEvent> timeline;
  final List<RiskRelationshipNode> relationshipNodes;
  final String adapterVersion;
  factory RiskOperationItem.fromMap(Map<String, dynamic> map) {
    final graph = _map(map['relationshipGraph']);
    return RiskOperationItem(
      signalId: _required(map['signalId'], 'signalId'),
      sourceSystem: _required(map['sourceSystem'], 'sourceSystem'),
      sourceRecordId: _required(map['sourceRecordId'], 'sourceRecordId'),
      sourceRecordVersion: _string(map['sourceRecordVersion'], 'v1'),
      tenantId: _required(map['tenantId'], 'tenantId'),
      canonicalBrandId: _required(map['canonicalBrandId'], 'canonicalBrandId'),
      canonicalSubjectId: _required(
        map['canonicalSubjectId'],
        'canonicalSubjectId',
      ),
      subjectType: _required(map['subjectType'], 'subjectType'),
      title: _required(map['title'], 'title'),
      summary: _required(map['summary'], 'summary'),
      occurredAt: _date(map['occurredAt']),
      currentStatus: _string(map['currentStatus'], 'unknown'),
      riskClass: _string(map['riskClass'], 'other'),
      severity: _string(map['severity'], 'info'),
      confidence: _double(map['confidence']),
      evidenceQuality: EvidenceQualityProjection.fromMap(
        _map(map['evidenceQuality']),
      ),
      caseCandidacy: CaseCandidacyProjection.fromMap(
        _map(map['caseCandidacy']),
      ),
      timeline: _maps(
        map['timeline'],
      ).map(RiskTimelineEvent.fromMap).toList(growable: false),
      relationshipNodes: _maps(
        graph['nodes'],
      ).map(RiskRelationshipNode.fromMap).toList(growable: false),
      adapterVersion: _required(map['adapterVersion'], 'adapterVersion'),
    );
  }
}

class RiskOperationsSummary {
  const RiskOperationsSummary({
    required this.totalVisibleSignals,
    required this.highOrCriticalRisk,
    required this.awaitingHumanReview,
    required this.strongCaseCandidates,
    required this.insufficientEvidence,
  });
  final int totalVisibleSignals;
  final int highOrCriticalRisk;
  final int awaitingHumanReview;
  final int strongCaseCandidates;
  final int insufficientEvidence;
  factory RiskOperationsSummary.fromMap(Map<String, dynamic> map) =>
      RiskOperationsSummary(
        totalVisibleSignals: _integer(map['totalVisibleSignals']),
        highOrCriticalRisk: _integer(map['highOrCriticalRisk']),
        awaitingHumanReview: _integer(map['awaitingHumanReview']),
        strongCaseCandidates: _integer(map['strongCaseCandidates']),
        insufficientEvidence: _integer(map['insufficientEvidence']),
      );
}

class RiskOperationsPageResult {
  const RiskOperationsPageResult({
    required this.summary,
    required this.items,
    required this.nextPageToken,
    required this.partialSourceUnavailable,
  });
  final RiskOperationsSummary summary;
  final List<RiskOperationItem> items;
  final String? nextPageToken;
  final bool partialSourceUnavailable;
  factory RiskOperationsPageResult.fromMap(Map<String, dynamic> map) {
    if (map['contractVersion'] != 'risk-operations-read-v1' ||
        map['readOnly'] != true ||
        map['writesPerformed'] != 0) {
      throw const FormatException('Risk operations response contract invalid');
    }
    final availability = _maps(map['sourceAvailability']);
    return RiskOperationsPageResult(
      summary: RiskOperationsSummary.fromMap(_map(map['summary'])),
      items: _maps(
        map['items'],
      ).map(RiskOperationItem.fromMap).toList(growable: false),
      nextPageToken: _nullable(map['nextPageToken']),
      partialSourceUnavailable: availability.any(
        (item) => item['status'] == 'unavailable',
      ),
    );
  }
}

String _string(Object? value, [String fallback = '']) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
String _required(Object? value, String field) {
  final result = _string(value);
  if (result.isEmpty) throw FormatException('$field required');
  return result;
}

String? _nullable(Object? value) {
  final result = _string(value);
  return result.isEmpty ? null : result;
}

int _integer(Object? value) => value is num ? value.toInt() : 0;
double? _double(Object? value) => value is num ? value.toDouble() : null;
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];
Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const [];
