import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String radar;

  setUpAll(() {
    radar = File(
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
      'counterfeit_twin_public_radar_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('empty public category state uses natural sliver height', () {
    final match = RegExp(
      r'else if \(_visibleComparisons\.isEmpty\)'
      r'([\s\S]*?)'
      r'\n\s*else\n\s*SliverPadding\(',
    ).firstMatch(radar);

    expect(match, isNotNull);

    final emptyStateBlock = match!.group(1)!;
    expect(emptyStateBlock, contains('SliverToBoxAdapter('));
    expect(emptyStateBlock, isNot(contains('SliverFillRemaining(')));
  });

  test('empty state keeps the shared report action', () {
    expect(radar, contains('onReport: _openReport'));
    expect(radar, contains("label: const Text('Sahte İkiz Bildir')"));
  });

  test('empty state reserves safe space above the floating action', () {
    expect(
      radar,
      contains('padding: const EdgeInsets.fromLTRB(24, 24, 24, 120)'),
    );
  });
}
