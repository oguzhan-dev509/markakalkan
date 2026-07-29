// ignore_for_file: prefer_initializing_formals

part of 'risk_scan_contracts_v1.dart';

final class RiskScanReportFindingSnapshotV1 {
  RiskScanReportFindingSnapshotV1({
    required String findingId,
    required RiskScanChannelCode channelCode,
    required RiskScanFindingType findingType,
    required String title,
    required String summary,
    required RiskScanRiskLevel riskLevel,
    required RiskScanConfidenceLevel confidenceLevel,
    required RiskScanImpactLevel impactLevel,
    required RiskScanInterventionDifficulty interventionDifficulty,
    required RiskScanReviewStatus reviewStatus,
    required RiskScanRecommendationCode recommendationCode,
  }) : findingId = _requiredString(findingId, 'findingId'),
       channelCode = channelCode,
       findingType = findingType,
       title = _requiredString(title, 'title'),
       summary = _requiredString(summary, 'summary'),
       riskLevel = riskLevel,
       confidenceLevel = confidenceLevel,
       impactLevel = impactLevel,
       interventionDifficulty = interventionDifficulty,
       reviewStatus = reviewStatus,
       recommendationCode = recommendationCode;

  final String findingId;
  final RiskScanChannelCode channelCode;
  final RiskScanFindingType findingType;
  final String title;
  final String summary;
  final RiskScanRiskLevel riskLevel;
  final RiskScanConfidenceLevel confidenceLevel;
  final RiskScanImpactLevel impactLevel;
  final RiskScanInterventionDifficulty interventionDifficulty;
  final RiskScanReviewStatus reviewStatus;
  final RiskScanRecommendationCode recommendationCode;

  factory RiskScanReportFindingSnapshotV1.fromJson(Map<String, dynamic> json) =>
      RiskScanReportFindingSnapshotV1(
        findingId: _requiredString(json['findingId'], 'findingId'),
        channelCode: _channelCodeFrom(json['channelCode']),
        findingType: _findingTypeFrom(json['findingType']),
        title: _requiredString(json['title'], 'title'),
        summary: _requiredString(json['summary'], 'summary'),
        riskLevel: _riskLevelFrom(json['riskLevel']),
        confidenceLevel: _confidenceLevelFrom(json['confidenceLevel']),
        impactLevel: _impactLevelFrom(json['impactLevel']),
        interventionDifficulty: _interventionDifficultyFrom(
          json['interventionDifficulty'],
        ),
        reviewStatus: _reviewStatusFrom(json['reviewStatus']),
        recommendationCode: _recommendationCodeFrom(json['recommendationCode']),
      );

  Map<String, Object?> toJson() => {
    'findingId': findingId,
    'channelCode': _channelCodeValue(channelCode),
    'findingType': _findingTypeValue(findingType),
    'title': title,
    'summary': summary,
    'riskLevel': _riskLevelValue(riskLevel),
    'confidenceLevel': _confidenceLevelValue(confidenceLevel),
    'impactLevel': _impactLevelValue(impactLevel),
    'interventionDifficulty': _interventionDifficultyValue(
      interventionDifficulty,
    ),
    'reviewStatus': _reviewStatusValue(reviewStatus),
    'recommendationCode': _recommendationCodeValue(recommendationCode),
  };
}

final class RiskScanReportChannelSnapshotV1 {
  RiskScanReportChannelSnapshotV1({
    required RiskScanChannelCode channelCode,
    required RiskScanChannelStatus status,
    required RiskScanCoverageStatus coverageStatus,
    required int observationCount,
    required int findingCount,
    RiskScanRiskLevel? highestRiskLevel,
  }) : channelCode = channelCode,
       status = status,
       coverageStatus = coverageStatus,
       observationCount = _requiredNonNegativeInt(
         observationCount,
         'observationCount',
       ),
       findingCount = _requiredNonNegativeInt(findingCount, 'findingCount'),
       highestRiskLevel = highestRiskLevel {
    const finalStatuses = {
      RiskScanChannelStatus.completed,
      RiskScanChannelStatus.completedWithLimits,
      RiskScanChannelStatus.failedTerminal,
      RiskScanChannelStatus.skipped,
    };
    if (!finalStatuses.contains(this.status)) {
      throw const FormatException('report channel status must be final');
    }
    if (this.findingCount == 0 && this.highestRiskLevel != null) {
      throw const FormatException(
        'highestRiskLevel must be absent when findingCount is zero',
      );
    }
    if (this.findingCount > 0 && this.highestRiskLevel == null) {
      throw const FormatException(
        'highestRiskLevel is required when findingCount is positive',
      );
    }
  }

