import 'package:cloud_functions/cloud_functions.dart';

class CorporateApplicationSummary {
  const CorporateApplicationSummary({required this.reviewNote});

  final String reviewNote;

  factory CorporateApplicationSummary.fromMap(Map<String, dynamic> map) {
    return CorporateApplicationSummary(
      reviewNote: (map['reviewNote'] ?? '').toString().trim(),
    );
  }
}

class CorporateAccessSnapshot {
  const CorporateAccessSnapshot({
    required this.accessGranted,
    required this.state,
    this.application,
  });

  final bool accessGranted;
  final String state;
  final CorporateApplicationSummary? application;

  factory CorporateAccessSnapshot.fromMap(Map<String, dynamic> map) {
    final rawApplication = map['application'];
    return CorporateAccessSnapshot(
      accessGranted: map['accessGranted'] == true,
      state: (map['state'] ?? 'none').toString().trim(),
      application: rawApplication is Map
          ? CorporateApplicationSummary.fromMap(
              Map<String, dynamic>.from(rawApplication),
            )
          : null,
    );
  }
}

class CorporateAccessService {
  CorporateAccessService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<CorporateAccessSnapshot> getMyAccess() async {
    final result = await _functions
        .httpsCallable('getMyCorporateAccess')
        .call<Map<String, dynamic>>();
    return CorporateAccessSnapshot.fromMap(result.data);
  }
}
