part of 'commands_v1.dart';

abstract interface class PersistenceCommandViewV1 {
  String get contractVersion;
  String get commandId;
  PersistenceSubjectTypeV1 get subjectType;
  String get subjectId;
  IdentityScope get subjectIdentity;
  Map<String, Object?> get subjectJson;
  ReadinessDecisionBindingV1 get readinessBinding;
  PersistenceIdempotencyBindingV1 get idempotencyBinding;
  PersistenceTargetNamespaceV1 get targetNamespace;
  PersistenceAuthorizationContextV1 get authorizationContext;
  DateTime get commandRequestedAt;
  String get requestedByModule;
  bool get dryRun;
  PersistenceCommandProvenanceV1 get commandProvenance;
  Map<String, Object?> toJson();
}

String buildPersistenceCommandIdV1({
  required PersistenceSubjectTypeV1 subjectType,
  required String subjectId,
  required PersistenceTargetNamespaceV1 targetNamespace,
  required String idempotencyKey,
  required String tenantId,
}) => _encode([
  persistenceCommandContractVersionV1,
  _commandSubjectValue(subjectType),
  _required(subjectId, 'subjectId'),
  _targetValue(targetNamespace),
  _required(idempotencyKey, 'idempotencyKey'),
  _required(tenantId, 'tenantId'),
]);

mixin _CommandCommonV1 implements PersistenceCommandViewV1 {
  @override
  String get contractVersion => persistenceCommandContractVersionV1;

  @override
  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'commandId': commandId,
    'subjectType': _commandSubjectValue(subjectType),
    'subject': subjectJson,
    'readinessBinding': readinessBinding.toJson(),
    'idempotencyBinding': idempotencyBinding.toJson(),
    'targetNamespace': persistenceTargetNamespaceValueV1(targetNamespace),
    'authorizationContext': authorizationContext.toJson(),
    'commandRequestedAt': commandRequestedAt.toIso8601String(),
    'requestedByModule': requestedByModule,
    'dryRun': dryRun,
    'commandProvenance': commandProvenance.toJson(),
  };
}

final class PersistRiskSignalCommandV1 with _CommandCommonV1 {
  PersistRiskSignalCommandV1({
    required this.commandId,
    required this.subject,
    required this.readinessBinding,
    required this.idempotencyBinding,
    required this.targetNamespace,
    required this.authorizationContext,
    required this.commandRequestedAt,
    required this.requestedByModule,
    required this.dryRun,
    required this.commandProvenance,
  });
  factory PersistRiskSignalCommandV1.create({
    required RiskSignalContractV1 subject,
    required ReadinessDecisionBindingV1 readinessBinding,
    required PersistenceIdempotencyBindingV1 idempotencyBinding,
    required PersistenceTargetNamespaceV1 targetNamespace,
    required PersistenceAuthorizationContextV1 authorizationContext,
    required DateTime commandRequestedAt,
    required String requestedByModule,
    required bool dryRun,
    required PersistenceCommandProvenanceV1 commandProvenance,
  }) => PersistRiskSignalCommandV1(
    commandId: buildPersistenceCommandIdV1(
      subjectType: PersistenceSubjectTypeV1.riskSignal,
      subjectId: subject.signalId,
      targetNamespace: targetNamespace,
      idempotencyKey: idempotencyBinding.canonicalKey,
      tenantId: authorizationContext.tenantId,
    ),
    subject: subject,
    readinessBinding: readinessBinding,
    idempotencyBinding: idempotencyBinding,
    targetNamespace: targetNamespace,
    authorizationContext: authorizationContext,
    commandRequestedAt: commandRequestedAt,
    requestedByModule: _required(requestedByModule, 'requestedByModule'),
    dryRun: dryRun,
    commandProvenance: commandProvenance,
  );
  @override
  final String commandId;
  final RiskSignalContractV1 subject;
  @override
  PersistenceSubjectTypeV1 get subjectType =>
      PersistenceSubjectTypeV1.riskSignal;
  @override
  String get subjectId => subject.signalId;
  @override
  IdentityScope get subjectIdentity => subject.identityScope;
  @override
  Map<String, Object?> get subjectJson => subject.toJson();
  @override
  final ReadinessDecisionBindingV1 readinessBinding;
  @override
  final PersistenceIdempotencyBindingV1 idempotencyBinding;
  @override
  final PersistenceTargetNamespaceV1 targetNamespace;
  @override
  final PersistenceAuthorizationContextV1 authorizationContext;
  @override
  final DateTime commandRequestedAt;
  @override
  final String requestedByModule;
  @override
  final bool dryRun;
  @override
  final PersistenceCommandProvenanceV1 commandProvenance;
}

