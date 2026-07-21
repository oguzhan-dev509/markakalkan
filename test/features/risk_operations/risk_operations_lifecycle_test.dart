import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_lifecycle.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_repository.dart';

class _MemoryStorage implements RiskOperationsSessionStorage {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
}

class _UnavailableStorage implements RiskOperationsSessionStorage {
  @override
  String? read(String key) => throw StateError('session storage unavailable');
  @override
  void write(String key, String value) =>
      throw StateError('session storage unavailable');
}

String Function() _ids(String prefix) {
  var sequence = 0;
  return () => '$prefix-${(++sequence).toString().padLeft(8, '0')}';
}

void main() {
  test('same physical tab survives full app reload but app boot changes', () {
    final storage = _MemoryStorage();
    final first = RiskOperationsLifecycleProvider(
      nextId: _ids('first'),
      browserContext: RiskOperationsBrowserContext(sessionStorage: storage),
    );
    final reload = RiskOperationsLifecycleProvider(
      nextId: _ids('reload'),
      browserContext: RiskOperationsBrowserContext(
        sessionStorage: storage,
        navigationType: RiskOperationsNavigationType.reload,
      ),
    );
    expect(reload.browserTabSessionId, first.browserTabSessionId);
    expect(reload.appBootId, isNot(first.appBootId));
    expect(
      reload.browserContext.navigationType,
      RiskOperationsNavigationType.reload,
    );
  });

  test('a new physical tab receives a different tab session identity', () {
    final first = RiskOperationsLifecycleProvider(
      nextId: _ids('tab-one'),
      browserContext: RiskOperationsBrowserContext(
        sessionStorage: _MemoryStorage(),
      ),
    );
    final second = RiskOperationsLifecycleProvider(
      nextId: _ids('tab-two'),
      browserContext: RiskOperationsBrowserContext(
        sessionStorage: _MemoryStorage(),
      ),
    );
    expect(second.browserTabSessionId, isNot(first.browserTabSessionId));
  });

  test('sessionStorage denial degrades safely to app-memory identity', () {
    final lifecycle = RiskOperationsLifecycleProvider(
      nextId: _ids('degraded'),
      browserContext: RiskOperationsBrowserContext(
        sessionStorage: _UnavailableStorage(),
      ),
    );
    expect(lifecycle.browserTabSessionId, startsWith('degraded-'));
    expect(lifecycle.browserTabSessionId, isNot(lifecycle.appBootId));
    expect(lifecycle.lifecycleQuality, RiskOperationsLifecycleQuality.degraded);
  });

  test('browser API failure degrades lifecycle and navigation safely', () {
    final lifecycle = RiskOperationsLifecycleProvider(
      nextId: _ids('browser-failure'),
      browserContext: RiskOperationsBrowserContext(
        sessionStorage: _MemoryStorage(),
        navigationType: RiskOperationsNavigationType.unknown,
        browserAccessDegraded: true,
      ),
    );
    expect(lifecycle.lifecycleQuality, RiskOperationsLifecycleQuality.degraded);
    expect(
      lifecycle.browserContext.navigationType,
      RiskOperationsNavigationType.unknown,
    );
  });

  test('auth epoch changes only on transitions into authenticated state', () {
    final lifecycle = RiskOperationsLifecycleProvider(
      nextId: _ids('auth'),
      browserContext: const RiskOperationsBrowserContext(),
    );
    lifecycle.observeAuthentication(false);
    expect(lifecycle.authEpoch, 0);
    lifecycle.observeAuthentication(true);
    lifecycle.observeAuthentication(true);
    expect(lifecycle.authEpoch, 1);
    lifecycle.observeAuthentication(false);
    lifecycle.observeAuthentication(true);
    expect(lifecycle.authEpoch, 2);
  });

  test('route and navigation identities have independent scopes', () {
    final lifecycle = RiskOperationsLifecycleProvider(
      nextId: _ids('scope'),
      browserContext: const RiskOperationsBrowserContext(),
    );
    final navigation = lifecycle.createNavigationRequestId();
    final firstRoute = lifecycle.createRouteEntryId();
    final secondRoute = lifecycle.createRouteEntryId();
    expect({navigation, firstRoute, secondRoute}, hasLength(3));
  });

  test('navigation and route provenance serialize without URL contents', () {
    const diagnostics = RiskOperationsReadDiagnostics(
      browserTabSessionId: 'browser-tab-0001',
      appBootId: 'app-boot-0001',
      authEpoch: 1,
      navigationRequestId: 'navigation-0001',
      routeEntryId: 'route-entry-0001',
      pageInstanceId: 'page-instance-0001',
      loadAttemptId: 'load-attempt-0001',
      navigationType: RiskOperationsNavigationType.backForward,
      routeEntryCause: RiskOperationsRouteEntryCause.browserBackForward,
      pageshowPersisted: true,
      initialVisibilityState: 'hidden',
      documentReferrerPresent: true,
      serviceWorkerControlled: true,
      lifecycleQuality: RiskOperationsLifecycleQuality.normal,
      trigger: RiskOperationsLoadTrigger.initialMount,
      attemptSequence: 1,
    );
    final map = diagnostics.toMap();
    expect(map['navigationType'], 'back_forward');
    expect(map['routeEntryCause'], 'browser_back_forward');
    expect(map['pageshowPersisted'], true);
    expect(map['lifecycleQuality'], 'normal');
    expect(map.keys, isNot(contains('url')));
    expect(map.keys, isNot(contains('referrer')));
  });

  test('all conservative route causes and navigation types are stable', () {
    expect(
      RiskOperationsRouteEntryCause.values.map((value) => value.wireValue),
      containsAll(<String>[
        'corporate_hub_card',
        'browser_reload_restore',
        'browser_back_forward',
        'auth_post_login_resume',
        'direct_route',
        'unknown',
      ]),
    );
    expect(
      RiskOperationsNavigationType.values.map((value) => value.wireValue),
      containsAll(<String>[
        'navigate',
        'reload',
        'back_forward',
        'prerender',
        'unknown',
      ]),
    );
  });

  test('PerformanceNavigationTiming values normalize deterministically', () {
    expect(
      riskOperationsNavigationTypeFromWire('navigate'),
      RiskOperationsNavigationType.navigate,
    );
    expect(
      riskOperationsNavigationTypeFromWire('reload'),
      RiskOperationsNavigationType.reload,
    );
    expect(
      riskOperationsNavigationTypeFromWire('back_forward'),
      RiskOperationsNavigationType.backForward,
    );
    expect(
      riskOperationsNavigationTypeFromWire('prerender'),
      RiskOperationsNavigationType.prerender,
    );
    expect(
      riskOperationsNavigationTypeFromWire('unexpected'),
      RiskOperationsNavigationType.unknown,
    );
  });

  test('safe client lifecycle event names are canonical and payload-free', () {
    expect(
      RiskOperationsClientLifecycleEvent.values.map((value) => value.wireValue),
      <String>[
        'risk_client_app_boot',
        'risk_client_auth_transition',
        'risk_route_push_requested',
        'risk_route_mounted',
        'risk_route_disposed',
      ],
    );
  });
}
