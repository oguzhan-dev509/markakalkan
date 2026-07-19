import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/shared/risk_contracts/v1/identity/identity_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  const resolver = IdentityResolverV1();

  test('trusted source tenant remains resolved', () {
    final result = resolver.resolve(
      request(scope: scope(tenantId: 'tenant-1')),
    );
    expect(result.status, IdentityResolutionResultStatus.resolved);
    expect(result.resolvedIdentityScope?.tenantId, 'tenant-1');
  });

  test('owner-only scope remains partial without mapping', () {
    final result = resolver.resolve(request(scope: scope(ownerUid: 'owner-1')));
    expect(result.status, IdentityResolutionResultStatus.partial);
    expect(result.resolvedIdentityScope?.ownerUid, 'owner-1');
    expect(result.resolvedIdentityScope?.tenantId, isNull);
  });

  test('ownerUid is never copied into another namespace', () {
    final identity = resolver
        .resolve(request(scope: scope(ownerUid: 'same-value')))
        .resolvedIdentityScope!;
    expect(identity.ownerUid, 'same-value');
    expect(identity.tenantId, isNull);
    expect(identity.brandId, isNull);
  });

  test('brandUid-only scope remains partial without mapping', () {
    final result = resolver.resolve(request(scope: scope(brandUid: 'brand-u')));
    expect(result.status, IdentityResolutionResultStatus.partial);
    expect(result.resolvedIdentityScope?.brandUid, 'brand-u');
    expect(result.resolvedIdentityScope?.tenantId, isNull);
  });

  test('authoritative brandUid mapping resolves tenant', () {
    final result = resolver.resolve(
      request(
        scope: scope(brandUid: 'brand-u'),
        mappings: [mapping('map-1', tenantId: 'tenant-1', brandUid: 'brand-u')],
      ),
    );
    expect(result.status, IdentityResolutionResultStatus.resolved);
    expect(result.resolvedIdentityScope?.tenantId, 'tenant-1');
    expect(result.matchedMappingRefs, ['map-1']);
  });

  test('authoritative ownerUid mapping resolves tenant', () {
    final result = resolver.resolve(
      request(
        scope: scope(ownerUid: 'owner-1'),
        mappings: [mapping('map-1', tenantId: 'tenant-1', ownerUid: 'owner-1')],
      ),
    );
    expect(result.status, IdentityResolutionResultStatus.resolved);
    expect(result.resolvedIdentityScope?.ownerUid, 'owner-1');
    expect(result.resolvedIdentityScope?.tenantId, 'tenant-1');
  });

  test('source tenant conflicting with mapping tenant fails closed', () {
    final result = resolver.resolve(
      request(
        scope: scope(tenantId: 'tenant-a', ownerUid: 'owner-1'),
        mappings: [mapping('map-1', tenantId: 'tenant-b', ownerUid: 'owner-1')],
      ),
    );
    expect(result.status, IdentityResolutionResultStatus.conflict);
    expect(result.resolvedIdentityScope, isNull);
  });

  test('two tenant mappings for one claim conflict', () {
    final result = resolver.resolve(
      request(
        scope: scope(ownerUid: 'owner-1'),
        mappings: [
          mapping('map-a', tenantId: 'tenant-a', ownerUid: 'owner-1'),
          mapping('map-b', tenantId: 'tenant-b', ownerUid: 'owner-1'),
        ],
      ),
    );
    expect(result.status, IdentityResolutionResultStatus.conflict);
    expect(result.conflicts, contains('conflicting_tenant_id'));
  });

  test('brandId and brandUid remain distinct even with equal strings', () {
    final result = resolver.resolve(
      request(
        scope: scope(tenantId: 'tenant-1', brandId: 'x', brandUid: 'x'),
      ),
    );
    expect(result.resolvedIdentityScope?.brandId, 'x');
    expect(result.resolvedIdentityScope?.brandUid, 'x');
  });

  test('expired mapping is not accepted', () {
    final result = resolver.resolve(
      request(
        scope: scope(ownerUid: 'owner-1'),
        mappings: [
          mapping(
            'expired',
            tenantId: 'tenant-1',
            ownerUid: 'owner-1',
            expiresAt: DateTime.parse('2026-07-18T00:00:00Z'),
          ),
        ],
      ),
    );
    expect(result.status, IdentityResolutionResultStatus.partial);
    expect(result.matchedMappingRefs, isEmpty);
  });

  test('future mapping is not accepted', () {
    final result = resolver.resolve(
      request(
        scope: scope(brandUid: 'brand-u'),
        mappings: [
          mapping(
            'future',
            tenantId: 'tenant-1',
            brandUid: 'brand-u',
            effectiveAt: DateTime.parse('2026-07-20T00:00:00Z'),
          ),
        ],
      ),
    );
    expect(result.status, IdentityResolutionResultStatus.partial);
    expect(result.matchedMappingRefs, isEmpty);
  });

  test('claim and mapping input order cannot change result', () {
    final claims = [
      claim(IdentityClaimNamespace.ownerUid, 'owner-1'),
      claim(IdentityClaimNamespace.brandUid, 'brand-u'),
    ];
    final mappings = [
      mapping('map-b', tenantId: 'tenant-1', ownerUid: 'owner-1'),
      mapping('map-a', tenantId: 'tenant-1', brandUid: 'brand-u'),
    ];
    final first = resolver.resolve(
      request(scope: scope(), claims: claims, mappings: mappings),
    );
    final second = resolver.resolve(
      request(
        scope: scope(),
        claims: claims.reversed.toList(),
        mappings: mappings.reversed.toList(),
      ),
    );
    expect(jsonEncode(first.toJson()), jsonEncode(second.toJson()));
  });

  test('same request produces deterministic JSON', () {
    final input = request(scope: scope(tenantId: 'tenant-1'));
    expect(
      jsonEncode(resolver.resolve(input).toJson()),
      jsonEncode(resolver.resolve(input).toJson()),
    );
  });

  test('resolver does not mutate claim, mapping, or metadata inputs', () {
    final metadata = <String, Object?>{
      'nested': <Object?>['original'],
    };
    final claims = [
      claim(IdentityClaimNamespace.ownerUid, 'owner-1', metadata),
    ];
    final mappings = [
      mapping('map-1', tenantId: 'tenant-1', ownerUid: 'owner-1'),
    ];
    resolver.resolve(
      request(
        scope: scope(ownerUid: 'owner-1'),
        claims: claims,
        mappings: mappings,
      ),
    );
    expect(metadata, {
      'nested': ['original'],
    });
    expect(claims.single.value, 'owner-1');
    expect(mappings.single.tenantId, 'tenant-1');
    expect(
      () => (claims.single.metadata['nested']! as List<Object?>).add('changed'),
      throwsUnsupportedError,
    );
  });

  test('conflict result cannot be constructed with bindable scope', () {
    expect(
      () => IdentityResolutionResultV1(
        status: IdentityResolutionResultStatus.conflict,
        resolvedIdentityScope: scope(tenantId: 'tenant-1'),
        acceptedClaimRefs: const [],
        rejectedClaimRefs: const [],
        matchedMappingRefs: const [],
        conflicts: const ['conflict'],
        reasons: const ['identity_conflict'],
        resolutionAt: resolutionAt,
        provenance: provenance(),
      ),
      throwsFormatException,
    );
  });
}

