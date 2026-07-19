import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/persistence/persistence_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

import 'persistence_test_fixtures.dart';

void main() {
  const evaluator = CaseCandidatePersistenceReadinessEvaluatorV1();

  test('valid proposed candidate allows without review or promotion key', () {
    final decision = evaluator.evaluate(
      candidateRequest(candidate(signals: [entity('signal-1')])),
    );
    expect(decision.allowed, isTrue);
    expect(decision.evaluatedIdempotencyKey, isNull);
  });
  test('candidate without signal and risk source denies', () {
    expect(evaluator.evaluate(candidateRequest(candidate())).allowed, isFalse);
  });
  test('empty dedup title and summary fail at typed contract boundary', () {
    for (final field in ['dedup', 'title', 'summary']) {
      expect(
        () => CaseCandidateContractV1(
          caseCandidateId: 'candidate-1',
          identityScope: identity(),
          sourceSignalRefs: [entity('signal-1')],
          status: CaseCandidateStatus.proposed,
          recommendedPriority: CaseCandidatePriority.high,
          title: field == 'title' ? '' : 'Title',
          summary: field == 'summary' ? '' : 'Summary',
          deduplicationKey: field == 'dedup' ? '' : 'dedup',
          proposedAt: createdAt,
          provenance: provenance(),
        ),
        throwsFormatException,
      );
    }
  });
  test('accepted requires reviewedAt and reviewedBy', () {
    final missingBoth = candidate(
      status: CaseCandidateStatus.accepted,
      signals: [entity('s')],
    );
    final decision = evaluator.evaluate(candidateRequest(missingBoth));
    expect(decision.allowed, isFalse);
    expect(
      decision.blockers.map((x) => x.code),
      containsAll([
        'case_candidate.review_time_missing',
        'case_candidate.reviewer_missing',
      ]),
    );
  });
  test('dismissed requires review fields', () {
    final decision = evaluator.evaluate(
      candidateRequest(
        candidate(
          status: CaseCandidateStatus.dismissed,
          signals: [entity('s')],
        ),
      ),
    );
    expect(decision.allowed, isFalse);
  });
  test('promoted missing case ref is rejected by typed contract', () {
    expect(
      () => candidate(
        status: CaseCandidateStatus.promoted,
        signals: [entity('s')],
        reviewedAt: evaluatedAt,
        reviewedBy: 'reviewer',
      ),
      throwsFormatException,
    );
  });
  test('promoted requires review fields in readiness policy', () {
    final promoted = candidate(
      status: CaseCandidateStatus.promoted,
      signals: [entity('s')],
      promotedCaseRef: entity('case-1'),
    );
    expect(evaluator.evaluate(candidateRequest(promoted)).allowed, isFalse);
  });
  test('review before proposal denies', () {
    final accepted = candidate(
      status: CaseCandidateStatus.accepted,
      signals: [entity('s')],
      reviewedAt: createdAt.subtract(const Duration(seconds: 1)),
      reviewedBy: 'reviewer',
    );
    expect(evaluator.evaluate(candidateRequest(accepted)).allowed, isFalse);
  });
  test('empty evidence assets and related refs are warnings only', () {
    final decision = evaluator.evaluate(
      candidateRequest(candidate(signals: [entity('s')])),
    );
    expect(decision.allowed, isTrue);
    expect(
      decision.warnings.map((x) => x.code),
      containsAll([
        'case_candidate.evidence_empty',
        'case_candidate.assets_empty',
        'case_candidate.related_refs_empty',
      ]),
    );
  });
  test('under review missing reviewedAt is warning only', () {
    final decision = evaluator.evaluate(
      candidateRequest(
        candidate(
          status: CaseCandidateStatus.underReview,
          signals: [entity('s')],
        ),
      ),
    );
    expect(decision.allowed, isTrue);
    expect(
      decision.warnings.map((x) => x.code),
      contains('case_candidate.review_time_missing'),
    );
  });
}
