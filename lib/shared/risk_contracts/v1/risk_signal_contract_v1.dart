// ignore_for_file: prefer_initializing_formals

part of 'shared_risk_contracts_v1.dart';

final class RiskSignalContractV1 {
  RiskSignalContractV1({
    required String signalId,
    required IdentityScope identityScope,
    required SignalSource signalSource,
    required NamespacedValue signalType,
    required CanonicalSeverity canonicalSeverity,
    required String summary,
    required RiskSignalReviewStatus reviewStatus,
    required DateTime detectedAt,
    required DateTime createdAt,
    required ProvenanceEnvelope provenance,
    CanonicalAssetRef? canonicalAssetRef,
    String? originalSeverity,
    ConfidenceValue? confidence,
    List<EvidenceRef> evidenceRefs = const [],
    List<CanonicalEntityRef> relatedEntityRefs = const [],
    DateTime? occurredAt,
  }) : signalId = _requiredString(signalId, 'signalId'),
       identityScope = identityScope,
       canonicalAssetRef = canonicalAssetRef,
       signalSource = signalSource,
       signalType = signalType,
       canonicalSeverity = canonicalSeverity,
       originalSeverity = _optionalString(originalSeverity, 'originalSeverity'),
       confidence = confidence,
       summary = _requiredString(summary, 'summary'),
       evidenceRefs = List<EvidenceRef>.unmodifiable(evidenceRefs),
       relatedEntityRefs = List<CanonicalEntityRef>.unmodifiable(
         relatedEntityRefs,
       ),
       reviewStatus = reviewStatus,
       occurredAt = occurredAt,
       detectedAt = detectedAt,
       createdAt = createdAt,
       provenance = provenance;

  final String signalId;
  final String contractVersion = riskSignalContractVersionV1;
  final IdentityScope identityScope;
  final CanonicalAssetRef? canonicalAssetRef;
  final SignalSource signalSource;
  final NamespacedValue signalType;
  final CanonicalSeverity canonicalSeverity;
  final String? originalSeverity;
  final ConfidenceValue? confidence;
  final String summary;
  final List<EvidenceRef> evidenceRefs;
  final List<CanonicalEntityRef> relatedEntityRefs;
  final RiskSignalReviewStatus reviewStatus;
  final DateTime? occurredAt;
  final DateTime detectedAt;
  final DateTime createdAt;
  final ProvenanceEnvelope provenance;

  factory RiskSignalContractV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != riskSignalContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    return RiskSignalContractV1(
      signalId: _requiredString(json['signalId'], 'signalId'),
      identityScope: IdentityScope.fromJson(
        _requiredMap(json['identityScope'], 'identityScope'),
      ),
      canonicalAssetRef: json['canonicalAssetRef'] == null
          ? null
          : CanonicalAssetRef.fromJson(
              _requiredMap(json['canonicalAssetRef'], 'canonicalAssetRef'),
            ),
      signalSource: SignalSource.fromJson(
        _requiredMap(json['signalSource'], 'signalSource'),
      ),
      signalType: NamespacedValue.fromJson(
        _requiredMap(json['signalType'], 'signalType'),
      ),
      canonicalSeverity: _severityFrom(json['canonicalSeverity']),
      originalSeverity: _optionalString(
        json['originalSeverity'],
        'originalSeverity',
      ),
      confidence: json['confidence'] == null
          ? null
          : ConfidenceValue.fromJson(
              _requiredMap(json['confidence'], 'confidence'),
            ),
      summary: _requiredString(json['summary'], 'summary'),
      evidenceRefs: _mapList(
        json['evidenceRefs'],
        'evidenceRefs',
      ).map(EvidenceRef.fromJson).toList(growable: false),
      relatedEntityRefs: _mapList(
        json['relatedEntityRefs'],
        'relatedEntityRefs',
      ).map(CanonicalEntityRef.fromJson).toList(growable: false),
      reviewStatus: _signalReviewFrom(json['reviewStatus']),
      occurredAt: _optionalDate(json['occurredAt'], 'occurredAt'),
      detectedAt: _requiredDate(json['detectedAt'], 'detectedAt'),
      createdAt: _requiredDate(json['createdAt'], 'createdAt'),
      provenance: ProvenanceEnvelope.fromJson(
        _requiredMap(json['provenance'], 'provenance'),
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'signalId': signalId,
    'contractVersion': contractVersion,
    'identityScope': identityScope.toJson(),
    if (canonicalAssetRef != null)
      'canonicalAssetRef': canonicalAssetRef!.toJson(),
    'signalSource': signalSource.toJson(),
    'signalType': signalType.toJson(),
    'canonicalSeverity': _severityValue(canonicalSeverity),
    if (originalSeverity != null) 'originalSeverity': originalSeverity,
    if (confidence != null) 'confidence': confidence!.toJson(),
    'summary': summary,
    'evidenceRefs': evidenceRefs.map((item) => item.toJson()).toList(),
    'relatedEntityRefs': relatedEntityRefs
        .map((item) => item.toJson())
        .toList(),
    'reviewStatus': _signalReviewValue(reviewStatus),
    if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
    'detectedAt': detectedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'provenance': provenance.toJson(),
  };
}
