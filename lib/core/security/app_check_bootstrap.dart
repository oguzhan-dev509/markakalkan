import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

enum AppCheckBootstrapState { uninitialized, activating, ready, unavailable }

typedef AppCheckActivator = Future<void> Function(String siteKey);
typedef AppCheckTokenProbe = Future<String?> Function();

class AppCheckBootstrap extends ChangeNotifier {
  AppCheckBootstrap({
    AppCheckActivator? activate,
    AppCheckTokenProbe? tokenProbe,
    bool? isWeb,
  }) : _activate = activate ?? _activateEnterprise,
       _tokenProbe = tokenProbe ?? _probeToken,
       _isWeb = isWeb ?? kIsWeb;

  static const String siteKeyEnvironmentName =
      'MARKAKALKAN_RECAPTCHA_ENTERPRISE_SITE_KEY';
  static final AppCheckBootstrap instance = AppCheckBootstrap();

  final AppCheckActivator _activate;
  final AppCheckTokenProbe _tokenProbe;
  final bool _isWeb;
  AppCheckBootstrapState _state = AppCheckBootstrapState.uninitialized;

  AppCheckBootstrapState get state => _state;
  bool get isReady => _state == AppCheckBootstrapState.ready;

  Future<void> initialize({String? siteKey}) async {
    if (_state != AppCheckBootstrapState.uninitialized) return;
    _setState(AppCheckBootstrapState.activating);

    final configuredKey =
        (siteKey ?? const String.fromEnvironment(siteKeyEnvironmentName))
            .trim();
    if (!_isWeb || configuredKey.isEmpty) {
      _setState(AppCheckBootstrapState.unavailable);
      return;
    }

    try {
      await _activate(configuredKey);
      _setState(AppCheckBootstrapState.ready);
    } catch (_) {
      _setState(AppCheckBootstrapState.unavailable);
    }
  }

  Future<bool> verifyTokenAcquisition() async {
    if (!isReady) return false;
    try {
      final token = await _tokenProbe();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _setState(AppCheckBootstrapState value) {
    _state = value;
    notifyListeners();
  }

  static Future<void> _activateEnterprise(String siteKey) {
    return FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(siteKey),
    );
  }

  static Future<String?> _probeToken() => FirebaseAppCheck.instance.getToken();
}
