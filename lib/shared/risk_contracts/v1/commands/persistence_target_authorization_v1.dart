// ignore_for_file: prefer_initializing_formals

part of 'commands_v1.dart';

PersistenceTargetNamespaceV1 parsePersistenceTargetNamespaceV1(String value) =>
    switch (_required(value, 'targetNamespace')) {
      'shared_risk_signals' => PersistenceTargetNamespaceV1.sharedRiskSignals,
      'shared_risk_assessments' =>
        PersistenceTargetNamespaceV1.sharedRiskAssessments,
      'shared_case_candidates' =>
        PersistenceTargetNamespaceV1.sharedCaseCandidates,
      final unknown => throw FormatException(
        'Unsupported target namespace: $unknown',
      ),
    };

final class PersistenceAuthorizationContextV1 {
  PersistenceAuthorizationContextV1({
    required String actorUid,
    required this.actorType,
    required String tenantId,
    required List<String> roles,
    required List<String> permissions,
    required String authorizationSource,
    required this.authorizedAt,
    DateTime? expiresAt,
    String? brandId,
    String? requestId,
    Map<String, Object?> metadata = const {},
  }) : actorUid = _required(actorUid, 'actorUid'),
       tenantId = _required(tenantId, 'tenantId'),
       brandId = _optional(brandId, 'brandId'),
       roles = List.unmodifiable(
         ({...roles.map((v) => _required(v, 'roles[]'))}.toList()..sort()),
       ),
       permissions = List.unmodifiable(
         ({...permissions.map((v) => _required(v, 'permissions[]'))}.toList()
           ..sort()),
       ),
       authorizationSource = _required(
         authorizationSource,
         'authorizationSource',
       ),
       expiresAt = expiresAt,
       requestId = _optional(requestId, 'requestId'),
       metadata = _freeze(metadata, 'metadata')! as Map<String, Object?> {
    if (expiresAt != null && !authorizedAt.isBefore(expiresAt)) {
      throw const FormatException('authorization validity interval is invalid');
    }
  }

  final String actorUid;
  final PersistenceActorTypeV1 actorType;
  final String tenantId;
  final String? brandId;
  final List<String> roles;
  final List<String> permissions;
  final String authorizationSource;
  final DateTime authorizedAt;
  final DateTime? expiresAt;
  final String? requestId;
  final Map<String, Object?> metadata;

  bool isActiveAt(DateTime time) =>
      !time.isBefore(authorizedAt) &&
      (expiresAt == null || time.isBefore(expiresAt!));

  Map<String, Object?> toJson() => {
    'actorUid': actorUid,
    'actorType': actorType.name,
    'tenantId': tenantId,
    if (brandId != null) 'brandId': brandId,
    'roles': roles,
    'permissions': permissions,
    'authorizationSource': authorizationSource,
    'authorizedAt': authorizedAt.toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (requestId != null) 'requestId': requestId,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}
