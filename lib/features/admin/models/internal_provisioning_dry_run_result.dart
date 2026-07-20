class InternalProvisioningDryRunResult {
  const InternalProvisioningDryRunResult({
    required this.outcome,
    required this.transactionCommitted,
    required this.rolloutMode,
    required this.blockerCodes,
    required this.tenantId,
    required this.brandId,
    required this.membershipId,
    required this.receiptId,
    required this.auditEventId,
  });

  final String outcome;
  final bool transactionCommitted;
  final String rolloutMode;
  final List<String> blockerCodes;
  final String? tenantId;
  final String? brandId;
  final String? membershipId;
  final String? receiptId;
  final String? auditEventId;

  factory InternalProvisioningDryRunResult.fromMap(Map<Object?, Object?> map) {
    String requiredString(String key) {
      final value = map[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid provisioning response');
      }
      return value.trim();
    }

    String? optionalString(String key) {
      final value = map[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final rawBlockers = map['blockerCodes'];
    if (rawBlockers is! List || map['transactionCommitted'] is! bool) {
      throw const FormatException('Invalid provisioning response');
    }
    final blockers = rawBlockers
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (blockers.length != rawBlockers.length) {
      throw const FormatException('Invalid provisioning response');
    }

    return InternalProvisioningDryRunResult(
      outcome: requiredString('outcome'),
      transactionCommitted: map['transactionCommitted'] == true,
      rolloutMode: requiredString('rolloutMode'),
      blockerCodes: blockers,
      tenantId: optionalString('tenantId'),
      brandId: optionalString('brandId'),
      membershipId: optionalString('membershipId'),
      receiptId: optionalString('receiptId'),
      auditEventId: optionalString('auditEventId'),
    );
  }
}
