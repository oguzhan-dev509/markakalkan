import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

const String publicLiteRiskScanCallableContractVersionV1 =
    'risk-scan-public-lite-callable-v1';
const String publicLiteRiskScanProjectionContractVersionV1 =
    'risk-scan-public-lite-projection-v1';

final RegExp _publicLiteAccessKeyPattern = RegExp(
  r'^hrt1\.[a-f0-9]{64}\.[A-Za-z0-9_-]{43}$',
);

final class PublicLiteRiskScanStartRequest {
  PublicLiteRiskScanStartRequest({
    required String requestId,
    required String brandName,
    required String officialWebsiteUrl,
    required String anonymousClientNonce,
  }) : requestId = _requiredText(requestId, 'requestId'),
       brandName = _requiredText(brandName, 'brandName'),
       officialWebsiteUrl = _validatedWebsite(officialWebsiteUrl),
       anonymousClientNonce = _requiredText(
         anonymousClientNonce,
         'anonymousClientNonce',
       );

  final String requestId;
  final String brandName;
  final String officialWebsiteUrl;
  final String anonymousClientNonce;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'requestId': requestId,
    'brandName': brandName,
    'officialWebsiteUrl': officialWebsiteUrl,
    'anonymousClientNonce': anonymousClientNonce,
  };
}

final class PublicLiteRiskScanStartResult {
  const PublicLiteRiskScanStartResult({
    required this.outcome,
    required this.accessKey,
    required this.projection,
  });

  final String outcome;
  final String accessKey;
  final PublicLiteRiskScanProjection projection;

  factory PublicLiteRiskScanStartResult.fromMap(Map<String, dynamic> map) {
    _requireCallableContract(map);
    final outcome = _requiredString(map, 'outcome');
    if (outcome != 'created' && outcome != 'idempotent_success') {
      throw FormatException('Unsupported Public Lite outcome: $outcome');
    }

    final accessKey = _requiredString(map, 'accessKey');
    if (!_publicLiteAccessKeyPattern.hasMatch(accessKey)) {
      throw const FormatException('Geçersiz Public Lite erişim anahtarı.');
    }

    return PublicLiteRiskScanStartResult(
      outcome: outcome,
      accessKey: accessKey,
      projection: PublicLiteRiskScanProjection.fromMap(
        _requiredMap(map, 'projection'),
      ),
    );
  }
}

final class PublicLiteRiskScanProjection {
  const PublicLiteRiskScanProjection({
    required this.scanRunId,
    required this.scanMode,
    required this.accessTier,
    required this.identityMode,
    required this.status,
    required this.coverageStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.target,
    required this.channels,
    required this.report,
  });

  final String scanRunId;
  final String scanMode;
  final String accessTier;
  final String identityMode;
  final String status;
  final String coverageStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final PublicLiteRiskScanTarget? target;
  final List<PublicLiteRiskScanChannel> channels;
  final PublicLiteRiskScanReport? report;

  bool get isReportReady =>
      status == 'completed' || status == 'completedWithLimits';

  bool get isTerminal =>
      isReportReady ||
      status == 'failedTerminal' ||
      status == 'cancelled' ||
      status == 'expired';

  factory PublicLiteRiskScanProjection.fromMap(Map<String, dynamic> map) {
    final version = _requiredString(map, 'contractVersion');
    if (version != publicLiteRiskScanProjectionContractVersionV1) {
      throw FormatException('Unsupported Public Lite projection: $version');
    }

    return PublicLiteRiskScanProjection(
      scanRunId: _requiredString(map, 'scanRunId'),
      scanMode: _requiredString(map, 'scanMode'),
      accessTier: _requiredString(map, 'accessTier'),
      identityMode: _requiredString(map, 'identityMode'),
      status: _requiredString(map, 'status'),
      coverageStatus: _requiredString(map, 'coverageStatus'),
      createdAt: _nullableDateTime(map['createdAt'], 'createdAt'),
      updatedAt: _nullableDateTime(map['updatedAt'], 'updatedAt'),
      expiresAt: _nullableDateTime(map['expiresAt'], 'expiresAt'),
      target: map['target'] == null
          ? null
          : PublicLiteRiskScanTarget.fromMap(_map(map['target'])),
      channels: _list(map['channels'])
          .map((item) => PublicLiteRiskScanChannel.fromMap(_map(item)))
          .toList(growable: false),
      report: map['report'] == null
          ? null
          : PublicLiteRiskScanReport.fromMap(_map(map['report'])),
    );
  }
}

