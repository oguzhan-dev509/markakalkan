part of 'persistence_v1.dart';

final class PersistenceReadinessPolicyV1 {
  const PersistenceReadinessPolicyV1();

  static const allowedModules = {
    'traceability',
    'monitoring',
    'digital_market_monitoring',
    'digital_detective',
  };

  List<PersistenceReadinessIssueV1> commonIssues({
    required String policyVersion,
    required IdentityScope subjectIdentity,
    required IdentityResolutionResultV1 identityResult,
    required ProvenanceEnvelope subjectProvenance,
  }) {
    final issues = <PersistenceReadinessIssueV1>[];
    if (policyVersion != riskPersistenceReadinessPolicyVersionV1) {
      issues.add(
        blocker(
          'contract.unsupported_policy',
          'policyVersion',
          'Unsupported persistence policy.',
        ),
      );
    }
    if (!allowedModules.contains(subjectProvenance.producerModule)) {
      issues.add(
        blocker(
          'provenance.unknown_producer',
          'provenance.producerModule',
          'Producer module is not allowlisted.',
        ),
      );
    }
    if (identityResult.status != IdentityResolutionResultStatus.resolved ||
        identityResult.resolvedIdentityScope?.tenantId == null) {
      issues.add(
        blocker(
          'identity.not_resolved',
          'identityResolutionResult.status',
          'Resolved tenant identity is required.',
        ),
      );
    } else {
      final resolved = identityResult.resolvedIdentityScope!;
      _compareIdentity(
        issues,
        'tenantId',
        subjectIdentity.tenantId,
        resolved.tenantId,
      );
      _compareIdentity(
        issues,
        'brandId',
        subjectIdentity.brandId,
        resolved.brandId,
      );
      _compareIdentity(
        issues,
        'brandUid',
        subjectIdentity.brandUid,
        resolved.brandUid,
      );
      _compareIdentity(
        issues,
        'ownerUid',
        subjectIdentity.ownerUid,
        resolved.ownerUid,
      );
      if (resolved.brandId == null) {
        issues.add(
          warning(
            'identity.brand_unresolved',
            'resolvedIdentityScope.brandId',
            'Tenant is resolved without a brand ID.',
          ),
        );
      }
    }
    if (subjectProvenance.producerModule.trim().isEmpty) {
      issues.add(
        blocker(
          'provenance.producer_missing',
          'provenance.producerModule',
          'Producer module is required.',
        ),
      );
    }
    return issues;
  }

  List<PersistenceReadinessIssueV1> sourceKeyIssues(
    SourceIngestionKeyV1? key,
    ProvenanceEnvelope provenance,
  ) {
    if (key == null) {
      return [
        blocker(
          'idempotency.exact_key_missing',
          'sourceIngestionKey',
          'Exact source ingestion key is required.',
        ),
      ];
    }
    final issues = <PersistenceReadinessIssueV1>[];
    if (key.kind != SourceIngestionKeyKind.exactOccurrence) {
      issues.add(
        blocker(
          'idempotency.exact_key_required',
          'sourceIngestionKey.kind',
          'Stable recurrence key cannot persist an occurrence.',
        ),
      );
    }
    if (key.sourceModule != provenance.producerModule) {
      issues.add(
        blocker(
          'consistency.source_module_mismatch',
          'sourceIngestionKey.sourceModule',
          'Idempotency and provenance modules differ.',
        ),
      );
    }
    if (key.sourceType.trim().isEmpty ||
        key.stableSourceParts.isEmpty ||
        key.canonicalKey.trim().isEmpty) {
      issues.add(
        blocker(
          'idempotency.key_invalid',
          'sourceIngestionKey',
          'Idempotency key is incomplete.',
        ),
      );
    }
    if (provenance.producerModule == 'digital_detective' &&
        (key.stableSourceParts.length != 3 ||
            provenance.taskId == null ||
            provenance.executionId == null ||
            provenance.findingKey == null)) {
      issues.add(
        blocker(
          'provenance.ddt_occurrence_incomplete',
          'provenance',
          'Digital Detective occurrence provenance is incomplete.',
        ),
      );
    }
    if ((provenance.producerModule == 'traceability' ||
            provenance.producerModule == 'monitoring' ||
            provenance.producerModule == 'digital_market_monitoring') &&
        provenance.sourceRecordId == null) {
      issues.add(
        blocker(
          'provenance.source_record_missing',
          'provenance.sourceRecordId',
          'Exact source record ID is required.',
        ),
      );
    }
    return issues;
  }

  void duplicateRefWarnings(
    List<PersistenceReadinessIssueV1> issues,
    Iterable<String> refs,
  ) {
    final seen = <String>{};
    for (final ref in refs.toList()..sort()) {
      if (!seen.add(ref)) {
        issues.add(
          warning(
            'reference.duplicate',
            'references',
            'Duplicate typed reference.',
            relatedReference: ref,
          ),
        );
      }
    }
  }

  PersistenceReadinessIssueV1 blocker(
    String code,
    String path,
    String message, {
    String? relatedReference,
  }) => PersistenceReadinessIssueV1(
    code: code,
    severity: PersistenceReadinessIssueSeverityV1.blocker,
    fieldPath: path,
    message: message,
    relatedReference: relatedReference,
  );
  PersistenceReadinessIssueV1 warning(
    String code,
    String path,
    String message, {
    String? relatedReference,
  }) => PersistenceReadinessIssueV1(
    code: code,
    severity: PersistenceReadinessIssueSeverityV1.warning,
    fieldPath: path,
    message: message,
    relatedReference: relatedReference,
  );

  void _compareIdentity(
    List<PersistenceReadinessIssueV1> issues,
    String field,
    String? source,
    String? resolved,
  ) {
    if (source != null && resolved != null && source != resolved) {
      issues.add(
        blocker(
          'identity.scope_conflict',
          'identityScope.$field',
          'Subject and resolved identity conflict.',
        ),
      );
    }
  }
}
