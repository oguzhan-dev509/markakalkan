import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  EvidenceQualityRefV1 quality(
    EvidenceQualityLevelV1 level, {
    List<String> reasonCodes = const [],
    Map<String, Object?> evaluatedFrom = const {},
    String? evaluatorVersion,
  }) => EvidenceQualityRefV1(
    level: level,
    reasonCodes: reasonCodes,
    evaluatedFrom: evaluatedFrom,
    evaluatorVersion: evaluatorVersion,
  );

  test(
    'canonical quality levels preserve existing risk operation wire codes',
    () {
      expect(
        quality(EvidenceQualityLevelV1.verifiedPrimary).toJson()['level'],
        'verified_primary',
      );
      expect(
        quality(EvidenceQualityLevelV1.corroborated).toJson()['level'],
        'corroborated',
      );
      expect(
        quality(EvidenceQualityLevelV1.singleSource).toJson()['level'],
        'single_source',
      );
      expect(
        quality(EvidenceQualityLevelV1.insufficient).toJson()['level'],
        'insufficient',
      );
      expect(
        quality(EvidenceQualityLevelV1.unavailable).toJson()['level'],
        'unavailable',
      );
    },
  );

  test('JSON round-trip preserves evaluator evidence', () {
    final original = quality(
      EvidenceQualityLevelV1.corroborated,
      reasonCodes: const ['evidence.multiple_independent_sources'],
      evaluatedFrom: const {
        'evidenceReferenceCount': 3,
        'sourceCount': 2,
        'primaryVerified': false,
      },
      evaluatorVersion: 'risk-operations-evaluator-v1',
    );
    final restored = EvidenceQualityRefV1.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
  });

  test('unknown contract version fails closed', () {
    final json = quality(EvidenceQualityLevelV1.singleSource).toJson();
    json['contractVersion'] = 'evidence-quality-ref-v999';
    expect(
      () => EvidenceQualityRefV1.fromJson(Map<String, dynamic>.from(json)),
      throwsFormatException,
    );
  });

  test('unknown quality level fails closed', () {
    final json = quality(EvidenceQualityLevelV1.singleSource).toJson();
    json['level'] = 'strong';
    expect(
      () => EvidenceQualityRefV1.fromJson(Map<String, dynamic>.from(json)),
      throwsFormatException,
    );
  });

  test('reason codes are immutable validated snapshots', () {
    final reasons = <String>['evidence.single_source_only'];
    final value = quality(
      EvidenceQualityLevelV1.singleSource,
      reasonCodes: reasons,
    );
    reasons.clear();
    expect(value.reasonCodes, ['evidence.single_source_only']);
    expect(
      () => value.reasonCodes.add('evidence.other'),
      throwsUnsupportedError,
    );
  });

  test('empty reason code fails closed', () {
    expect(
      () =>
          quality(EvidenceQualityLevelV1.insufficient, reasonCodes: const ['']),
      throwsFormatException,
    );
  });

  test('evaluatedFrom is an immutable snapshot', () {
    final evaluatedFrom = <String, Object?>{
      'sourceCount': 1,
      'primaryVerified': false,
    };
    final value = quality(
      EvidenceQualityLevelV1.singleSource,
      evaluatedFrom: evaluatedFrom,
    );
    evaluatedFrom['sourceCount'] = 99;
    expect(value.evaluatedFrom['sourceCount'], 1);
    expect(
      () => value.evaluatedFrom['sourceCount'] = 2,
      throwsUnsupportedError,
    );
  });

  test('evaluator version is optional', () {
    expect(
      quality(EvidenceQualityLevelV1.unavailable).evaluatorVersion,
      isNull,
    );
  });

  test('quality level is categorical and carries no ordinal strength rank', () {
    final json = quality(EvidenceQualityLevelV1.verifiedPrimary).toJson();
    expect(json.containsKey('strength'), isFalse);
    expect(json.containsKey('rank'), isFalse);
    expect(json.containsKey('levelNumber'), isFalse);
  });

  test(
    'module-specific trade secret strength code is not a canonical level',
    () {
      final json = quality(EvidenceQualityLevelV1.insufficient).toJson();
      json['level'] = 'conclusive';
      expect(
        () => EvidenceQualityRefV1.fromJson(Map<String, dynamic>.from(json)),
        throwsFormatException,
      );
    },
  );

  test('quality truth contains no entitlement or payment fields', () {
    final json = quality(
      EvidenceQualityLevelV1.verifiedPrimary,
      evaluatorVersion: 'risk-operations-evaluator-v1',
    ).toJson();
    expect(json.containsKey('subscription'), isFalse);
    expect(json.containsKey('payment'), isFalse);
    expect(json.containsKey('accessRequirement'), isFalse);
    expect(json.containsKey('verifiedBrand'), isFalse);
    expect(json.containsKey('operationAuthority'), isFalse);
  });
}
