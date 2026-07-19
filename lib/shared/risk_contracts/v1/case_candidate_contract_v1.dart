// ignore_for_file: prefer_initializing_formals

part of 'shared_risk_contracts_v1.dart';

final class CaseCandidateContractV1 {
  CaseCandidateContractV1({
    required String caseCandidateId,
    required IdentityScope identityScope,
    required CaseCandidateStatus status,
    required CaseCandidatePriority recommendedPriority,
    required String title,
    required String summary,
    required String deduplicationKey,
    required DateTime proposedAt,
    required ProvenanceEnvelope provenance,
    List<CanonicalEntityRef> sourceSignalRefs = const [],
    List<CanonicalEntityRef> sourceRiskRefs = const [],
    List<CanonicalAssetRef> canonicalAssetRefs = const [],
    List<EvidenceRef> evidenceRefs = const [],
    List<CanonicalEntityRef> relatedEntityRefs = const [],
    DateTime? reviewedAt,
    String? reviewedBy,
    CanonicalEntityRef? promotedCaseRef,
  }) : caseCandidateId = _requiredString(caseCandidateId, 'caseCandidateId'),
       identityScope = identityScope,
       sourceSignalRefs = List<CanonicalEntityRef>.unmodifiable(
         sourceSignalRefs,
       ),
       sourceRiskRefs = List<CanonicalEntityRef>.unmodifiable(sourceRiskRefs),
       canonicalAssetRefs = List<CanonicalAssetRef>.unmodifiable(
         canonicalAssetRefs,
       ),
       evidenceRefs = List<EvidenceRef>.unmodifiable(evidenceRefs),
       relatedEntityRefs = List<CanonicalEntityRef>.unmodifiable(
         relatedEntityRefs,
       ),
       status = status,
       recommendedPriority = recommendedPriority,
       title = _requiredString(title, 'title'),
       summary = _requiredString(summary, 'summary'),
       deduplicationKey = _requiredString(deduplicationKey, 'deduplicationKey'),
       proposedAt = proposedAt,
       reviewedAt = reviewedAt,
       reviewedBy = _optionalString(reviewedBy, 'reviewedBy'),
       promotedCaseRef = promotedCaseRef,
       provenance = provenance {
    if (status == CaseCandidateStatus.promoted && promotedCaseRef == null) {
      throw FormatException('promoted candidate requires promotedCaseRef');
    }
  }

  final String caseCandidateId;
  final String contractVersion = caseCandidateContractVersionV1;
  final IdentityScope identityScope;
  final List<CanonicalEntityRef> sourceSignalRefs;
  final List<CanonicalEntityRef> sourceRiskRefs;
  final List<CanonicalAssetRef> canonicalAssetRefs;
  final List<EvidenceRef> evidenceRefs;
  final List<CanonicalEntityRef> relatedEntityRefs;
  final CaseCandidateStatus status;
  final CaseCandidatePriority recommendedPriority;
  final String title;
  final String summary;
  final String deduplicationKey;
  final DateTime proposedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final CanonicalEntityRef? promotedCaseRef;
  final ProvenanceEnvelope provenance;

  factory CaseCandidateContractV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != caseCandidateContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    return CaseCandidateContractV1(
      caseCandidateId: _requiredString(
        json['caseCandidateId'],
        'caseCandidateId',
      ),
      identityScope: IdentityScope.fromJson(
        _requiredMap(json['identityScope'], 'identityScope'),
      ),
      sourceSignalRefs: _mapList(
        json['sourceSignalRefs'],
        'sourceSignalRefs',
      ).map(CanonicalEntityRef.fromJson).toList(growable: false),
      sourceRiskRefs: _mapList(
        json['sourceRiskRefs'],
        'sourceRiskRefs',
      ).map(CanonicalEntityRef.fromJson).toList(growable: false),
      canonicalAssetRefs: _mapList(
        json['canonicalAssetRefs'],
        'canonicalAssetRefs',
      ).map(CanonicalAssetRef.fromJson).toList(growable: false),
      evidenceRefs: _mapList(
        json['evidenceRefs'],
        'evidenceRefs',
      ).map(EvidenceRef.fromJson).toList(growable: false),
      relatedEntityRefs: _mapList(
        json['relatedEntityRefs'],
        'relatedEntityRefs',
      ).map(CanonicalEntityRef.fromJson).toList(growable: false),
      status: _caseStatusFrom(json['status']),
      recommendedPriority: _enumValue(json['recommendedPriority'], {
        for (final item in CaseCandidatePriority.values) item.name: item,
      }, 'recommendedPriority'),
      title: _requiredString(json['title'], 'title'),
      summary: _requiredString(json['summary'], 'summary'),
      deduplicationKey: _requiredString(
        json['deduplicationKey'],
        'deduplicationKey',
      ),
      proposedAt: _requiredDate(json['proposedAt'], 'proposedAt'),
      reviewedAt: _optionalDate(json['reviewedAt'], 'reviewedAt'),
      reviewedBy: _optionalString(json['reviewedBy'], 'reviewedBy'),
      promotedCaseRef: json['promotedCaseRef'] == null
          ? null
          : CanonicalEntityRef.fromJson(
              _requiredMap(json['promotedCaseRef'], 'promotedCaseRef'),
            ),
      provenance: ProvenanceEnvelope.fromJson(
        _requiredMap(json['provenance'], 'provenance'),
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'caseCandidateId': caseCandidateId,
    'contractVersion': contractVersion,
    'identityScope': identityScope.toJson(),
    'sourceSignalRefs': sourceSignalRefs.map((item) => item.toJson()).toList(),
    'sourceRiskRefs': sourceRiskRefs.map((item) => item.toJson()).toList(),
    'canonicalAssetRefs': canonicalAssetRefs
        .map((item) => item.toJson())
        .toList(),
    'evidenceRefs': evidenceRefs.map((item) => item.toJson()).toList(),
    'relatedEntityRefs': relatedEntityRefs
        .map((item) => item.toJson())
        .toList(),
    'status': _caseStatusValue(status),
    'recommendedPriority': recommendedPriority.name,
    'title': title,
    'summary': summary,
    'deduplicationKey': deduplicationKey,
    'proposedAt': proposedAt.toIso8601String(),
    if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
    if (reviewedBy != null) 'reviewedBy': reviewedBy,
    if (promotedCaseRef != null) 'promotedCaseRef': promotedCaseRef!.toJson(),
    'provenance': provenance.toJson(),
  };
}
