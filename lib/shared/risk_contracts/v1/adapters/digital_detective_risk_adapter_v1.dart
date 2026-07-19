import '../shared_risk_contracts_v1.dart';

final class DigitalDetectiveFindingContextV1 {
  const DigitalDetectiveFindingContextV1({
    required this.taskId,
    required this.executionId,
    required this.workflowRef,
    required this.detectedAt,
    required this.createdAt,
    required this.adaptedAt,
    this.tenantId,
    this.brandId,
    this.brandUid,
    this.ownerUid,
    this.sourceId,
    this.snapshotId,
    this.contentHash,
  });

  final String taskId;
  final String executionId;
  final String workflowRef;
  final String? tenantId;
  final String? brandId;
  final String? brandUid;
  final String? ownerUid;
  final String? sourceId;
  final String? snapshotId;
  final String? contentHash;
  final DateTime detectedAt;
  final DateTime createdAt;
  final DateTime adaptedAt;
}

final class DigitalDetectiveRiskAdapterV1 {
  const DigitalDetectiveRiskAdapterV1();

  RiskSignalContractV1 toSignal(
    Map<String, dynamic> finding, {
    required DigitalDetectiveFindingContextV1 context,
  }) {
    final findingKey = _required(finding['findingKey'], 'findingKey');
    final candidateId = _required(finding['candidateId'], 'candidateId');
    final sourceUrl = _required(finding['sourceUrl'], 'sourceUrl');
    final signalType = _required(finding['signalType'], 'signalType');
    final severity = _required(finding['severity'], 'severity');
    final description = _required(finding['description'], 'description');
    final confidence = finding['confidence'];
    if (confidence is! num || !confidence.isFinite) {
      throw const FormatException('confidence must be a finite number');
    }
    final requiresHumanReview = finding['requiresHumanReview'];
    if (requiresHumanReview is! bool) {
      throw const FormatException('requiresHumanReview must be a boolean');
    }
    final automatedConclusion = _required(
      finding['automatedConclusion'],
      'automatedConclusion',
    );
    final references = finding['evidenceReferences'];
    if (references is! List) {
      throw const FormatException('evidenceReferences must be an array');
    }

    final sourceId = _optional(context.sourceId);
    final identity = _identity(context);
    return RiskSignalContractV1(
      signalId: 'digital-detective:finding:$findingKey',
      identityScope: identity,
      signalSource: SignalSource(
        module: 'digital_detective',
        sourceType: 'digital_field_scanner_finding',
        sourceId: sourceId,
      ),
      signalType: NamespacedValue(
        namespace: 'digital_detective.digital_field_scanner',
        value: signalType,
      ),
      canonicalSeverity: canonicalSeverity(severity),
      originalSeverity: severity,
      confidence: ConfidenceValue(
        normalizedScore: confidence.toDouble(),
        originalValue: confidence,
        originalScale: 'digital_field_scanner.confidence.0_1',
        sourceNamespace: 'digital_detective.digital_field_scanner',
      ),
      summary: description,
      evidenceRefs: references
          .map(
            (value) => EvidenceRef(
              evidenceType: 'structured_evidence',
              referenceType: 'snapshot_id',
              referenceId: _required(value, 'evidenceReferences[]'),
              sourceModule: 'digital_detective',
              metadata: {
                'requiresHumanReview': requiresHumanReview,
                'automatedConclusion': automatedConclusion,
              },
            ),
          )
          .toList(growable: false),
      relatedEntityRefs: [
        CanonicalEntityRef(
          module: 'digital_detective',
          entityType: 'candidate_source',
          entityId: candidateId,
        ),
        CanonicalEntityRef(
          module: 'digital_detective',
          entityType: 'source_url',
          entityId: sourceUrl,
        ),
      ],
      reviewStatus: requiresHumanReview
          ? RiskSignalReviewStatus.underReview
          : RiskSignalReviewStatus.newSignal,
      detectedAt: context.detectedAt,
      createdAt: context.createdAt,
      provenance: ProvenanceEnvelope(
        producerModule: 'digital_detective',
        producerVersion: 'digital-detective-risk-adapter-v1',
        sourceRecordId: candidateId,
        executionId: _required(context.executionId, 'executionId'),
        workflowRef: _required(context.workflowRef, 'workflowRef'),
        taskId: _required(context.taskId, 'taskId'),
        sourceId: sourceId,
        snapshotId: _optional(context.snapshotId),
        findingKey: findingKey,
        contentHash: _optional(context.contentHash),
        sourceCreatedAt: context.createdAt,
        adaptedAt: context.adaptedAt,
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
          'Unsupported Digital Detective severity: $sourceValue',
        ),
      };

  IdentityScope _identity(DigitalDetectiveFindingContextV1 context) {
    final tenantId = _optional(context.tenantId);
    final brandId = _optional(context.brandId);
    final brandUid = _optional(context.brandUid);
    final ownerUid = _optional(context.ownerUid);
    final hasAny = [
      tenantId,
      brandId,
      brandUid,
      ownerUid,
    ].any((value) => value != null);
    return IdentityScope(
      tenantId: tenantId,
      brandId: brandId,
      brandUid: brandUid,
      ownerUid: ownerUid,
      resolutionStatus: tenantId != null
          ? IdentityResolutionStatus.resolved
          : hasAny
          ? IdentityResolutionStatus.partial
          : IdentityResolutionStatus.unresolved,
      resolutionSource: 'digital_detective.finding_envelope',
      unresolvedReasons: [if (tenantId == null) 'tenant_id_unresolved'],
    );
  }

  String _required(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field is required');
    }
    return value.trim();
  }

  String? _optional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
