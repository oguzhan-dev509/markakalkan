import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

enum AppCheckBootstrapState { uninitialized, activating, ready, unavailable }

typedef AppCheckActivator = Future<void> Function(String siteKey);
typedef AppCheckAutoRefreshEnabler = Future<void> Function(bool enabled);
typedef AppCheckTokenProbe = Future<String?> Function(bool forceRefresh);

class AppCheckUnavailableException implements Exception {
  const AppCheckUnavailableException();
}

class AppCheckBootstrap extends ChangeNotifier {
  AppCheckBootstrap({
    AppCheckActivator? activate,
    AppCheckAutoRefreshEnabler? enableAutoRefresh,
    AppCheckTokenProbe? tokenProbe,
    bool? isWeb,
  }) : _activate = activate ?? _activateEnterprise,
       _enableAutoRefresh = enableAutoRefresh ?? _enableTokenAutoRefresh,
       _tokenProbe = tokenProbe ?? _probeToken,
       _isWeb = isWeb ?? kIsWeb;

  static const String siteKeyEnvironmentName =
      'MARKAKALKAN_RECAPTCHA_ENTERPRISE_SITE_KEY';
  static final AppCheckBootstrap instance = AppCheckBootstrap();

  final AppCheckActivator _activate;
  final AppCheckAutoRefreshEnabler _enableAutoRefresh;
  final AppCheckTokenProbe _tokenProbe;
  final bool _isWeb;
  AppCheckBootstrapState _state = AppCheckBootstrapState.uninitialized;
  Future<void>? _inFlightReadiness;
  bool _activated = false;

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
      await _enableAutoRefresh(true);
      _activated = true;
      await ensureReady();
    } on AppCheckUnavailableException {
      rethrow;
    } catch (_) {
      _setState(AppCheckBootstrapState.unavailable);
      throw const AppCheckUnavailableException();
    }
  }

  Future<void> ensureReady() {
    final activeRequest = _inFlightReadiness;
    if (activeRequest != null) return activeRequest;
    if (!_isWeb || !_activated) {
      return Future<void>.error(const AppCheckUnavailableException());
    }

    late final Future<void> request;
    request = _acquireToken().whenComplete(() {
      if (identical(_inFlightReadiness, request)) {
        _inFlightReadiness = null;
      }
    });
    _inFlightReadiness = request;
    return request;
  }

  Future<bool> verifyTokenAcquisition() async {
    try {
      await ensureReady();
      return true;
    } on AppCheckUnavailableException {
      return false;
    }
  }

  Future<void> _acquireToken() async {
    try {
      var token = await _tokenProbe(false);
      if (token == null || token.trim().isEmpty) {
        token = await _tokenProbe(true);
      }
      if (token == null || token.trim().isEmpty) {
        throw const AppCheckUnavailableException();
      }
      _setState(AppCheckBootstrapState.ready);
    } on AppCheckUnavailableException {
      _setState(AppCheckBootstrapState.unavailable);
      rethrow;
    } catch (_) {
      _setState(AppCheckBootstrapState.unavailable);
      throw const AppCheckUnavailableException();
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

  static Future<void> _enableTokenAutoRefresh(bool enabled) =>
      FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(enabled);

  static Future<String?> _probeToken(bool forceRefresh) =>
      FirebaseAppCheck.instance.getToken(forceRefresh);
}
