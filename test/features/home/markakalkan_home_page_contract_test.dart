import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final homeSource = File(
    'lib/features/home/presentation/markakalkan_home_page.dart',
  ).readAsStringSync();

  test(
    'hero slogan, approved supporting copy, and hero actions are preserved',
    () {
      expect(homeSource, contains('Müşteriniz orijinalini bilsin,'));
      expect(homeSource, contains('siz sahtesini görün.'));
      expect(
        homeSource,
        contains('Riskleri bulun, delilleri koruyun, vakaya dönüştürün '),
      );
      expect(homeSource, contains('ve sonuca kadar yönetin.'));
      expect(homeSource, contains("label: const Text('Markanızı Koruyun')"));
      expect(homeSource, contains("label: const Text('Marka Dedektifi')"));
    },
  );

  test(
    'guided intent and mobile verification keep the approved top order',
    () {
      const heroMarker = 'SliverToBoxAdapter(child: _HeroSection())';
      const intentMarker =
          'SliverToBoxAdapter(child: _ProtectionIntentSection())';
      const mobileVerificationMarker =
          'SliverToBoxAdapter(child: _MobileVerificationSection())';
      const radarMarker = 'SliverToBoxAdapter(child: _PublicRadarSection())';

      final heroIndex = homeSource.indexOf(heroMarker);
      final intentIndex = homeSource.indexOf(intentMarker);
      final mobileVerificationIndex =
          homeSource.indexOf(mobileVerificationMarker);
      final radarIndex = homeSource.indexOf(radarMarker);

      expect(heroIndex, greaterThanOrEqualTo(0));
      expect(intentIndex, greaterThan(heroIndex));
      expect(mobileVerificationIndex, greaterThan(intentIndex));
      expect(radarIndex, greaterThan(mobileVerificationIndex));
      expect(
        homeSource.substring(heroIndex, radarIndex),
        contains(mobileVerificationMarker),
      );
      expect(homeSource, contains('Gerçek Ürün – Sahte İkiz Karşılaştırmaları'));
    },
  );

  test('mobile hero is compact and defers the verification card', () {
    final heroStart = homeSource.indexOf('class _HeroSection');
    final heroEnd = homeSource.indexOf('class _HeroLabel');
    expect(heroStart, greaterThanOrEqualTo(0));
    expect(heroEnd, greaterThan(heroStart));

    final heroSource = homeSource.substring(heroStart, heroEnd);
    expect(
      heroSource,
      contains('final compact = MediaQuery.sizeOf(context).width < 820;'),
    );
    expect(heroSource, contains('horizontal: compact ? 24 : 28'));
    expect(heroSource, contains('vertical: compact ? 40 : 72'));
    expect(heroSource, contains('fontSize: compact ? 34 : 46'));
    expect(heroSource, contains('height: compact ? 1.08 : 1.12'));
    expect(heroSource, contains('if (isNarrow) {'));
    expect(heroSource, contains('return introduction;'));
    expect(
      heroSource,
      contains('const Expanded(flex: 4, child: verificationCard)'),
    );
    expect(heroSource, contains("label: const Text('Markanızı Koruyun')"));
    expect(heroSource, contains("label: const Text('Marka Dedektifi')"));
  });

  test('mobile verification restores the existing verifier after intent', () {
    final start = homeSource.indexOf('class _MobileVerificationSection');
    final end = homeSource.indexOf('class _ProtectionIntentSection');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final source = homeSource.substring(start, end);
    expect(source, contains('if (constraints.maxWidth >= 820)'));
    expect(source, contains('return const SizedBox.shrink();'));
    expect(source, contains('child: const _VerificationCard()'));
    expect(source, contains('Color(0xFFF7FAFC)'));
  });

  test('MK-UX-HOME-1 exposes the eight approved user-purpose cards', () {
    final intentStart = homeSource.indexOf('class _ProtectionIntentSection');
    final radarStart = homeSource.indexOf('class _PublicRadarSection');
    expect(intentStart, greaterThanOrEqualTo(0));
    expect(radarStart, greaterThan(intentStart));

    final intentSource = homeSource.substring(intentStart, radarStart);

    expect(
      intentSource,
      contains('Markanızı bugün neye karşı korumak istiyorsunuz?'),
    );
    expect(
      intentSource,
      contains('İhtiyacınızı seçin; MarkaKalkan size doğru yolu göstersin.'),
    );

    const cards = <String, String>{
      'Sahte ürün': 'Ürününüze benzeyen şüpheli satışları bulun.',
      'Sahte hesap': 'Markanızı taklit eden hesapları inceleyin.',
      'Taklit web sitesi': 'Markanızı kullanan şüpheli siteleri bulun.',
      'İzinsiz satıcı': 'Yetkisiz ve tekrar eden satışları takip edin.',
      'Korsan içerik':
          'İzinsiz kullanılan içerikleri ve dijital varlıkları bulun.',
      'Üretim ve tedarik riski':
          'Üretici, tesis ve tedarik zinciri risklerini yönetin.',
      'Gümrük riski':
          'Sahte ürünlere karşı sınır ve gümrük seçeneklerini değerlendirin.',
      'Marka ihlali': 'Delil, vaka ve müdahale seçeneklerine geçin.',
    };

    for (final entry in cards.entries) {
      expect(intentSource, contains("title: '${entry.key}'"));
      expect(intentSource, contains("'${entry.value}'"));
    }

    expect('_ProtectionIntentData('.allMatches(intentSource).length, 9);
  });

  test('purpose-card selection is guidance-only and starts no operation', () {
    final intentStart = homeSource.indexOf('class _ProtectionIntentSection');
    final radarStart = homeSource.indexOf('class _PublicRadarSection');
    final intentSource = homeSource.substring(intentStart, radarStart);

    expect(intentSource, contains('showModalBottomSheet<void>'));
    expect(
      intentSource,
      contains('Bu seçim yalnızca size doğru yolu gösterir; tarama veya '),
    );
    expect(intentSource, contains('başka bir işlem başlatmaz.'));

    for (final forbidden in <String>[
      'AppRouter.',
      'FirebaseFunctions',
      'httpsCallable',
      'startPublicLiteRiskScan',
      'n8n',
      'tenantId',
      'matterScopeCode',
      'countryCode',
    ]) {
      expect(intentSource, isNot(contains(forbidden)));
    }
  });

  test(
    'Sahte ürün guidance explains AI value without auto-starting a scan',
    () {
      final intentStart = homeSource.indexOf('class _ProtectionIntentSection');
      final radarStart = homeSource.indexOf('class _PublicRadarSection');
      final intentSource = homeSource.substring(intentStart, radarStart);

      expect(intentSource, contains('Sahte ürünleri bulmak istiyorsunuz'));
      expect(
        intentSource,
        contains(
          'MarkaKalkan’ın 12 Yapay Zekâ Ajanı dijital kaynaklarda şüpheli ',
        ),
      );
      expect(intentSource, contains("'Markanızı seçin'"));
      expect(intentSource, contains("'Mevcut sonuçları inceleyin'"));
      expect(intentSource, contains("'Gerekirse yeni tarama başlatın'"));
    },
  );

  test('intent cards use four-two-one responsive columns', () {
    final intentStart = homeSource.indexOf('class _ProtectionIntentSection');
    final radarStart = homeSource.indexOf('class _PublicRadarSection');
    final intentSource = homeSource.substring(intentStart, radarStart);

    expect(
      intentSource,
      contains('final columns = width >= 1040 ? 4 : (width >= 620 ? 2 : 1);'),
    );
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

  test('HRT public acquisition section is visible after the radar', () {
    expect(homeSource, contains('class _PublicRiskScanSection'));
    expect(
      homeSource,
      contains('SliverToBoxAdapter(child: _PublicRiskScanSection())'),
    );
    expect(homeSource, contains('ÜCRETSİZ HIZLI RİSK TARAMASI'));
    expect(homeSource, contains('Markamı Ücretsiz Tara'));
    expect(homeSource, contains('AppRouter.openPublicLiteRiskScan(context)'));
    expect(homeSource, isNot(contains('openPublicLiteRiskScanPreview')));
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

  test('MK-UX-HOME-2 guidance stays pure and CTA routing is navigation-only', () {
    final source = File(
      'lib/features/home/presentation/markakalkan_home_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    const startMarker =
        'class _ProtectionIntentSection extends StatelessWidget {';
    const endMarker = 'class _PublicRadarSection extends StatelessWidget {';
    final start = source.indexOf(startMarker);
    final end = source.indexOf(endMarker);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final block = source.substring(start, end);

    const mappings = <String>[
      "code: 'counterfeit_product',\n"
          "      ctaLabel: 'Dijital Dedektife geç',\n"
          '      destination: _ProtectionIntentDestination.brandDetective,',
      "code: 'fake_account',\n"
          "      ctaLabel: 'Dijital Dedektife geç',\n"
          '      destination: _ProtectionIntentDestination.brandDetective,',
      "code: 'fake_website',\n"
          "      ctaLabel: 'Dijital Dedektife geç',\n"
          '      destination: _ProtectionIntentDestination.brandDetective,',
      "code: 'unauthorized_seller',\n"
          "      ctaLabel: 'Satıcı takibine geç',\n"
          '      destination: '
          '_ProtectionIntentDestination.digitalMarketMonitoring,',
      "code: 'pirated_content',\n"
          "      ctaLabel: 'Dijital Dedektife geç',\n"
          '      destination: '
          '_ProtectionIntentDestination.digitalDetectiveTasks,',
      "code: 'supply_risk',\n"
          "      ctaLabel: 'Tedarik güvenliğine geç',\n"
          '      destination: _ProtectionIntentDestination.supplySecurity,',
      "code: 'customs_risk',\n"
          "      ctaLabel: 'Gümrük güvenliğine geç',\n"
          '      destination: _ProtectionIntentDestination.customsSecurity,',
      "code: 'trademark_infringement',\n"
          "      ctaLabel: 'Müdahale seçeneklerini incele',\n"
          '      destination: '
          '_ProtectionIntentDestination.interventionLegal,',
    ];

    for (final mapping in mappings) {
      expect(block, contains(mapping));
    }

    const safeRoutes = <String>[
      'AppRouter.openBrandDetectiveHub(context)',
      'AppRouter.openDijitalPazarIzleme(context)',
      'AppRouter.openDigitalDetectiveTasks(context)',
      'AppRouter.openSupplySecurityHub(context)',
      'AppRouter.openCustomsSecurityHub(context)',
      'AppRouter.openInterventionLegalHub(context)',
    ];
    for (final route in safeRoutes) {
      expect(source, contains(route));
    }

    expect(
      source,
      contains('Future<void> _openProtectionIntentDestination('),
    );
    expect(block, isNot(contains('AppRouter.')));
    expect(
      block,
      contains(
        'onContinue: () => '
        '_openProtectionIntentDestination(context, intent),',
      ),
    );

    expect(
      block,
      contains("onTap: () => _openGuidance(context, intent),"),
    );
    expect(block, contains('showModalBottomSheet<void>'));
    expect(
      block,
      contains("key: Key('homeIntentContinue_\${intent.code}')"),
    );
    expect(block, contains('Navigator.of(context).pop();'));
    expect(block, contains('await onContinue();'));
    expect(
      block,
      contains(
        'Bu seçim yalnızca size doğru yolu gösterir; tarama veya ',
      ),
    );
    expect(block, contains('başka bir işlem başlatmaz.'));

    const forbidden = <String>[
      'httpsCallable',
      'FirebaseFunctions',
      'startPublicLiteRiskScan',
      'openPublicLiteRiskScan',
      'n8n',
      'createInterventionLegalMatter',
      'createCustomsBorderIntervention',
      'createCustomsProtectionProfile',
      'recordExternalSubmission',
      'recordAuthorityOutcome',
      'createAndActivate',
      'AppRouter.openDigitalDetectiveFindings',
    ];
    for (final marker in forbidden) {
      expect(block, isNot(contains(marker)));
    }
  });
}
