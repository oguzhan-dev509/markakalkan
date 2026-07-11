import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final model = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/models/'
    'counterfeit_twin_public_contract.dart',
  ).readAsStringSync();

  final page = File(
    'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
    'counterfeit_twin_public_detail_page.dart',
  ).readAsStringSync();

  test('public contract decodes structured comparison metadata', () {
    expect(model, contains('CounterfeitTwinComparisonCodec.decode'));
    expect(model, contains('decodedComparison'));
  });

  test('public page renders a responsive three-column comparison', () {
    expect(page, contains('Gerçek–Sahte Karşılaştırma Tablosu'));
    expect(page, contains('Kontrol noktası'));
    expect(page, contains('Gerçek ürün / varlık'));
    expect(page, contains('Sahte / doğrulanmamış ürün'));
    expect(page, contains('_PublicComparisonTable'));
  });

  test('public page renders observed prices and their difference', () {
    expect(page, contains('Gerçek fiyat'));
    expect(page, contains('Sahte / şüpheli fiyat'));
    expect(page, contains('Fiyat farkı'));
    expect(page, contains('Fiyat tespit tarihi'));
    expect(page, contains('_priceComparisonText'));
  });

  test('public page renders image attribution without metadata leakage', () {
    expect(page, contains('Gerçek görsel kaynağı / atfı'));
    expect(page, contains('Şüpheli görsel kaynağı / atfı'));

    expect(
      RegExp(
        r'detail\s*'
        r'\.decodedComparison\s*'
        r'\.legacyNotes\s*'
        r'\.isNotEmpty',
        multiLine: true,
      ).hasMatch(page),
      isTrue,
    );

    expect(
      RegExp(
        r'detail\s*'
        r'\.decodedComparison\s*'
        r'\.legacyNotes\s*'
        r'\.map',
        multiLine: true,
      ).hasMatch(page),
      isTrue,
    );
  });

  test('legacy public records remain valid without extended evidence', () {
    expect(page, contains('if (!_hasExtendedEvidence(detail))'));
    expect(page, contains('return const SizedBox.shrink();'));
  });
}
