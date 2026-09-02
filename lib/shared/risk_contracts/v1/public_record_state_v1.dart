part of 'shared_risk_contracts_v1.dart';

const String publicRecordStateContractVersionV1 = 'public-record-state-v1';

enum PublicRecordStateCodeV1 { pending, underReview, published, rejected }

String _publicRecordStateCodeValue(PublicRecordStateCodeV1 value) =>
    switch (value) {
      PublicRecordStateCodeV1.pending => 'pending',
      PublicRecordStateCodeV1.underReview => 'under_review',
      PublicRecordStateCodeV1.published => 'published',
      PublicRecordStateCodeV1.rejected => 'rejected',
    };

PublicRecordStateCodeV1 _publicRecordStateCodeFrom(Object? value) =>
    _enumValue(value, {
      'pending': PublicRecordStateCodeV1.pending,
      'under_review': PublicRecordStateCodeV1.underReview,
      'published': PublicRecordStateCodeV1.published,
      'rejected': PublicRecordStateCodeV1.rejected,
    }, 'publicStateCode');

final class PublicRecordStateV1 {
  const PublicRecordStateV1({
    required this.publicStateCode,
    this.verifiedAt,
    this.disputedAt,
    this.correctedAt,
    this.responseRef,
  });

  final String contractVersion = publicRecordStateContractVersionV1;
  final PublicRecordStateCodeV1 publicStateCode;
  final DateTime? verifiedAt;
  final DateTime? disputedAt;
  final DateTime? correctedAt;
  final CanonicalEntityRef? responseRef;

  factory PublicRecordStateV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != publicRecordStateContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }

    return PublicRecordStateV1(
      publicStateCode: _publicRecordStateCodeFrom(json['publicStateCode']),
      verifiedAt: _optionalDate(json['verifiedAt'], 'verifiedAt'),
      disputedAt: _optionalDate(json['disputedAt'], 'disputedAt'),
      correctedAt: _optionalDate(json['correctedAt'], 'correctedAt'),
      responseRef: json['responseRef'] == null
          ? null
          : CanonicalEntityRef.fromJson(
              _requiredMap(json['responseRef'], 'responseRef'),
            ),
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'publicStateCode': _publicRecordStateCodeValue(publicStateCode),
    if (verifiedAt != null) 'verifiedAt': verifiedAt!.toIso8601String(),
    if (disputedAt != null) 'disputedAt': disputedAt!.toIso8601String(),
    if (correctedAt != null) 'correctedAt': correctedAt!.toIso8601String(),
    if (responseRef != null) 'responseRef': responseRef!.toJson(),
  };
}
