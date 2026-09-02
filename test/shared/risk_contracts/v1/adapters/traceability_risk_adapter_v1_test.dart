import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/traceability/data/traceability_models.dart';
import 'package:markakalkan/shared/risk_contracts/v1/adapters/traceability_risk_adapter_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  const adapter = TraceabilityRiskAdapterV1();
  final adaptedAt = DateTime.parse('2026-07-19T12:00:00Z');

  test('suspicious scan maps to shared signal with typed references', () {
    final signal = adapter.toSignal(
      scan(),
      adaptedAt: adaptedAt,
      ownerUid: 'owner-1',
    );
    expect(signal.signalSource.module, 'traceability');
    expect(signal.signalType.value, 'suspicious');
    expect(signal.canonicalSeverity, CanonicalSeverity.high);
    expect(
      signal.relatedEntityRefs.map((item) => item.entityType),
      containsAll(['verification_scan', 'public_code', 'product', 'batch']),
    );
  });

  test('risk score, original scale, and reasons remain lossless', () {
    final risk = adapter.toRiskAssessment(
      scan(),
      adaptedAt: adaptedAt,
      ownerUid: 'owner-1',
    );
    expect(risk.score?.value, 78);
    expect(risk.score?.minimum, 0);
    expect(risk.score?.maximum, 100);
    expect(risk.score?.originalScale, 'traceability.risk_score.0_100');
    expect(risk.reasons, ['repeated_scan', 'platform_changed']);
  });

  test('ownerUid remains partial and is never copied', () {
    final identity = adapter
        .toSignal(scan(), adaptedAt: adaptedAt, ownerUid: 'owner-1')
        .identityScope;
    expect(identity.ownerUid, 'owner-1');
    expect(identity.tenantId, isNull);
    expect(identity.brandId, isNull);
    expect(identity.resolutionStatus, IdentityResolutionStatus.partial);
  });

  test('missing identity produces unresolved scope', () {
    final identity = adapter
        .toSignal(scan(), adaptedAt: adaptedAt)
        .identityScope;
    expect(identity.resolutionStatus, IdentityResolutionStatus.unresolved);
    expect(identity.ownerUid, isNull);
  });

  test('no evidence is invented from unavailable evidenceCount', () {
    final signal = adapter.toSignal(scan(), adaptedAt: adaptedAt);
    expect(signal.evidenceRefs, isEmpty);
  });

  test('none and unknown risk levels fail closed', () {
    expect(() => adapter.canonicalSeverity('none'), throwsFormatException);
    expect(() => adapter.canonicalSeverity('urgent'), throwsFormatException);
  });

  test('createdAt is the documented detectedAt source', () {
    final signal = adapter.toSignal(scan(), adaptedAt: adaptedAt);
    expect(signal.detectedAt, scan().createdAt);
    expect(signal.provenance.adaptedAt, adaptedAt);
  });

  test('same input produces byte-semantically equal JSON', () {
    final first = adapter.toSignal(scan(), adaptedAt: adaptedAt).toJson();
    final second = adapter.toSignal(scan(), adaptedAt: adaptedAt).toJson();
    expect(jsonEncode(first), jsonEncode(second));
  });

  group('EvidenceQualityRefV1 adapter integration', () {
    const qualityAdapter = TraceabilityRiskAdapterV1();

    test('preserves every canonical evidence quality wire code', () {
      for (final level in [
        'verified_primary',
        'corroborated',
        'single_source',
        'insufficient',
        'unavailable',
      ]) {
        expect(
          qualityAdapter.toEvidenceQualityRef(level: level).toJson()['level'],
          level,
        );
      }
    });

    test('preserves evaluator evidence without vocabulary remapping', () {
      final value = qualityAdapter.toEvidenceQualityRef(
        level: 'corroborated',
        reasonCodes: const ['evidence.multiple_independent_sources'],
        evaluatedFrom: const {
          'evidenceReferenceCount': 3,
          'sourceCount': 2,
          'primaryVerified': false,
        },
        evaluatorVersion: 'risk-operations-evaluator-v1',
      );

      expect(value.toJson(), {
        'contractVersion': evidenceQualityRefContractVersionV1,
        'level': 'corroborated',
        'reasonCodes': ['evidence.multiple_independent_sources'],
        'evaluatedFrom': {
          'evidenceReferenceCount': 3,
          'sourceCount': 2,
          'primaryVerified': false,
        },
        'evaluatorVersion': 'risk-operations-evaluator-v1',
      });
    });

    test('unknown evidence quality level fails closed', () {
      expect(
        () => qualityAdapter.toEvidenceQualityRef(level: 'strong'),
        throwsFormatException,
      );
    });

    test('does not infer evidence quality from traceability risk severity', () {
      final value = qualityAdapter.toEvidenceQualityRef(
        level: 'single_source',
        evaluatedFrom: const {
          'sourceSystem': 'traceability',
          'sourceCount': 1,
          'primaryVerified': false,
        },
      );

      expect(value.toJson()['level'], 'single_source');
      expect(value.toJson().containsKey('riskLevel'), isFalse);
      expect(value.toJson().containsKey('riskScore'), isFalse);
    });

    test('adapter returns immutable evaluator evidence snapshots', () {
      final reasons = <String>['evidence.single_source_only'];
      final evaluatedFrom = <String, Object?>{
        'sourceCount': 1,
        'primaryVerified': false,
      };

      final value = qualityAdapter.toEvidenceQualityRef(
        level: 'single_source',
        reasonCodes: reasons,
        evaluatedFrom: evaluatedFrom,
      );

      reasons.clear();
      evaluatedFrom['sourceCount'] = 99;

      expect(value.reasonCodes, ['evidence.single_source_only']);
      expect(value.evaluatedFrom['sourceCount'], 1);
      expect(
        () => value.reasonCodes.add('evidence.other'),
        throwsUnsupportedError,
      );
      expect(
        () => value.evaluatedFrom['sourceCount'] = 2,
        throwsUnsupportedError,
      );
    });

    test('quality bridge carries no entitlement or persistence fields', () {
      final json = qualityAdapter
          .toEvidenceQualityRef(
            level: 'verified_primary',
            evaluatorVersion: 'risk-operations-evaluator-v1',
          )
          .toJson();

      for (final field in [
        'subscription',
        'payment',
        'accessRequirement',
        'verifiedBrand',
        'operationAuthority',
        'persistenceTarget',
        'command',
      ]) {
        expect(json.containsKey(field), isFalse);
      }
    });
  });
}

SuspiciousVerificationScan scan() => SuspiciousVerificationScan(
  id: 'scan-1',
  publicCode: 'MK-TEST-001',
  productId: 'product-1',
  batchId: 'batch-1',
  brandName: 'Synthetic Brand',
  productName: 'Synthetic Product',
  batchNumber: 'B-1',
  status: 'suspicious',
  platform: 'web',
  source: 'qr',
  scanNumber: 3,
  repeatScan: true,
  riskScore: 78,
  riskLevel: 'high',
  riskReasons: const ['repeated_scan', 'platform_changed'],
  reviewStatus: 'pending',
  reviewNotes: '',
  caseId: '',
  createdAt: DateTime.parse('2026-07-19T10:00:00Z'),
  reviewedAt: null,
);
