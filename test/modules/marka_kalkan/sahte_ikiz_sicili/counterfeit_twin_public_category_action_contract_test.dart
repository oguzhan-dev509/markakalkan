import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String radar;

  setUpAll(() {
    radar = File(
      'lib/modules/marka_kalkan/sahte_ikiz_sicili/presentation/'
      'counterfeit_twin_public_radar_page.dart',
    ).readAsStringSync();
  });

  test('every category card exposes an explicit action button', () {
    expect(
      radar,
      contains(r"'counterfeit-twin-category-action-${data.value}'"),
    );
    expect(radar, contains('onPressed: onTap'));
    expect(radar, contains("label: const Text('Karşılaştırmaları incele')"));
  });

  test('AI and robot category remains independently selectable', () {
    expect(radar, contains("value: 'ai_robot'"));
    expect(radar, contains('CounterfeitTwinPublicSection.aiRobot'));
    expect(radar, contains('onTap: () => _selectCategory(data.value)'));
  });

  test('whole card and explicit CTA share the same callback', () {
    expect(radar, contains('onTap: onTap'));
    expect(radar, contains('onPressed: onTap'));
  });
}
