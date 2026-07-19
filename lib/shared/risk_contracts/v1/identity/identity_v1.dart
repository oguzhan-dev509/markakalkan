library;

import '../shared_risk_contracts_v1.dart';

part 'identity_claim_mapping_v1.dart';
part 'identity_resolution_contracts_v1.dart';
part 'identity_resolver_v1.dart';

enum IdentityClaimNamespace { tenantId, brandId, brandUid, ownerUid }

enum IdentityClaimSource { sourceRecord, authoritativeMapping, callerContext }

enum IdentityResolutionResultStatus { resolved, partial, unresolved, conflict }

String _requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field is required');
  }
  return value.trim();
}

String? _optionalText(Object? value, String field) {
  if (value == null) return null;
  return _requiredText(value, field);
}

Object? _freeze(Object? value, String field) {
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value.map((item) => _freeze(item, field)),
    );
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('$field keys must be strings');
      }
      result[entry.key as String] = _freeze(entry.value, field);
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw FormatException('$field contains a non-JSON value');
}

Map<String, Object?> _frozenMetadata(Object? value, String field) {
  if (value == null) return const {};
  final result = _freeze(value, field);
  if (result is! Map<String, Object?>) {
    throw FormatException('$field must be an object');
  }
  return result;
}

String _namespaceValue(IdentityClaimNamespace value) => switch (value) {
  IdentityClaimNamespace.tenantId => 'tenant_id',
  IdentityClaimNamespace.brandId => 'brand_id',
  IdentityClaimNamespace.brandUid => 'brand_uid',
  IdentityClaimNamespace.ownerUid => 'owner_uid',
};

String _claimSourceValue(IdentityClaimSource value) => switch (value) {
  IdentityClaimSource.sourceRecord => 'source_record',
  IdentityClaimSource.authoritativeMapping => 'authoritative_mapping',
  IdentityClaimSource.callerContext => 'caller_context',
};

String _lengthEncode(Iterable<String> values) =>
    values.map((value) => '${value.length}:$value').join('|');
