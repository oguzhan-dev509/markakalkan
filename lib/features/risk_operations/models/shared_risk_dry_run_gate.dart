abstract final class SharedRiskDryRunGate {
  static const bool enabled = bool.fromEnvironment(
    'MARKAKALKAN_ENABLE_SHARED_RISK_DRY_RUN',
    defaultValue: false,
  );
}
