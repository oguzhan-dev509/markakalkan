import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/admin/data/internal_provisioning_dry_run_service.dart';
import 'package:markakalkan/features/admin/models/internal_provisioning_dry_run_result.dart';

void main() {
  test('sends only fixed pilot, dryRun true and safe correlation id', () async {
    Map<String, Object>? request;
    final service = InternalProvisioningDryRunService(
      random: Random(7),
      caller: (value) async {
        request = value;
        return _validResponse();
      },
    );

    final result = await service.run();

    expect(request!.keys, <String>{'pilotCode', 'dryRun', 'correlationId'});
    expect(request!['pilotCode'], InternalProvisioningDryRunService.pilotCode);
    expect(request!['dryRun'], isTrue);
    expect(request!['correlationId'], matches(RegExp(r'^web-[0-9a-f]{32}$')));
    expect(result.outcome, InternalProvisioningOutcome.dryRunReady);
    expect(result.dryRun, isTrue);
    expect(result.transactionCommitted, isFalse);
  });

  test('sanitizes known response fields and rejects malformed values', () {
    final response = <Object?, Object?>{
      ..._validResponse(),
      'unknownPayload': <String, Object>{'secret': true},
    };
    final result = InternalProvisioningDryRunResult.fromMap(response);
    expect(result.blockerCodes, isEmpty);
    expect(result.tenantId, 'tenant-1234');

    expect(
      () => InternalProvisioningDryRunResult.fromMap(<Object?, Object?>{
        ...response,
        'transactionCommitted': 'false',
      }),
      throwsFormatException,
    );
  });
}

Map<Object?, Object?> _validResponse() => <Object?, Object?>{
  'outcome': 'dry_run_ready',
  'dryRun': true,
  'transactionCommitted': false,
  'rolloutMode': 'dry_run_only',
  'blockerCodes': <String>[],
  'tenantId': 'tenant-1234',
  'brandId': 'brand-1234',
  'membershipId': 'membership-1234',
  'receiptId': 'receipt-1234',
  'auditEventId': 'audit-1234',
};
