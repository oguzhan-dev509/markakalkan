import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/features/admin/models/internal_provisioning_dry_run_result.dart';

typedef ProvisioningDryRunCaller =
    Future<Map<Object?, Object?>> Function(Map<String, Object> request);

class InternalProvisioningDryRunService {
  InternalProvisioningDryRunService({
    FirebaseFunctions? functions,
    ProvisioningDryRunCaller? caller,
    Random? random,
  }) : _caller = caller ?? _firebaseCaller(functions),
       _random = random ?? Random.secure();

  static const String pilotCode = 'MK-RST-0J-INTERNAL-001';
  final ProvisioningDryRunCaller _caller;
  final Random _random;

  Future<InternalProvisioningDryRunResult> run() async {
    final response = await _caller(<String, Object>{
      'pilotCode': pilotCode,
      'dryRun': true,
      'correlationId': _correlationId(),
    });
    return InternalProvisioningDryRunResult.fromMap(response);
  }

  String _correlationId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return 'web-${bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
  }

  static ProvisioningDryRunCaller _firebaseCaller(FirebaseFunctions? value) {
    final functions =
        value ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
    return (request) async {
      final result = await functions
          .httpsCallable('provisionInternalTenantBrandPilot')
          .call<Object?>(request);
      final data = result.data;
      if (data is! Map) {
        throw const FormatException('Invalid provisioning response');
      }
      return Map<Object?, Object?>.from(data);
    };
  }
}
