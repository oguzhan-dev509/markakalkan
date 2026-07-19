// ignore_for_file: prefer_initializing_formals

part of 'identity_v1.dart';

final class IdentityClaimV1 {
  IdentityClaimV1({
    required this.namespace,
    required String value,
    required String sourceModule,
    required this.claimSource,
    String? sourceRecordId,
    DateTime? assertedAt,
    Map<String, Object?> metadata = const {},
  }) : value = _requiredText(value, 'value'),
       sourceModule = _requiredText(sourceModule, 'sourceModule'),
       sourceRecordId = _optionalText(sourceRecordId, 'sourceRecordId'),
       assertedAt = assertedAt,
       metadata = _frozenMetadata(metadata, 'metadata');

  final IdentityClaimNamespace namespace;
  final String value;
  final String sourceModule;
  final String? sourceRecordId;
  final IdentityClaimSource claimSource;
  final DateTime? assertedAt;
  final Map<String, Object?> metadata;

  String get claimRef => _lengthEncode([
    _namespaceValue(namespace),
    value,
    sourceModule,
    sourceRecordId ?? '',
    _claimSourceValue(claimSource),
  ]);

  Map<String, Object?> toJson() => {
    'namespace': _namespaceValue(namespace),
    'value': value,
    'sourceModule': sourceModule,
    if (sourceRecordId != null) 'sourceRecordId': sourceRecordId,
    'claimSource': _claimSourceValue(claimSource),
    if (assertedAt != null) 'assertedAt': assertedAt!.toIso8601String(),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

final class AuthoritativeIdentityMappingV1 {
  AuthoritativeIdentityMappingV1({
    required String mappingId,
    required String tenantId,
    required String mappingSource,
    required ProvenanceEnvelope provenance,
    String? brandId,
    String? brandUid,
    String? ownerUid,
    DateTime? effectiveAt,
    DateTime? expiresAt,
  }) : mappingId = _requiredText(mappingId, 'mappingId'),
       tenantId = _requiredText(tenantId, 'tenantId'),
       brandId = _optionalText(brandId, 'brandId'),
       brandUid = _optionalText(brandUid, 'brandUid'),
       ownerUid = _optionalText(ownerUid, 'ownerUid'),
       mappingSource = _requiredText(mappingSource, 'mappingSource'),
       effectiveAt = effectiveAt,
       expiresAt = expiresAt,
       provenance = provenance {
    if (this.brandId == null &&
        this.brandUid == null &&
        this.ownerUid == null) {
      throw const FormatException(
        'mapping requires at least one non-tenant identity',
      );
    }
    if (effectiveAt != null &&
        expiresAt != null &&
        !effectiveAt.isBefore(expiresAt)) {
      throw const FormatException('mapping validity interval is invalid');
    }
  }

  final String mappingId;
  final String tenantId;
  final String? brandId;
  final String? brandUid;
  final String? ownerUid;
  final String mappingSource;
  final DateTime? effectiveAt;
  final DateTime? expiresAt;
  final ProvenanceEnvelope provenance;

  bool isActiveAt(DateTime resolutionAt) =>
      (effectiveAt == null || !resolutionAt.isBefore(effectiveAt!)) &&
      (expiresAt == null || resolutionAt.isBefore(expiresAt!));

  String? valueFor(IdentityClaimNamespace namespace) => switch (namespace) {
    IdentityClaimNamespace.tenantId => tenantId,
    IdentityClaimNamespace.brandId => brandId,
    IdentityClaimNamespace.brandUid => brandUid,
    IdentityClaimNamespace.ownerUid => ownerUid,
  };

  Map<String, Object?> toJson() => {
    'mappingId': mappingId,
    'tenantId': tenantId,
    if (brandId != null) 'brandId': brandId,
    if (brandUid != null) 'brandUid': brandUid,
    if (ownerUid != null) 'ownerUid': ownerUid,
    'mappingSource': mappingSource,
    if (effectiveAt != null) 'effectiveAt': effectiveAt!.toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    'provenance': provenance.toJson(),
  };
}
