part of 'persistence_v1.dart';

final class CaseCandidatePersistenceReadinessEvaluatorV1 {
  const CaseCandidatePersistenceReadinessEvaluatorV1();
  static const _policy = PersistenceReadinessPolicyV1();

  PersistenceReadinessDecisionV1 evaluate(
    CaseCandidatePersistenceReadinessRequestV1 request,
  ) {
    final subject = request.subject;
    final issues = _policy.commonIssues(
      policyVersion: request.policyVersion,
      subjectIdentity: subject.identityScope,
      identityResult: request.identityResolutionResult,
      subjectProvenance: subject.provenance,
    );
    if (subject.contractVersion != caseCandidateContractVersionV1) {
      issues.add(
        _policy.blocker(
          'contract.unsupported_version',
          'subject.contractVersion',
          'Unsupported case candidate contract.',
        ),
      );
    }
    if (subject.sourceSignalRefs.isEmpty && subject.sourceRiskRefs.isEmpty) {
      issues.add(
        _policy.blocker(
          'case_candidate.source_missing',
          'subject.sourceSignalRefs',
          'Candidate requires a signal or risk source.',
        ),
      );
    }
    if (subject.reviewedAt != null &&
        subject.reviewedAt!.isBefore(subject.proposedAt)) {
      issues.add(
        _policy.blocker(
          'timestamp.review_invalid',
          'subject.reviewedAt',
          'Review cannot precede proposal.',
        ),
      );
    }
    final reviewRequired =
        subject.status == CaseCandidateStatus.accepted ||
        subject.status == CaseCandidateStatus.dismissed ||
        subject.status == CaseCandidateStatus.promoted;
    if (reviewRequired && subject.reviewedAt == null) {
      issues.add(
        _policy.blocker(
          'case_candidate.review_time_missing',
          'subject.reviewedAt',
          'Review time is required for this status.',
        ),
      );
    }
    if (reviewRequired && subject.reviewedBy == null) {
      issues.add(
        _policy.blocker(
          'case_candidate.reviewer_missing',
          'subject.reviewedBy',
          'Reviewer is required for this status.',
        ),
      );
    }
    if (subject.status == CaseCandidateStatus.underReview &&
        subject.reviewedAt == null) {
      issues.add(
        _policy.warning(
          'case_candidate.review_time_missing',
          'subject.reviewedAt',
          'Under-review candidate has no review time.',
        ),
      );
    }
    if (subject.status == CaseCandidateStatus.promoted &&
        subject.promotedCaseRef == null) {
      issues.add(
        _policy.blocker(
          'case_candidate.promoted_ref_missing',
          'subject.promotedCaseRef',
          'Promoted candidate requires a case reference.',
        ),
      );
    }
    if (subject.evidenceRefs.isEmpty) {
      issues.add(
        _policy.warning(
          'case_candidate.evidence_empty',
          'subject.evidenceRefs',
          'Candidate has no evidence reference.',
        ),
      );
    }
    if (subject.relatedEntityRefs.isEmpty) {
      issues.add(
        _policy.warning(
          'case_candidate.related_refs_empty',
          'subject.relatedEntityRefs',
          'Candidate has no related entities.',
        ),
      );
    }
    if (subject.canonicalAssetRefs.isEmpty) {
      issues.add(
        _policy.warning(
          'case_candidate.assets_empty',
          'subject.canonicalAssetRefs',
          'Candidate has no canonical asset.',
        ),
      );
    }
    _policy.duplicateRefWarnings(issues, [
      ...subject.sourceSignalRefs.map(
        (ref) => '${ref.entityType}:${ref.entityId}',
      ),
      ...subject.sourceRiskRefs.map(
        (ref) => '${ref.entityType}:${ref.entityId}',
      ),
      ...subject.evidenceRefs.map(
        (ref) => '${ref.referenceType}:${ref.referenceId}',
      ),
    ]);
    return PersistenceReadinessDecisionV1(
      policyVersion: request.policyVersion,
      subjectType: PersistenceSubjectTypeV1.caseCandidate,
      subjectId: subject.caseCandidateId,
      issues: issues,
      evaluatedAt: request.evaluatedAt,
      identityResolutionStatus: request.identityResolutionResult.status,
      evaluatedIdempotencyKey: request.sourceIngestionKey?.canonicalKey,
      provenance: request.provenance,
    );
  }
}
