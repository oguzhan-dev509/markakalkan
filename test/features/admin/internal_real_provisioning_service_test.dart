import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/admin/data/internal_real_provisioning_controller.dart';
import 'package:markakalkan/features/admin/data/internal_real_provisioning_service.dart';
import 'package:markakalkan/features/admin/models/internal_provisioning_dry_run_result.dart';
import 'package:markakalkan/features/admin/models/internal_real_provisioning_gate.dart';

void main() {
  test('real service sends only exact pilot and dryRun false', () async {
    Map<String, Object>? request;
    final service = InternalRealProvisioningService(
      random: Random(11),
      caller: (value) async {
        request = value;
        return _response(outcome: 'created', committed: true);
      },
    );

    final result = await service.create();

    expect(request!.keys, <String>{'pilotCode', 'dryRun', 'correlationId'});
    expect(request!['pilotCode'], InternalRealProvisioningService.pilotCode);
    expect(request!['dryRun'], isFalse);
    expect(
      request!['correlationId'],
      matches(RegExp(r'^web-real-[0-9a-f]{32}$')),
    );
    expect(result.outcome, InternalProvisioningOutcome.created);
    expect(result.transactionCommitted, isTrue);
  });

  test(
    'canonical replay is accepted and non-canonical alias is rejected',
    () async {
      final replay = InternalRealProvisioningService(
        caller: (_) async =>
            _response(outcome: 'idempotent_success', committed: false),
      );
      expect(
        (await replay.create()).outcome,
        InternalProvisioningOutcome.idempotentSuccess,
      );

      final alias = InternalRealProvisioningService(
        caller: (_) async => _response(
          outcome: <String>['provision', 'ed'].join(),
          committed: true,
        ),
      );
      expect(alias.create, throwsFormatException);
    },
  );

  test('controller blocks double submit and locks after completion', () async {
    final pending = Completer<Map<Object?, Object?>>();
    var calls = 0;
    final controller = InternalRealProvisioningController(
      sessionLock: InternalRealProvisioningSessionLock(),
      service: InternalRealProvisioningService(
        caller: (_) {
          calls += 1;
          return pending.future;
        },
      ),
    );

    final first = controller.submitConfirmed(confirmed: true);
    final second = await controller.submitConfirmed(confirmed: true);
    expect(second, isNull);
    expect(calls, 1);

    pending.complete(_response(outcome: 'created', committed: true));
    await first;
    expect(controller.state, InternalRealProvisioningSubmissionState.completed);
    expect(await controller.submitConfirmed(confirmed: true), isNull);
    expect(calls, 1);
  });

  test('explicit confirmation and build gate are fail-closed', () async {
    var calls = 0;
    final controller = InternalRealProvisioningController(
      sessionLock: InternalRealProvisioningSessionLock(),
      service: InternalRealProvisioningService(
        caller: (_) async {
          calls += 1;
          return _response(outcome: 'created', committed: true);
        },
      ),
    );

    expect(InternalRealProvisioningGate.enabled, isFalse);
    expect(await controller.submitConfirmed(confirmed: false), isNull);
    expect(calls, 0);
  });

  test('session lock survives controller recreation and failures', () async {
    final lock = InternalRealProvisioningSessionLock();
    var calls = 0;
    final first = InternalRealProvisioningController(
      sessionLock: lock,
      service: InternalRealProvisioningService(
        caller: (_) async {
          calls += 1;
          throw StateError('safe failure');
        },
      ),
    );
    await expectLater(first.submitConfirmed(confirmed: true), throwsStateError);

    final recreated = InternalRealProvisioningController(
      sessionLock: lock,
      service: InternalRealProvisioningService(
        caller: (_) async {
          calls += 1;
          return _response(outcome: 'created', committed: true);
        },
      ),
    );
    expect(await recreated.submitConfirmed(confirmed: true), isNull);
    expect(calls, 1);
  });
}

Map<Object?, Object?> _response({
  required String outcome,
  required bool committed,
}) => <Object?, Object?>{
  'outcome': outcome,
  'dryRun': false,
  'transactionCommitted': committed,
  'rolloutMode': 'single_pilot_create',
  'blockerCodes': <String>[],
  'tenantId': 'tenant-1234',
  'brandId': 'brand-1234',
  'membershipId': 'membership-1234',
  'receiptId': 'receipt-1234',
  'auditEventId': 'audit-1234',
};
