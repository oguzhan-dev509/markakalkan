import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

void main() {
  final configuredValue = <String>['configured', 'value'].join('-');

  test('enterprise activation reaches ready without exposing token', () async {
    String? receivedKey;
    bool? autoRefreshEnabled;
    final bootstrap = AppCheckBootstrap(
      isWeb: true,
      activate: (key) async => receivedKey = key,
      enableAutoRefresh: (enabled) async => autoRefreshEnabled = enabled,
      tokenProbe: (_) => _successfulProbe(),
    );

    await bootstrap.initialize(siteKey: configuredValue);

    expect(receivedKey, configuredValue);
    expect(autoRefreshEnabled, isTrue);
    expect(bootstrap.state, AppCheckBootstrapState.ready);
    expect(await bootstrap.verifyTokenAcquisition(), isTrue);
  });

  test('available cached token does not force refresh', () async {
    final forceRefreshes = <bool>[];
    final bootstrap = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async {},
      enableAutoRefresh: (_) async {},
      tokenProbe: (forceRefresh) async {
        forceRefreshes.add(forceRefresh);
        return 'present';
      },
    );

    await bootstrap.initialize(siteKey: configuredValue);
    await bootstrap.ensureReady();

    expect(forceRefreshes, [false, false]);
    expect(bootstrap.isReady, isTrue);
  });

  test('missing configuration fails safe without activation', () async {
    var activated = false;
    var autoRefreshCalled = false;
    final bootstrap = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async => activated = true,
      enableAutoRefresh: (_) async => autoRefreshCalled = true,
    );

    await bootstrap.initialize(siteKey: '  ');

    expect(activated, isFalse);
    expect(autoRefreshCalled, isFalse);
    expect(bootstrap.state, AppCheckBootstrapState.unavailable);
    expect(await bootstrap.verifyTokenAcquisition(), isFalse);
  });

  test('activation failure is surfaced with only safe state', () async {
    final failedActivation = AppCheckBootstrap(
      isWeb: true,
      activate: (_) => Future<void>.error(StateError('secret detail')),
      enableAutoRefresh: (_) async {},
    );
    await expectLater(
      failedActivation.initialize(siteKey: configuredValue),
      throwsA(isA<AppCheckUnavailableException>()),
    );
    expect(failedActivation.state, AppCheckBootstrapState.unavailable);
  });

  test('null token is not ready after one controlled force refresh', () async {
    final forceRefreshes = <bool>[];
    final bootstrap = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async {},
      enableAutoRefresh: (_) async {},
      tokenProbe: (forceRefresh) async {
        forceRefreshes.add(forceRefresh);
        return null;
      },
    );

    await expectLater(
      bootstrap.initialize(siteKey: configuredValue),
      throwsA(isA<AppCheckUnavailableException>()),
    );
    expect(forceRefreshes, [false, true]);
    expect(bootstrap.state, AppCheckBootstrapState.unavailable);
  });

  test('token acquisition error is surfaced', () async {
    final bootstrap = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async {},
      enableAutoRefresh: (_) async {},
      tokenProbe: (_) => _failedProbe(),
    );

    await expectLater(
      bootstrap.initialize(siteKey: configuredValue),
      throwsA(isA<AppCheckUnavailableException>()),
    );
    expect(bootstrap.state, AppCheckBootstrapState.unavailable);
  });

  test('auto refresh failure is surfaced', () async {
    final failedRefresh = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async {},
      enableAutoRefresh: (_) => Future<void>.error(StateError('secret detail')),
    );
    await expectLater(
      failedRefresh.initialize(siteKey: configuredValue),
      throwsA(isA<AppCheckUnavailableException>()),
    );
    expect(failedRefresh.state, AppCheckBootstrapState.unavailable);
  });

  test('concurrent ensureReady calls share one token request', () async {
    final token = Completer<String?>();
    var tokenRequests = 0;
    final bootstrap = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async {},
      enableAutoRefresh: (_) async {},
      tokenProbe: (_) {
        tokenRequests++;
        return token.future;
      },
    );

    final initialization = bootstrap.initialize(siteKey: configuredValue);
    await Future<void>.delayed(Duration.zero);
    final concurrent = bootstrap.ensureReady();
    expect(tokenRequests, 1);

    token.complete('present');
    await Future.wait([initialization, concurrent]);
    expect(tokenRequests, 1);
    expect(bootstrap.isReady, isTrue);
  });

  test('production bootstrap preserves Firebase, App Check, runApp order', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final firebase = mainSource.indexOf('await Firebase.initializeApp');
    final appCheck = mainSource.indexOf(
      'await AppCheckBootstrap.instance.initialize()',
    );
    final run = mainSource.indexOf('runApp(const MarkaKalkanApp())');

    expect(firebase, greaterThanOrEqualTo(0));
    expect(appCheck, greaterThan(firebase));
    expect(run, greaterThan(appCheck));
    expect(
      File('lib/core/security/app_check_bootstrap.dart').readAsStringSync(),
      contains('setTokenAutoRefreshEnabled(enabled)'),
    );
  });
}

Future<String?> _successfulProbe() async => 'present';

Future<String?> _failedProbe() =>
    Future<String?>.error(StateError('unavailable'));
