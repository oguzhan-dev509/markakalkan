import 'package:cloud_functions/cloud_functions.dart';

import 'traceability_models.dart';

class TraceabilityService {
  TraceabilityService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<List<SuspiciousVerificationScan>> listSuspiciousScans({
    int limit = 50,
    String? reviewStatus,
    String? riskLevel,
  }) async {
    final callable = _functions.httpsCallable(
      'listSuspiciousVerificationScans',
    );
    final response = await callable.call<Map<String, dynamic>>({
      'limit': limit,
      if (reviewStatus != null && reviewStatus.trim().isNotEmpty)
        'reviewStatus': reviewStatus.trim(),
      if (riskLevel != null && riskLevel.trim().isNotEmpty)
        'riskLevel': riskLevel.trim(),
    });
    final rawItems = response.data['items'];
    if (rawItems is! List) return const <SuspiciousVerificationScan>[];
    return rawItems
        .whereType<Map>()
        .map(
          (item) => SuspiciousVerificationScan.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<SuspiciousVerificationScan> reviewScan({
    required String scanId,
    required String reviewStatus,
    String reviewNotes = '',
  }) async {
    final callable = _functions.httpsCallable(
      'reviewSuspiciousVerificationScan',
    );
    final response = await callable.call<Map<String, dynamic>>({
      'scanId': scanId,
      'reviewStatus': reviewStatus,
      'reviewNotes': reviewNotes,
    });
    return SuspiciousVerificationScan.fromMap(
      Map<String, dynamic>.from(response.data['item'] as Map),
    );
  }

  Future<TraceabilityCaseSummary> createCaseFromScan({
    required String scanId,
    String? title,
    String? summary,
  }) async {
    final callable = _functions.httpsCallable('createTraceabilityCaseFromScan');
    final response = await callable.call<Map<String, dynamic>>({
      'scanId': scanId,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (summary != null && summary.trim().isNotEmpty)
        'summary': summary.trim(),
    });
    return TraceabilityCaseSummary.fromMap(
      Map<String, dynamic>.from(response.data['item'] as Map),
    );
  }

  Future<List<TraceabilityCaseSummary>> listCases({
    int limit = 50,
    String? status,
  }) async {
    final callable = _functions.httpsCallable('listTraceabilityCases');
    final response = await callable.call<Map<String, dynamic>>({
      'limit': limit,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    });
    final rawItems = response.data['items'];
    if (rawItems is! List) return const <TraceabilityCaseSummary>[];
    return rawItems
        .whereType<Map>()
        .map(
          (item) =>
              TraceabilityCaseSummary.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }
}
