import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  setUpAll(
    () => source = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/presentation/supply_production_asset_create_dialog.dart',
    ).readAsStringSync(),
  );
  test('loads inventories', () {
    expect(source, contains('partnerRepository.listAll(limit: 500)'));
    expect(source, contains('facilityRepository.listAll(limit: 500)'));
  });
  test('creates authenticated draft', () {
    expect(source, contains('tenantId: widget.user.uid'));
    expect(source, contains('brandId: widget.user.uid'));
    expect(source, contains('status: SupplyProductionAssetStatus.draft'));
    expect(source, contains('await widget.repository.create(asset)'));
  });
  test('no lifecycle controls', () {
    expect(source, isNot(contains('destroyedAt:')));
    expect(source, isNot(contains('archivedAt:')));
    expect(
      source,
      isNot(contains('DropdownButtonFormField<SupplyProductionAssetStatus>')),
    );
  });
}
