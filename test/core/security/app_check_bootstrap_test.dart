import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

void main() {
  final configuredValue = <String>['configured', 'value'].join('-');

  test('enterprise activation reaches ready without exposing token', () async {
    String? receivedKey;
    final bootstrap = AppCheckBootstrap(
      isWeb: true,
      activate: (key) async => receivedKey = key,
      tokenProbe: _successfulProbe,
    );

    await bootstrap.initialize(siteKey: configuredValue);

    expect(receivedKey, configuredValue);
    expect(bootstrap.state, AppCheckBootstrapState.ready);
    expect(await bootstrap.verifyTokenAcquisition(), isTrue);
  });

  test('missing configuration fails safe without activation', () async {
    var activated = false;
    final bootstrap = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async => activated = true,
    );

    await bootstrap.initialize(siteKey: '  ');

    expect(activated, isFalse);
    expect(bootstrap.state, AppCheckBootstrapState.unavailable);
    expect(await bootstrap.verifyTokenAcquisition(), isFalse);
  });

  test('activation and token failures produce only safe state', () async {
    final failedActivation = AppCheckBootstrap(
      isWeb: true,
      activate: (_) => Future<void>.error(StateError('secret detail')),
    );
    await failedActivation.initialize(siteKey: configuredValue);
    expect(failedActivation.state, AppCheckBootstrapState.unavailable);

    final failedToken = AppCheckBootstrap(
      isWeb: true,
      activate: (_) async {},
      tokenProbe: _failedProbe,
    );
    await failedToken.initialize(siteKey: configuredValue);
    expect(await failedToken.verifyTokenAcquisition(), isFalse);
  });
}

Future<String?> _successfulProbe() async => 'present';

Future<String?> _failedProbe() =>
    Future<String?>.error(StateError('unavailable'));
