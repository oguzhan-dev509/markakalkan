// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: deprecated_member_use
import 'dart:html' as html;

import 'risk_operations_lifecycle.dart';

class _WebSessionStorage implements RiskOperationsSessionStorage {
  @override
  String? read(String key) => html.window.sessionStorage[key];

  @override
  void write(String key, String value) {
    html.window.sessionStorage[key] = value;
  }
}

RiskOperationsNavigationType _navigationType() {
  final entries = html.window.performance.getEntriesByType('navigation');
  if (entries.isEmpty) {
    return RiskOperationsNavigationType.unknown;
  }
  final type = (entries.first as dynamic).type;
  return switch (type) {
    'navigate' => RiskOperationsNavigationType.navigate,
    'reload' => RiskOperationsNavigationType.reload,
    'back_forward' => RiskOperationsNavigationType.backForward,
    'prerender' => RiskOperationsNavigationType.prerender,
    _ => RiskOperationsNavigationType.unknown,
  };
}

RiskOperationsBrowserContext createRiskOperationsBrowserContext() {
  var pageShowPersisted = false;
  html.window.onPageShow.listen((event) {
    if (event is html.PageTransitionEvent) {
      pageShowPersisted = event.persisted == true;
    }
  });
  return RiskOperationsBrowserContext(
    sessionStorage: _WebSessionStorage(),
    navigationType: _navigationType(),
    pageshowPersisted: () => pageShowPersisted,
    initialVisibilityState: html.document.visibilityState,
    documentReferrerPresent: html.document.referrer.isNotEmpty,
    serviceWorkerControlled:
        html.window.navigator.serviceWorker?.controller != null,
  );
}
