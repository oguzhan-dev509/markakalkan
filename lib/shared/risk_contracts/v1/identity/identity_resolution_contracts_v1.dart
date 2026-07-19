// ignore_for_file: prefer_initializing_formals

part of 'identity_v1.dart';

final class IdentityResolutionRequestV1 {
  IdentityResolutionRequestV1({
    required this.sourceIdentityScope,
    required List<IdentityClaimV1> identityClaims,
    required List<AuthoritativeIdentityMappingV1> authoritativeMappings,
    required this.resolutionAt,
    required String requestedByModule,
    required this.provenance,
    CanonicalEntityRef? sourceRecordRef,
  }) : identityClaims = List.unmodifiable(identityClaims),
       authoritativeMappings = List.unmodifiable(authoritativeMappings),
       requestedByModule = _requiredText(
         requestedByModule,
         'requestedByModule',
       ),
       sourceRecordRef = sourceRecordRef;

  final IdentityScope sourceIdentityScope;
  final List<IdentityClaimV1> identityClaims;
  final List<AuthoritativeIdentityMappingV1> authoritativeMappings;
  final DateTime resolutionAt;
  final String requestedByModule;
  final CanonicalEntityRef? sourceRecordRef;
  final ProvenanceEnvelope provenance;

  Map<String, Object?> toJson() => {
    'sourceIdentityScope': sourceIdentityScope.toJson(),
    'identityClaims': identityClaims.map((item) => item.toJson()).toList(),
    'authoritativeMappings': authoritativeMappings
        .map((item) => item.toJson())
        .toList(),
    'resolutionAt': resolutionAt.toIso8601String(),
    'requestedByModule': requestedByModule,
    if (sourceRecordRef != null) 'sourceRecordRef': sourceRecordRef!.toJson(),
    'provenance': provenance.toJson(),
  };
}

final class IdentityResolutionResultV1 {
  IdentityResolutionResultV1({
    required this.status,
    required List<String> acceptedClaimRefs,
    required List<String> rejectedClaimRefs,
    required List<String> matchedMappingRefs,
    required List<String> conflicts,
    required List<String> reasons,
    required this.resolutionAt,
    required this.provenance,
    IdentityScope? resolvedIdentityScope,
  }) : resolvedIdentityScope = resolvedIdentityScope,
       acceptedClaimRefs = List.unmodifiable(acceptedClaimRefs),
       rejectedClaimRefs = List.unmodifiable(rejectedClaimRefs),
       matchedMappingRefs = List.unmodifiable(matchedMappingRefs),
       conflicts = List.unmodifiable(conflicts),
       reasons = List.unmodifiable(reasons) {
    if (status == IdentityResolutionResultStatus.resolved &&
        (resolvedIdentityScope == null ||
            resolvedIdentityScope.tenantId == null)) {
      throw const FormatException('resolved result requires tenant identity');
    }
    if (status == IdentityResolutionResultStatus.conflict &&
        resolvedIdentityScope != null) {
      throw const FormatException('conflict result cannot expose identity');
    }
  }

  final IdentityResolutionResultStatus status;
  final IdentityScope? resolvedIdentityScope;
  final List<String> acceptedClaimRefs;
  final List<String> rejectedClaimRefs;
  final List<String> matchedMappingRefs;
  final List<String> conflicts;
  final List<String> reasons;
  final DateTime resolutionAt;
  final ProvenanceEnvelope provenance;

  Map<String, Object?> toJson() => {
    'status': status.name,
    if (resolvedIdentityScope != null)
      'resolvedIdentityScope': resolvedIdentityScope!.toJson(),
    'acceptedClaimRefs': acceptedClaimRefs,
    'rejectedClaimRefs': rejectedClaimRefs,
    'matchedMappingRefs': matchedMappingRefs,
    'conflicts': conflicts,
    'reasons': reasons,
    'resolutionAt': resolutionAt.toIso8601String(),
    'provenance': provenance.toJson(),
  };
}