final resolutionAt = DateTime.parse('2026-07-19T12:00:00Z');

IdentityScope scope({
  String? tenantId,
  String? brandId,
  String? brandUid,
  String? ownerUid,
}) => IdentityScope(
  tenantId: tenantId,
  brandId: brandId,
  brandUid: brandUid,
  ownerUid: ownerUid,
  resolutionStatus: tenantId != null
      ? IdentityResolutionStatus.resolved
      : [brandId, brandUid, ownerUid].any((value) => value != null)
      ? IdentityResolutionStatus.partial
      : IdentityResolutionStatus.unresolved,
);

IdentityClaimV1 claim(
  IdentityClaimNamespace namespace,
  String value, [
  Map<String, Object?> metadata = const {},
]) => IdentityClaimV1(
  namespace: namespace,
  value: value,
  sourceModule: 'test',
  claimSource: IdentityClaimSource.sourceRecord,
  metadata: metadata,
);

AuthoritativeIdentityMappingV1 mapping(
  String id, {
  required String tenantId,
  String? brandId,
  String? brandUid,
  String? ownerUid,
  DateTime? effectiveAt,
  DateTime? expiresAt,
}) => AuthoritativeIdentityMappingV1(
  mappingId: id,
  tenantId: tenantId,
  brandId: brandId,
  brandUid: brandUid,
  ownerUid: ownerUid,
  mappingSource: 'test_authority',
  effectiveAt: effectiveAt,
  expiresAt: expiresAt,
  provenance: provenance(),
);

IdentityResolutionRequestV1 request({
  required IdentityScope scope,
  List<IdentityClaimV1> claims = const [],
  List<AuthoritativeIdentityMappingV1> mappings = const [],
}) => IdentityResolutionRequestV1(
  sourceIdentityScope: scope,
  identityClaims: claims,
  authoritativeMappings: mappings,
  resolutionAt: resolutionAt,
  requestedByModule: 'test',
  provenance: provenance(),
);

ProvenanceEnvelope provenance() => ProvenanceEnvelope(
  producerModule: 'test',
  adaptedAt: DateTime.parse('2026-07-19T11:00:00Z'),
);
