part of 'commands_v1.dart';

final class ReadinessDecisionBindingV1 {
  const ReadinessDecisionBindingV1({
    required this.decision,
    required this.subjectFingerprint,
  });
  final PersistenceReadinessDecisionV1 decision;
  final SubjectFingerprintV1 subjectFingerprint;
  Map<String, Object?> toJson() => {
    'decision': decision.toJson(),
    'subjectFingerprint': subjectFingerprint.toJson(),
  };
}

final class PersistenceIdempotencyBindingV1 {
  PersistenceIdempotencyBindingV1._({
    required this.purpose,
    required String canonicalKey,
    this.sourceIngestionKey,
    this.caseCandidateId,
    this.candidateDeduplicationKey,
    this.tenantId,
    this.targetNamespace,
  }) : canonicalKey = _required(canonicalKey, 'canonicalKey');

  factory PersistenceIdempotencyBindingV1.exactSource(
    SourceIngestionKeyV1 key,
  ) {
    if (key.kind != SourceIngestionKeyKind.exactOccurrence) {
      throw const FormatException('exact source occurrence key is required');
    }
    return PersistenceIdempotencyBindingV1._(
      purpose: PersistenceIdempotencyPurposeV1.exactSourceOccurrence,
      canonicalKey: key.canonicalKey,
      sourceIngestionKey: key,
    );
  }

  factory PersistenceIdempotencyBindingV1.caseCandidate({
    required String caseCandidateId,
    required String deduplicationKey,
    required String tenantId,
    required PersistenceTargetNamespaceV1 targetNamespace,
  }) {
    final id = _required(caseCandidateId, 'caseCandidateId');
    final dedup = _required(deduplicationKey, 'deduplicationKey');
    final tenant = _required(tenantId, 'tenantId');
    final canonical = _encode([
      'case-candidate-initial-persistence-v1',
      id,
      dedup,
      tenant,
      _targetValue(targetNamespace),
    ]);
    return PersistenceIdempotencyBindingV1._(
      purpose: PersistenceIdempotencyPurposeV1.caseCandidateInitialPersistence,
      canonicalKey: canonical,
      caseCandidateId: id,
      candidateDeduplicationKey: dedup,
      tenantId: tenant,
      targetNamespace: targetNamespace,
    );
  }

  final PersistenceIdempotencyPurposeV1 purpose;
  final String canonicalKey;
  final SourceIngestionKeyV1? sourceIngestionKey;
  final String? caseCandidateId;
  final String? candidateDeduplicationKey;
  final String? tenantId;
  final PersistenceTargetNamespaceV1? targetNamespace;
  Map<String, Object?> toJson() => {
    'purpose': purpose.name,
    'canonicalKey': canonicalKey,
    if (sourceIngestionKey != null)
      'sourceIngestionKey': sourceIngestionKey!.toJson(),
    if (caseCandidateId != null) 'caseCandidateId': caseCandidateId,
    if (candidateDeduplicationKey != null)
      'candidateDeduplicationKey': candidateDeduplicationKey,
    if (tenantId != null) 'tenantId': tenantId,
    if (targetNamespace != null)
      'targetNamespace': persistenceTargetNamespaceValueV1(targetNamespace!),
  };
}

final class PersistenceCommandProvenanceV1 {
  PersistenceCommandProvenanceV1({
    required String requestedByModule,
    required this.createdAt,
    String? sourceCommandId,
    String? correlationId,
    String? parentCommandId,
    String? requestId,
    Map<String, Object?> metadata = const {},
  }) : requestedByModule = _required(requestedByModule, 'requestedByModule'),
       sourceCommandId = _optional(sourceCommandId, 'sourceCommandId'),
       correlationId = _optional(correlationId, 'correlationId'),
       parentCommandId = _optional(parentCommandId, 'parentCommandId'),
       requestId = _optional(requestId, 'requestId'),
       metadata = _freeze(metadata, 'metadata')! as Map<String, Object?>;
  final String requestedByModule;
  final String? sourceCommandId;
  final String? correlationId;
  final String? parentCommandId;
  final String? requestId;
  final DateTime createdAt;
  final Map<String, Object?> metadata;
  Map<String, Object?> toJson() => {
    'requestedByModule': requestedByModule,
    if (sourceCommandId != null) 'sourceCommandId': sourceCommandId,
    if (correlationId != null) 'correlationId': correlationId,
    if (parentCommandId != null) 'parentCommandId': parentCommandId,
    if (requestId != null) 'requestId': requestId,
    'createdAt': createdAt.toIso8601String(),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}
