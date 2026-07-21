import 'package:cloud_functions/cloud_functions.dart';

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
