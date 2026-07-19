import 'package:markakalkan/shared/risk_contracts/v1/audit/audit_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/commands/commands_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/identity/identity_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/persistence/persistence_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

import '../persistence/persistence_test_fixtures.dart' as base;

final commandAt = DateTime.parse('2026-07-19T16:00:00Z');
final auditAt = DateTime.parse('2026-07-19T17:00:00Z');

PersistenceAuthorizationContextV1 authorization({
  String tenantId = 'tenant-1',
  String? brandId = 'brand-1',
  List<String> roles = const ['risk_writer'],
  List<String> permissions = const ['risk_signal.persist'],
  DateTime? authorizedAt,
  DateTime? expiresAt,
}) => PersistenceAuthorizationContextV1(
  actorUid: 'actor-1',
  actorType: PersistenceActorTypeV1.serviceAccount,
  tenantId: tenantId,
  brandId: brandId,
  roles: roles,
  permissions: permissions,
  authorizationSource: 'verified-token-context',
  authorizedAt: authorizedAt ?? DateTime.parse('2026-07-19T14:00:00Z'),
  expiresAt: expiresAt,
  requestId: 'request-1',
  metadata: const {
    'scope': {'verified': true},
  },
);

PersistenceCommandProvenanceV1 commandProvenance({
  String module = 'traceability',
  DateTime? createdAt,
}) => PersistenceCommandProvenanceV1(
  requestedByModule: module,
  createdAt: createdAt ?? commandAt,
  correlationId: 'correlation-1',
);

PersistenceReadinessDecisionV1 decisionCopy(
  PersistenceReadinessDecisionV1 source, {
  String? policyVersion,
  PersistenceSubjectTypeV1? subjectType,
  String? subjectId,
  List<PersistenceReadinessIssueV1>? issues,
  DateTime? evaluatedAt,
  IdentityResolutionResultStatus? identityStatus,
  String? evaluatedIdempotencyKey,
  bool removeIdempotencyKey = false,
}) => PersistenceReadinessDecisionV1(
  policyVersion: policyVersion ?? source.policyVersion,
  subjectType: subjectType ?? source.subjectType,
  subjectId: subjectId ?? source.subjectId,
  issues: issues ?? [...source.blockers, ...source.warnings],
  evaluatedAt: evaluatedAt ?? source.evaluatedAt,
  identityResolutionStatus: identityStatus ?? source.identityResolutionStatus,
  evaluatedIdempotencyKey: removeIdempotencyKey
      ? null
      : evaluatedIdempotencyKey ?? source.evaluatedIdempotencyKey,
  provenance: source.provenance,
);

PersistRiskSignalCommandV1 signalCommand({
  RiskSignalContractV1? subject,
  PersistenceAuthorizationContextV1? auth,
  PersistenceTargetNamespaceV1 target =
      PersistenceTargetNamespaceV1.sharedRiskSignals,
  String module = 'traceability',
  PersistenceReadinessDecisionV1? readiness,
  SubjectFingerprintV1? fingerprint,
  PersistenceIdempotencyBindingV1? idempotency,
  DateTime? requestedAt,
  DateTime? provenanceAt,
  String? commandId,
}) {
  final actualSubject = subject ?? base.signal();
  final key = base.keyFor('traceability');
  final binding =
      idempotency ?? PersistenceIdempotencyBindingV1.exactSource(key);
  final ready =
      readiness ??
      const RiskSignalPersistenceReadinessEvaluatorV1().evaluate(
        base.signalRequest(subject: actualSubject, key: key),
      );
  final actualAuth = auth ?? authorization();
  final time = requestedAt ?? commandAt;
  final provenance = commandProvenance(
    module: module,
    createdAt: provenanceAt ?? time,
  );
  final readinessBinding = ReadinessDecisionBindingV1(
    decision: ready,
    subjectFingerprint:
        fingerprint ??
        const SubjectFingerprintBuilderV1().riskSignal(actualSubject),
  );
  final canonical = PersistRiskSignalCommandV1.create(
    subject: actualSubject,
    readinessBinding: readinessBinding,
    idempotencyBinding: binding,
    targetNamespace: target,
    authorizationContext: actualAuth,
    commandRequestedAt: time,
    requestedByModule: module,
    dryRun: true,
    commandProvenance: provenance,
  );
  if (commandId == null) return canonical;
  return PersistRiskSignalCommandV1(
    commandId: commandId,
    subject: canonical.subject,
    readinessBinding: canonical.readinessBinding,
    idempotencyBinding: canonical.idempotencyBinding,
    targetNamespace: canonical.targetNamespace,
    authorizationContext: canonical.authorizationContext,
    commandRequestedAt: canonical.commandRequestedAt,
    requestedByModule: canonical.requestedByModule,
    dryRun: canonical.dryRun,
    commandProvenance: canonical.commandProvenance,
  );
}

PersistRiskAssessmentCommandV1 riskCommand({
  PersistenceTargetNamespaceV1 target =
      PersistenceTargetNamespaceV1.sharedRiskAssessments,
}) {
  final subject = base.risk();
  final key = base.keyFor('traceability');
  final idempotency = PersistenceIdempotencyBindingV1.exactSource(key);
  final readiness = const RiskAssessmentPersistenceReadinessEvaluatorV1()
      .evaluate(base.riskRequest(subject: subject));
  return PersistRiskAssessmentCommandV1.create(
    subject: subject,
    readinessBinding: ReadinessDecisionBindingV1(
      decision: readiness,
      subjectFingerprint: const SubjectFingerprintBuilderV1().riskAssessment(
        subject,
      ),
    ),
    idempotencyBinding: idempotency,
    targetNamespace: target,
    authorizationContext: authorization(
      permissions: const ['risk_assessment.persist'],
    ),
    commandRequestedAt: commandAt,
    requestedByModule: 'traceability',
    dryRun: true,
    commandProvenance: commandProvenance(),
  );
}

PersistCaseCandidateCommandV1 candidateCommand({
  PersistenceTargetNamespaceV1 target =
      PersistenceTargetNamespaceV1.sharedCaseCandidates,
}) {
  final subject = base.candidate(signals: [base.entity('signal-1')]);
  final readiness = const CaseCandidatePersistenceReadinessEvaluatorV1()
      .evaluate(base.candidateRequest(subject));
  final binding = PersistenceIdempotencyBindingV1.caseCandidate(
    caseCandidateId: subject.caseCandidateId,
    deduplicationKey: subject.deduplicationKey,
    tenantId: 'tenant-1',
    targetNamespace: target,
  );
  return PersistCaseCandidateCommandV1.create(
    subject: subject,
    readinessBinding: ReadinessDecisionBindingV1(
      decision: readiness,
      subjectFingerprint: const SubjectFingerprintBuilderV1().caseCandidate(
        subject,
      ),
    ),
    idempotencyBinding: binding,
    targetNamespace: target,
    authorizationContext: authorization(
      permissions: const ['case_candidate.persist'],
    ),
    commandRequestedAt: commandAt,
    requestedByModule: 'traceability',
    dryRun: true,
    commandProvenance: commandProvenance(),
  );
}

PersistenceCommandAuditDecisionV1 auditSignal(
  PersistRiskSignalCommandV1 command, {
  DateTime? at,
}) => const RiskSignalPersistenceCommandAuditorV1().audit(
  command,
  auditedAt: at ?? auditAt,
);
