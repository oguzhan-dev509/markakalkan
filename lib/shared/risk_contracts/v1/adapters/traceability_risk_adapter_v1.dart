import '../../../../features/traceability/data/traceability_models.dart';
import '../shared_risk_contracts_v1.dart';

final class TraceabilityRiskAdapterV1 {
  const TraceabilityRiskAdapterV1();

  RiskSignalContractV1 toSignal(
    SuspiciousVerificationScan scan, {
    required DateTime adaptedAt,
    String? ownerUid,
  }) {
    final createdAt = scan.createdAt;
    if (createdAt == null) {
      throw const FormatException('Traceability scan createdAt is required');
    }
    final severity = canonicalSeverity(scan.riskLevel);
    final identity = _identity(ownerUid);
    final related = _relatedRefs(scan);

    return RiskSignalContractV1(
      signalId: 'traceability:verification-scan:${_required(scan.id, 'id')}',
      identityScope: identity,
      canonicalAssetRef: _assetRef(scan),
      signalSource: SignalSource(
        module: 'traceability',
        sourceType: 'suspicious_verification_scan',
        sourceId: scan.id,
      ),
      signalType: NamespacedValue(
        namespace: 'traceability.verification',
        value: _required(scan.status, 'status'),
      ),
      canonicalSeverity: severity,
      originalSeverity: scan.riskLevel,
      summary: _summary(scan),
      evidenceRefs: const [],
      relatedEntityRefs: related,
      reviewStatus: reviewStatus(scan.reviewStatus),
      detectedAt: createdAt,
      createdAt: createdAt,
      provenance: ProvenanceEnvelope(
        producerModule: 'traceability',
        producerVersion: 'traceability-risk-adapter-v1',
        sourceRecordId: scan.id,
        sourceCreatedAt: createdAt,
        adaptedAt: adaptedAt,
      ),
    );
  }

  RiskAssessmentContractV1 toRiskAssessment(
    SuspiciousVerificationScan scan, {
    required DateTime adaptedAt,
    String? ownerUid,
  }) {
    final createdAt = scan.createdAt;
    if (createdAt == null) {
      throw const FormatException('Traceability scan createdAt is required');
    }
    return RiskAssessmentContractV1(
      riskId: 'traceability:verification-scan-risk:${_required(scan.id, 'id')}',
      identityScope: _identity(ownerUid),
      canonicalAssetRef: _assetRef(scan),
      riskCategory: NamespacedValue(
        namespace: 'traceability.verification',
        value: 'suspicious_scan',
      ),
      canonicalSeverity: canonicalSeverity(scan.riskLevel),
      originalSeverity: scan.riskLevel,
      score: ScoreValue(
        value: scan.riskScore,
        minimum: 0,
        maximum: 100,
        originalValue: scan.riskScore,
        originalScale: 'traceability.risk_score.0_100',
      ),
      reasons: scan.riskReasons,
      sourceSignalRefs: [
        CanonicalEntityRef(
          module: 'traceability',
          entityType: 'risk_signal',
          entityId: 'traceability:verification-scan:${scan.id}',
        ),
      ],
      relatedEntityRefs: _relatedRefs(scan),
      status: _riskStatus(scan.reviewStatus),
      assessedAt: createdAt,
      createdAt: createdAt,
      provenance: ProvenanceEnvelope(
        producerModule: 'traceability',
        producerVersion: 'traceability-risk-adapter-v1',
        sourceRecordId: scan.id,
        sourceCreatedAt: createdAt,
        adaptedAt: adaptedAt,
      ),
    );
  }

  CanonicalSeverity canonicalSeverity(String sourceValue) =>
      switch (sourceValue.trim()) {
        'low' => CanonicalSeverity.low,
        'medium' => CanonicalSeverity.medium,
        'high' => CanonicalSeverity.high,
        'critical' => CanonicalSeverity.critical,
        _ => throw FormatException(
          'Unsupported traceability riskLevel: $sourceValue',
        ),
      };

  RiskSignalReviewStatus reviewStatus(String sourceValue) =>
      switch (sourceValue.trim()) {
        'pending' => RiskSignalReviewStatus.newSignal,
        'reviewed' => RiskSignalReviewStatus.underReview,
        'dismissed' => RiskSignalReviewStatus.dismissed,
        'escalated' => RiskSignalReviewStatus.escalated,
        _ => throw FormatException(
          'Unsupported traceability reviewStatus: $sourceValue',
        ),
      };

  IdentityScope _identity(String? ownerUid) {
    final cleanOwner = _optional(ownerUid);
    return IdentityScope(
      ownerUid: cleanOwner,
      resolutionStatus: cleanOwner == null
          ? IdentityResolutionStatus.unresolved
          : IdentityResolutionStatus.partial,
      resolutionSource: 'traceability.verification_scan',
      unresolvedReasons: [
        if (cleanOwner == null) 'owner_uid_unavailable',
        'tenant_id_unresolved',
        'brand_id_unresolved',
      ],
    );
  }

  CanonicalAssetRef? _assetRef(SuspiciousVerificationScan scan) {
    final productId = _optional(scan.productId);
    final batchId = _optional(scan.batchId);
    if (productId == null && batchId == null) return null;
    return CanonicalAssetRef(
      assetType: batchId == null ? 'product' : 'product_batch',
      assetId: batchId ?? productId!,
      module: 'traceability',
      productId: productId,
    );
  }

  List<CanonicalEntityRef> _relatedRefs(SuspiciousVerificationScan scan) => [
    CanonicalEntityRef(
      module: 'traceability',
      entityType: 'verification_scan',
      entityId: _required(scan.id, 'id'),
    ),
    if (_optional(scan.publicCode) case final value?)
      CanonicalEntityRef(
        module: 'traceability',
        entityType: 'public_code',
        entityId: value,
        displayCode: value,
      ),
    if (_optional(scan.productId) case final value?)
      CanonicalEntityRef(
        module: 'traceability',
        entityType: 'product',
        entityId: value,
      ),
    if (_optional(scan.batchId) case final value?)
      CanonicalEntityRef(
        module: 'traceability',
        entityType: 'batch',
        entityId: value,
      ),
    if (_optional(scan.caseId) case final value?)
      CanonicalEntityRef(
        module: 'traceability',
        entityType: 'traceability_case',
        entityId: value,
      ),
  ];

  String _summary(SuspiciousVerificationScan scan) {
    final code = _optional(scan.publicCode) ?? scan.id;
    final reasons = scan.riskReasons.join(', ');
    return reasons.isEmpty
        ? 'Suspicious verification scan: $code'
        : 'Suspicious verification scan: $code ($reasons)';
  }

  RiskAssessmentStatus _riskStatus(String value) => switch (value.trim()) {
    'pending' => RiskAssessmentStatus.identified,
    'reviewed' => RiskAssessmentStatus.underReview,
    'dismissed' => RiskAssessmentStatus.closed,
    'escalated' => RiskAssessmentStatus.accepted,
    _ => throw FormatException('Unsupported traceability reviewStatus: $value'),
  };

  String _required(String value, String field) {
    final clean = value.trim();
    if (clean.isEmpty) throw FormatException('Traceability $field is required');
    return clean;
  }

  String? _optional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
