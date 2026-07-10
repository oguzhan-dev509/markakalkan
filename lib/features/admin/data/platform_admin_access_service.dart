import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/features/admin/models/platform_admin_access.dart';

class PlatformAdminAccessService {
  PlatformAdminAccessService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<PlatformAdminAccess> getMyAccess() async {
    final result = await _functions
        .httpsCallable('getMyPlatformAdminAccess')
        .call<Map<String, dynamic>>();

    return PlatformAdminAccess.fromMap(result.data);
  }
}
