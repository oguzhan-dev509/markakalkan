// ignore_for_file: prefer_initializing_formals, curly_braces_in_flow_control_structures

part of 'audit_v1.dart';

final class PersistenceCommandAuditIssueV1 {
  PersistenceCommandAuditIssueV1({
    required String code,
    required this.severity,
    required String message,
    String? fieldPath,
    String? relatedReference,
  }) : code = _required(code, 'code'),
       message = _required(message, 'message'),
       fieldPath = fieldPath,
       relatedReference = relatedReference {
    if (!this.code.contains('.'))
      throw const FormatException('audit issue code must be namespaced');
  }
  final String code;
  final PersistenceCommandAuditSeverityV1 severity;
  final String message;
  final String? fieldPath;
  final String? relatedReference;
  String get sortKey =>
      '$code\u0000${fieldPath ?? ''}\u0000${relatedReference ?? ''}';
  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity.name,
    'message': message,
    if (fieldPath != null) 'fieldPath': fieldPath,
    if (relatedReference != null) 'relatedReference': relatedReference,
  };
}

final class PersistenceCommandAuditDecisionV1 {
  PersistenceCommandAuditDecisionV1({
    required String commandId,
    required this.subjectType,
    required String subjectId,
    required this.targetNamespace,
    required List<PersistenceCommandAuditIssueV1> issues,
    required this.dryRun,
    required this.commandRequestedAt,
    required this.auditedAt,
    required String readinessPolicyVersion,
    required String authorizationTenantId,
    required String persistenceIdempotencyKey,
    required this.subjectFingerprint,
    required this.provenance,
  }) : commandId = _required(commandId, 'commandId'),
       subjectId = _required(subjectId, 'subjectId'),
       readinessPolicyVersion = _required(
         readinessPolicyVersion,
         'readinessPolicyVersion',
       ),
       authorizationTenantId = _required(
         authorizationTenantId,
         'authorizationTenantId',
       ),
       persistenceIdempotencyKey = _required(
         persistenceIdempotencyKey,
         'persistenceIdempotencyKey',
       ),
       blockers = List.unmodifiable(
         (issues
             .where(
               (x) => x.severity == PersistenceCommandAuditSeverityV1.blocker,
             )
             .toList()
           ..sort((a, b) => a.sortKey.compareTo(b.sortKey))),
       ),
       warnings = List.unmodifiable(
         (issues
             .where(
               (x) => x.severity == PersistenceCommandAuditSeverityV1.warning,
             )
             .toList()
           ..sort((a, b) => a.sortKey.compareTo(b.sortKey))),
       );
  final String contractVersion = persistenceCommandAuditContractVersionV1;
  final String commandId;
  final PersistenceSubjectTypeV1 subjectType;
  final String subjectId;
  final PersistenceTargetNamespaceV1 targetNamespace;
  final List<PersistenceCommandAuditIssueV1> blockers;
  final List<PersistenceCommandAuditIssueV1> warnings;
  final bool dryRun;
  final DateTime commandRequestedAt;
  final DateTime auditedAt;
  final String readinessPolicyVersion;
  final String authorizationTenantId;
  final String persistenceIdempotencyKey;
  final SubjectFingerprintV1 subjectFingerprint;
  final PersistenceCommandProvenanceV1 provenance;
  bool get executable => blockers.isEmpty;
  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'commandId': commandId,
    'subjectType': _subjectValue(subjectType),
    'subjectId': subjectId,
    'targetNamespace': persistenceTargetNamespaceValueV1(targetNamespace),
    'executable': executable,
    'dryRun': dryRun,
    'blockers': blockers.map((x) => x.toJson()).toList(),
    'warnings': warnings.map((x) => x.toJson()).toList(),
    'commandRequestedAt': commandRequestedAt.toIso8601String(),
    'auditedAt': auditedAt.toIso8601String(),
    'readinessPolicyVersion': readinessPolicyVersion,
    'authorizationTenantId': authorizationTenantId,
    'persistenceIdempotencyKey': persistenceIdempotencyKey,
    'subjectFingerprint': subjectFingerprint.toJson(),
    'provenance': provenance.toJson(),
  };
}
