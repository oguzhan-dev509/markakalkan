// ignore_for_file: prefer_initializing_formals

part of 'risk_scan_contracts_v1.dart';

final class RiskScanChannelContractV1 {
  RiskScanChannelContractV1({
    required String scanRunId,
    required RiskScanChannelCode channelCode,
    required RiskScanChannelStatus status,
    required RiskScanCoverageStatus coverageStatus,
    required int attemptCount,
    required int observationCount,
    required int findingCount,
    required DateTime updatedAt,
    List<String> limitReasonCodes = const [],
    DateTime? startedAt,
    DateTime? completedAt,
  }) : scanRunId = _requiredString(scanRunId, 'scanRunId'),
       channelCode = channelCode,
       status = status,
       coverageStatus = coverageStatus,
       attemptCount = _requiredNonNegativeInt(attemptCount, 'attemptCount'),
       observationCount = _requiredNonNegativeInt(
         observationCount,
         'observationCount',
       ),
       findingCount = _requiredNonNegativeInt(findingCount, 'findingCount'),
       limitReasonCodes = List<String>.unmodifiable(
         limitReasonCodes.map(
           (item) => _requiredString(item, 'limitReasonCodes'),
         ),
       ),
       startedAt = startedAt,
       completedAt = completedAt,
       updatedAt = updatedAt {
    if (this.startedAt != null && this.updatedAt.isBefore(this.startedAt!)) {
      throw const FormatException('updatedAt cannot precede startedAt');
    }
    if (this.startedAt != null &&
        this.completedAt != null &&
        this.completedAt!.isBefore(this.startedAt!)) {
      throw const FormatException('completedAt cannot precede startedAt');
    }
  }

  final String contractVersion = riskScanChannelContractVersionV1;
  final String scanRunId;
  final RiskScanChannelCode channelCode;
  final RiskScanChannelStatus status;
  final RiskScanCoverageStatus coverageStatus;
  final int attemptCount;
  final int observationCount;
  final int findingCount;
  final List<String> limitReasonCodes;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  factory RiskScanChannelContractV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != riskScanChannelContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    return RiskScanChannelContractV1(
      scanRunId: _requiredString(json['scanRunId'], 'scanRunId'),
      channelCode: _channelCodeFrom(json['channelCode']),
      status: _channelStatusFrom(json['status']),
      coverageStatus: _coverageStatusFrom(json['coverageStatus']),
      attemptCount: _requiredNonNegativeInt(
        json['attemptCount'],
        'attemptCount',
      ),
      observationCount: _requiredNonNegativeInt(
        json['observationCount'],
        'observationCount',
      ),
      findingCount: _requiredNonNegativeInt(
        json['findingCount'],
        'findingCount',
      ),
      limitReasonCodes: _stringList(
        json['limitReasonCodes'],
        'limitReasonCodes',
      ),
      startedAt: _optionalDate(json['startedAt'], 'startedAt'),
      completedAt: _optionalDate(json['completedAt'], 'completedAt'),
      updatedAt: _requiredDate(json['updatedAt'], 'updatedAt'),
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'scanRunId': scanRunId,
    'channelCode': _channelCodeValue(channelCode),
    'status': _channelStatusValue(status),
    'coverageStatus': _coverageStatusValue(coverageStatus),
    'attemptCount': attemptCount,
    'observationCount': observationCount,
    'findingCount': findingCount,
    'limitReasonCodes': limitReasonCodes,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
