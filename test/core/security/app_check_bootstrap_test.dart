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
      tokenProbe: _successfulProbe,
    );

    await bootstrap.initialize(siteKey: configuredValue);

    expect(receivedKey, configuredValue);
    expect(autoRefreshEnabled, isTrue);
    expect(bootstrap.state, AppCheckBootstrapState.ready);
    expect(await bootstrap.verifyTokenAcquisition(), isTrue);
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

  test('activation and token failures produce only safe state', () async {
    final failedActivation = AppCheckBootstrap(
      isWeb: true,
      activate: (_) => Future<void>.error(StateError('secret detail')),
      enableAutoRefresh: (_) async {},
    );
    await failedActivation.initialize(siteKey: configuredValue);
    expect(failedActivation.state, AppCheckBootstrapState.unavailable);

    final failedToken = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async {},
      enableAutoRefresh: (_) async {},
      tokenProbe: _failedProbe,
    );
    await failedToken.initialize(siteKey: configuredValue);
    expect(await failedToken.verifyTokenAcquisition(), isFalse);

    final failedRefresh = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async {},
      enableAutoRefresh: (_) => Future<void>.error(StateError('secret detail')),
    );
    await failedRefresh.initialize(siteKey: configuredValue);
    expect(failedRefresh.state, AppCheckBootstrapState.unavailable);
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
