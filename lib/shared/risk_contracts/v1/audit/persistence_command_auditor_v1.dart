// ignore_for_file: curly_braces_in_flow_control_structures

part of 'audit_v1.dart';

final class PersistenceCommandAuditorCoreV1 {
  const PersistenceCommandAuditorCoreV1();
  static const _fingerprints = SubjectFingerprintBuilderV1();
  static const _modules = {
    'risk_orchestration',
    'traceability',
    'monitoring',
    'digital_market_monitoring',
    'digital_detective',
  };

  PersistenceCommandAuditDecisionV1 audit(
    PersistenceCommandViewV1 command, {
    required DateTime auditedAt,
    required PersistenceTargetNamespaceV1 expectedTarget,
    required String requiredPermission,
    required PersistenceIdempotencyPurposeV1 requiredPurpose,
  }) {
    final issues = <PersistenceCommandAuditIssueV1>[];
    void block(String code, String path, String message) => issues.add(
      PersistenceCommandAuditIssueV1(
        code: code,
        severity: PersistenceCommandAuditSeverityV1.blocker,
        fieldPath: path,
        message: message,
      ),
    );
    void warn(String code, String path, String message) => issues.add(
      PersistenceCommandAuditIssueV1(
        code: code,
        severity: PersistenceCommandAuditSeverityV1.warning,
        fieldPath: path,
        message: message,
      ),
    );

    if (command.contractVersion != persistenceCommandContractVersionV1)
      block(
        'command.version_unsupported',
        'contractVersion',
        'Unsupported command contract.',
      );
    if (command.targetNamespace != expectedTarget)
      block(
        'target.subject_mismatch',
        'targetNamespace',
        'Target does not match subject type.',
      );
    if (!_modules.contains(command.requestedByModule) ||
        command.commandProvenance.requestedByModule !=
            command.requestedByModule) {
      block(
        'command.requester_denied',
        'requestedByModule',
        'Command producer is not allowlisted or inconsistent.',
      );
    }
    final auth = command.authorizationContext;
    if (!auth.permissions.contains(requiredPermission))
      block(
        'authorization.permission_missing',
        'authorizationContext.permissions',
        'Exact persistence permission is required.',
      );
    if (!auth.isActiveAt(command.commandRequestedAt))
      block(
        'authorization.not_active',
        'authorizationContext',
        'Authorization is not active at command time.',
      );
    final resolved = command.readinessBinding.decision;
    if (!resolved.allowed || resolved.blockers.isNotEmpty)
      block(
        'readiness.denied',
        'readinessDecision.allowed',
        'Readiness decision must allow persistence.',
      );
    if (resolved.warnings.isNotEmpty)
      warn(
        'readiness.warnings_present',
        'readinessDecision.warnings',
        'Readiness decision contains non-blocking warnings.',
      );
    if (resolved.policyVersion != riskPersistenceReadinessPolicyVersionV1)
      block(
        'readiness.policy_unsupported',
        'readinessDecision.policyVersion',
        'Readiness policy is unsupported.',
      );
    if (resolved.subjectType != command.subjectType ||
        resolved.subjectId != command.subjectId)
      block(
        'binding.readiness_subject_mismatch',
        'readinessDecision.subjectId',
        'Readiness subject does not match command.',
      );
    if (resolved.identityResolutionStatus !=
        IdentityResolutionResultStatus.resolved)
      block(
        'readiness.identity_not_resolved',
        'readinessDecision.identityResolutionStatus',
        'Readiness identity must be resolved.',
      );
    if (resolved.evaluatedAt.isAfter(command.commandRequestedAt))
      block(
        'chronology.readiness_future',
        'readinessDecision.evaluatedAt',
        'Readiness cannot be evaluated after command request.',
      );
    final tenant = command.subjectIdentity.tenantId;
    if (tenant == null || tenant != auth.tenantId)
      block(
        'authorization.tenant_mismatch',
        'authorizationContext.tenantId',
        'Authorization tenant does not match subject.',
      );
    if (auth.brandId != null &&
        command.subjectIdentity.brandId != null &&
        auth.brandId != command.subjectIdentity.brandId)
      block(
        'authorization.brand_mismatch',
        'authorizationContext.brandId',
        'Authorization brand does not match subject.',
      );

    final expectedFingerprint = _fingerprints.fromJson(command.subjectJson);
    final boundFingerprint = command.readinessBinding.subjectFingerprint;
    if (boundFingerprint.algorithm != subjectFingerprintAlgorithmV1)
      block(
        'fingerprint.algorithm_unsupported',
        'subjectFingerprint.algorithm',
        'Fingerprint algorithm is unsupported.',
      );
    if (boundFingerprint.value != expectedFingerprint.value)
      block(
        'fingerprint.subject_mismatch',
        'subjectFingerprint.value',
        'Subject fingerprint does not match command subject.',
      );
    final idempotency = command.idempotencyBinding;
    if (idempotency.purpose != requiredPurpose)
      block(
        'idempotency.purpose_mismatch',
        'idempotencyBinding.purpose',
        'Idempotency purpose does not match subject.',
      );
    if (requiredPurpose ==
        PersistenceIdempotencyPurposeV1.caseCandidateInitialPersistence) {
      if (idempotency.caseCandidateId != command.subjectId ||
          idempotency.candidateDeduplicationKey !=
              command.subjectJson['deduplicationKey'] ||
          idempotency.tenantId != auth.tenantId ||
          idempotency.targetNamespace != command.targetNamespace) {
        block(
          'idempotency.candidate_binding_mismatch',
          'idempotencyBinding',
          'Candidate persistence binding does not match command.',
        );
      }
    }
    if (requiredPurpose ==
            PersistenceIdempotencyPurposeV1.exactSourceOccurrence &&
        resolved.evaluatedIdempotencyKey == null)
      block(
        'idempotency.readiness_key_missing',
        'readinessDecision.evaluatedIdempotencyKey',
        'Readiness exact idempotency key is required.',
      );
    if (resolved.evaluatedIdempotencyKey != null &&
        resolved.evaluatedIdempotencyKey != idempotency.canonicalKey)
      block(
        'idempotency.readiness_mismatch',
        'idempotencyBinding.canonicalKey',
        'Readiness and command idempotency keys differ.',
      );
    final expectedCommandId = buildPersistenceCommandIdV1(
      subjectType: command.subjectType,
      subjectId: command.subjectId,
      targetNamespace: command.targetNamespace,
      idempotencyKey: idempotency.canonicalKey,
      tenantId: auth.tenantId,
    );
    if (expectedCommandId != command.commandId)
      block('command.id_mismatch', 'commandId', 'Command ID is not canonical.');
    if (command.commandProvenance.createdAt != command.commandRequestedAt)
      block(
        'chronology.command_provenance_mismatch',
        'commandProvenance.createdAt',
        'Command provenance time must equal request time.',
      );
    if (auditedAt.isBefore(command.commandRequestedAt))
      block(
        'chronology.audit_before_command',
        'auditedAt',
        'Audit cannot precede command.',
      );
    return PersistenceCommandAuditDecisionV1(
      commandId: command.commandId,
      subjectType: command.subjectType,
      subjectId: command.subjectId,
      targetNamespace: command.targetNamespace,
      issues: issues,
      dryRun: command.dryRun,
      commandRequestedAt: command.commandRequestedAt,
      auditedAt: auditedAt,
      readinessPolicyVersion: resolved.policyVersion,
      authorizationTenantId: auth.tenantId,
      persistenceIdempotencyKey: idempotency.canonicalKey,
      subjectFingerprint: expectedFingerprint,
      provenance: command.commandProvenance,
    );
  }
}

