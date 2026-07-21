import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_models.dart';
import 'package:markakalkan/features/risk_operations/data/shared_risk_dry_run_service.dart';

RiskOperationItem item() => RiskOperationItem.fromMap({
  'signalId': 'signal-1',
  'sourceSystem': 'traceability',
  'sourceRecordId': 'scan-1',
  'sourceRecordVersion': 'version-1',
  'tenantId': 'tenant-1',
  'canonicalBrandId': 'brand-1',
  'canonicalSubjectId': 'product-1',
  'subjectType': 'product',
  'title': 'Şüpheli tarama',
  'summary': 'İnsan incelemesi gerekli',
  'currentStatus': 'pending',
  'riskClass': 'traceability_anomaly',
  'severity': 'medium',
  'confidence': .6,
  'evidenceQuality': {
    'level': 'single_source',
    'reasonCodes': ['evidence.single_source_only'],
    'evaluatorVersion': 'v1',
  },
  'caseCandidacy': {
    'status': 'review_candidate',
    'reasonCodes': ['case.human_review_threshold'],
    'evaluatedAt': '2026-07-21T00:00:00.000Z',
    'evaluatorVersion': 'v1',
    'requiresHumanReview': true,
  },
  'timeline': const [],
  'relationshipGraph': const {'nodes': []},
  'adapterVersion': 'risk-operations-read-adapter-v1',
  'projectionFingerprint':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
});

Map<Object?, Object?> safeResponse(String outcome) => {
  'outcome': outcome,
  'dryRun': true,
  'transactionCommitted': false,
  'writeAttempted': false,
};

void main() {
  test('sends exactly six canonical fields with dryRun true', () async {
    final calls = <Map<String, Object>>[];
    final service = CallableSharedRiskDryRunService(
      random: Random(7),
      transport: (request) async {
        calls.add(request);
        return safeResponse('dry_run_ready');
      },
    );
    final result = await service.validate(item());
    expect(result.outcome, SharedRiskDryRunOutcome.dryRunReady);
    expect(calls, hasLength(1));
    expect(calls.single.keys.toSet(), {
      'sourceSystem',
      'sourceRecordId',
      'expectedSourceRecordVersion',
      'expectedProjectionFingerprint',
      'dryRun',
      'correlationId',
    });
    expect(calls.single['dryRun'], isTrue);
    for (final forbidden in [
      'tenantId',
      'canonicalBrandId',
      'ownerUid',
      'role',
      'permission',
      'displayName',
    ]) {
      expect(calls.single, isNot(contains(forbidden)));
    }
  });

  test('does not retry and locks the record after the first attempt', () async {
    var calls = 0;
    final service = CallableSharedRiskDryRunService(
      transport: (_) async {
        calls += 1;
        return safeResponse('conflict');
      },
    );
    expect(
      (await service.validate(item())).outcome,
      SharedRiskDryRunOutcome.conflict,
    );
    expect(
      (await service.validate(item())).outcome,
      SharedRiskDryRunOutcome.blocked,
    );
    expect(calls, 1);
  });

  test('success parser is fail-closed for every write invariant', () async {
    for (final mutation in <Map<Object?, Object?>>[
      {
        'outcome': 'created',
        'dryRun': true,
        'transactionCommitted': false,
        'writeAttempted': false,
      },
      {
        'outcome': 'dry_run_ready',
        'dryRun': false,
        'transactionCommitted': false,
        'writeAttempted': false,
      },
      {
        'outcome': 'dry_run_ready',
        'dryRun': true,
        'transactionCommitted': true,
        'writeAttempted': false,
      },
      {
        'outcome': 'dry_run_ready',
        'dryRun': true,
        'transactionCommitted': false,
        'writeAttempted': true,
      },
      {'outcome': 'dry_run_ready'},
      {
        'outcome': 'unexpected',
        'dryRun': true,
        'transactionCommitted': false,
        'writeAttempted': false,
      },
    ]) {
      final result = await CallableSharedRiskDryRunService(
        transport: (_) async => mutation,
      ).validate(item());
      expect(result.outcome, SharedRiskDryRunOutcome.failed);
      expect(result.succeeded, isFalse);
    }
  });

  test('safe presentation never exposes canonical codes', () {
    for (final outcome in SharedRiskDryRunOutcome.values) {
      final message = SharedRiskDryRunResult(outcome).turkishMessage;
      expect(message, isNotEmpty);
      expect(message, isNot(contains('_')));
      expect(message, isNot(contains('fingerprint')));
      expect(message, isNot(contains('correlation')));
    }
  });
}
