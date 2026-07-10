import 'package:cloud_functions/cloud_functions.dart';

class AdminEntryGateService {
  AdminEntryGateService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<bool> verifyEntryCode(String code) async {
    final result = await _functions
        .httpsCallable('verifyAdminEntryGate')
        .call<Map<String, dynamic>>({'code': code});

    return result.data['granted'] == true;
  }
}
