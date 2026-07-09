import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production asset registry has strategic responsive hero', () {
    final source = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_production_asset_registry_page.dart',
    ).readAsStringSync();

    expect(source, contains('const _ProductionAssetHero()'));
    expect(source, contains('class _ProductionAssetHero'));
    expect(source, contains('Kalıbı kontrol eden üretimi'));
    expect(source, contains('üretimi kontrol eden pazarı yönlendirir.'));
    expect(source, contains("'Fiziksel'"));
    expect(source, contains("'Dijital'"));
    expect(source, contains("'Hibrit'"));
    expect(source, contains('class _EquipmentBoard'));
    expect(source, contains("'Kalıp'"));
    expect(source, contains("'CAD/CAM'"));
    expect(source, contains("'3D Model'"));
    expect(source, contains("'PCB'"));
  });
}
