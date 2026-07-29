part of 'risk_scan_contracts_v1.dart';

final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

T _enumValue<T extends Enum>(
  Object? value,
  Map<String, T> values,
  String field,
) {
  final text = _requiredString(value, field);
  final result = values[text];
  if (result == null) throw FormatException('Unknown $field: $text');
  return result;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field is required');
  }
  return value.trim();
}

String? _optionalString(Object? value, String field) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value.trim();
}

String _requiredSha256(Object? value, String field) {
  final text = _requiredString(value, field);
  if (!_sha256Pattern.hasMatch(text)) {
    throw FormatException('$field must be lowercase SHA-256');
  }
  return text;
}

String _requiredUuid(Object? value, String field) {
  final text = _requiredString(value, field).toLowerCase();
  if (!_uuidPattern.hasMatch(text)) {
    throw FormatException('$field must be a canonical UUID');
  }
  return text;
}

int _requiredNonNegativeInt(Object? value, String field) {
  if (value is! int || value < 0) {
    throw FormatException('$field must be a non-negative integer');
  }
  return value;
}

DateTime _requiredDate(Object? value, String field) {
  final text = _requiredString(value, field);
  final parsed = DateTime.tryParse(text);
  if (parsed == null) throw FormatException('$field must be ISO-8601');
  return parsed;
}

DateTime? _optionalDate(Object? value, String field) {
  if (value == null) return null;
  return _requiredDate(value, field);
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object');
  return Map<String, dynamic>.from(value);
}

List<String> _stringList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an array');
  return List<String>.unmodifiable(
    value.map((item) => _requiredString(item, field)),
  );
}

final class RiskScanTargetContractV1 {
  RiskScanTargetContractV1({
    required String brandNameNormalized,
    required String officialWebsiteCanonicalUrl,
    required String officialHost,
    required String targetFingerprintSha256,
  }) : brandNameNormalized = _requiredString(
         brandNameNormalized,
         'brandNameNormalized',
       ),
       officialWebsiteCanonicalUrl = _canonicalWebUrl(
         officialWebsiteCanonicalUrl,
         'officialWebsiteCanonicalUrl',
       ),
       officialHost = _canonicalHost(officialHost, 'officialHost'),
       targetFingerprintSha256 = _requiredSha256(
         targetFingerprintSha256,
         'targetFingerprintSha256',
       ) {
    final uri = Uri.parse(this.officialWebsiteCanonicalUrl);
    if (uri.host.toLowerCase() != this.officialHost) {
      throw const FormatException(
        'officialHost must match officialWebsiteCanonicalUrl',
      );
    }
  }

  final String contractVersion = riskScanTargetContractVersionV1;
  final String brandNameNormalized;
  final String officialWebsiteCanonicalUrl;
  final String officialHost;
  final String targetFingerprintSha256;

  factory RiskScanTargetContractV1.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(json['contractVersion'], 'contractVersion');
    if (version != riskScanTargetContractVersionV1) {
      throw FormatException('Unsupported contractVersion: $version');
    }
    return RiskScanTargetContractV1(
      brandNameNormalized: _requiredString(
        json['brandNameNormalized'],
        'brandNameNormalized',
      ),
      officialWebsiteCanonicalUrl: _requiredString(
        json['officialWebsiteCanonicalUrl'],
        'officialWebsiteCanonicalUrl',
      ),
      officialHost: _requiredString(json['officialHost'], 'officialHost'),
      targetFingerprintSha256: _requiredSha256(
        json['targetFingerprintSha256'],
        'targetFingerprintSha256',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'contractVersion': contractVersion,
    'brandNameNormalized': brandNameNormalized,
    'officialWebsiteCanonicalUrl': officialWebsiteCanonicalUrl,
    'officialHost': officialHost,
    'targetFingerprintSha256': targetFingerprintSha256,
  };
}

String _canonicalWebUrl(Object? value, String field) {
  final text = _requiredString(value, field);
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw FormatException('$field must be a canonical public web URL');
  }
  return uri.toString();
}

String _canonicalHost(Object? value, String field) {
  final text = _requiredString(value, field).toLowerCase();
  if (text.contains('/') || text.contains(':') || text.contains(' ')) {
    throw FormatException('$field must be a canonical host');
  }
  final uri = Uri.tryParse('https://$text');
  if (uri == null || uri.host != text || !text.contains('.')) {
    throw FormatException('$field must be a canonical host');
  }
  return text;
}
