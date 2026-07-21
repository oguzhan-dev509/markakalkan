import 'package:cloud_functions/cloud_functions.dart';

import 'risk_operations_models.dart';

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
  Future<RiskOperationsPageResult> list(RiskOperationsQuery query);
}

class CallableRiskOperationsRepository implements RiskOperationsRepository {
  CallableRiskOperationsRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
  final FirebaseFunctions _functions;
  @override
  Future<RiskOperationsPageResult> list(RiskOperationsQuery query) async {
    final response = await _functions
        .httpsCallable('listRiskOperationsReadModel')
        .call<Map<String, dynamic>>(query.toMap());
    return RiskOperationsPageResult.fromMap(
      Map<String, dynamic>.from(response.data),
    );
  }
}
