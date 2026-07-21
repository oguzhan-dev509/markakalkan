import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'risk_operations_lifecycle.dart';

const riskOperationsBrowserProviderKind = 'web_interop_v1';

class _WebSessionStorage implements RiskOperationsSessionStorage {
  @override
  String? read(String key) => web.window.sessionStorage.getItem(key);

  @override
  void write(String key, String value) {
    web.window.sessionStorage.setItem(key, value);
  }
}

(RiskOperationsNavigationType, bool) _navigationType() {
  try {
    final entries = web.window.performance
        .getEntriesByType('navigation')
        .toDart;
    if (entries.isEmpty) {
      return (RiskOperationsNavigationType.unknown, false);
    }
    final navigation = entries.first as web.PerformanceNavigationTiming;
    return (riskOperationsNavigationTypeFromWire(navigation.type), false);
  } catch (_) {
    return (RiskOperationsNavigationType.unknown, true);
  }
}

RiskOperationsBrowserContext createRiskOperationsBrowserContext() {
  try {
    var accessDegraded = false;
    var pageShowPersisted = false;
    final navigation = _navigationType();
    accessDegraded = navigation.$2;

    var initialVisibilityState = 'unknown';
    try {
      initialVisibilityState = web.document.visibilityState;
    } catch (_) {
      accessDegraded = true;
    }

    var documentReferrerPresent = false;
    try {
      documentReferrerPresent = web.document.referrer.isNotEmpty;
    } catch (_) {
      accessDegraded = true;
    }

    var serviceWorkerControlled = false;
    try {
      serviceWorkerControlled =
          web.window.navigator.serviceWorker.controller != null;
    } catch (_) {
      accessDegraded = true;
    }

    try {
      web.window.addEventListener(
        'pageshow',
        ((web.Event event) {
          try {
            final transition = event as web.PageTransitionEvent;
            pageShowPersisted = transition.persisted;
          } catch (_) {
            pageShowPersisted = false;
          }
        }).toJS,
      );
    } catch (_) {
      accessDegraded = true;
    }

    return RiskOperationsBrowserContext(
      providerKind: riskOperationsBrowserProviderKind,
      sessionStorage: _WebSessionStorage(),
      navigationType: accessDegraded
          ? RiskOperationsNavigationType.unknown
          : navigation.$1,
      pageshowPersisted: () => pageShowPersisted,
      initialVisibilityState: initialVisibilityState,
      documentReferrerPresent: documentReferrerPresent,
      serviceWorkerControlled: serviceWorkerControlled,
      browserAccessDegraded: accessDegraded,
    );
  } catch (_) {
    return const RiskOperationsBrowserContext(
      providerKind: riskOperationsBrowserProviderKind,
      browserAccessDegraded: true,
    );
  }
}
