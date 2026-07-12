import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final homeSource = File(
    'lib/features/home/presentation/markakalkan_home_page.dart',
  ).readAsStringSync();

  test('hero slogan and existing hero actions are preserved', () {
    expect(homeSource, contains('Müşteriniz orijinalini bilsin,'));
    expect(homeSource, contains('siz sahtesini görün.'));
    expect(homeSource, contains("label: const Text('Markanızı Koruyun')"));
    expect(homeSource, contains("label: const Text('Marka Dedektifi')"));
  });

  test('public radar showcase remains directly below the hero', () {
    expect(homeSource, contains('SliverToBoxAdapter(child: _HeroSection())'));
    expect(
      homeSource,
      contains('SliverToBoxAdapter(child: _PublicRadarSection())'),
    );
    expect(homeSource, contains('Gerçek Ürün – Sahte İkiz Karşılaştırmaları'));
  });

  test('ANA-1A introduces three high-impact homepage sections', () {
    expect(homeSource, contains('class _PublicServicesSection'));
    expect(homeSource, contains('class _AiFieldDetectivesShowcase'));
    expect(homeSource, contains('class _DefenseChainSection'));
    expect(homeSource, contains('Koruma, doğrulama ve kayıt tek kapıda'));
    expect(homeSource, contains('12 uzman yapay zekâ dedektifi,'));
    expect(homeSource, contains('markanız için aynı operasyonda çalışır.'));
    expect(
      homeSource,
      contains('Birbirinden kopuk araçlar değil, yaşayan bir savunma sistemi'),
    );
  });

  test('public service cards use existing safe router methods', () {
    expect(
      homeSource,
      contains('AppRouter.openCounterfeitTwinPublicRadar(context)'),
    );
    expect(
      homeSource,
      contains('AppRouter.openIpCreationPriorityRegistry(context)'),
    );
    expect(homeSource, contains('AppRouter.openProductVerification(context)'));
  });

  test('AI showcase links to the existing detectives hub', () {
    expect(homeSource, contains('AppRouter.openAiFieldDetectivesHub(context)'));
    expect(homeSource, contains('Dedektifleri Keşfet'));
    expect(homeSource, contains('Markanız İçin Görev Başlat'));
  });

  test('ANA-1B exposes five visual solution families', () {
    expect(homeSource, contains('HomeSolutionFamiliesSection'));
    final sectionSource = File(
      'lib/features/home/presentation/widgets/'
      'home_solution_families_section.dart',
    ).readAsStringSync();
    expect(sectionSource, contains('Fikri Varlık Savunması'));
    expect(sectionSource, contains('Dijital Tehdit İstihbaratı'));
    expect(sectionSource, contains('Sahtecilik ve Klon Savunması'));
    expect(sectionSource, contains('Üretim ve Tedarik Güvenliği'));
    expect(sectionSource, contains('Ürün Kimliği ve Doğrulama'));
    expect(sectionSource, contains('MouseRegion'));
    expect(sectionSource, contains('AnimatedContainer'));
  });

  test('ANA-1C applies the final dark visual theme foundation', () {
    final solutionSource = File(
      'lib/features/home/presentation/widgets/'
      'home_solution_families_section.dart',
    ).readAsStringSync();

    expect(homeSource, contains('backgroundColor: const Color(0xFF061722)'));
    expect(solutionSource, contains('Color(0xFF061722)'));
    expect(solutionSource, contains('Color(0xFF0A2533)'));
    expect(solutionSource, contains('Color(0xFF101A3A)'));
    expect(solutionSource, contains('Color(0xFFF0BD5B)'));
    expect(solutionSource, contains('color: Colors.white'));
    expect(solutionSource, contains('Color(0xFFC7D6DD)'));
  });

  test('ANA-1D adds isolated sponsor and partner network sections', () {
    final partnerSource = File(
      'lib/features/home/presentation/widgets/'
      'home_partners_sponsor_section.dart',
    ).readAsStringSync();

    expect(homeSource, contains('HomePartnersSponsorSection()'));
    expect(partnerSource, contains('SPONSORLU ALAN'));
    expect(partnerSource, contains('İŞ ORTAKLIĞI AĞI'));
    expect(partnerSource, contains('Gerçek iş ortakları'));
    expect(partnerSource, contains('Kurumsal İş Birliği'));
    expect(partnerSource, contains('İş Ortağı Olun'));
    expect(partnerSource, isNot(contains('AWS')));
    expect(partnerSource, isNot(contains('Microsoft')));
    expect(partnerSource, isNot(contains('Google Cloud')));
  });

  test('advertising and partner placeholders are not mixed into ANA-1A', () {
    expect(homeSource, isNot(contains('GoogleMobileAds')));
    expect(homeSource, isNot(contains('AdWidget')));
    expect(homeSource, isNot(contains('partnerLogoUrl')));
  });
}
