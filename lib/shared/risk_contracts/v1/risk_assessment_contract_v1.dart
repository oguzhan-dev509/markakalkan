// ignore_for_file: prefer_initializing_formals

part of 'shared_risk_contracts_v1.dart';

final class RiskAssessmentContractV1 {
  RiskAssessmentContractV1({
    required String riskId,
    required IdentityScope identityScope,
    required NamespacedValue riskCategory,
    required CanonicalSeverity canonicalSeverity,
    required List<String> reasons,
    required RiskAssessmentStatus status,
    required DateTime assessedAt,
    required DateTime createdAt,
    required ProvenanceEnvelope provenance,
    CanonicalAssetRef? canonicalAssetRef,
    String? originalSeverity,
    ScoreValue? score,
    List<CanonicalEntityRef> sourceSignalRefs = const [],
    List<EvidenceRef> evidenceRefs = const [],
    List<CanonicalEntityRef> relatedEntityRefs = const [],
    DateTime? nextReviewAt,
    String? createdBy,
  }) : riskId = _requiredString(riskId, 'riskId'),
       identityScope = identityScope,
       canonicalAssetRef = canonicalAssetRef,
       riskCategory = riskCategory,
       canonicalSeverity = canonicalSeverity,
       originalSeverity = _optionalString(originalSeverity, 'originalSeverity'),
       score = score,
       reasons = List<String>.unmodifiable(
         reasons.map((item) => _requiredString(item, 'reasons')),
       ),
       sourceSignalRefs = List<CanonicalEntityRef>.unmodifiable(
         sourceSignalRefs,
       ),
       evidenceRefs = List<EvidenceRef>.unmodifiable(evidenceRefs),
       relatedEntityRefs = List<CanonicalEntityRef>.unmodifiable(
         relatedEntityRefs,
       ),
       status = status,
       assessedAt = assessedAt,
       nextReviewAt = nextReviewAt,
       createdAt = createdAt,
       createdBy = _optionalString(createdBy, 'createdBy'),
       provenance = provenance;

  final String riskId;
  final String contractVersion = riskAssessmentContractVersionV1;
  final IdentityScope identityScope;
  final CanonicalAssetRef? canonicalAssetRef;
  final NamespacedValue riskCategory;
  final CanonicalSeverity canonicalSeverity;
  final String? originalSeverity;
  final ScoreValue? score;
  final List<String> reasons;
  final List<CanonicalEntityRef> sourceSignalRefs;
  final List<EvidenceRef> evidenceRefs;
  final List<CanonicalEntityRef> relatedEntityRefs;
  final RiskAssessmentStatus status;
  final DateTime assessedAt;
  final DateTime? nextReviewAt;
  final DateTime createdAt;
  final String? createdBy;
  final ProvenanceEnvelope provenance;

  factory RiskAssessmentContractV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != riskAssessmentContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    return RiskAssessmentContractV1(
      riskId: _requiredString(json['riskId'], 'riskId'),
      identityScope: IdentityScope.fromJson(
        _requiredMap(json['identityScope'], 'identityScope'),
      ),
      canonicalAssetRef: json['canonicalAssetRef'] == null
          ? null
          : CanonicalAssetRef.fromJson(
              _requiredMap(json['canonicalAssetRef'], 'canonicalAssetRef'),
            ),
      riskCategory: NamespacedValue.fromJson(
        _requiredMap(json['riskCategory'], 'riskCategory'),
      ),
      canonicalSeverity: _severityFrom(json['canonicalSeverity']),
      originalSeverity: _optionalString(
        json['originalSeverity'],
        'originalSeverity',
      ),
      score: json['score'] == null
          ? null
          : ScoreValue.fromJson(_requiredMap(json['score'], 'score')),
      reasons: _stringList(json['reasons'], 'reasons'),
      sourceSignalRefs: _mapList(
        json['sourceSignalRefs'],
        'sourceSignalRefs',
      ).map(CanonicalEntityRef.fromJson).toList(growable: false),
      evidenceRefs: _mapList(
        json['evidenceRefs'],
        'evidenceRefs',
      ).map(EvidenceRef.fromJson).toList(growable: false),
      relatedEntityRefs: _mapList(
        json['relatedEntityRefs'],
        'relatedEntityRefs',
      ).map(CanonicalEntityRef.fromJson).toList(growable: false),
      status: _riskStatusFrom(json['status']),
      assessedAt: _requiredDate(json['assessedAt'], 'assessedAt'),
      nextReviewAt: _optionalDate(json['nextReviewAt'], 'nextReviewAt'),
      createdAt: _requiredDate(json['createdAt'], 'createdAt'),
      createdBy: _optionalString(json['createdBy'], 'createdBy'),
      provenance: ProvenanceEnvelope.fromJson(
        _requiredMap(json['provenance'], 'provenance'),
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'riskId': riskId,
    'contractVersion': contractVersion,
    'identityScope': identityScope.toJson(),
    if (canonicalAssetRef != null)
      'canonicalAssetRef': canonicalAssetRef!.toJson(),
    'riskCategory': riskCategory.toJson(),
    'canonicalSeverity': _severityValue(canonicalSeverity),
    if (originalSeverity != null) 'originalSeverity': originalSeverity,
    if (score != null) 'score': score!.toJson(),
    'reasons': reasons,
    'sourceSignalRefs': sourceSignalRefs.map((item) => item.toJson()).toList(),
    'evidenceRefs': evidenceRefs.map((item) => item.toJson()).toList(),
    'relatedEntityRefs': relatedEntityRefs
        .map((item) => item.toJson())
        .toList(),
    'status': _riskStatusValue(status),
    'assessedAt': assessedAt.toIso8601String(),
    if (nextReviewAt != null) 'nextReviewAt': nextReviewAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    if (createdBy != null) 'createdBy': createdBy,
    'provenance': provenance.toJson(),
  };
}
