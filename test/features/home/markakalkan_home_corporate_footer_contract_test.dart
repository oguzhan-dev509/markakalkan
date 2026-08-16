import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final homeSource = File(
    'lib/features/home/presentation/markakalkan_home_page.dart',
  ).readAsStringSync();

  test('home corporate footer preserves hero and sponsor ordering', () {
    expect(homeSource, contains('Müşteriniz orijinalini bilsin,'));
    expect(homeSource, contains('siz sahtesini görün.'));
    expect(homeSource, contains("label: const Text('Markanızı Koruyun')"));
    expect(homeSource, contains("label: const Text('Marka Dedektifi')"));

    final sponsorIndex = homeSource.indexOf(
      'SliverToBoxAdapter(child: HomePartnersSponsorSection())',
    );
    final footerIndex = homeSource.indexOf(
      'SliverToBoxAdapter(child: _Footer())',
    );

    expect(sponsorIndex, greaterThanOrEqualTo(0));
    expect(footerIndex, greaterThan(sponsorIndex));
  });

  test(
    'home corporate footer exposes the approved information architecture',
    () {
      for (final marker in <String>[
        "Key('homeCorporateFooter')",
        "Key('homeTrustSecurityPanel')",
        'Platform',
        'Kaynaklar',
        'Şirket',
        'Yasal',
        'Sahte İkiz Radarı',
        'Yaratım Öncelik Sicili',
        'Risk tarama hizmeti',
        'Tüm modüller',
        'Resmî kurumlar',
        'Kılavuzlar',
        'Sık sorulan sorular',
        'Blog',
        'Hakkımızda',
        'İletişim',
        'Kariyer',
        'Basın odası',
        'Kullanım koşulları',
        'Gizlilik politikası',
        'Çerez politikası',
        'KVKK Aydınlatma Metni',
        'Güvenlik ve gizlilik yaklaşımı',
        'Güvenli tasarım',
        'Erişim ve veri minimizasyonu',
        'Gizlilik ilkeleri',
        'KVKK ve GDPR odaklı yaklaşım',
        'Markanızı korumak, sahtecilikle mücadele etmek ve dijital ',
        'dünyada güvenliğinizi güçlendirmek için tasarlandı.',
        '© 2026 MarkaKalkan. Tüm hakları saklıdır.',
      ]) {
        expect(homeSource, contains(marker));
      }
    },
  );

  test(
    'footer navigation uses only three already-existing public router methods',
    () {
      final start = homeSource.indexOf(
        'class _Footer extends StatelessWidget {',
      );
      final end = homeSource.indexOf('class _FeatureData {');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final footerSource = homeSource.substring(start, end);

      expect(
        footerSource,
        contains('AppRouter.openCounterfeitTwinPublicRadar(context)'),
      );
      expect(
        footerSource,
        contains('AppRouter.openIpCreationPriorityRegistry(context)'),
      );
      expect(
        footerSource,
        contains('AppRouter.openPublicLiteRiskScan(context)'),
      );

      expect(RegExp(r'AppRouter\.').allMatches(footerSource).length, 3);
      expect(footerSource, isNot(contains('Navigator.of(context).push')));
      expect(footerSource, isNot(contains('MaterialPageRoute')));
    },
  );

  test(
    'footer design keeps controlled dark navy and blue accent treatment',
    () {
      expect(homeSource, contains('0xFF071B2C'));
      expect(homeSource, contains('0xFF102A43'));
      expect(homeSource, contains('0xFF2F80ED'));
      expect(homeSource, contains('width: 3'));
      expect(homeSource, contains('constraints.maxWidth < 860'));
    },
  );
}
