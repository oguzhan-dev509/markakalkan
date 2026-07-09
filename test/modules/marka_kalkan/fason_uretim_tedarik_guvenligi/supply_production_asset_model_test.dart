import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/constants/supply_production_asset_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fason_uretim_tedarik_guvenligi/models/supply_production_asset_model.dart';

void main() {
  SupplyProductionAssetModel buildModel() {
    return SupplyProductionAssetModel(
      id: 'asset-1',
      tenantId: 'tenant-1',
      brandId: 'tenant-1',
      assetCode: ' kalip-001 ',
      name: 'Kapak Enjeksiyon Kalıbı',
      assetClass: SupplyProductionAssetClass.physical,
      assetType: SupplyProductionAssetType.injectionMold,
      status: SupplyProductionAssetStatus.draft,
      relatedProductIds: const <String>['urun-1', 'urun-1', 'urun-2'],
      createdAt: DateTime.utc(2026, 7, 9),
      createdBy: 'tenant-1',
    );
  }

  test('normalizes code and cleans repeated ids', () {
    final model = buildModel();
    final map = model.toMap();
    expect(model.normalizedAssetCode, 'KALIP-001');
    expect(map['relatedProductIds'], <String>['urun-1', 'urun-2']);
  });

  test('update map excludes immutable and lifecycle fields', () {
    final map = buildModel().toUpdateMap(actorId: 'tenant-1');
    for (final key in <String>[
      'tenantId',
      'brandId',
      'assetCode',
      'assetCodeNormalized',
      'status',
      'destroyedAt',
      'destroyedBy',
      'destructionReason',
      'destructionEvidenceDocumentIds',
      'archivedAt',
      'archivedBy',
      'archiveReason',
      'createdAt',
      'createdBy',
    ]) {
      expect(map.containsKey(key), isFalse, reason: key);
    }
    expect(map['updatedAt'], isA<FieldValue>());
    expect(map['updatedBy'], 'tenant-1');
  });
}
