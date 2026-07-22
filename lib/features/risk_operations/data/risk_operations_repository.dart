import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';

import 'risk_operations_lifecycle.dart';
import 'risk_operations_models.dart';

enum RiskOperationsLoadTrigger {
  initialMount('initial_mount'),
  dateChange('date_change'),
  filterChange('filter_change'),
  pullToRefresh('pull_to_refresh'),
  errorRetry('error_retry'),
  pagination('pagination');

  const RiskOperationsLoadTrigger(this.wireValue);
  final String wireValue;
}

class RiskOperationsReadDiagnostics {
  const RiskOperationsReadDiagnostics({
    required this.browserTabSessionId,
    required this.appBootId,
    required this.authEpoch,
    required this.navigationRequestId,
    required this.routeEntryId,
    required this.navigationType,
    required this.routeEntryCause,
    required this.pageshowPersisted,
    required this.initialVisibilityState,
    required this.documentReferrerPresent,
    required this.serviceWorkerControlled,
    required this.lifecycleQuality,
    required this.pageInstanceId,
    required this.loadAttemptId,
    required this.trigger,
    required this.attemptSequence,
  });

  final String browserTabSessionId;
  final String appBootId;
  final int authEpoch;
  final String navigationRequestId;
  final String routeEntryId;
  final RiskOperationsNavigationType navigationType;
  final RiskOperationsRouteEntryCause routeEntryCause;
  final bool pageshowPersisted;
  final String initialVisibilityState;
  final bool documentReferrerPresent;
  final bool serviceWorkerControlled;
  final RiskOperationsLifecycleQuality lifecycleQuality;
  final String pageInstanceId;
  final String loadAttemptId;
  final RiskOperationsLoadTrigger trigger;
  final int attemptSequence;

  Map<String, dynamic> toMap() => {
    'browserTabSessionId': browserTabSessionId,
    'appBootId': appBootId,
    'authEpoch': authEpoch,
    'navigationRequestId': navigationRequestId,
    'routeEntryId': routeEntryId,
    'navigationType': navigationType.wireValue,
    'routeEntryCause': routeEntryCause.wireValue,
    'pageshowPersisted': pageshowPersisted,
    'initialVisibilityState': initialVisibilityState,
    'documentReferrerPresent': documentReferrerPresent,
    'serviceWorkerControlled': serviceWorkerControlled,
    'lifecycleQuality': lifecycleQuality.wireValue,
    'pageInstanceId': pageInstanceId,
    'loadAttemptId': loadAttemptId,
    'trigger': trigger.wireValue,
    'attemptSequence': attemptSequence,
  };
}

class RiskOperationsQuery {
  const RiskOperationsQuery({
    this.pageSize = 25,
    this.pageToken,
    this.sourceSystem,
    this.riskClass,
    this.severity,
    this.evidenceQuality,
    this.caseCandidacy,
    this.occurredFrom,
    this.occurredTo,
    this.query,
  });
  final int pageSize;
  final String? pageToken;
  final String? sourceSystem;
  final String? riskClass;
  final String? severity;
  final String? evidenceQuality;
  final String? caseCandidacy;
  final DateTime? occurredFrom;
  final DateTime? occurredTo;
  final String? query;
  Map<String, dynamic> toMap() => {
    'pageSize': pageSize,
    if (pageToken != null) 'pageToken': pageToken,
    if (sourceSystem != null) 'sourceSystem': sourceSystem,
    if (riskClass != null) 'riskClass': riskClass,
    if (severity != null) 'severity': severity,
    if (evidenceQuality != null) 'evidenceQuality': evidenceQuality,
    if (caseCandidacy != null) 'caseCandidacy': caseCandidacy,
    if (occurredFrom != null)
      'occurredFrom': occurredFrom!.toUtc().toIso8601String(),
    if (occurredTo != null) 'occurredTo': occurredTo!.toUtc().toIso8601String(),
    if (query != null && query!.trim().isNotEmpty) 'query': query!.trim(),
  };
}

abstract interface class RiskOperationsRepository {
  Future<RiskOperationsPageResult> list(
    RiskOperationsQuery query,
    RiskOperationsReadDiagnostics diagnostics,
  );
}

typedef RiskOperationsCallableTransport =
    Future<Object?> Function(Map<String, dynamic> request);
typedef RiskOperationsFailureLogger =
    void Function(Map<String, Object?> safeFields);

enum RiskOperationsRepositoryFailureStage {
  callableResultReceived('callable_result_received'),
  rootResponseNormalization('root_response_normalization'),
  pageResultParsing('page_result_parsing');

