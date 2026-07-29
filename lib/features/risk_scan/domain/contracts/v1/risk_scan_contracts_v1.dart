library;

part 'risk_scan_common_v1.dart';
part 'risk_scan_run_contract_v1.dart';
part 'risk_scan_channel_contract_v1.dart';

const String riskScanTargetContractVersionV1 = 'risk-scan-target-v1';
const String riskScanRunContractVersionV1 = 'risk-scan-run-v1';
const String riskScanChannelContractVersionV1 = 'risk-scan-channel-v1';

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
