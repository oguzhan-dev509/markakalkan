import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/dashboard/presentation/corporate_hub_page.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_models.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_lifecycle.dart';
import 'package:markakalkan/features/risk_operations/data/risk_operations_repository.dart';
import 'package:markakalkan/features/risk_operations/presentation/risk_operations_console_page.dart';

class _Observer extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

class _Repository implements RiskOperationsRepository {
  int calls = 0;
  @override
  Future<RiskOperationsPageResult> list(
    RiskOperationsQuery query,
    RiskOperationsReadDiagnostics diagnostics,
  ) async {
    calls++;
    return RiskOperationsPageResult.fromMap({
      'contractVersion': 'risk-operations-read-v1',
      'readOnly': true,
      'writesPerformed': 0,
      'summary': {
        'totalVisibleSignals': 0,
        'highOrCriticalRisk': 0,
        'awaitingHumanReview': 0,
        'strongCaseCandidates': 0,
        'insufficientEvidence': 0,
      },
      'items': <Object>[],
      'nextPageToken': null,
      'sourceAvailability': <Object>[],
    });
  }
}

class _Ids extends RiskOperationsLifecycleProvider {
  _Ids()
    : super(
        nextId: _next,
        browserContext: const RiskOperationsBrowserContext(),
      );
  static int value = 0;
  static String _next() => 'navigation-id-${++value}';
}

void main() {
  test(
    'corporate hub routes the existing risk module card to the read console',
    () {
      final hub = File(
        'lib/features/dashboard/presentation/corporate_hub_page.dart',
      ).readAsStringSync();
      final router = File('lib/app/router.dart').readAsStringSync();
      expect(hub, contains("id: 'risk_scans'"));
      expect(hub, contains("case 'risk_scans':"));
      expect(hub, contains('AppRouter.openRiskOperationsConsole'));
      expect(router, contains('openRiskOperationsConsole'));
      expect(router, contains('RiskOperationsConsolePage'));
    },
  );

  test(
    'console is tenant-private and does not implement admin bypass or writes',
    () {
      final page = File(
        'lib/features/risk_operations/presentation/risk_operations_console_page.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/features/risk_operations/data/risk_operations_repository.dart',
      ).readAsStringSync();
      expect(page, contains('Risk ve Şüpheli Taramalar'));
      expect(page, isNot(contains('platform_admins')));
      expect(repository, contains('listRiskOperationsReadModel'));
      expect(repository, isNot(contains('.collection(')));
      expect(repository, isNot(contains('.set(')));
      expect(repository, isNot(contains('.add(')));
    },
  );

  test('approved home hero source is untouched by the risk console', () {
    final home = File(
      'lib/features/home/presentation/markakalkan_home_page.dart',
    ).readAsStringSync();
    expect(home, contains('Müşteriniz orijinalini bilsin'));
    expect(home, isNot(contains('RiskOperationsConsolePage')));
  });

  testWidgets(
    'one real Corporate Hub card tap pushes one named page instance',
    (tester) async {
      final observer = _Observer();
      final repository = _Repository();
      final ids = _Ids();
      var navigationIdsCreated = 0;
      var pageInstances = 0;
      Future<void> open(BuildContext context) {
        final navigationId = ids.createNavigationRequestId();
        navigationIdsCreated++;
        return Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/risk-operations'),
            builder: (_) => RiskOperationsConsolePage(
              navigationRequestId: navigationId,
              routeEntryCause: RiskOperationsRouteEntryCause.corporateHubCard,
              repository: repository,
              lifecycleProvider: ids,
              onStateCreated: () => pageInstances++,
            ),
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: CorporateHubPage(
            userEmailProvider: () => null,
            riskOperationsRouteOpener: open,
          ),
        ),
      );
      observer.pushed.clear();
      final card = find.text('Risk ve Şüpheli Taramalar');
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(observer.pushed, hasLength(1));
      expect(observer.pushed.single.settings.name, '/risk-operations');
      expect(navigationIdsCreated, 1);
      expect(pageInstances, 1);
      expect(repository.calls, 1);
    },
  );

  testWidgets('rapid double card tap currently produces one route push', (
    tester,
  ) async {
    final observer = _Observer();
    var pushesRequested = 0;
    Future<void> open(BuildContext context) {
      pushesRequested++;
      return Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/risk-operations'),
          builder: (_) => const Scaffold(body: Text('risk route')),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: CorporateHubPage(
          userEmailProvider: () => null,
          riskOperationsRouteOpener: open,
        ),
      ),
    );
    observer.pushed.clear();
    final card = find.text('Risk ve Şüpheli Taramalar');
    await tester.ensureVisible(card);
    await tester.tap(card, warnIfMissed: false);
    await tester.tap(card, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(pushesRequested, 1);
    expect(observer.pushed, hasLength(1));
  });
}
