import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

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
    required this.clientTabId,
    required this.navigationId,
    required this.pageInstanceId,
    required this.loadAttemptId,
    required this.trigger,
    required this.attemptSequence,
  });

  final String clientTabId;
  final String navigationId;
  final String pageInstanceId;
  final String loadAttemptId;
  final RiskOperationsLoadTrigger trigger;
  final int attemptSequence;

  Map<String, dynamic> toMap() => {
    'clientTabId': clientTabId,
    'navigationId': navigationId,
    'pageInstanceId': pageInstanceId,
    'loadAttemptId': loadAttemptId,
    'trigger': trigger.wireValue,
    'attemptSequence': attemptSequence,
  };
}

class RiskOperationsDiagnosticIdProvider {
  RiskOperationsDiagnosticIdProvider({
    String Function()? nextId,
    String? clientTabId,
  }) : _nextId = nextId ?? _secureId,
       clientTabId = clientTabId ?? (nextId ?? _secureId)();

  static final RiskOperationsDiagnosticIdProvider instance =
      RiskOperationsDiagnosticIdProvider();

  final String Function() _nextId;
  final String clientTabId;

  String createNavigationId() => _nextId();
  String createPageInstanceId() => _nextId();
  String createLoadAttemptId() => _nextId();

  static String _secureId() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
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

class CallableRiskOperationsRepository implements RiskOperationsRepository {
  CallableRiskOperationsRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
  final FirebaseFunctions _functions;
  @override
  Future<RiskOperationsPageResult> list(
    RiskOperationsQuery query,
    RiskOperationsReadDiagnostics diagnostics,
  ) async {
    final response = await _functions
        .httpsCallable('listRiskOperationsReadModel')
        .call<Map<String, dynamic>>({...query.toMap(), ...diagnostics.toMap()});
    return RiskOperationsPageResult.fromMap(
      Map<String, dynamic>.from(response.data),
    );
  }
}
