// ignore_for_file: prefer_initializing_formals

part of 'risk_scan_contracts_v1.dart';

final class RiskScanObservationContractV1 {
  RiskScanObservationContractV1({
    required String observationId,
    required String scanRunId,
    required RiskScanChannelCode channelCode,
    required RiskScanObservationSourceType sourceType,
    required String sourceUrlCanonical,
    required String sourceHost,
    required RiskScanAcquisitionStatus acquisitionStatus,
    required DateTime observedAt,
    required DateTime createdAt,
    required bool immutable,
    String? sourceTitleSnapshot,
    String? contentFingerprintSha256,
    DateTime? acquiredAt,
  }) : observationId = _requiredString(observationId, 'observationId'),
       scanRunId = _requiredString(scanRunId, 'scanRunId'),
       channelCode = channelCode,
       sourceType = sourceType,
       sourceUrlCanonical = _canonicalWebUrl(
         sourceUrlCanonical,
         'sourceUrlCanonical',
       ),
       sourceHost = _canonicalHost(sourceHost, 'sourceHost'),
       sourceTitleSnapshot = _optionalString(
         sourceTitleSnapshot,
         'sourceTitleSnapshot',
       ),
       acquisitionStatus = acquisitionStatus,
       contentFingerprintSha256 = _optionalSha256(
         contentFingerprintSha256,
         'contentFingerprintSha256',
       ),
       observedAt = observedAt,
       acquiredAt = acquiredAt,
       createdAt = createdAt,
       immutable = immutable {
    final uri = Uri.parse(this.sourceUrlCanonical);
    if (uri.host.toLowerCase() != this.sourceHost) {
      throw const FormatException('sourceHost must match sourceUrlCanonical');
    }
    if (this.observedAt.isAfter(this.createdAt)) {
      throw const FormatException('observedAt cannot follow createdAt');
    }
    if (this.acquiredAt != null && this.acquiredAt!.isBefore(this.observedAt)) {
      throw const FormatException('acquiredAt cannot precede observedAt');
    }
    if (this.acquiredAt != null && this.acquiredAt!.isAfter(this.createdAt)) {
      throw const FormatException('acquiredAt cannot follow createdAt');
    }
    if (!this.immutable) {
      throw const FormatException('immutable must be true');
    }

    final hasAcquiredAt = this.acquiredAt != null;
    final hasFingerprint = this.contentFingerprintSha256 != null;
    if (this.acquisitionStatus == RiskScanAcquisitionStatus.acquired) {
      if (!hasAcquiredAt || !hasFingerprint) {
        throw const FormatException(
          'acquired observation requires acquiredAt and fingerprint',
        );
      }
    } else if (this.acquisitionStatus ==
        RiskScanAcquisitionStatus.acquiredWithLimits) {
      if (!hasAcquiredAt) {
        throw const FormatException(
          'acquired_with_limits observation requires acquiredAt',
        );
      }
    } else if (hasAcquiredAt || hasFingerprint) {
      throw const FormatException(
        'non-acquired observation cannot contain acquisition output',
      );
    }
  }

  final String contractVersion = riskScanObservationContractVersionV1;
  final String observationId;
  final String scanRunId;
  final RiskScanChannelCode channelCode;
  final RiskScanObservationSourceType sourceType;
  final String sourceUrlCanonical;
  final String sourceHost;
  final String? sourceTitleSnapshot;
  final RiskScanAcquisitionStatus acquisitionStatus;
  final String? contentFingerprintSha256;
  final DateTime observedAt;
  final DateTime? acquiredAt;
  final DateTime createdAt;
  final bool immutable;

  factory RiskScanObservationContractV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != riskScanObservationContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    final immutable = json['immutable'];
    if (immutable is! bool) {
      throw const FormatException('immutable must be a boolean');
    }
    return RiskScanObservationContractV1(
      observationId: _requiredString(json['observationId'], 'observationId'),
      scanRunId: _requiredString(json['scanRunId'], 'scanRunId'),
      channelCode: _channelCodeFrom(json['channelCode']),
      sourceType: _observationSourceTypeFrom(json['sourceType']),
      sourceUrlCanonical: _requiredString(
        json['sourceUrlCanonical'],
        'sourceUrlCanonical',
      ),
      sourceHost: _requiredString(json['sourceHost'], 'sourceHost'),
      sourceTitleSnapshot: _optionalString(
        json['sourceTitleSnapshot'],
        'sourceTitleSnapshot',
      ),
      acquisitionStatus: _acquisitionStatusFrom(json['acquisitionStatus']),
      contentFingerprintSha256: _optionalSha256(
        json['contentFingerprintSha256'],
        'contentFingerprintSha256',
      ),
      observedAt: _requiredDate(json['observedAt'], 'observedAt'),
      acquiredAt: _optionalDate(json['acquiredAt'], 'acquiredAt'),
      createdAt: _requiredDate(json['createdAt'], 'createdAt'),
      immutable: immutable,
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'observationId': observationId,
    'scanRunId': scanRunId,
    'channelCode': _channelCodeValue(channelCode),
    'sourceType': _observationSourceTypeValue(sourceType),
    'sourceUrlCanonical': sourceUrlCanonical,
    'sourceHost': sourceHost,
    if (sourceTitleSnapshot != null) 'sourceTitleSnapshot': sourceTitleSnapshot,
    'acquisitionStatus': _acquisitionStatusValue(acquisitionStatus),
    if (contentFingerprintSha256 != null)
      'contentFingerprintSha256': contentFingerprintSha256,
    'observedAt': observedAt.toIso8601String(),
    if (acquiredAt != null) 'acquiredAt': acquiredAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'immutable': immutable,
  };
}

String? _optionalSha256(Object? value, String field) {
  if (value == null) return null;
  return _requiredSha256(value, field);
}
