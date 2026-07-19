import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/persistence/persistence_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

import 'persistence_test_fixtures.dart';

void main() {
  const evaluator = RiskAssessmentPersistenceReadinessEvaluatorV1();

  test('valid assessment with exact provenance allows', () {
    expect(evaluator.evaluate(riskRequest()).allowed, isTrue);
  });
  test('empty reasons deny', () {
    expect(
      evaluator.evaluate(riskRequest(subject: risk(reasons: const []))).allowed,
      isFalse,
    );
  });
  test('missing score allows with warning', () {
    final decision = evaluator.evaluate(riskRequest());
    expect(decision.allowed, isTrue);
    expect(
      decision.warnings.map((x) => x.code),
      contains('risk.score_missing'),
    );
  });
  test('invalid score range is rejected by typed contract boundary', () {
    expect(
      () => ScoreValue(value: 101, minimum: 0, maximum: 100),
      throwsRangeError,
    );
    expect(
      () => ScoreValue(value: 1, minimum: 10, maximum: 10),
      throwsRangeError,
    );
  });
  test(
    'source signals can substitute for otherwise absent source provenance',
    () {
      final subject = risk(
        sourceSignals: [entity('signal-1')],
        sourceProvenance: provenance(sourceRecordId: null),
      );
      final decision = evaluator.evaluate(riskRequest(subject: subject));
      expect(
        decision.blockers.map((x) => x.code),
        isNot(contains('risk.source_missing')),
      );
    },
  );
  test('missing signal refs and exact provenance denies', () {
    final subject = risk(sourceProvenance: provenance(sourceRecordId: null));
    expect(evaluator.evaluate(riskRequest(subject: subject)).allowed, isFalse);
  });
  test('next review before assessment denies', () {
    final subject = risk(
      nextReviewAt: createdAt.subtract(const Duration(minutes: 1)),
    );
    expect(evaluator.evaluate(riskRequest(subject: subject)).allowed, isFalse);
  });
  test('optional evidence asset review and related fields create warnings', () {
    final decision = evaluator.evaluate(riskRequest());
    expect(
      decision.warnings.map((x) => x.code),
      containsAll([
        'risk.evidence_empty',
        'risk.asset_missing',
        'risk.next_review_missing',
        'risk.related_refs_empty',
      ]),
    );
  });
  test('score without original scale is warning not blocker', () {
    final subject = risk(score: ScoreValue(value: 4, minimum: 0, maximum: 10));
    final decision = evaluator.evaluate(riskRequest(subject: subject));
    expect(decision.allowed, isTrue);
    expect(
      decision.warnings.map((x) => x.code),
      contains('risk.score_scale_missing'),
    );
  });
}
