import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  PublicRecordStateV1 state(
    PublicRecordStateCodeV1 code, {
    DateTime? verifiedAt,
    DateTime? disputedAt,
    DateTime? correctedAt,
    CanonicalEntityRef? responseRef,
  }) => PublicRecordStateV1(
    publicStateCode: code,
    verifiedAt: verifiedAt,
    disputedAt: disputedAt,
    correctedAt: correctedAt,
    responseRef: responseRef,
  );

  test('preserves observed public publication wire codes exactly', () {
    expect(
      state(PublicRecordStateCodeV1.pending).toJson()['publicStateCode'],
      'pending',
    );
    expect(
      state(PublicRecordStateCodeV1.underReview).toJson()['publicStateCode'],
      'under_review',
    );
    expect(
      state(PublicRecordStateCodeV1.published).toJson()['publicStateCode'],
      'published',
    );
    expect(
      state(PublicRecordStateCodeV1.rejected).toJson()['publicStateCode'],
      'rejected',
    );
  });

  test('JSON round-trip preserves minimal public record state', () {
    final original = state(
      PublicRecordStateCodeV1.published,
      verifiedAt: DateTime.utc(2026, 9, 2, 9, 30),
      disputedAt: DateTime.utc(2026, 9, 2, 9, 35),
      correctedAt: DateTime.utc(2026, 9, 2, 9, 40),
      responseRef: CanonicalEntityRef(
        module: 'public_radar',
        entityType: 'brand_response',
        entityId: 'response-001',
      ),
    );

    expect(
      PublicRecordStateV1.fromJson(original.toJson()).toJson(),
      original.toJson(),
    );
  });

  test('unknown contract version fails closed', () {
    final json = state(PublicRecordStateCodeV1.pending).toJson();
    json['contractVersion'] = 'public-record-state-v999';

    expect(
      () => PublicRecordStateV1.fromJson(Map<String, dynamic>.from(json)),
      throwsFormatException,
    );
  });

  test('unknown public state code fails closed', () {
    final json = state(PublicRecordStateCodeV1.pending).toJson();
    json['publicStateCode'] = 'withdrawn';

    expect(
      () => PublicRecordStateV1.fromJson(Map<String, dynamic>.from(json)),
      throwsFormatException,
    );
  });

  test(
    'verification and response concepts are not publication state codes',
    () {
      for (final code in ['verified', 'resolved']) {
        final json = state(PublicRecordStateCodeV1.pending).toJson();
        json['publicStateCode'] = code;

        expect(
          () => PublicRecordStateV1.fromJson(Map<String, dynamic>.from(json)),
          throwsFormatException,
        );
      }
    },
  );

  test('dispute and correction are metadata, not invented state codes', () {
    for (final code in ['disputed', 'corrected']) {
      final json = state(PublicRecordStateCodeV1.pending).toJson();
      json['publicStateCode'] = code;

      expect(
        () => PublicRecordStateV1.fromJson(Map<String, dynamic>.from(json)),
        throwsFormatException,
      );
    }

    final value = state(
      PublicRecordStateCodeV1.published,
      disputedAt: DateTime.utc(2026, 9, 2, 10),
      correctedAt: DateTime.utc(2026, 9, 2, 11),
    );

    expect(value.disputedAt, DateTime.utc(2026, 9, 2, 10));
    expect(value.correctedAt, DateTime.utc(2026, 9, 2, 11));
  });

  test('optional lifecycle timestamps serialize only when present', () {
    final minimal = state(PublicRecordStateCodeV1.pending).toJson();

    expect(minimal.containsKey('verifiedAt'), isFalse);
    expect(minimal.containsKey('disputedAt'), isFalse);
    expect(minimal.containsKey('correctedAt'), isFalse);

    final populated = state(
      PublicRecordStateCodeV1.published,
      verifiedAt: DateTime.utc(2026, 9, 2, 9),
      disputedAt: DateTime.utc(2026, 9, 2, 10),
      correctedAt: DateTime.utc(2026, 9, 2, 11),
    ).toJson();

    expect(populated['verifiedAt'], '2026-09-02T09:00:00.000Z');
    expect(populated['disputedAt'], '2026-09-02T10:00:00.000Z');
    expect(populated['correctedAt'], '2026-09-02T11:00:00.000Z');
  });

  test('malformed optional lifecycle timestamp fails closed', () {
    final json = state(PublicRecordStateCodeV1.published).toJson();
    json['verifiedAt'] = 'not-a-date';

    expect(
      () => PublicRecordStateV1.fromJson(Map<String, dynamic>.from(json)),
      throwsFormatException,
    );
  });

  test('responseRef reuses canonical entity reference', () {
    final value = state(
      PublicRecordStateCodeV1.published,
      responseRef: CanonicalEntityRef(
        module: 'public_radar',
        entityType: 'brand_response',
        entityId: 'response-002',
      ),
    );

    expect(value.responseRef!.module, 'public_radar');
    expect(value.responseRef!.entityType, 'brand_response');
    expect(value.responseRef!.entityId, 'response-002');
  });

  test(
    'no separate objection correction or verification status fields exist',
    () {
      final json = state(
        PublicRecordStateCodeV1.published,
        verifiedAt: DateTime.utc(2026, 9, 2, 9),
        disputedAt: DateTime.utc(2026, 9, 2, 10),
        correctedAt: DateTime.utc(2026, 9, 2, 11),
      ).toJson();

      expect(json.containsKey('verificationStatus'), isFalse);
      expect(json.containsKey('objectionStatus'), isFalse);
      expect(json.containsKey('correctionStatus'), isFalse);
      expect(json.containsKey('responseStatus'), isFalse);
    },
  );

  test('public record truth contains no entitlement or payment fields', () {
    final json = state(PublicRecordStateCodeV1.published).toJson();

    expect(json.containsKey('subscription'), isFalse);
    expect(json.containsKey('payment'), isFalse);
    expect(json.containsKey('accessRequirement'), isFalse);
    expect(json.containsKey('verifiedBrand'), isFalse);
    expect(json.containsKey('operationAuthority'), isFalse);
  });
}
