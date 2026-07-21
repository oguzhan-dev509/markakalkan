import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_models.dart';
import 'package:markakalkan/features/risk_operations/data/shared_risk_promotion_service.dart';

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

void main() {
  test(
    'real promotion sends only exact command fields and dryRun false',
    () async {
      final calls = <Map<String, dynamic>>[];
      final service = CallableSharedRiskPromotionService(
        transport: (request) async {
          calls.add(request);
          return {'outcome': 'created'};
        },
      );
      final result = await service.promote(item());
      expect(result.outcome, SharedRiskPromotionOutcome.created);
      expect(calls, hasLength(1));
      expect(calls.single.keys.toSet(), {
        'sourceSystem',
        'sourceRecordId',
        'expectedSourceRecordVersion',
        'expectedProjectionFingerprint',
        'dryRun',
        'correlationId',
      });
      expect(calls.single['dryRun'], isFalse);
      for (final forbidden in [
        'tenantId',
        'canonicalBrandId',
        'ownerUid',
        'role',
        'permission',
      ]) {
        expect(calls.single, isNot(contains(forbidden)));
      }
    },
  );

  test('there is no retry and the session locks repeat submission', () async {
    var calls = 0;
    final service = CallableSharedRiskPromotionService(
      transport: (_) async {
        calls += 1;
        return {'outcome': 'conflict'};
      },
    );
    expect(
      (await service.promote(item())).outcome,
      SharedRiskPromotionOutcome.conflict,
    );
    expect(
      (await service.promote(item())).outcome,
      SharedRiskPromotionOutcome.blocked,
    );
    expect(calls, 1);
  });

  test('canonical outcomes have Turkish safe presentation', () {
    for (final outcome in SharedRiskPromotionOutcome.values) {
      final message = SharedRiskPromotionResult(outcome).turkishMessage;
      expect(message, isNotEmpty);
      expect(message, isNot(contains('_')));
    }
  });
}