final class RiskSignalPersistenceCommandAuditorV1 {
  const RiskSignalPersistenceCommandAuditorV1();
  PersistenceCommandAuditDecisionV1 audit(
    PersistRiskSignalCommandV1 command, {
    required DateTime auditedAt,
  }) => const PersistenceCommandAuditorCoreV1().audit(
    command,
    auditedAt: auditedAt,
    expectedTarget: PersistenceTargetNamespaceV1.sharedRiskSignals,
    requiredPermission: 'risk_signal.persist',
    requiredPurpose: PersistenceIdempotencyPurposeV1.exactSourceOccurrence,
  );
}

final class RiskAssessmentPersistenceCommandAuditorV1 {
  const RiskAssessmentPersistenceCommandAuditorV1();
  PersistenceCommandAuditDecisionV1 audit(
    PersistRiskAssessmentCommandV1 command, {
    required DateTime auditedAt,
  }) => const PersistenceCommandAuditorCoreV1().audit(
    command,
    auditedAt: auditedAt,
    expectedTarget: PersistenceTargetNamespaceV1.sharedRiskAssessments,
    requiredPermission: 'risk_assessment.persist',
    requiredPurpose: PersistenceIdempotencyPurposeV1.exactSourceOccurrence,
  );
}

final class CaseCandidatePersistenceCommandAuditorV1 {
  const CaseCandidatePersistenceCommandAuditorV1();
  PersistenceCommandAuditDecisionV1 audit(
    PersistCaseCandidateCommandV1 command, {
    required DateTime auditedAt,
  }) => const PersistenceCommandAuditorCoreV1().audit(
    command,
    auditedAt: auditedAt,
    expectedTarget: PersistenceTargetNamespaceV1.sharedCaseCandidates,
    requiredPermission: 'case_candidate.persist',
    requiredPurpose:
        PersistenceIdempotencyPurposeV1.caseCandidateInitialPersistence,
  );
}
