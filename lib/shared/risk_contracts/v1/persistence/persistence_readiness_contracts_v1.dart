// ignore_for_file: prefer_initializing_formals

part of 'persistence_v1.dart';

final class PersistenceReadinessIssueV1 {
  PersistenceReadinessIssueV1({
    required String code,
    required this.severity,
    required String message,
    String? fieldPath,
    String? relatedReference,
    Map<String, Object?> metadata = const {},
  }) : code = _required(code, 'code'),
       message = _required(message, 'message'),
       fieldPath = fieldPath == null ? null : _required(fieldPath, 'fieldPath'),
       relatedReference = relatedReference == null
           ? null
           : _required(relatedReference, 'relatedReference'),
       metadata = _freeze(metadata, 'metadata')! as Map<String, Object?> {
    if (!this.code.contains('.')) {
      throw const FormatException('issue code must be namespaced');
    }
  }

  final String code;
  final PersistenceReadinessIssueSeverityV1 severity;
  final String? fieldPath;
  final String message;
  final String? relatedReference;
  final Map<String, Object?> metadata;

  String get sortKey =>
      '$code\u0000${fieldPath ?? ''}\u0000${relatedReference ?? ''}';

  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity.name,
    if (fieldPath != null) 'fieldPath': fieldPath,
    'message': message,
    if (relatedReference != null) 'relatedReference': relatedReference,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

sealed class PersistenceReadinessRequestV1 {
  PersistenceReadinessRequestV1({
    required this.identityResolutionResult,
    required this.evaluatedAt,
    required String requestedByModule,
    required String policyVersion,
    required this.provenance,
  }) : requestedByModule = _required(requestedByModule, 'requestedByModule'),
       policyVersion = _required(policyVersion, 'policyVersion');

  final IdentityResolutionResultV1 identityResolutionResult;
  final DateTime evaluatedAt;
  final String requestedByModule;
  final String policyVersion;
  final ProvenanceEnvelope provenance;
}

final class RiskSignalPersistenceReadinessRequestV1
    extends PersistenceReadinessRequestV1 {
  RiskSignalPersistenceReadinessRequestV1({
    required this.subject,
    required this.sourceIngestionKey,
    required super.identityResolutionResult,
    required super.evaluatedAt,
    required super.requestedByModule,
    required super.policyVersion,
    required super.provenance,
  });
  final RiskSignalContractV1 subject;
  final SourceIngestionKeyV1? sourceIngestionKey;
}

final class RiskAssessmentPersistenceReadinessRequestV1
    extends PersistenceReadinessRequestV1 {
  RiskAssessmentPersistenceReadinessRequestV1({
    required this.subject,
    required this.sourceIngestionKey,
    required super.identityResolutionResult,
    required super.evaluatedAt,
    required super.requestedByModule,
    required super.policyVersion,
    required super.provenance,
  });
  final RiskAssessmentContractV1 subject;
  final SourceIngestionKeyV1? sourceIngestionKey;
}

final class CaseCandidatePersistenceReadinessRequestV1
    extends PersistenceReadinessRequestV1 {
  CaseCandidatePersistenceReadinessRequestV1({
    required this.subject,
    required super.identityResolutionResult,
    required super.evaluatedAt,
    required super.requestedByModule,
    required super.policyVersion,
    required super.provenance,
    this.sourceIngestionKey,
  });
  final CaseCandidateContractV1 subject;
  final SourceIngestionKeyV1? sourceIngestionKey;
}

final class PersistenceReadinessDecisionV1 {
  PersistenceReadinessDecisionV1({
    required String policyVersion,
    required this.subjectType,
    required String subjectId,
    required List<PersistenceReadinessIssueV1> issues,
    required this.evaluatedAt,
    required this.identityResolutionStatus,
    required this.provenance,
    String? evaluatedIdempotencyKey,
  }) : policyVersion = _required(policyVersion, 'policyVersion'),
       subjectId = _required(subjectId, 'subjectId'),
       evaluatedIdempotencyKey = evaluatedIdempotencyKey,
       blockers = List.unmodifiable(
         (issues
             .where(
               (item) =>
                   item.severity == PersistenceReadinessIssueSeverityV1.blocker,
             )
             .toList()
           ..sort((a, b) => a.sortKey.compareTo(b.sortKey))),
       ),
       warnings = List.unmodifiable(
         (issues
             .where(
               (item) =>
                   item.severity == PersistenceReadinessIssueSeverityV1.warning,
             )
             .toList()
           ..sort((a, b) => a.sortKey.compareTo(b.sortKey))),
       );

  final String contractVersion = persistenceReadinessContractVersionV1;
  final String policyVersion;
  final PersistenceSubjectTypeV1 subjectType;
  final String subjectId;
  final List<PersistenceReadinessIssueV1> blockers;
  final List<PersistenceReadinessIssueV1> warnings;
  final DateTime evaluatedAt;
  final IdentityResolutionResultStatus identityResolutionStatus;
  final String? evaluatedIdempotencyKey;
  final ProvenanceEnvelope provenance;
  bool get allowed => blockers.isEmpty;

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'policyVersion': policyVersion,
    'subjectType': _subjectTypeValue(subjectType),
    'subjectId': subjectId,
    'allowed': allowed,
    'blockers': blockers.map((item) => item.toJson()).toList(),
    'warnings': warnings.map((item) => item.toJson()).toList(),
    'evaluatedAt': evaluatedAt.toIso8601String(),
    'identityResolutionStatus': identityResolutionStatus.name,
    if (evaluatedIdempotencyKey != null)
      'evaluatedIdempotencyKey': evaluatedIdempotencyKey,
    'provenance': provenance.toJson(),
  };
}
