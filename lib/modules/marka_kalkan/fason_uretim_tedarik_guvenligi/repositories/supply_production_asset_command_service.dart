import 'package:cloud_functions/cloud_functions.dart';

import '../models/supply_production_asset_model.dart';

class SupplyProductionAssetCommandService {
  SupplyProductionAssetCommandService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<String> create(SupplyProductionAssetModel asset) async {
    final response = await _functions
        .httpsCallable('createSupplyProductionAsset')
        .call<Map<String, dynamic>>(_payload(asset));

    final assetId = response.data['assetId'];
    if (assetId is! String || assetId.trim().isEmpty) {
      throw StateError('Üretim varlığı oluşturuldu ancak kimlik dönmedi.');
    }
    return assetId.trim();
  }

  Future<List<SupplyProductionAssetModel>> listAll() async {
    final response = await _functions
        .httpsCallable('listSupplyProductionAssets')
        .call<Map<String, dynamic>>();

    final rawAssets = response.data['assets'];
    if (rawAssets is! List) {
      throw StateError('Üretim varlığı listesi sunucudan alınamadı.');
    }

    return rawAssets
        .map((item) {
          if (item is! Map) {
            throw const FormatException(
              'Üretim varlığı kayıt biçimi geçersiz.',
            );
          }

          final data = Map<String, dynamic>.from(item);
          final id = data.remove('id')?.toString().trim() ?? '';
          if (id.isEmpty) {
            throw const FormatException('Üretim varlığı kimliği eksik.');
          }

          for (final field in <String>[
            'createdAt',
            'updatedAt',
            'destroyedAt',
            'archivedAt',
          ]) {
            final value = data[field];
            if (value is int) {
              data[field] = DateTime.fromMillisecondsSinceEpoch(value);
            }
          }

          return SupplyProductionAssetModel.fromMap(id: id, data: data);
        })
        .toList(growable: false);
  }

  Future<void> update(SupplyProductionAssetModel asset) async {
    final assetId = asset.id.trim();
    if (assetId.isEmpty) {
      throw ArgumentError.value(asset.id, 'asset.id', 'assetId boş olamaz.');
    }

    final payload = _payload(asset)..remove('assetCode');
    await _functions.httpsCallable('updateSupplyProductionAsset').call<void>(
      <String, dynamic>{'assetId': assetId, ...payload},
    );
  }

  static Map<String, dynamic> _payload(SupplyProductionAssetModel asset) {
    return <String, dynamic>{
      'assetCode': asset.assetCode.trim(),
      'name': asset.name.trim(),
      'assetClass': asset.assetClass.value,
      'assetType': asset.assetType.value,
      'partnerId': _cleanNullable(asset.partnerId),
      'facilityId': _cleanNullable(asset.facilityId),
      'description': _cleanNullable(asset.description),
      'manufacturer': _cleanNullable(asset.manufacturer),
      'modelNumber': _cleanNullable(asset.modelNumber),
      'serialNumber': _cleanNullable(asset.serialNumber),
      'internalReference': _cleanNullable(asset.internalReference),
      'physicalLocation': _cleanNullable(asset.physicalLocation),
      'digitalStorageReference': _cleanNullable(asset.digitalStorageReference),
      'version': _cleanNullable(asset.version),
      'fileHash': _cleanNullable(asset.fileHash),
      'confidentialityLevel': _cleanNullable(asset.confidentialityLevel),
      'relatedProductIds': List<String>.from(asset.relatedProductIds),
      'relatedIpAssetIds': List<String>.from(asset.relatedIpAssetIds),
      'evidenceDocumentIds': List<String>.from(asset.evidenceDocumentIds),
      'notes': _cleanNullable(asset.notes),
      'metadata': Map<String, dynamic>.from(asset.metadata),
    };
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
