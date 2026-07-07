import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String router;
  late String corporateHub;
  late String moduleHub;

  setUpAll(() {
    router = File('lib/app/router.dart').readAsStringSync();
    corporateHub = File(
      'lib/features/dashboard/presentation/corporate_hub_page.dart',
    ).readAsStringSync();
    moduleHub = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_security_hub_page.dart',
    ).readAsStringSync();
  });

  group('Supply security UI navigation contract', () {
    test('router yönetim merkezini açar', () {
      expect(router, contains('openSupplySecurityHub'));
      expect(router, contains('SupplySecurityHubPage'));
    });

    test('kurumsal merkez kartı aktif ve yönlendirilmiştir', () {
      expect(corporateHub, contains("id: 'supply_security'"));
      expect(corporateHub, contains("case 'supply_security':"));
      expect(
        corporateHub,
        contains('AppRouter.openSupplySecurityHub(context)'),
      );
    });

    test('ana ekran iki sicil merkezini görünür kılar', () {
      expect(moduleHub, contains('Fason Üretici ve Tedarikçi Sicili'));
      expect(moduleHub, contains('Tesis, Depo ve Üretim Noktası Sicili'));
      expect(moduleHub, contains('SupplyPartnerRegistryPage'));
      expect(moduleHub, contains('SupplyFacilityRegistryPage'));
    });

    test('temel savunma ilkesi ekranda yer alır', () {
      expect(
        moduleHub,
        contains('Sahte ürünle mücadele satış noktasında değil,'),
      );
      expect(
        moduleHub,
        contains('üretim emri ve tedarik zincirinin başladığı yerde'),
      );
    });
  });
}
