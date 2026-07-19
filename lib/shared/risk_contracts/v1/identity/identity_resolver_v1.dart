part of 'identity_v1.dart';

final class IdentityResolverV1 {
  const IdentityResolverV1();

  IdentityResolutionResultV1 resolve(IdentityResolutionRequestV1 request) {
    final known = _knownValues(request);
    final conflicts = <String>{};
    for (final entry in known.entries) {
      if (entry.value.length > 1) {
        conflicts.add('conflicting_${_namespaceValue(entry.key)}');
      }
    }

    final activeMappings =
        request.authoritativeMappings
            .where((mapping) => mapping.isActiveAt(request.resolutionAt))
            .where((mapping) => _matchesKnown(mapping, known))
            .toList()
          ..sort((a, b) => a.mappingId.compareTo(b.mappingId));

    final candidateTenants = <String>{
      ...known[IdentityClaimNamespace.tenantId] ?? const <String>{},
      ...activeMappings.map((mapping) => mapping.tenantId),
    };
    if (candidateTenants.length > 1) {
      conflicts.add('conflicting_tenant_id');
    }
    for (final mapping in activeMappings) {
      for (final namespace in const [
        IdentityClaimNamespace.brandId,
        IdentityClaimNamespace.brandUid,
        IdentityClaimNamespace.ownerUid,
      ]) {
        final mapped = mapping.valueFor(namespace);
        final values = known[namespace] ?? const <String>{};
        if (mapped != null && values.isNotEmpty && !values.contains(mapped)) {
          conflicts.add('mapping_${_namespaceValue(namespace)}_conflict');
        }
      }
    }

    final claimRefs =
        request.identityClaims.map((claim) => claim.claimRef).toList()..sort();
    final mappingRefs = activeMappings.map((item) => item.mappingId).toList();
    if (conflicts.isNotEmpty) {
      return IdentityResolutionResultV1(
        status: IdentityResolutionResultStatus.conflict,
        acceptedClaimRefs: const [],
        rejectedClaimRefs: claimRefs,
        matchedMappingRefs: mappingRefs,
        conflicts: conflicts.toList()..sort(),
        reasons: const ['identity_conflict'],
        resolutionAt: request.resolutionAt,
        provenance: request.provenance,
      );
    }

    final tenantId = candidateTenants.singleOrNull;
    final hasAnyIdentity = known.values.any((values) => values.isNotEmpty);
    if (tenantId == null) {
      return IdentityResolutionResultV1(
        status: hasAnyIdentity
            ? IdentityResolutionResultStatus.partial
            : IdentityResolutionResultStatus.unresolved,
        resolvedIdentityScope: hasAnyIdentity
            ? _scope(known, null, IdentityResolutionStatus.partial)
            : null,
        acceptedClaimRefs: claimRefs,
        rejectedClaimRefs: const [],
        matchedMappingRefs: mappingRefs,
        conflicts: const [],
        reasons: [
          hasAnyIdentity ? 'tenant_id_not_resolved' : 'no_identity_evidence',
        ],
        resolutionAt: request.resolutionAt,
        provenance: request.provenance,
      );
    }

    final merged = <IdentityClaimNamespace, Set<String>>{
      for (final entry in known.entries) entry.key: {...entry.value},
    };
    for (final mapping in activeMappings) {
      for (final namespace in IdentityClaimNamespace.values) {
        final value = mapping.valueFor(namespace);
        if (value != null) (merged[namespace] ??= {}).add(value);
      }
    }
    return IdentityResolutionResultV1(
      status: IdentityResolutionResultStatus.resolved,
      resolvedIdentityScope: _scope(
        merged,
        tenantId,
        IdentityResolutionStatus.resolved,
      ),
      acceptedClaimRefs: claimRefs,
      rejectedClaimRefs: const [],
      matchedMappingRefs: mappingRefs,
      conflicts: const [],
      reasons: [
        activeMappings.isEmpty
            ? 'trusted_source_tenant_preserved'
            : 'authoritative_mapping_matched',
      ],
      resolutionAt: request.resolutionAt,
      provenance: request.provenance,
    );
  }

  Map<IdentityClaimNamespace, Set<String>> _knownValues(
    IdentityResolutionRequestV1 request,
  ) {
    final result = <IdentityClaimNamespace, Set<String>>{};
    void add(IdentityClaimNamespace namespace, String? value) {
      final clean = value?.trim();
      if (clean != null && clean.isNotEmpty) {
        (result[namespace] ??= {}).add(clean);
      }
    }

    final scope = request.sourceIdentityScope;
    add(IdentityClaimNamespace.tenantId, scope.tenantId);
    add(IdentityClaimNamespace.brandId, scope.brandId);
    add(IdentityClaimNamespace.brandUid, scope.brandUid);
    add(IdentityClaimNamespace.ownerUid, scope.ownerUid);
    for (final claim in request.identityClaims) {
      add(claim.namespace, claim.value);
    }
    return result;
  }

  bool _matchesKnown(
    AuthoritativeIdentityMappingV1 mapping,
    Map<IdentityClaimNamespace, Set<String>> known,
  ) => IdentityClaimNamespace.values.any((namespace) {
    final mapped = mapping.valueFor(namespace);
    return mapped != null && (known[namespace]?.contains(mapped) ?? false);
  });

  IdentityScope _scope(
    Map<IdentityClaimNamespace, Set<String>> values,
    String? tenantId,
    IdentityResolutionStatus status,
  ) => IdentityScope(
    tenantId: tenantId,
    brandId: _single(values[IdentityClaimNamespace.brandId]),
    brandUid: _single(values[IdentityClaimNamespace.brandUid]),
    ownerUid: _single(values[IdentityClaimNamespace.ownerUid]),
    resolutionStatus: status,
    resolutionSource: 'identity_resolver_v1',
    unresolvedReasons: status == IdentityResolutionStatus.resolved
        ? const []
        : const ['tenant_id_unresolved'],
  );

  String? _single(Set<String>? values) =>
      values == null || values.isEmpty ? null : values.single;
}
