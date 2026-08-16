import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Public Lite keeps sponsor area and uses compact legal footer only', () {
    final source = File(
      'lib/features/risk_scan/presentation/'
      'public_lite_sponsor_footer_section.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      'İş Ortaklarımız / Sponsorlarımız',
      'Markanızı korumak için güç birliği yapıyoruz',
      'Stratejik iş ortaklarımız ve sponsorlarımız, MarkaKalkan’ın',
      'Yalnızca doğrulanmış',
      'Sponsor alanı',
      'Tüm iş ortaklarımızı görüntüle',
      'Siz de burada yer almak ister misiniz?',
    ]) {
      expect(source, contains(marker));
    }

    expect(source, contains("Key('publicLiteCompactLegalFooter')"));
    expect(source, contains("label: 'MarkaKalkan yasal bağlantıları'"));
    expect(source, contains('color: _navyDeep'));
    expect(source, contains('width: 3'));

    for (final marker in <String>[
      'Kullanım koşulları',
      'Gizlilik politikası',
      'Çerez politikası',
      'KVKK Aydınlatma Metni',
      '© 2026 MarkaKalkan. Tüm hakları saklıdır.',
      'Türkçe',
    ]) {
      expect(source, contains(marker));
    }

    for (final removed in <String>[
      "'Platform'",
      "'Kaynaklar'",
      "'Şirket'",
      "'Yasal'",
      "'Güvenlik ve gizlilik yaklaşımı'",
      "'Güvenli tasarım'",
      "'Erişim ve veri minimizasyonu'",
      "'Gizlilik ilkeleri'",
      "'KVKK ve GDPR odaklı yaklaşım'",
      "'Sahte İkiz Radarı'",
      "'Yaratım Öncelik Sicili'",
      "'Resmî kurumlar'",
      "'Hakkımızda'",
      "'Kariyer'",
      "'Basın odası'",
      "'Blog'",
    ]) {
      expect(source, isNot(contains(removed)));
    }
  });

  test(
    'Public Lite page still integrates sponsor/footer section exactly once',
    () {
      final source = File(
        'lib/features/risk_scan/presentation/'
        'public_lite_risk_scan_preview_page.dart',
      ).readAsStringSync();

      expect(
        RegExp(
          r'const PublicLiteSponsorFooterSection\(\)',
        ).allMatches(source).length,
        1,
      );
      expect(source, contains('Marka ve resmî kaynak'));
    },
  );

  test('home hero remains outside this patch', () {
    final source = File(
      'lib/features/home/presentation/markakalkan_home_page.dart',
    ).readAsStringSync();

    expect(source, contains('Müşteriniz orijinalini bilsin,'));
    expect(source, contains('siz sahtesini görün.'));
  });
}
