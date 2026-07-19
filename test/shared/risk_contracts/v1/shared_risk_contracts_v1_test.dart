import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  final adaptedAt = DateTime.utc(2026, 7, 20, 12);

  Map<String, dynamic> identity({String status = 'resolved'}) => {
    if (status == 'resolved') 'tenantId': 'tenant-1',
    'brandUid': 'brand-uid-1',
    'resolutionStatus': status,
    'resolutionSource': 'adapter-test',
    'unresolvedReasons': status == 'resolved' ? <String>[] : ['tenant_unknown'],
  };

  Map<String, dynamic> provenance() => {
    'producerModule': 'digital_detective',
    'producerVersion': 'v1',
    'sourceRecordId': 'record-1',
    'executionId': 'execution-1',
    'workflowRef': 'workflow-1',
    'taskId': 'task-1',
    'sourceId': 'source-1',
    'snapshotId': 'snapshot-1',
    'findingKey': 'finding-1',
    'contentHash': 'hash-1',
    'sourceCreatedAt': '2026-07-20T10:00:00.000Z',
    'adaptedAt': adaptedAt.toIso8601String(),
  };

  Map<String, dynamic> signalJson() => {
    'signalId': 'signal-1',
    'contractVersion': riskSignalContractVersionV1,
    'identityScope': identity(),
    'canonicalAssetRef': {
      'assetType': 'product',
      'assetId': 'product-1',
      'module': 'products',
      'brandId': 'brand-1',
      'versionRef': 'v3',
    },
    'signalSource': {
      'module': 'digital_detective',
      'sourceType': 'scanner_finding',
      'sourceId': 'finding-1',
    },
    'signalType': {
      'namespace': 'digital_detective.signal_type',
      'value': 'price_anomaly',
    },
    'canonicalSeverity': 'high',
    'originalSeverity': 'VERY_HIGH_VENDOR_VALUE',
    'confidence': {
      'normalizedScore': 0.91,
      'originalValue': {'level': 'verified', 'rank': 5},
      'originalScale': 'counterfeit_twin_confidence_v1',
      'sourceNamespace': 'counterfeit_twin',
    },
    'summary': 'Fiyat anomalisi insan incelemesi gerektiriyor.',
    'evidenceRefs': [
      {
        'evidenceType': 'structured_evidence',
        'referenceType': 'snapshot_id',
        'referenceId': 'snapshot-1',
        'sourceModule': 'digital_detective',
        'hashAlgorithm': 'sha256',
        'hashValue': 'abc123',
        'capturedAt': '2026-07-20T09:00:00.000Z',
        'metadata': {'contentType': 'text/html'},
      },
    ],
    'relatedEntityRefs': [
      {
        'module': 'monitoring',
        'entityType': 'monitoring_signal',
        'entityId': 'monitoring-signal-1',
      },
    ],
    'reviewStatus': 'new',
    'occurredAt': '2026-07-20T08:00:00.000Z',
    'detectedAt': '2026-07-20T09:00:00.000Z',
    'createdAt': '2026-07-20T09:01:00.000Z',
    'provenance': provenance(),
  };

  Map<String, dynamic> riskJson() => {
    'riskId': 'risk-1',
    'contractVersion': riskAssessmentContractVersionV1,
    'identityScope': identity(),
    'riskCategory': {
      'namespace': 'ip_trade_secret.threat_category',
      'value': 'unauthorized_access',
    },
    'canonicalSeverity': 'critical',
    'originalSeverity': 'informational_to_critical:4',
    'score': {
      'value': 7.5,
      'minimum': 0,
      'maximum': 10,
      'modelVersion': 'risk-model-v2',
      'originalValue': 75,
      'originalScale': '0..100',
    },
    'reasons': ['unauthorized_access'],
    'sourceSignalRefs': [
      {
        'module': 'shared_risk',
        'entityType': 'risk_signal',
        'entityId': 'signal-1',
      },
    ],
    'evidenceRefs': <Map<String, dynamic>>[],
    'relatedEntityRefs': <Map<String, dynamic>>[],
    'status': 'identified',
    'assessedAt': '2026-07-20T10:00:00.000Z',
    'nextReviewAt': '2026-08-20T10:00:00.000Z',
    'createdAt': '2026-07-20T10:01:00.000Z',
    'createdBy': 'reviewer-1',
    'provenance': provenance(),
  };

  Map<String, dynamic> candidateJson() => {
    'caseCandidateId': 'candidate-1',
    'contractVersion': caseCandidateContractVersionV1,
    'identityScope': identity(),
    'sourceSignalRefs': [
      {
        'module': 'shared_risk',
        'entityType': 'risk_signal',
        'entityId': 'signal-1',
      },
    ],
    'sourceRiskRefs': [
      {
        'module': 'shared_risk',
        'entityType': 'risk_assessment',
        'entityId': 'risk-1',
      },
    ],
    'canonicalAssetRefs': <Map<String, dynamic>>[],
    'evidenceRefs': <Map<String, dynamic>>[],
    'relatedEntityRefs': <Map<String, dynamic>>[],
    'status': 'proposed',
    'recommendedPriority': 'high',
    'title': 'Şüpheli tarama vaka adayı',
    'summary': 'Nihai vaka değildir; insan incelemesi gerekir.',
    'deduplicationKey': 'signal-1|risk-1',
    'proposedAt': '2026-07-20T11:00:00.000Z',
    'provenance': provenance(),
  };

  Map<String, dynamic> jsonRoundTrip(Map<String, Object?> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

  test('minimum signal JSON is accepted and round-trips', () {
    final model = RiskSignalContractV1.fromJson(signalJson());
    final restored = RiskSignalContractV1.fromJson(
      jsonRoundTrip(model.toJson()),
    );
    expect(restored.signalId, 'signal-1');
    expect(restored.contractVersion, riskSignalContractVersionV1);
  });

  test('minimum risk JSON is accepted and round-trips', () {
    final model = RiskAssessmentContractV1.fromJson(riskJson());
    final restored = RiskAssessmentContractV1.fromJson(
      jsonRoundTrip(model.toJson()),
    );
    expect(restored.riskId, 'risk-1');
    expect(restored.score?.maximum, 10);
  });

  test('minimum case candidate JSON is accepted and round-trips', () {
    final model = CaseCandidateContractV1.fromJson(candidateJson());
    expect(
      CaseCandidateContractV1.fromJson(jsonRoundTrip(model.toJson())).status,
      CaseCandidateStatus.proposed,
    );
  });

  test('missing required fields are rejected by every contract', () {
    expect(
      () =>
          RiskSignalContractV1.fromJson({...signalJson()}..remove('signalId')),
      throwsFormatException,
    );
    expect(
      () => RiskAssessmentContractV1.fromJson(
        {...riskJson()}..remove('assessedAt'),
      ),
      throwsFormatException,
    );
    expect(
      () => CaseCandidateContractV1.fromJson(
        {...candidateJson()}..remove('title'),
      ),
      throwsFormatException,
    );
  });

  test('unknown canonical severity is rejected', () {
    expect(
      () => RiskSignalContractV1.fromJson({
        ...signalJson(),
        'canonicalSeverity': 'very_high',
      }),
      throwsFormatException,
    );
  });

  test('original severity and confidence round-trip without loss', () {
    final restored = RiskSignalContractV1.fromJson(
      jsonRoundTrip(RiskSignalContractV1.fromJson(signalJson()).toJson()),
    );
    expect(restored.originalSeverity, 'VERY_HIGH_VENDOR_VALUE');
    expect(restored.confidence?.originalValue, {
      'level': 'verified',
      'rank': 5,
    });
    expect(
      restored.confidence?.originalScale,
      'counterfeit_twin_confidence_v1',
    );
  });

  test('partial and unresolved identities serialize without inferred IDs', () {
    for (final status in ['partial', 'unresolved']) {
      final scope = IdentityScope.fromJson(identity(status: status));
      final output = scope.toJson();
      expect(output['resolutionStatus'], status);
      expect(output.containsKey('tenantId'), isFalse);
      expect(output.containsKey('brandId'), isFalse);
      expect(output['brandUid'], 'brand-uid-1');
      expect(scope.isPersistenceReady, isFalse);
    }
  });

  test('occurred detected captured retrieved semantics remain separate', () {
    final restored = RiskSignalContractV1.fromJson(
      jsonRoundTrip(RiskSignalContractV1.fromJson(signalJson()).toJson()),
    );
    expect(restored.occurredAt, DateTime.parse('2026-07-20T08:00:00.000Z'));
    expect(restored.detectedAt, DateTime.parse('2026-07-20T09:00:00.000Z'));
    expect(
      restored.evidenceRefs.single.capturedAt,
      DateTime.parse('2026-07-20T09:00:00.000Z'),
    );
    expect(restored.createdAt, DateTime.parse('2026-07-20T09:01:00.000Z'));
  });

  test('all immutable provenance values survive round-trip', () {
    final restored = RiskSignalContractV1.fromJson(
      jsonRoundTrip(RiskSignalContractV1.fromJson(signalJson()).toJson()),
    ).provenance;
    expect(restored.executionId, 'execution-1');
    expect(restored.workflowRef, 'workflow-1');
    expect(restored.taskId, 'task-1');
    expect(restored.sourceId, 'source-1');
    expect(restored.snapshotId, 'snapshot-1');
    expect(restored.findingKey, 'finding-1');
    expect(restored.contentHash, 'hash-1');
    expect(restored.adaptedAt, adaptedAt);
  });

  test('risk score supports different explicit scales', () {
    final tenPoint = ScoreValue.fromJson(
      riskJson()['score']! as Map<String, dynamic>,
    );
    final probability = ScoreValue(value: 0.42, minimum: 0, maximum: 1);
    expect(tenPoint.toJson()['maximum'], 10);
    expect(probability.toJson(), containsPair('maximum', 1));
  });

  test('case candidate requires deduplicationKey', () {
    expect(
      () => CaseCandidateContractV1.fromJson(
        {...candidateJson()}..remove('deduplicationKey'),
      ),
      throwsFormatException,
    );
  });

  test('collection fields and metadata are immutable snapshots', () {
    final reasons = <String>['first'];
    final model = RiskAssessmentContractV1(
      riskId: 'risk-immutable',
      identityScope: IdentityScope.fromJson(identity()),
      riskCategory: NamespacedValue(namespace: 'test', value: 'risk'),
      canonicalSeverity: CanonicalSeverity.low,
      reasons: reasons,
      status: RiskAssessmentStatus.identified,
      assessedAt: adaptedAt,
      createdAt: adaptedAt,
      provenance: ProvenanceEnvelope.fromJson(provenance()),
    );
    reasons.add('mutated');
    expect(model.reasons, ['first']);
    expect(() => model.reasons.add('blocked'), throwsUnsupportedError);
  });
}
