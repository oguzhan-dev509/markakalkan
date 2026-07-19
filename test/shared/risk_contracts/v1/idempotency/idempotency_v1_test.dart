import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/idempotency/idempotency_v1.dart';

void main() {
  const builder = SourceIngestionKeyBuilderV1();

  test('same Traceability scan produces same exact key', () {
    final a = builder.traceabilityScan(scanId: 'scan-1');
    final b = builder.traceabilityScan(scanId: 'scan-1');
    expect(a.canonicalKey, b.canonicalKey);
    expect(a.stableSourceParts, ['scan-1']);
  });

  test('different Traceability scan IDs produce different keys', () {
    expect(
      builder.traceabilityScan(scanId: 'scan-1').canonicalKey,
      isNot(builder.traceabilityScan(scanId: 'scan-2').canonicalKey),
    );
  });

  test('same Monitoring signal produces same exact key', () {
    expect(
      builder.monitoringSignal(signalId: 'signal-1').canonicalKey,
      builder.monitoringSignal(signalId: 'signal-1').canonicalKey,
    );
  });

  test('DDT exact occurrence key is deterministic', () {
    expect(
      exact(builder, executionId: 'execution-1').canonicalKey,
      exact(builder, executionId: 'execution-1').canonicalKey,
    );
  });

  test('DDT execution ID changes exact occurrence key', () {
    expect(
      exact(builder, executionId: 'execution-1').canonicalKey,
      isNot(exact(builder, executionId: 'execution-2').canonicalKey),
    );
  });

  test('stable finding key is independent of execution', () {
    final stable = builder.digitalDetectiveStableFinding(
      taskId: 'task-1',
      findingKey: 'finding-1',
    );
    expect(stable.stableSourceParts, ['task-1', 'finding-1']);
    expect(stable.kind, SourceIngestionKeyKind.stableFinding);
    expect(stable.toJson().containsKey('executionId'), isFalse);
  });

  test('different finding key changes stable key', () {
    final a = builder.digitalDetectiveStableFinding(
      taskId: 'task-1',
      findingKey: 'a',
    );
    final b = builder.digitalDetectiveStableFinding(
      taskId: 'task-1',
      findingKey: 'b',
    );
    expect(a.canonicalKey, isNot(b.canonicalKey));
  });

  test('empty stable key part is rejected', () {
    expect(
      () => builder.digitalDetectiveStableFinding(
        taskId: 'task-1',
        findingKey: ' ',
      ),
      throwsFormatException,
    );
  });

  test('length-prefix encoding prevents ambiguous concatenation', () {
    final a = SourceIngestionKeyV1(
      sourceModule: 'test',
      sourceType: 'test',
      kind: SourceIngestionKeyKind.exactOccurrence,
      stableSourceParts: const ['ab', 'c'],
    );
    final b = SourceIngestionKeyV1(
      sourceModule: 'test',
      sourceType: 'test',
      kind: SourceIngestionKeyKind.exactOccurrence,
      stableSourceParts: const ['a', 'bc'],
    );
    expect(a.canonicalKey, isNot(b.canonicalKey));
  });

  test('same candidate and target produce same promotion key', () {
    final a = CasePromotionKeyV1(
      caseCandidateId: 'candidate-1',
      targetCaseNamespace: TargetCaseNamespace.traceabilityCase,
    );
    final b = CasePromotionKeyV1(
      caseCandidateId: 'candidate-1',
      targetCaseNamespace: TargetCaseNamespace.traceabilityCase,
    );
    expect(a.canonicalKey, b.canonicalKey);
  });

  test('different promotion target produces different key', () {
    final a = CasePromotionKeyV1(
      caseCandidateId: 'candidate-1',
      targetCaseNamespace: TargetCaseNamespace.traceabilityCase,
    );
    final b = CasePromotionKeyV1(
      caseCandidateId: 'candidate-1',
      targetCaseNamespace: TargetCaseNamespace.ipEnforcementCase,
    );
    expect(a.canonicalKey, isNot(b.canonicalKey));
  });

  test('unknown or empty target namespace is rejected', () {
    for (final value in ['', 'unknown_case']) {
      expect(
        () => CasePromotionKeyV1.fromNamespace(
          caseCandidateId: 'candidate-1',
          targetCaseNamespace: value,
        ),
        throwsFormatException,
      );
    }
  });

  test('idempotency JSON is deterministic', () {
    final key = exact(builder, executionId: 'execution-1');
    expect(jsonEncode(key.toJson()), jsonEncode(key.toJson()));
    final promotion = CasePromotionKeyV1(
      caseCandidateId: 'candidate-1',
      targetCaseNamespace: TargetCaseNamespace.futureUnifiedCase,
    );
    expect(jsonEncode(promotion.toJson()), jsonEncode(promotion.toJson()));
  });
}

SourceIngestionKeyV1 exact(
  SourceIngestionKeyBuilderV1 builder, {
  required String executionId,
}) => builder.digitalDetectiveExactOccurrence(
  taskId: 'task-1',
  executionId: executionId,
  findingKey: 'finding-1',
);
