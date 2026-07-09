import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  setUpAll(
    () => source = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/presentation/supply_production_asset_registry_page.dart',
    ).readAsStringSync(),
  );
  test('authenticated tenant callable list', () {
    expect(source, contains('FirebaseAuth.instance.currentUser'));
    expect(
      source,
      contains('SupplyProductionAssetRepository(tenantId: user.uid)'),
    );
    expect(source, contains('FutureBuilder<List<SupplyProductionAssetModel>>'));
    expect(source, contains('future: repository.listAllFromServer()'));
    expect(source, isNot(contains('stream: repository.watchAll()')));
  });
  test('filters and metrics', () {
    expect(source, contains('SupplyProductionAssetClass? _classFilter'));
    expect(source, contains('SupplyProductionAssetType? _typeFilter'));
    expect(source, contains('SupplyProductionAssetStatus? _statusFilter'));
    expect(source, contains("labelText: 'Ara'"));
    expect(source, contains("'Fiziksel'"));
    expect(source, contains("'Dijital'"));
    expect(source, contains("'Hibrit'"));
  });
  test('create action', () {
    expect(source, contains('showSupplyProductionAssetCreateDialog('));
    expect(source, contains("'Yeni Varlık'"));
  });
}
