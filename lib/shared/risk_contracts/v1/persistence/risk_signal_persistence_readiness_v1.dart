part of 'persistence_v1.dart';

final class RiskSignalPersistenceReadinessEvaluatorV1 {
  const RiskSignalPersistenceReadinessEvaluatorV1();
  static const _policy = PersistenceReadinessPolicyV1();

  PersistenceReadinessDecisionV1 evaluate(
    RiskSignalPersistenceReadinessRequestV1 request,
  ) {
    final subject = request.subject;
    final issues =
        _policy.commonIssues(
          policyVersion: request.policyVersion,
          subjectIdentity: subject.identityScope,
          identityResult: request.identityResolutionResult,
          subjectProvenance: subject.provenance,
        )..addAll(
          _policy.sourceKeyIssues(
            request.sourceIngestionKey,
            subject.provenance,
          ),
        );
    if (subject.contractVersion != riskSignalContractVersionV1) {
      issues.add(
        _policy.blocker(
          'contract.unsupported_version',
          'subject.contractVersion',
          'Unsupported risk signal contract.',
        ),
      );
    }
    if (subject.signalSource.module != subject.provenance.producerModule ||
        request.sourceIngestionKey?.sourceModule !=
            subject.signalSource.module) {
      issues.add(
        _policy.blocker(
          'consistency.source_module_mismatch',
          'subject.signalSource.module',
          'Signal source, provenance and key modules must match.',
        ),
      );
    }
    if (subject.canonicalAssetRef == null) {
      issues.add(
        _policy.warning(
          'signal.asset_missing',
          'subject.canonicalAssetRef',
          'Signal has no canonical asset reference.',
        ),
      );
    }
    if (subject.evidenceRefs.isEmpty) {
      issues.add(
        _policy.warning(
          'signal.evidence_empty',
          'subject.evidenceRefs',
          'Signal has no evidence reference.',
        ),
      );
    }
    if (subject.relatedEntityRefs.isEmpty) {
      issues.add(
        _policy.warning(
          'signal.related_refs_empty',
          'subject.relatedEntityRefs',
          'Signal has no related entity reference.',
        ),
      );
    }
    if (subject.confidence == null) {
      issues.add(
        _policy.warning(
          'signal.confidence_missing',
          'subject.confidence',
          'Signal has no confidence value.',
        ),
      );
    }
    _policy.duplicateRefWarnings(issues, [
      ...subject.evidenceRefs.map(
        (ref) => '${ref.referenceType}:${ref.referenceId}',
      ),
      ...subject.relatedEntityRefs.map(
        (ref) => '${ref.entityType}:${ref.entityId}',
      ),
    ]);
    return PersistenceReadinessDecisionV1(
      policyVersion: request.policyVersion,
      subjectType: PersistenceSubjectTypeV1.riskSignal,
      subjectId: subject.signalId,
      issues: issues,
      evaluatedAt: request.evaluatedAt,
      identityResolutionStatus: request.identityResolutionResult.status,
      evaluatedIdempotencyKey: request.sourceIngestionKey?.canonicalKey,
      provenance: request.provenance,
    );
  }
}
