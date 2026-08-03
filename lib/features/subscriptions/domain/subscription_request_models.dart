const String createSubscriptionRequestCommandVersionV1 =
    'subscription-service-request-create-command-v1';
const String subscriptionRequestCallableContractVersionV1 =
    'subscription-service-callable-v1';
const String broadDigitalScanSubscriptionProductCode =
    'broad_digital_scan_subscription';
const String publicLiteRiskScanSubscriptionSourceType = 'public_lite_risk_scan';

final RegExp _subscriptionRequestUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class BroadDigitalScanSubscriptionSource {
  BroadDigitalScanSubscriptionSource({
    required String scanRunId,
    required String brandName,
    required String officialWebsiteUrl,
    String? reportId,
  }) : scanRunId = _requiredText(scanRunId, 'scanRunId', 160),
       reportId = _optionalText(reportId, 'reportId', 160),
       brandName = _requiredText(brandName, 'brandName', 240),
       officialWebsiteUrl = _validatedWebsite(officialWebsiteUrl);

  final String scanRunId;
  final String? reportId;
  final String brandName;
  final String officialWebsiteUrl;

  Map<String, Object?> toMap() => <String, Object?>{
    'sourceType': publicLiteRiskScanSubscriptionSourceType,
    'scanRunId': scanRunId,
    'reportId': reportId,
    'brandName': brandName,
    'officialWebsiteUrl': officialWebsiteUrl,
  };
}

final class CreateSubscriptionServiceRequestCommand {
  CreateSubscriptionServiceRequestCommand({
    required String requestId,
    required this.source,
  }) : requestId = _validatedUuid(requestId);

  final String requestId;
  final BroadDigitalScanSubscriptionSource source;

  Map<String, Object?> toMap() => <String, Object?>{
    'contractVersion': createSubscriptionRequestCommandVersionV1,
    'requestId': requestId,
    'productCode': broadDigitalScanSubscriptionProductCode,
    'source': source.toMap(),
  };
}

final class SubscriptionServiceRequestResult {
  const SubscriptionServiceRequestResult({
    required this.resultId,
    required this.status,
    required this.idempotentReplay,
  });

  final String resultId;
  final String status;
  final bool idempotentReplay;

  factory SubscriptionServiceRequestResult.fromValue(Object? value) {
    final map = _objectMap(value, 'response');
    final contractVersion = _requiredMapText(map, 'contractVersion', 120);
    if (contractVersion != subscriptionRequestCallableContractVersionV1) {
      throw const FormatException(
        'Abonelik talebi yanıt sözleşmesi desteklenmiyor.',
      );
    }
    if (_requiredMapText(map, 'resultType', 120) !=
        'subscription_service_request') {
      throw const FormatException('Abonelik talebi sonuç türü geçersiz.');
    }

    final replay = map['idempotentReplay'];
    if (replay is! bool) {
      throw const FormatException('Abonelik talebi tekrar bilgisi geçersiz.');
    }

    return SubscriptionServiceRequestResult(
      resultId: _requiredMapText(map, 'resultId', 160),
      status: _requiredMapText(map, 'status', 80),
      idempotentReplay: replay,
    );
  }
}

String _validatedUuid(String value) {
  final clean = _requiredText(value, 'requestId', 36);
  if (!_subscriptionRequestUuidPattern.hasMatch(clean)) {
    throw const FormatException('requestId geçerli UUID v4 değil.');
  }
  return clean.toLowerCase();
}

String _validatedWebsite(String value) {
  final clean = _requiredText(value, 'officialWebsiteUrl', 2048);
  final uri = Uri.tryParse(clean);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Resmî internet adresi geçersiz.');
  }
  return uri.removeFragment().toString();
}

String _requiredText(String value, String field, int maximum) {
  final clean = value.trim();
  if (clean.isEmpty || clean.length > maximum) {
    throw FormatException('$field geçersiz.');
  }
  return clean;
}

String? _optionalText(String? value, String field, int maximum) {
  if (value == null) {
    return null;
  }
  return _requiredText(value, field, maximum);
}

Map<String, Object?> _objectMap(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('$field nesne olmalıdır.');
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredMapText(Map<String, Object?> map, String field, int maximum) {
  final value = map[field];
  if (value is! String) {
    throw FormatException('$field metin olmalıdır.');
  }
  return _requiredText(value, field, maximum);
}
