import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
      expect(hub, contains('AppRouter.openRiskOperationsConsole(context)'));
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
}
