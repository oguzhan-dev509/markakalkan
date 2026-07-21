import 'dart:math';

import 'risk_operations_browser_context.dart';

enum RiskOperationsNavigationType {
  navigate('navigate'),
  reload('reload'),
  backForward('back_forward'),
  prerender('prerender'),
  unknown('unknown');

  const RiskOperationsNavigationType(this.wireValue);
  final String wireValue;
}

enum RiskOperationsRouteEntryCause {
  corporateHubCard('corporate_hub_card'),
  browserReloadRestore('browser_reload_restore'),
  browserBackForward('browser_back_forward'),
  authPostLoginResume('auth_post_login_resume'),
  directRoute('direct_route'),
  unknown('unknown');

  const RiskOperationsRouteEntryCause(this.wireValue);
  final String wireValue;
}

enum RiskOperationsLifecycleQuality {
  normal('normal'),
  degraded('degraded');

  const RiskOperationsLifecycleQuality(this.wireValue);
  final String wireValue;
}

enum RiskOperationsClientLifecycleEvent {
  appBoot('risk_client_app_boot'),
  authTransition('risk_client_auth_transition'),
  routePushRequested('risk_route_push_requested'),
  routeMounted('risk_route_mounted'),
  routeDisposed('risk_route_disposed');

  const RiskOperationsClientLifecycleEvent(this.wireValue);
  final String wireValue;
}

abstract interface class RiskOperationsSessionStorage {
  String? read(String key);
  void write(String key, String value);
}

class RiskOperationsBrowserContext {
  const RiskOperationsBrowserContext({
    this.sessionStorage,
    this.navigationType = RiskOperationsNavigationType.unknown,
    bool Function()? pageshowPersisted,
    this.initialVisibilityState = 'unknown',
    this.documentReferrerPresent = false,
    this.serviceWorkerControlled = false,
  }) : _pageshowPersisted = pageshowPersisted;

  final RiskOperationsSessionStorage? sessionStorage;
  final RiskOperationsNavigationType navigationType;
  final bool Function()? _pageshowPersisted;
  final String initialVisibilityState;
  final bool documentReferrerPresent;
  final bool serviceWorkerControlled;

  bool get pageshowPersisted => _pageshowPersisted?.call() ?? false;
}

class RiskOperationsLifecycleProvider {
  RiskOperationsLifecycleProvider({
    String Function()? nextId,
    RiskOperationsBrowserContext? browserContext,
  }) : _nextId = nextId ?? secureId,
       browserContext = browserContext ?? createRiskOperationsBrowserContext() {
    appBootId = _nextId();
    final tabSession = _loadBrowserTabSessionId();
    browserTabSessionId = tabSession.$1;
    lifecycleQuality = tabSession.$2;
  }

  static const sessionStorageKey = 'markakalkan.risk.browser_tab_session.v1';
  static final RiskOperationsLifecycleProvider instance =
      RiskOperationsLifecycleProvider();

  final String Function() _nextId;
  final RiskOperationsBrowserContext browserContext;
  late final String appBootId;
  late final String browserTabSessionId;
  late final RiskOperationsLifecycleQuality lifecycleQuality;
  bool? _authenticated;
  int _authEpoch = 0;

  int get authEpoch => _authEpoch;

  void observeAuthentication(bool authenticated) {
    if (authenticated && _authenticated != true) {
      _authEpoch += 1;
    }
    _authenticated = authenticated;
  }

  String createNavigationRequestId() => _nextId();
  String createRouteEntryId() => _nextId();
  String createPageInstanceId() => _nextId();
  String createLoadAttemptId() => _nextId();

  (String, RiskOperationsLifecycleQuality) _loadBrowserTabSessionId() {
    final storage = browserContext.sessionStorage;
    if (storage != null) {
      try {
        final existing = storage.read(sessionStorageKey);
        if (existing != null && _validId(existing)) {
          return (existing, RiskOperationsLifecycleQuality.normal);
        }
        final created = _nextId();
        storage.write(sessionStorageKey, created);
        return (created, RiskOperationsLifecycleQuality.normal);
      } catch (_) {
        // Privacy settings can disable sessionStorage. Degrade to app memory.
      }
    }
    return (_nextId(), RiskOperationsLifecycleQuality.degraded);
  }

  static bool _validId(String value) =>
      value.length >= 8 &&
      value.length <= 64 &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);

  static String secureId() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