  const RiskOperationsRepositoryFailureStage(this.wireValue);
  final String wireValue;
}

class RiskOperationsRepositoryException implements Exception {
  const RiskOperationsRepositoryException({
    required this.failureStage,
    required this.exceptionType,
    this.firebaseCode,
  });

  final RiskOperationsRepositoryFailureStage failureStage;
  final String exceptionType;
  final String? firebaseCode;
}

class RiskOperationsResponseNormalizationException implements Exception {
  const RiskOperationsResponseNormalizationException();
}

Map<String, dynamic> normalizeRiskOperationsResponse(Object? value) {
  final normalized = _normalizeCallableValue(value);
  if (normalized is! Map<String, dynamic>) {
    throw const RiskOperationsResponseNormalizationException();
  }
  return normalized;
}

Object? _normalizeCallableValue(Object? value) {
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is List) {
    return value.map(_normalizeCallableValue).toList(growable: false);
  }
  if (value is Map) {
    final normalized = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const RiskOperationsResponseNormalizationException();
      }
      normalized[key] = _normalizeCallableValue(entry.value);
    }
    return normalized;
  }
  throw const RiskOperationsResponseNormalizationException();
}

class CallableRiskOperationsRepository implements RiskOperationsRepository {
  CallableRiskOperationsRepository({
    FirebaseFunctions? functions,
    RiskOperationsCallableTransport? transport,
    RiskOperationsFailureLogger? failureLogger,
  }) : _transport = transport ?? _firebaseTransport(functions),
       _failureLogger = failureLogger ?? _logFailure;

  final RiskOperationsCallableTransport _transport;
  final RiskOperationsFailureLogger _failureLogger;

  @override
  Future<RiskOperationsPageResult> list(
    RiskOperationsQuery query,
    RiskOperationsReadDiagnostics diagnostics,
  ) async {
    Object? responseRoot;
    try {
      responseRoot = await _transport({
        ...query.toMap(),
        ...diagnostics.toMap(),
      });
    } catch (error) {
      throw _failure(
        RiskOperationsRepositoryFailureStage.callableResultReceived,
        error,
        diagnostics,
      );
    }

    late final Map<String, dynamic> normalized;
    try {
      normalized = normalizeRiskOperationsResponse(responseRoot);
    } catch (error) {
      throw _failure(
        RiskOperationsRepositoryFailureStage.rootResponseNormalization,
        error,
        diagnostics,
        responseRoot: responseRoot,
      );
    }

    try {
      return RiskOperationsPageResult.fromMap(normalized);
    } catch (error) {
      throw _failure(
        RiskOperationsRepositoryFailureStage.pageResultParsing,
        error,
        diagnostics,
        responseRoot: responseRoot,
      );
    }
  }

  RiskOperationsRepositoryException _failure(
    RiskOperationsRepositoryFailureStage stage,
    Object error,
    RiskOperationsReadDiagnostics diagnostics, {
    Object? responseRoot,
  }) {
    final exception = RiskOperationsRepositoryException(
      failureStage: stage,
      exceptionType: error.runtimeType.toString(),
      firebaseCode: error is FirebaseFunctionsException ? error.code : null,
    );
    _failureLogger(<String, Object?>{
      'event': 'risk_operations_repository_failed',
      'failureStage': stage.wireValue,
      'exceptionType': exception.exceptionType,
      'lifecycleCorrelationHash': _correlationHash(diagnostics),
      'routeEntryCause': diagnostics.routeEntryCause.wireValue,
      'responseRootType': responseRoot?.runtimeType.toString() ?? 'null',
      'transactionCommitted': false,
      'writeAttempted': false,
    });
    return exception;
  }

  static String _correlationHash(RiskOperationsReadDiagnostics diagnostics) =>
      sha256
          .convert(
            utf8.encode(
              '${diagnostics.appBootId}:${diagnostics.navigationRequestId}:'
              '${diagnostics.routeEntryId}:${diagnostics.loadAttemptId}',
            ),
          )
          .toString();

  static void _logFailure(Map<String, Object?> safeFields) {
    developer.log(jsonEncode(safeFields), name: 'risk_operations_repository');
  }

  static RiskOperationsCallableTransport _firebaseTransport(
    FirebaseFunctions? value,
  ) {
    final functions =
        value ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
    return (request) async {
      final response = await functions
          .httpsCallable('listRiskOperationsReadModel')
          .call<Object?>(request);
      return response.data;
    };
  }
}
