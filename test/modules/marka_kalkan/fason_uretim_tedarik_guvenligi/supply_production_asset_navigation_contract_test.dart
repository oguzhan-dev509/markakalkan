import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String hub;
  setUpAll(
    () => hub = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/presentation/supply_security_hub_page.dart',
    ).readAsStringSync(),
  );
  test('hub opens production assets', () {
    expect(
      hub,
      contains("import 'supply_production_asset_registry_page.dart';"),
    );
    expect(hub, contains("'Üretim Varlıkları Sicili'"));
    expect(hub, contains('const SupplyProductionAssetRegistryPage()'));
  });
  test('hub badges', () {
    expect(hub, contains("'Fiziksel varlıklar'"));
    expect(hub, contains("'Dijital üretim dosyaları'"));
    expect(hub, contains("'Hibrit kayıtlar'"));
  });
}
