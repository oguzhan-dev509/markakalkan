class InternalRealProvisioningGate {
  const InternalRealProvisioningGate._();

  static const bool enabled = bool.fromEnvironment(
    'MARKAKALKAN_ENABLE_INTERNAL_REAL_PROVISIONING',
    defaultValue: false,
  );
}
