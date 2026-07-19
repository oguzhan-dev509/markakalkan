part of 'persistence_v1.dart';

final class RiskAssessmentPersistenceReadinessEvaluatorV1 {
  const RiskAssessmentPersistenceReadinessEvaluatorV1();
  static const _policy = PersistenceReadinessPolicyV1();

  PersistenceReadinessDecisionV1 evaluate(
    RiskAssessmentPersistenceReadinessRequestV1 request,
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
    if (subject.contractVersion != riskAssessmentContractVersionV1) {
      issues.add(
        _policy.blocker(
          'contract.unsupported_version',
          'subject.contractVersion',
          'Unsupported risk assessment contract.',
        ),
      );
    }
    if (subject.reasons.isEmpty) {
      issues.add(
        _policy.blocker(
          'risk.reasons_empty',
          'subject.reasons',
          'Risk reasons are required.',
        ),
      );
    }
    if (subject.nextReviewAt != null &&
        subject.nextReviewAt!.isBefore(subject.assessedAt)) {
      issues.add(
        _policy.blocker(
          'timestamp.next_review_invalid',
          'subject.nextReviewAt',
          'Next review cannot precede assessment.',
        ),
      );
    }
    if (subject.sourceSignalRefs.isEmpty &&
        subject.provenance.sourceRecordId == null &&
        !(subject.provenance.producerModule == 'digital_detective' &&
            subject.provenance.findingKey != null)) {
      issues.add(
        _policy.blocker(
          'risk.source_missing',
          'subject.sourceSignalRefs',
          'Risk requires a source signal or exact provenance.',
        ),
      );
    }
    if (subject.score == null) {
      issues.add(
        _policy.warning(
          'risk.score_missing',
          'subject.score',
          'Risk has no score.',
        ),
      );
    } else if (subject.score!.originalScale == null) {
      issues.add(
        _policy.warning(
          'risk.score_scale_missing',
          'subject.score.originalScale',
          'Original score scale is not recorded.',
        ),
      );
    }
    if (subject.evidenceRefs.isEmpty) {
      issues.add(
        _policy.warning(
          'risk.evidence_empty',
          'subject.evidenceRefs',
          'Risk has no evidence reference.',
        ),
      );
    }
    if (subject.canonicalAssetRef == null) {
      issues.add(
        _policy.warning(
          'risk.asset_missing',
          'subject.canonicalAssetRef',
          'Risk has no canonical asset.',
        ),
      );
    }
    if (subject.nextReviewAt == null) {
      issues.add(
        _policy.warning(
          'risk.next_review_missing',
          'subject.nextReviewAt',
          'Risk has no next review time.',
        ),
      );
    }
    if (subject.relatedEntityRefs.isEmpty) {
      issues.add(
        _policy.warning(
          'risk.related_refs_empty',
          'subject.relatedEntityRefs',
          'Risk has no related entities.',
        ),
      );
    }
    _policy.duplicateRefWarnings(issues, [
      ...subject.sourceSignalRefs.map(
        (ref) => '${ref.entityType}:${ref.entityId}',
      ),
      ...subject.evidenceRefs.map(
        (ref) => '${ref.referenceType}:${ref.referenceId}',
      ),
      ...subject.relatedEntityRefs.map(
        (ref) => '${ref.entityType}:${ref.entityId}',
      ),
    ]);
    return PersistenceReadinessDecisionV1(
      policyVersion: request.policyVersion,
      subjectType: PersistenceSubjectTypeV1.riskAssessment,
      subjectId: subject.riskId,
      issues: issues,
      evaluatedAt: request.evaluatedAt,
      identityResolutionStatus: request.identityResolutionResult.status,
      evaluatedIdempotencyKey: request.sourceIngestionKey?.canonicalKey,
      provenance: request.provenance,
    );
  }
}