final class PublicLiteRiskScanTarget {
  const PublicLiteRiskScanTarget({
    required this.brandNameNormalized,
    required this.officialHost,
  });

  final String? brandNameNormalized;
  final String? officialHost;

  factory PublicLiteRiskScanTarget.fromMap(Map<String, dynamic> map) =>
      PublicLiteRiskScanTarget(
        brandNameNormalized: _nullableString(map['brandNameNormalized']),
        officialHost: _nullableString(map['officialHost']),
      );
}

final class PublicLiteRiskScanChannel {
  const PublicLiteRiskScanChannel({
    required this.channelCode,
    required this.status,
    required this.coverageStatus,
    required this.observationCount,
    required this.findingCount,
    required this.limitReasonCodes,
    required this.startedAt,
    required this.completedAt,
  });

  final String? channelCode;
  final String? status;
  final String? coverageStatus;
  final int observationCount;
  final int findingCount;
  final List<String> limitReasonCodes;
  final DateTime? startedAt;
  final DateTime? completedAt;

  factory PublicLiteRiskScanChannel.fromMap(Map<String, dynamic> map) =>
      PublicLiteRiskScanChannel(
        channelCode: _nullableString(map['channelCode']),
        status: _nullableString(map['status']),
        coverageStatus: _nullableString(map['coverageStatus']),
        observationCount: _nonNegativeInt(map['observationCount']),
        findingCount: _nonNegativeInt(map['findingCount']),
        limitReasonCodes: _list(
          map['limitReasonCodes'],
        ).map(_stringValue).toList(growable: false),
        startedAt: _nullableDateTime(map['startedAt'], 'startedAt'),
        completedAt: _nullableDateTime(map['completedAt'], 'completedAt'),
      );
}

final class PublicLiteRiskScanFinding {
  const PublicLiteRiskScanFinding({
    required this.findingId,
    required this.findingType,
    required this.channelCode,
    required this.riskLevel,
    required this.confidenceLevel,
    required this.impactLevel,
    required this.interventionDifficulty,
    required this.reviewStatus,
    required this.recommendationCode,
    required this.title,
    required this.summary,
  });

  final String? findingId;
  final String? findingType;
  final String? channelCode;
  final String? riskLevel;
  final String? confidenceLevel;
  final String? impactLevel;
  final String? interventionDifficulty;
  final String? reviewStatus;
  final String? recommendationCode;
  final String? title;
  final String? summary;

  factory PublicLiteRiskScanFinding.fromMap(Map<String, dynamic> map) =>
      PublicLiteRiskScanFinding(
        findingId: _nullableString(map['findingId']),
        findingType: _nullableString(map['findingType']),
        channelCode: _nullableString(map['channelCode']),
        riskLevel: _nullableString(map['riskLevel']),
        confidenceLevel: _nullableString(map['confidenceLevel']),
        impactLevel: _nullableString(map['impactLevel']),
        interventionDifficulty: _nullableString(map['interventionDifficulty']),
        reviewStatus: _nullableString(map['reviewStatus']),
        recommendationCode: _nullableString(map['recommendationCode']),
        title: _nullableString(map['title']),
        summary: _nullableString(map['summary']),
      );
}

final class PublicLiteRiskScanReport {
  const PublicLiteRiskScanReport({
    required this.reportId,
    required this.reportVersion,
    required this.generatedAt,
    required this.status,
    required this.coverageStatus,
    required this.overallRiskLevel,
    required this.overallConfidenceLevel,
    required this.recommendedAction,
    required this.summary,
    required this.findingCount,
    required this.observationCount,
    required this.topFindingSnapshots,
    required this.channelDistribution,
  });

  final String? reportId;
  final Object? reportVersion;
  final DateTime? generatedAt;
  final String? status;
  final String? coverageStatus;
  final String? overallRiskLevel;
  final String? overallConfidenceLevel;
  final String? recommendedAction;
  final String? summary;
  final int findingCount;
  final int observationCount;
  final List<PublicLiteRiskScanFinding> topFindingSnapshots;
  final List<PublicLiteRiskScanChannel> channelDistribution;

