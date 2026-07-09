import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production asset rules allow tenant reads and deny client writes', () {
    final rules = File('firestore.rules').readAsStringSync();
    const marker =
        'match /supply_security_production_assets/{productionAssetId}';
    final start = rules.indexOf(marker);
    expect(start, greaterThanOrEqualTo(0));

    final end = rules.indexOf('\n    }', start);
    final block = rules.substring(start, end + 6);
    expect(block, contains('resource.data.tenantId == request.auth.uid'));
    expect(block, contains('allow create, update, delete: if false;'));
  });

  test('functions index exports production asset callables', () {
    final index = File('functions/index.js').readAsStringSync();
    expect(index, contains('buildCreateSupplyProductionAsset'));
    expect(index, contains('buildUpdateSupplyProductionAsset'));
    expect(index, contains('exports.createSupplyProductionAsset'));
    expect(index, contains('exports.updateSupplyProductionAsset'));
  });
}
