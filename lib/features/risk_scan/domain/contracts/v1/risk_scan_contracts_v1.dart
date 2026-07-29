library;

part 'risk_scan_common_v1.dart';
part 'risk_scan_run_contract_v1.dart';
part 'risk_scan_channel_contract_v1.dart';
part 'risk_scan_observation_contract_v1.dart';
part 'risk_scan_finding_contract_v1.dart';
part 'risk_scan_report_contract_v1.dart';
part 'risk_scan_claim_contract_v1.dart';

const String riskScanTargetContractVersionV1 = 'risk-scan-target-v1';
const String riskScanRunContractVersionV1 = 'risk-scan-run-v1';
const String riskScanChannelContractVersionV1 = 'risk-scan-channel-v1';
const String riskScanObservationContractVersionV1 = 'risk-scan-observation-v1';
const String riskScanFindingContractVersionV1 = 'risk-scan-finding-v1';
const String riskScanReportContractVersionV1 = 'risk-scan-report-v1';
const String riskScanClaimContractVersionV1 = 'risk-scan-claim-v1';

enum RiskScanMode { quick }

enum RiskScanAccessTier { publicLite, registered }

enum RiskScanIdentityMode { anonymous, resolved }

enum RiskScanRunStatus {
  created,
  validatingTarget,
  queued,
  acquiring,
  assessing,
  reporting,
  completed,
  completedWithLimits,
  failedRetryable,
  failedTerminal,
  cancelled,
  expired,
}

enum RiskScanCoverageStatus { complete, limited, insufficient }

enum RiskScanChannelCode { similarDomains, openWeb, marketplaceLimited }

enum RiskScanChannelStatus {
  queued,
  acquiring,
  assessing,
  completed,
  completedWithLimits,
  failedRetryable,
  failedTerminal,
  skipped,
}

String _scanModeValue(RiskScanMode value) => value.name;

RiskScanMode _scanModeFrom(Object? value) =>
    _enumValue(value, {'quick': RiskScanMode.quick}, 'scanMode');

String _accessTierValue(RiskScanAccessTier value) => switch (value) {
  RiskScanAccessTier.publicLite => 'public_lite',
  RiskScanAccessTier.registered => 'registered',
};

RiskScanAccessTier _accessTierFrom(Object? value) => _enumValue(value, {
  'public_lite': RiskScanAccessTier.publicLite,
  'registered': RiskScanAccessTier.registered,
}, 'accessTier');

String _identityModeValue(RiskScanIdentityMode value) => value.name;

RiskScanIdentityMode _identityModeFrom(Object? value) => _enumValue(value, {
  for (final item in RiskScanIdentityMode.values) item.name: item,
}, 'identityMode');

String _runStatusValue(RiskScanRunStatus value) => switch (value) {
  RiskScanRunStatus.validatingTarget => 'validating_target',
  RiskScanRunStatus.completedWithLimits => 'completed_with_limits',
  RiskScanRunStatus.failedRetryable => 'failed_retryable',
  RiskScanRunStatus.failedTerminal => 'failed_terminal',
  _ => value.name,
};

RiskScanRunStatus _runStatusFrom(Object? value) => _enumValue(value, {
  'created': RiskScanRunStatus.created,
  'validating_target': RiskScanRunStatus.validatingTarget,
  'queued': RiskScanRunStatus.queued,
  'acquiring': RiskScanRunStatus.acquiring,
  'assessing': RiskScanRunStatus.assessing,
  'reporting': RiskScanRunStatus.reporting,
  'completed': RiskScanRunStatus.completed,
  'completed_with_limits': RiskScanRunStatus.completedWithLimits,
  'failed_retryable': RiskScanRunStatus.failedRetryable,
  'failed_terminal': RiskScanRunStatus.failedTerminal,
  'cancelled': RiskScanRunStatus.cancelled,
  'expired': RiskScanRunStatus.expired,
}, 'status');

String _coverageStatusValue(RiskScanCoverageStatus value) => value.name;

RiskScanCoverageStatus _coverageStatusFrom(Object? value) => _enumValue(value, {
  for (final item in RiskScanCoverageStatus.values) item.name: item,
}, 'coverageStatus');

String _channelCodeValue(RiskScanChannelCode value) => switch (value) {
  RiskScanChannelCode.similarDomains => 'similar_domains',
  RiskScanChannelCode.openWeb => 'open_web',
  RiskScanChannelCode.marketplaceLimited => 'marketplace_limited',
};

