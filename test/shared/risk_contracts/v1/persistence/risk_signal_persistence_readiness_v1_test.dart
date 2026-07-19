import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/idempotency/idempotency_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/identity/identity_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/persistence/persistence_v1.dart';

import 'persistence_test_fixtures.dart';

void main() {
  const evaluator = RiskSignalPersistenceReadinessEvaluatorV1();

  test('supported policy and resolved tenant allow with warnings only', () {
    final decision = evaluator.evaluate(signalRequest());
    expect(decision.allowed, isTrue);
    expect(decision.blockers, isEmpty);
    expect(decision.warnings, isNotEmpty);
  });
  test('unknown policy denies', () {
    expect(
      evaluator.evaluate(signalRequest(policyVersion: 'v2')).allowed,
      isFalse,
    );
  });
  test('partial unresolved and conflict identity deny', () {
    for (final status in [
      IdentityResolutionResultStatus.partial,
      IdentityResolutionResultStatus.unresolved,
      IdentityResolutionResultStatus.conflict,
    ]) {
      expect(
        evaluator
            .evaluate(signalRequest(result: resolution(status: status)))
            .allowed,
        isFalse,
      );
    }
  });
  test('subject and resolved identity conflict denies', () {
    final result = resolution(tenantId: 'tenant-other');
    expect(evaluator.evaluate(signalRequest(result: result)).allowed, isFalse);
  });
  test('unknown producer module denies', () {
    final subject = signal(
      module: 'unknown',
      sourceProvenance: provenance(module: 'unknown'),
    );
    expect(
      evaluator
          .evaluate(signalRequest(subject: subject, key: keyFor('unknown')))
          .allowed,
      isFalse,
    );
  });
  test('valid Traceability and Monitoring signals allow', () {
    expect(evaluator.evaluate(signalRequest()).allowed, isTrue);
    final monitoring = signal(
      module: 'digital_market_monitoring',
      sourceProvenance: provenance(module: 'digital_market_monitoring'),
    );
    expect(
      evaluator
          .evaluate(
            signalRequest(
              subject: monitoring,
              key: keyFor('digital_market_monitoring'),
            ),
          )
          .allowed,
      isTrue,
    );
  });
  test('valid DDT exact occurrence allows', () {
    final ddtProvenance = provenance(
      module: 'digital_detective',
      sourceRecordId: 'candidate-1',
      taskId: 'task-1',
      executionId: 'execution-1',
      findingKey: 'finding-1',
    );
    final subject = signal(
      module: 'digital_detective',
      sourceProvenance: ddtProvenance,
    );
    expect(
      evaluator
          .evaluate(
            signalRequest(subject: subject, key: keyFor('digital_detective')),
          )
          .allowed,
      isTrue,
    );
  });
  test('DDT stable recurrence key denies persistence', () {
    final p = provenance(
      module: 'digital_detective',
      taskId: 'task-1',
      executionId: 'execution-1',
      findingKey: 'finding-1',
    );
    final subject = signal(module: 'digital_detective', sourceProvenance: p);
    final stable = const SourceIngestionKeyBuilderV1()
        .digitalDetectiveStableFinding(
          taskId: 'task-1',
          findingKey: 'finding-1',
        );
    expect(
      evaluator.evaluate(signalRequest(subject: subject, key: stable)).allowed,
      isFalse,
    );
  });
  test('missing key and module mismatch deny', () {
    final noKey = RiskSignalPersistenceReadinessRequestV1(
      subject: signal(),
      sourceIngestionKey: null,
      identityResolutionResult: resolution(),
      evaluatedAt: evaluatedAt,
      requestedByModule: 'test',
      policyVersion: riskPersistenceReadinessPolicyVersionV1,
      provenance: provenance(),
    );
    expect(evaluator.evaluate(noKey).allowed, isFalse);
    expect(
      evaluator
          .evaluate(signalRequest(key: keyFor('digital_market_monitoring')))
          .allowed,
      isFalse,
    );
  });
  test(
    'missing asset evidence related refs confidence and brand are warnings',
    () {
      final decision = evaluator.evaluate(
        signalRequest(result: resolution(brandId: null)),
      );
      expect(decision.allowed, isTrue);
      expect(
        decision.warnings.map((item) => item.code),
        containsAll([
          'signal.asset_missing',
          'signal.evidence_empty',
          'signal.related_refs_empty',
          'signal.confidence_missing',
          'identity.brand_unresolved',
        ]),
      );
    },
  );
  test('missing exact Traceability provenance denies', () {
    final subject = signal(sourceProvenance: provenance(sourceRecordId: null));
    expect(
      evaluator.evaluate(signalRequest(subject: subject)).allowed,
      isFalse,
    );
  });
  test('same request is deterministic and does not mutate inputs', () {
    final request = signalRequest();
    final before = jsonEncode(request.subject.toJson());
    final first = jsonEncode(evaluator.evaluate(request).toJson());
    final second = jsonEncode(evaluator.evaluate(request).toJson());
    expect(first, second);
    expect(jsonEncode(request.subject.toJson()), before);
  });
  test('duplicate ref ordering cannot change sorted issues', () {
    final refsA = [entity('b'), entity('a'), entity('a')];
    final refsB = refsA.reversed.toList();
    final a = evaluator.evaluate(
      signalRequest(subject: signal(related: refsA)),
    );
    final b = evaluator.evaluate(
      signalRequest(subject: signal(related: refsB)),
    );
    expect(
      jsonEncode(a.blockers.map((x) => x.toJson()).toList()),
      jsonEncode(b.blockers.map((x) => x.toJson()).toList()),
    );
    expect(
      jsonEncode(a.warnings.map((x) => x.toJson()).toList()),
      jsonEncode(b.warnings.map((x) => x.toJson()).toList()),
    );
  });
}
