import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/features/admin/models/counterfeit_twin_admin_report.dart';

class CounterfeitTwinAdminService {
  CounterfeitTwinAdminService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<List<CounterfeitTwinAdminReport>> listReports() async {
    final result = await _functions
        .httpsCallable('listCounterfeitTwinReportsForAdmin')
        .call<dynamic>(const <String, dynamic>{});

    final data = _map(result.data);
    final rawReports = data['reports'];
    if (rawReports is! List) return const <CounterfeitTwinAdminReport>[];

    return rawReports
        .whereType<Map>()
        .map(CounterfeitTwinAdminReport.fromMap)
        .toList(growable: false);
  }

  Future<String> reviewReport({
    required String reportId,
    required String decision,
    required String reviewNote,
    required String publicSummary,
  }) async {
    final result = await _functions
        .httpsCallable('reviewCounterfeitTwinReport')
        .call<dynamic>(<String, dynamic>{
          'reportId': reportId,
          'decision': decision,
          'reviewNote': reviewNote.trim(),
          'publicSummary': publicSummary.trim(),
        });

    final data = _map(result.data);
    return (data['status'] ?? decision).toString().trim();
  }

  Future<void> deleteReport({
    required String reportId,
    required String deleteReason,
  }) async {
    await _functions.httpsCallable('deleteCounterfeitTwinReport').call<dynamic>(
      <String, dynamic>{
        'reportId': reportId,
        'deleteReason': deleteReason.trim(),
      },
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map<String, dynamic>(
    (key, item) => MapEntry<String, dynamic>(key.toString(), item),
  );
}