final class PersistRiskAssessmentCommandV1 with _CommandCommonV1 {
  PersistRiskAssessmentCommandV1({
    required this.commandId,
    required this.subject,
    required this.readinessBinding,
    required this.idempotencyBinding,
    required this.targetNamespace,
    required this.authorizationContext,
    required this.commandRequestedAt,
    required this.requestedByModule,
    required this.dryRun,
    required this.commandProvenance,
  });
  factory PersistRiskAssessmentCommandV1.create({
    required RiskAssessmentContractV1 subject,
    required ReadinessDecisionBindingV1 readinessBinding,
    required PersistenceIdempotencyBindingV1 idempotencyBinding,
    required PersistenceTargetNamespaceV1 targetNamespace,
    required PersistenceAuthorizationContextV1 authorizationContext,
    required DateTime commandRequestedAt,
    required String requestedByModule,
    required bool dryRun,
    required PersistenceCommandProvenanceV1 commandProvenance,
  }) => PersistRiskAssessmentCommandV1(
    commandId: buildPersistenceCommandIdV1(
      subjectType: PersistenceSubjectTypeV1.riskAssessment,
      subjectId: subject.riskId,
      targetNamespace: targetNamespace,
      idempotencyKey: idempotencyBinding.canonicalKey,
      tenantId: authorizationContext.tenantId,
    ),
    subject: subject,
    readinessBinding: readinessBinding,
    idempotencyBinding: idempotencyBinding,
    targetNamespace: targetNamespace,
    authorizationContext: authorizationContext,
    commandRequestedAt: commandRequestedAt,
    requestedByModule: _required(requestedByModule, 'requestedByModule'),
    dryRun: dryRun,
    commandProvenance: commandProvenance,
  );
  @override
  final String commandId;
  final RiskAssessmentContractV1 subject;
  @override
  PersistenceSubjectTypeV1 get subjectType =>
      PersistenceSubjectTypeV1.riskAssessment;
  @override
  String get subjectId => subject.riskId;
  @override
  IdentityScope get subjectIdentity => subject.identityScope;
  @override
  Map<String, Object?> get subjectJson => subject.toJson();
  @override
  final ReadinessDecisionBindingV1 readinessBinding;
  @override
  final PersistenceIdempotencyBindingV1 idempotencyBinding;
  @override
  final PersistenceTargetNamespaceV1 targetNamespace;
  @override
  final PersistenceAuthorizationContextV1 authorizationContext;
  @override
  final DateTime commandRequestedAt;
  @override
  final String requestedByModule;
  @override
  final bool dryRun;
  @override
  final PersistenceCommandProvenanceV1 commandProvenance;
}

final class PersistCaseCandidateCommandV1 with _CommandCommonV1 {
  PersistCaseCandidateCommandV1({
    required this.commandId,
    required this.subject,
    required this.readinessBinding,
    required this.idempotencyBinding,
    required this.targetNamespace,
    required this.authorizationContext,
    required this.commandRequestedAt,
    required this.requestedByModule,
    required this.dryRun,
    required this.commandProvenance,
  });
  factory PersistCaseCandidateCommandV1.create({
    required CaseCandidateContractV1 subject,
    required ReadinessDecisionBindingV1 readinessBinding,
    required PersistenceIdempotencyBindingV1 idempotencyBinding,
    required PersistenceTargetNamespaceV1 targetNamespace,
    required PersistenceAuthorizationContextV1 authorizationContext,
    required DateTime commandRequestedAt,
    required String requestedByModule,
    required bool dryRun,
    required PersistenceCommandProvenanceV1 commandProvenance,
  }) => PersistCaseCandidateCommandV1(
    commandId: buildPersistenceCommandIdV1(
      subjectType: PersistenceSubjectTypeV1.caseCandidate,
      subjectId: subject.caseCandidateId,
      targetNamespace: targetNamespace,
      idempotencyKey: idempotencyBinding.canonicalKey,
      tenantId: authorizationContext.tenantId,
    ),
    subject: subject,
    readinessBinding: readinessBinding,
    idempotencyBinding: idempotencyBinding,
    targetNamespace: targetNamespace,
    authorizationContext: authorizationContext,
    commandRequestedAt: commandRequestedAt,
    requestedByModule: _required(requestedByModule, 'requestedByModule'),
    dryRun: dryRun,
    commandProvenance: commandProvenance,
  );
  @override
  final String commandId;
  final CaseCandidateContractV1 subject;
  @override
  PersistenceSubjectTypeV1 get subjectType =>
      PersistenceSubjectTypeV1.caseCandidate;
  @override
  String get subjectId => subject.caseCandidateId;
  @override
  IdentityScope get subjectIdentity => subject.identityScope;
  @override
  Map<String, Object?> get subjectJson => subject.toJson();
  @override
  final ReadinessDecisionBindingV1 readinessBinding;
  @override
  final PersistenceIdempotencyBindingV1 idempotencyBinding;
  @override
  final PersistenceTargetNamespaceV1 targetNamespace;
  @override
  final PersistenceAuthorizationContextV1 authorizationContext;
  @override
  final DateTime commandRequestedAt;
  @override
  final String requestedByModule;
  @override
  final bool dryRun;
  @override
  final PersistenceCommandProvenanceV1 commandProvenance;
}