RiskScanChannelCode _channelCodeFrom(Object? value) => _enumValue(value, {
  'similar_domains': RiskScanChannelCode.similarDomains,
  'open_web': RiskScanChannelCode.openWeb,
  'marketplace_limited': RiskScanChannelCode.marketplaceLimited,
}, 'channelCode');

String _channelStatusValue(RiskScanChannelStatus value) => switch (value) {
  RiskScanChannelStatus.completedWithLimits => 'completed_with_limits',
  RiskScanChannelStatus.failedRetryable => 'failed_retryable',
  RiskScanChannelStatus.failedTerminal => 'failed_terminal',
  _ => value.name,
};

RiskScanChannelStatus _channelStatusFrom(Object? value) => _enumValue(value, {
  'queued': RiskScanChannelStatus.queued,
  'acquiring': RiskScanChannelStatus.acquiring,
  'assessing': RiskScanChannelStatus.assessing,
  'completed': RiskScanChannelStatus.completed,
  'completed_with_limits': RiskScanChannelStatus.completedWithLimits,
  'failed_retryable': RiskScanChannelStatus.failedRetryable,
  'failed_terminal': RiskScanChannelStatus.failedTerminal,
  'skipped': RiskScanChannelStatus.skipped,
}, 'status');

enum RiskScanObservationSourceType { domain, webPage, marketplaceListing }

enum RiskScanAcquisitionStatus {
  discovered,
  acquired,
  acquiredWithLimits,
  failedRetryable,
  failedTerminal,
  excluded,
}

enum RiskScanFindingType {
  similarDomain,
  brandNameSimilarity,
  contentSimilarity,
  marketplaceListingSignal,
}

enum RiskScanRiskLevel { low, medium, high, critical }

enum RiskScanConfidenceLevel { low, medium, high }

enum RiskScanImpactLevel { low, medium, high, critical }

enum RiskScanInterventionDifficulty { easy, moderate, difficult }

enum RiskScanReviewStatus {
  signal,
  reviewRequired,
  suspicious,
  confirmed,
  falsePositive,
}

enum RiskScanRecommendationCode {
  reviewFinding,
  compareWithOfficialSource,
  monitorSource,
  noImmediateAction,
}

enum RiskScanPromotionStatus { notRequested, promoted }

String _observationSourceTypeValue(RiskScanObservationSourceType value) =>
    switch (value) {
      RiskScanObservationSourceType.domain => 'domain',
      RiskScanObservationSourceType.webPage => 'web_page',
      RiskScanObservationSourceType.marketplaceListing => 'marketplace_listing',
    };

RiskScanObservationSourceType _observationSourceTypeFrom(Object? value) =>
    _enumValue(value, {
      'domain': RiskScanObservationSourceType.domain,
      'web_page': RiskScanObservationSourceType.webPage,
      'marketplace_listing': RiskScanObservationSourceType.marketplaceListing,
    }, 'sourceType');

String _acquisitionStatusValue(RiskScanAcquisitionStatus value) =>
    switch (value) {
      RiskScanAcquisitionStatus.acquiredWithLimits => 'acquired_with_limits',
      RiskScanAcquisitionStatus.failedRetryable => 'failed_retryable',
      RiskScanAcquisitionStatus.failedTerminal => 'failed_terminal',
      _ => value.name,
    };

RiskScanAcquisitionStatus _acquisitionStatusFrom(Object? value) =>
    _enumValue(value, {
      'discovered': RiskScanAcquisitionStatus.discovered,
      'acquired': RiskScanAcquisitionStatus.acquired,
      'acquired_with_limits': RiskScanAcquisitionStatus.acquiredWithLimits,
      'failed_retryable': RiskScanAcquisitionStatus.failedRetryable,
      'failed_terminal': RiskScanAcquisitionStatus.failedTerminal,
      'excluded': RiskScanAcquisitionStatus.excluded,
    }, 'acquisitionStatus');

String _findingTypeValue(RiskScanFindingType value) => switch (value) {
  RiskScanFindingType.similarDomain => 'similar_domain',
  RiskScanFindingType.brandNameSimilarity => 'brand_name_similarity',
  RiskScanFindingType.contentSimilarity => 'content_similarity',
  RiskScanFindingType.marketplaceListingSignal => 'marketplace_listing_signal',
};

RiskScanFindingType _findingTypeFrom(Object? value) => _enumValue(value, {
  'similar_domain': RiskScanFindingType.similarDomain,
  'brand_name_similarity': RiskScanFindingType.brandNameSimilarity,
  'content_similarity': RiskScanFindingType.contentSimilarity,
  'marketplace_listing_signal': RiskScanFindingType.marketplaceListingSignal,
}, 'findingType');

