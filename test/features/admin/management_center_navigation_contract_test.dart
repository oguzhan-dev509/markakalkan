import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Management center navigation contract', () {
    final routerSource = File('lib/app/router.dart').readAsStringSync();

    final hubSource = File(
      'lib/features/dashboard/presentation/corporate_hub_page.dart',
    ).readAsStringSync();

    final pageSource = File(
      'lib/features/admin/presentation/management_center_page.dart',
    ).readAsStringSync();

    test('router opens the management center page', () {
      expect(routerSource, contains('ManagementCenterPage'));
      expect(routerSource, contains('openManagementCenter'));
    });

    test('corporate hub exposes a dedicated management center card', () {
      expect(hubSource, contains("id: 'management_center'"));
      expect(hubSource, contains("title: 'MarkaKalkan Yönetim Merkezi'"));
      expect(hubSource, contains('AppRouter.openManagementCenter(context)'));
    });

    test('page gates access and shows both first management modules', () {
      expect(pageSource, contains('getMyAccess()'));
      expect(pageSource, contains('!access.isSuperAdmin'));
      expect(pageSource, contains("'Bu alana erişim yetkiniz bulunmuyor.'"));
      expect(pageSource, contains("'Marka Başvuruları'"));
      expect(pageSource, contains("'Sahte İkiz Radarı'"));
    });
  });
}
