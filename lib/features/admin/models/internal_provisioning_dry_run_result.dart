enum InternalProvisioningOutcome {
  created('created'),
  idempotentSuccess('idempotent_success'),
  dryRunReady('dry_run_ready'),
  conflict('conflict');

  const InternalProvisioningOutcome(this.wireValue);
  final String wireValue;

  static InternalProvisioningOutcome parse(String value) {
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () =>
          throw const FormatException('Invalid provisioning response'),
    );
  }
}

class InternalProvisioningResult {
  const InternalProvisioningResult({
    required this.outcome,
    required this.dryRun,
    required this.transactionCommitted,
    required this.rolloutMode,
    required this.blockerCodes,
    required this.tenantId,
    required this.brandId,
    required this.membershipId,
    required this.receiptId,
    required this.auditEventId,
  });

  final InternalProvisioningOutcome outcome;
  final bool dryRun;
  final bool transactionCommitted;
  final String rolloutMode;
  final List<String> blockerCodes;
  final String? tenantId;
  final String? brandId;
  final String? membershipId;
  final String? receiptId;
  final String? auditEventId;

  factory InternalProvisioningResult.fromMap(Map<Object?, Object?> map) {
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
    if (rawBlockers is! List ||
        map['dryRun'] is! bool ||
        map['transactionCommitted'] is! bool) {
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

    final outcome = InternalProvisioningOutcome.parse(
      requiredString('outcome'),
    );
    final dryRun = map['dryRun'] as bool;
    final committed = map['transactionCommitted'] as bool;
    if ((outcome == InternalProvisioningOutcome.created && !committed) ||
        (outcome != InternalProvisioningOutcome.created && committed) ||
        (outcome == InternalProvisioningOutcome.dryRunReady && !dryRun) ||
        (outcome != InternalProvisioningOutcome.dryRunReady && dryRun)) {
      throw const FormatException('Invalid provisioning response');
    }

    return InternalProvisioningResult(
      outcome: outcome,
      dryRun: dryRun,
      transactionCommitted: committed,
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

typedef InternalProvisioningDryRunResult = InternalProvisioningResult;