String _riskLevelValue(RiskScanRiskLevel value) => value.name;

RiskScanRiskLevel _riskLevelFrom(Object? value) => _enumValue(value, {
  for (final item in RiskScanRiskLevel.values) item.name: item,
}, 'riskLevel');

String _confidenceLevelValue(RiskScanConfidenceLevel value) => value.name;

RiskScanConfidenceLevel _confidenceLevelFrom(Object? value) => _enumValue(
  value,
  {for (final item in RiskScanConfidenceLevel.values) item.name: item},
  'confidenceLevel',
);

String _impactLevelValue(RiskScanImpactLevel value) => value.name;

RiskScanImpactLevel _impactLevelFrom(Object? value) => _enumValue(value, {
  for (final item in RiskScanImpactLevel.values) item.name: item,
}, 'impactLevel');

String _interventionDifficultyValue(RiskScanInterventionDifficulty value) =>
    value.name;

RiskScanInterventionDifficulty _interventionDifficultyFrom(Object? value) =>
    _enumValue(value, {
      for (final item in RiskScanInterventionDifficulty.values) item.name: item,
    }, 'interventionDifficulty');

String _reviewStatusValue(RiskScanReviewStatus value) => switch (value) {
  RiskScanReviewStatus.reviewRequired => 'review_required',
  RiskScanReviewStatus.falsePositive => 'false_positive',
  _ => value.name,
};

RiskScanReviewStatus _reviewStatusFrom(Object? value) => _enumValue(value, {
  'signal': RiskScanReviewStatus.signal,
  'review_required': RiskScanReviewStatus.reviewRequired,
  'suspicious': RiskScanReviewStatus.suspicious,
  'confirmed': RiskScanReviewStatus.confirmed,
  'false_positive': RiskScanReviewStatus.falsePositive,
}, 'reviewStatus');

String _recommendationCodeValue(RiskScanRecommendationCode value) =>
    switch (value) {
      RiskScanRecommendationCode.reviewFinding => 'review_finding',
      RiskScanRecommendationCode.compareWithOfficialSource =>
        'compare_with_official_source',
      RiskScanRecommendationCode.monitorSource => 'monitor_source',
      RiskScanRecommendationCode.noImmediateAction => 'no_immediate_action',
    };

RiskScanRecommendationCode _recommendationCodeFrom(Object? value) =>
    _enumValue(value, {
      'review_finding': RiskScanRecommendationCode.reviewFinding,
      'compare_with_official_source':
          RiskScanRecommendationCode.compareWithOfficialSource,
      'monitor_source': RiskScanRecommendationCode.monitorSource,
      'no_immediate_action': RiskScanRecommendationCode.noImmediateAction,
    }, 'recommendationCode');

String _promotionStatusValue(RiskScanPromotionStatus value) => switch (value) {
  RiskScanPromotionStatus.notRequested => 'not_requested',
  RiskScanPromotionStatus.promoted => 'promoted',
};

RiskScanPromotionStatus _promotionStatusFrom(Object? value) =>
    _enumValue(value, {
      'not_requested': RiskScanPromotionStatus.notRequested,
      'promoted': RiskScanPromotionStatus.promoted,
    }, 'promotionStatus');

enum RiskScanReportRecommendedAction {
  reviewTopFindings,
  claimScan,
  startHumanReview,
  noImmediateAction,
}

enum RiskScanClaimStatus { issued, claimed, expired, revoked }

String _reportRecommendedActionValue(
  RiskScanReportRecommendedAction value,
) => switch (value) {
  RiskScanReportRecommendedAction.reviewTopFindings => 'review_top_findings',
  RiskScanReportRecommendedAction.claimScan => 'claim_scan',
  RiskScanReportRecommendedAction.startHumanReview => 'start_human_review',
  RiskScanReportRecommendedAction.noImmediateAction => 'no_immediate_action',
};

RiskScanReportRecommendedAction _reportRecommendedActionFrom(Object? value) =>
    _enumValue(value, {
      'review_top_findings': RiskScanReportRecommendedAction.reviewTopFindings,
      'claim_scan': RiskScanReportRecommendedAction.claimScan,
      'start_human_review': RiskScanReportRecommendedAction.startHumanReview,
      'no_immediate_action': RiskScanReportRecommendedAction.noImmediateAction,
    }, 'recommendedAction');

String _claimStatusValue(RiskScanClaimStatus value) => value.name;

RiskScanClaimStatus _claimStatusFrom(Object? value) => _enumValue(value, {
  for (final item in RiskScanClaimStatus.values) item.name: item,
}, 'status');
