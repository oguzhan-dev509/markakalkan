import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const routerPath = 'lib/app/router.dart';
  const marketPath =
      'lib/modules/marka_kalkan/dijital_pazar_izleme/'
      'presentation/dijital_pazar_izleme_sayfasi.dart';

  late String router;
  late String market;

  setUpAll(() {
    router = File(routerPath).readAsStringSync();
    market = File(marketPath).readAsStringSync();
  });

  test('router imports counterfeit twin registry page', () {
    expect(
      router,
      contains(
        'sahte_ikiz_sicili/presentation/'
        'counterfeit_twin_registry_page.dart',
      ),
    );
  });

  test('router exposes counterfeit twin registry navigation', () {
    expect(router, contains('openCounterfeitTwinRegistry'));
    expect(router, contains('const CounterfeitTwinRegistryPage()'));
  });

  test('digital market center exposes active registry card', () {
    expect(market, contains("title: 'Sahte İkiz Sicili'"));
    expect(market, contains("'Kalıcı savunma sicili'"));
    expect(market, contains('Icons.content_copy_outlined'));
    expect(market, contains('isActive: true'));
  });

  test('registry card opens through AppRouter', () {
    expect(market, contains('AppRouter.openCounterfeitTwinRegistry(context)'));
  });

  test('registry remains inside digital market center', () {
    expect(market, contains('Dijital Pazar İzleme Merkezi'));
    expect(market, contains('Sahte İkiz Sicili'));
  });
}
