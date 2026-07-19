import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/adapters/digital_detective_risk_adapter_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  const adapter = DigitalDetectiveRiskAdapterV1();

  test('valid schema-shaped finding maps to a shared signal', () {
    final output = adapter.toSignal(finding(), context: context());
    expect(output.signalType.value, 'price_anomaly');
    expect(output.summary, contains('sentetik fiyat farkı'));
    expect(output.reviewStatus, RiskSignalReviewStatus.underReview);
  });

  test('confidence keeps normalized and original scale values', () {
    final confidence = adapter
        .toSignal(finding(), context: context())
        .confidence!;
    expect(confidence.normalizedScore, 0.8);
    expect(confidence.originalValue, 0.8);
    expect(confidence.originalScale, 'digital_field_scanner.confidence.0_1');
  });

  test('complete finding provenance is retained', () {
    final provenance = adapter
        .toSignal(finding(), context: context())
        .provenance;
    expect(provenance.findingKey, hex('f'));
    expect(provenance.executionId, 'execution-1');
    expect(provenance.taskId, 'task-1');
    expect(provenance.sourceId, hex('a'));
    expect(provenance.snapshotId, hex('b'));
    expect(provenance.contentHash, hex('c'));
    expect(provenance.workflowRef, 'workflow:scanner:v1');
  });

  test('evidence string references map without invented meaning', () {
    final evidence = adapter
        .toSignal(finding(), context: context())
        .evidenceRefs
        .single;
    expect(evidence.referenceType, 'snapshot_id');
    expect(evidence.referenceId, hex('e'));
    expect(evidence.metadata['requiresHumanReview'], isTrue);
    expect(evidence.metadata['automatedConclusion'], 'suspected_signal');
  });

  test('brandUid remains partial and is not copied to tenantId', () {
    final identity = adapter
        .toSignal(finding(), context: context())
        .identityScope;
    expect(identity.brandUid, 'brand-uid-1');
    expect(identity.tenantId, isNull);
    expect(identity.brandId, isNull);
    expect(identity.resolutionStatus, IdentityResolutionStatus.partial);
  });

  test('missing required finding field is rejected', () {
    final input = finding()..remove('findingKey');
    expect(
      () => adapter.toSignal(input, context: context()),
      throwsFormatException,
    );
  });

  test('unknown severity is rejected', () {
    final input = finding()..['severity'] = 'urgent';
    expect(
      () => adapter.toSignal(input, context: context()),
      throwsFormatException,
    );
  });

  test('missing required envelope value is rejected', () {
    expect(
      () => adapter.toSignal(
        finding(),
        context: DigitalDetectiveFindingContextV1(
          taskId: '',
          executionId: 'execution-1',
          workflowRef: 'workflow:v1',
          detectedAt: DateTime.parse('2026-07-19T10:00:00Z'),
          createdAt: DateTime.parse('2026-07-19T10:01:00Z'),
          adaptedAt: DateTime.parse('2026-07-19T12:00:00Z'),
        ),
      ),
      throwsFormatException,
    );
  });

  test('same input produces byte-semantically equal JSON', () {
    final first = adapter.toSignal(finding(), context: context()).toJson();
    final second = adapter.toSignal(finding(), context: context()).toJson();
    expect(jsonEncode(first), jsonEncode(second));
  });
}

Map<String, dynamic> finding() => {
  'findingKey': hex('f'),
  'candidateId': hex('d'),
  'sourceUrl': 'https://example.test/synthetic',
  'signalType': 'price_anomaly',
  'description':
      'TEST_FIXTURE sentetik fiyat farkı insan incelemesi gerektirir.',
  'severity': 'medium',
  'confidence': 0.8,
  'evidenceReferences': [hex('e')],
  'requiresHumanReview': true,
  'automatedConclusion': 'suspected_signal',
};

DigitalDetectiveFindingContextV1 context() => DigitalDetectiveFindingContextV1(
  taskId: 'task-1',
  executionId: 'execution-1',
  workflowRef: 'workflow:scanner:v1',
  brandUid: 'brand-uid-1',
  sourceId: hex('a'),
  snapshotId: hex('b'),
  contentHash: hex('c'),
  detectedAt: DateTime.parse('2026-07-19T10:00:00Z'),
  createdAt: DateTime.parse('2026-07-19T10:01:00Z'),
  adaptedAt: DateTime.parse('2026-07-19T12:00:00Z'),
);

String hex(String character) => character * 64;
