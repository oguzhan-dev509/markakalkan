import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production asset list uses callable server authority', () {
    final functionSource = File(
      'functions/supply_security/production_assets.js',
    ).readAsStringSync();
    final indexSource = File('functions/index.js').readAsStringSync();
    final commandSource = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'repositories/supply_production_asset_command_service.dart',
    ).readAsStringSync();
    final repositorySource = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'repositories/supply_production_asset_repository.dart',
    ).readAsStringSync();
    final registrySource = File(
      'lib/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/'
      'presentation/supply_production_asset_registry_page.dart',
    ).readAsStringSync();

    expect(functionSource, contains('buildListSupplyProductionAssets'));
    expect(indexSource, contains('exports.listSupplyProductionAssets'));
    expect(
      commandSource,
      contains("httpsCallable('listSupplyProductionAssets')"),
    );
    expect(repositorySource, contains('listAllFromServer'));
    expect(
      repositorySource,
      isNot(contains('Stream<List<SupplyProductionAssetModel>> watchAll')),
    );
    expect(
      registrySource,
      contains('FutureBuilder<List<SupplyProductionAssetModel>>'),
    );
    expect(registrySource, contains('future: repository.listAllFromServer()'));
  });
}