  factory PublicLiteRiskScanReport.fromMap(Map<String, dynamic> map) =>
      PublicLiteRiskScanReport(
        reportId: _nullableString(map['reportId']),
        reportVersion: map['reportVersion'],
        generatedAt: _nullableDateTime(map['generatedAt'], 'generatedAt'),
        status: _nullableString(map['status']),
        coverageStatus: _nullableString(map['coverageStatus']),
        overallRiskLevel: _nullableString(map['overallRiskLevel']),
        overallConfidenceLevel: _nullableString(map['overallConfidenceLevel']),
        recommendedAction: _nullableString(map['recommendedAction']),
        summary: _nullableString(map['summary']),
        findingCount: _nonNegativeInt(map['findingCount']),
        observationCount: _nonNegativeInt(map['observationCount']),
        topFindingSnapshots: _list(map['topFindingSnapshots'])
            .map((item) => PublicLiteRiskScanFinding.fromMap(_map(item)))
            .toList(growable: false),
        channelDistribution: _list(map['channelDistribution'])
            .map((item) => PublicLiteRiskScanChannel.fromMap(_map(item)))
            .toList(growable: false),
      );
}

typedef PublicLiteRiskScanCallable =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> request,
    );

abstract interface class PublicLiteRiskScanRepository {
  Future<PublicLiteRiskScanStartResult> start(
    PublicLiteRiskScanStartRequest request,
  );

  Future<PublicLiteRiskScanProjection> getStatus(String accessKey);

  Future<PublicLiteRiskScanProjection> getReport(String accessKey);
}

final class PublicLiteRiskScanRepositoryException implements Exception {
  const PublicLiteRiskScanRepositoryException({
    required this.code,
    required this.message,
    this.causeType,
  });

  final String code;
  final String message;
  final String? causeType;

  bool get isRetryable =>
      code == 'aborted' ||
      code == 'deadline-exceeded' ||
      code == 'resource-exhausted' ||
      code == 'unavailable';

  @override
  String toString() => 'PublicLiteRiskScanRepositoryException($code)';
}

