import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String home;
  late String router;
  late String corporate;
  late String publicPage;
  late String analysis;

  setUpAll(() {
    home = File(
      'lib/features/home/presentation/markakalkan_home_page.dart',
    ).readAsStringSync();
    router = File('lib/app/router.dart').readAsStringSync();
    corporate = File(
      'lib/features/dashboard/presentation/corporate_hub_page.dart',
    ).readAsStringSync();
    publicPage = File(
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
      'counterfeit_twin_public_radar_page.dart',
    ).readAsStringSync();
    analysis = File('analysis_options.yaml').readAsStringSync();
  });

  test('public home exposes the counterfeit twin radar', () {
    expect(home, contains('class _PublicRadarSection'));
    expect(home, contains('Gerçek Ürün – Sahte İkiz Karşılaştırmaları'));
    expect(home, contains('Karşılaştırmaları İncele'));
    expect(home, contains('Sahte İkiz Bildir'));
  });

  test('router opens public radar separately from private registry', () {
    expect(router, contains('openCounterfeitTwinRegistry'));
    expect(router, contains('openCounterfeitTwinPublicRadar'));
    expect(router, contains('CounterfeitTwinPublicRadarPage'));
  });

  test('corporate hub exposes a radar card', () {
    expect(corporate, contains("id: 'counterfeit_twin_radar'"));
    expect(corporate, contains("title: 'Sahte İkiz Radarı'"));
    expect(corporate, contains('openCounterfeitTwinPublicRadar'));
  });

  test('public page loads published comparisons', () {
    expect(publicPage, contains("'listPublicCounterfeitTwinComparisons'"));
    expect(publicPage, contains("data['comparisons']"));
    expect(publicPage, contains('CounterfeitTwinPublicDetail.fromMap'));
  });

  test('public report entry requires authentication', () {
    expect(publicPage, contains('final auth = FirebaseAuth.instance;'));
    expect(publicPage, contains('auth.currentUser == null'));
    expect(publicPage, contains('MarkaKalkanAuthIntent.counterfeitTwinReport'));
    expect(
      publicPage,
      contains('Bildirim formunu açmak için giriş işlemini tamamlayın.'),
    );
    expect(publicPage, contains('Bildirim için giriş gerekli'));
    expect(publicPage, contains('showCounterfeitTwinReportDialog'));
    expect(home, contains('FirebaseAuth.instance.currentUser'));
  });

  test('public radar covers product platform finance and robots', () {
    expect(publicPage, contains("'physical_product'"));
    expect(publicPage, contains("'saas_platform'"));
    expect(publicPage, contains("'financial_service'"));
    expect(publicPage, contains("'robotic_system'"));
    expect(publicPage, contains("'autonomous_ai_agent'"));
  });

  test('backup reports are excluded from analyzer', () {
    expect(analysis, contains('- backups/**'));
    expect(analysis, contains('- reports/**'));
  });
}