  final RiskScanChannelCode channelCode;
  final RiskScanChannelStatus status;
  final RiskScanCoverageStatus coverageStatus;
  final int observationCount;
  final int findingCount;
  final RiskScanRiskLevel? highestRiskLevel;

  factory RiskScanReportChannelSnapshotV1.fromJson(Map<String, dynamic> json) =>
      RiskScanReportChannelSnapshotV1(
        channelCode: _channelCodeFrom(json['channelCode']),
        status: _channelStatusFrom(json['status']),
        coverageStatus: _coverageStatusFrom(json['coverageStatus']),
        observationCount: _requiredNonNegativeInt(
          json['observationCount'],
          'observationCount',
        ),
        findingCount: _requiredNonNegativeInt(
          json['findingCount'],
          'findingCount',
        ),
        highestRiskLevel: _optionalRiskLevel(
          json['highestRiskLevel'],
          'highestRiskLevel',
        ),
      );

  Map<String, Object?> toJson() => {
    'channelCode': _channelCodeValue(channelCode),
    'status': _channelStatusValue(status),
    'coverageStatus': _coverageStatusValue(coverageStatus),
    'observationCount': observationCount,
    'findingCount': findingCount,
    if (highestRiskLevel != null)
      'highestRiskLevel': _riskLevelValue(highestRiskLevel!),
  };
}

final class RiskScanReportContractV1 {
  RiskScanReportContractV1({
    required String reportId,
    required String scanRunId,
    required int reportVersion,
    required RiskScanRiskLevel overallRiskLevel,
    required RiskScanConfidenceLevel overallConfidenceLevel,
    required RiskScanCoverageStatus coverageStatus,
    required List<RiskScanReportFindingSnapshotV1> topFindingSnapshots,
    required List<RiskScanReportChannelSnapshotV1> channelDistribution,
    required RiskScanReportRecommendedAction recommendedAction,
    required DateTime generatedAt,
    required String reportDigestSha256,
    required bool immutable,
  }) : reportId = _requiredString(reportId, 'reportId'),
       scanRunId = _requiredString(scanRunId, 'scanRunId'),
       reportVersion = _requiredPositiveInt(reportVersion, 'reportVersion'),
       overallRiskLevel = overallRiskLevel,
       overallConfidenceLevel = overallConfidenceLevel,
       coverageStatus = coverageStatus,
       topFindingSnapshots = _reportFindingSnapshots(topFindingSnapshots),
       channelDistribution = _reportChannelDistribution(channelDistribution),
       recommendedAction = recommendedAction,
       generatedAt = generatedAt,
       reportDigestSha256 = _requiredSha256(
         reportDigestSha256,
         'reportDigestSha256',
       ),
       immutable = immutable {
    if (!this.immutable) {
      throw const FormatException('immutable must be true');
    }
  }

  final String contractVersion = riskScanReportContractVersionV1;
  final String reportId;
  final String scanRunId;
  final int reportVersion;
  final RiskScanRiskLevel overallRiskLevel;
  final RiskScanConfidenceLevel overallConfidenceLevel;
  final RiskScanCoverageStatus coverageStatus;
  final List<RiskScanReportFindingSnapshotV1> topFindingSnapshots;
  final List<RiskScanReportChannelSnapshotV1> channelDistribution;
  final RiskScanReportRecommendedAction recommendedAction;
  final DateTime generatedAt;
  final String reportDigestSha256;
  final bool immutable;