final class CallablePublicLiteRiskScanRepository
    implements PublicLiteRiskScanRepository {
  CallablePublicLiteRiskScanRepository({
    FirebaseFunctions? functions,
    Future<void> Function()? ensureAppCheckReady,
    PublicLiteRiskScanCallable? callable,
  }) : _functions = callable == null
           ? functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3')
           : null,
       _ensureAppCheckReady =
           ensureAppCheckReady ?? AppCheckBootstrap.instance.ensureReady,
       _callable = callable;

  static const String startCallableName = 'startPublicLiteRiskScan';
  static const String statusCallableName = 'getPublicLiteRiskScanStatus';
  static const String reportCallableName = 'getPublicLiteRiskScanReport';

  final FirebaseFunctions? _functions;
  final Future<void> Function() _ensureAppCheckReady;
  final PublicLiteRiskScanCallable? _callable;

  @override
  Future<PublicLiteRiskScanStartResult> start(
    PublicLiteRiskScanStartRequest request,
  ) async {
    final response = await _callProtected(startCallableName, request.toMap());
    try {
      return PublicLiteRiskScanStartResult.fromMap(response);
    } on FormatException catch (error) {
      throw PublicLiteRiskScanRepositoryException(
        code: 'invalid-response',
        message: 'Risk taraması başlangıç yanıtı doğrulanamadı.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PublicLiteRiskScanProjection> getStatus(String accessKey) async {
    final response = await _callProtected(statusCallableName, <String, dynamic>{
      'accessKey': _validatedAccessKey(accessKey),
    });
    return _projectionFromResponse(response, 'durum');
  }

  @override
  Future<PublicLiteRiskScanProjection> getReport(String accessKey) async {
    final response = await _callProtected(reportCallableName, <String, dynamic>{
      'accessKey': _validatedAccessKey(accessKey),
    });
    return _projectionFromResponse(response, 'rapor');
  }

  Future<Map<String, dynamic>> _callProtected(
    String name,
    Map<String, dynamic> request,
  ) async {
    try {
      await _ensureAppCheckReady();
      final injected = _callable;
      if (injected != null) {
        return injected(name, Map<String, dynamic>.unmodifiable(request));
      }
      final result = await _functions!
          .httpsCallable(name)
          .call<Object?>(request);
      return _map(_normalizeCallableValue(result.data));
    } on PublicLiteRiskScanRepositoryException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw PublicLiteRiskScanRepositoryException(
        code: error.code,
        message: _safeFirebaseMessage(error),
        causeType: error.runtimeType.toString(),
      );
    } on AppCheckUnavailableException catch (error) {
      throw PublicLiteRiskScanRepositoryException(
        code: 'app-check-unavailable',
        message:
            'Güvenlik doğrulaması hazırlanamadı. Sayfayı yenileyip tekrar deneyin.',
        causeType: error.runtimeType.toString(),
      );
    } catch (error) {
      throw PublicLiteRiskScanRepositoryException(
        code: 'internal',
        message: 'Risk taraması işlemi güvenli biçimde tamamlanamadı.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  PublicLiteRiskScanProjection _projectionFromResponse(
    Map<String, dynamic> response,
    String label,
  ) {
    try {
      _requireCallableContract(response);
      return PublicLiteRiskScanProjection.fromMap(
        _requiredMap(response, 'projection'),
      );
    } on FormatException catch (error) {
      throw PublicLiteRiskScanRepositoryException(
        code: 'invalid-response',
        message: 'Risk taraması $label yanıtı doğrulanamadı.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  String _validatedAccessKey(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const PublicLiteRiskScanRepositoryException(
        code: 'invalid-argument',
        message: 'Tarama erişim anahtarı bulunamadı.',
      );
    }
    return normalized;
  }

  String _safeFirebaseMessage(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty && error.code != 'internal') {
      return message;
    }
    if (error.code == 'failed-precondition') {
      return 'Risk taraması henüz bu işlem için hazır değil.';
    }
    if (error.code == 'not-found') {
      return 'Tarama bulunamadı veya erişim süresi sona erdi.';
    }
    if (error.code == 'resource-exhausted') {
      return 'Saatlik tarama sınırına ulaşıldı. Daha sonra tekrar deneyin.';
    }
    if (error.code == 'unauthenticated' || error.code == 'permission-denied') {
      return 'Güvenlik doğrulaması kabul edilmedi.';
    }
    return 'Risk taraması işlemi güvenli biçimde tamamlanamadı.';
  }
}

void _requireCallableContract(Map<String, dynamic> map) {
  final version = _requiredString(map, 'contractVersion');
  if (version != publicLiteRiskScanCallableContractVersionV1) {
    throw FormatException('Unsupported Public Lite callable: $version');
  }
}

String _validatedWebsite(String value) {
  final normalized = _requiredText(value, 'officialWebsiteUrl');
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'Resmî internet adresi geçerli bir HTTP(S) adresi olmalıdır.',
    );
  }
  return normalized;
}

String _requiredText(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw FormatException('$field boş olamaz.');
  }
  return normalized;
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key geçerli bir metin olmalıdır.');
  }
  return value.trim();
}

String _stringValue(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Liste değeri geçerli bir metin olmalıdır.');
  }
  return value.trim();
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Beklenen değer metin olmalıdır.');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _nonNegativeInt(Object? value) {
  if (value is! num || value.isNaN || value.isInfinite || value < 0) {
    throw const FormatException('Sayaç negatif olmayan sayı olmalıdır.');
  }
  return value.toInt();
}

DateTime? _nullableDateTime(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$field ISO zaman damgası olmalıdır.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$field ISO zaman damgası olmalıdır.');
  }
  return parsed.toUtc();
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> map, String key) =>
    _map(map[key]);

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    throw const FormatException('Beklenen değer nesne olmalıdır.');
  }
  return value.map((key, child) => MapEntry(key.toString(), child));
}

List<dynamic> _list(Object? value) {
  if (value is! List) {
    throw const FormatException('Beklenen değer liste olmalıdır.');
  }
  return value;
}

dynamic _normalizeCallableValue(Object? value) {
  if (value is Map) {
    return value.map(
      (key, child) => MapEntry(key.toString(), _normalizeCallableValue(child)),
    );
  }
  if (value is List) {
    return value.map(_normalizeCallableValue).toList(growable: false);
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw const FormatException('Desteklenmeyen callable yanıt değeri.');
}