  factory RiskScanReportContractV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != riskScanReportContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    final immutable = json['immutable'];
    if (immutable is! bool) {
      throw const FormatException('immutable must be a boolean');
    }
    return RiskScanReportContractV1(
      reportId: _requiredString(json['reportId'], 'reportId'),
      scanRunId: _requiredString(json['scanRunId'], 'scanRunId'),
      reportVersion: _requiredPositiveInt(
        json['reportVersion'],
        'reportVersion',
      ),
      overallRiskLevel: _riskLevelFrom(json['overallRiskLevel']),
      overallConfidenceLevel: _confidenceLevelFrom(
        json['overallConfidenceLevel'],
      ),
      coverageStatus: _coverageStatusFrom(json['coverageStatus']),
      topFindingSnapshots: _reportFindingSnapshotsFromJson(
        json['topFindingSnapshots'],
      ),
      channelDistribution: _reportChannelDistributionFromJson(
        json['channelDistribution'],
      ),
      recommendedAction: _reportRecommendedActionFrom(
        json['recommendedAction'],
      ),
      generatedAt: _requiredDate(json['generatedAt'], 'generatedAt'),
      reportDigestSha256: _requiredSha256(
        json['reportDigestSha256'],
        'reportDigestSha256',
      ),
      immutable: immutable,
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'reportId': reportId,
    'scanRunId': scanRunId,
    'reportVersion': reportVersion,
    'overallRiskLevel': _riskLevelValue(overallRiskLevel),
    'overallConfidenceLevel': _confidenceLevelValue(overallConfidenceLevel),
    'coverageStatus': _coverageStatusValue(coverageStatus),
    'topFindingSnapshots': [
      for (final item in topFindingSnapshots) item.toJson(),
    ],
    'channelDistribution': [
      for (final item in channelDistribution) item.toJson(),
    ],
    'recommendedAction': _reportRecommendedActionValue(recommendedAction),
    'generatedAt': generatedAt.toIso8601String(),
    'reportDigestSha256': reportDigestSha256,
    'immutable': immutable,
  };
}

int _requiredPositiveInt(Object? value, String field) {
  if (value is! int || value < 1) {
    throw FormatException('$field must be a positive integer');
  }
  return value;
}

RiskScanRiskLevel? _optionalRiskLevel(Object? value, String field) {
  if (value == null) return null;
  return _enumValue(value, {
    for (final item in RiskScanRiskLevel.values) item.name: item,
  }, field);
}

List<RiskScanReportFindingSnapshotV1> _reportFindingSnapshots(
  List<RiskScanReportFindingSnapshotV1> value,
) {
  if (value.length > 5) {
    throw const FormatException('topFindingSnapshots cannot exceed five');
  }
  final result = List<RiskScanReportFindingSnapshotV1>.unmodifiable(value);
  final identifiers = result.map((item) => item.findingId).toList();
  if (identifiers.toSet().length != identifiers.length) {
    throw const FormatException(
      'topFindingSnapshots cannot contain duplicate findingId values',
    );
  }
  return result;
}

List<RiskScanReportFindingSnapshotV1> _reportFindingSnapshotsFromJson(
  Object? value,
) {
  if (value is! List) {
    throw const FormatException('topFindingSnapshots must be an array');
  }
  return _reportFindingSnapshots(
    value
        .map(
          (item) => RiskScanReportFindingSnapshotV1.fromJson(
            _requiredMap(item, 'topFindingSnapshots'),
          ),
        )
        .toList(),
  );
}

List<RiskScanReportChannelSnapshotV1> _reportChannelDistribution(
  List<RiskScanReportChannelSnapshotV1> value,
) {
  final result = List<RiskScanReportChannelSnapshotV1>.unmodifiable(value);
  final codes = result.map((item) => item.channelCode).toList();
  if (codes.length != RiskScanChannelCode.values.length ||
      codes.toSet().length != RiskScanChannelCode.values.length ||
      !codes.toSet().containsAll(RiskScanChannelCode.values)) {
    throw const FormatException(
      'channelDistribution must contain every V1 channel exactly once',
    );
  }
  return result;
}

List<RiskScanReportChannelSnapshotV1> _reportChannelDistributionFromJson(
  Object? value,
) {
  if (value is! List) {
    throw const FormatException('channelDistribution must be an array');
  }
  return _reportChannelDistribution(
    value
        .map(
          (item) => RiskScanReportChannelSnapshotV1.fromJson(
            _requiredMap(item, 'channelDistribution'),
          ),
        )
        .toList(),
  );
}
