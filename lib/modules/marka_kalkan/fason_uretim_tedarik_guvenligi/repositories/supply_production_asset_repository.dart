import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/supply_production_asset_enums.dart';
import '../models/supply_production_asset_model.dart';
import 'supply_production_asset_command_service.dart';

class SupplyProductionAssetRepository {
  SupplyProductionAssetRepository({
    required this.tenantId,
    FirebaseFirestore? firestore,
    SupplyProductionAssetCommandService? commandService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _commandService =
           commandService ?? SupplyProductionAssetCommandService();

  static const String collectionName = 'supply_security_production_assets';

  final String tenantId;
  final FirebaseFirestore _firestore;
  final SupplyProductionAssetCommandService _commandService;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Future<String> create(SupplyProductionAssetModel asset) async {
    _validate(asset, requireId: false);
    return _commandService.create(asset);
  }

  Future<void> update(SupplyProductionAssetModel asset) async {
    _validate(asset, requireId: true);
    await _commandService.update(asset);
  }

  Future<SupplyProductionAssetModel?> getById(String assetId) async {
    final cleanedId = _requiredId(assetId, 'assetId');
    final snapshot = await _collection.doc(cleanedId).get();
    if (!snapshot.exists || snapshot.data() == null) return null;

    final asset = SupplyProductionAssetModel.fromDocument(snapshot);
    _validateTenant(asset.tenantId);
    return asset;
  }

  Future<List<SupplyProductionAssetModel>> listAll({
    SupplyProductionAssetClass? assetClass,
    SupplyProductionAssetType? assetType,
    SupplyProductionAssetStatus? status,
    String? partnerId,
    String? facilityId,
    int limit = 200,
  }) async {
    Query<Map<String, dynamic>> query = _collection.where(
      'tenantId',
      isEqualTo: tenantId,
    );

    if (assetClass != null) {
      query = query.where('assetClass', isEqualTo: assetClass.value);
    }
    if (assetType != null) {
      query = query.where('assetType', isEqualTo: assetType.value);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    final cleanedPartnerId = _cleanNullable(partnerId);
    if (cleanedPartnerId != null) {
      query = query.where('partnerId', isEqualTo: cleanedPartnerId);
    }

    final cleanedFacilityId = _cleanNullable(facilityId);
    if (cleanedFacilityId != null) {
      query = query.where('facilityId', isEqualTo: cleanedFacilityId);
    }

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .get();

    return snapshot.docs
        .map(SupplyProductionAssetModel.fromDocument)
        .toList(growable: false);
  }

  void _validate(SupplyProductionAssetModel asset, {required bool requireId}) {
    _validateTenant(asset.tenantId);

    if (asset.brandId.trim() != tenantId.trim()) {
      throw StateError(
        'Üretim varlığı brandId ile repository tenantId eşleşmiyor.',
      );
    }

    if (requireId) _requiredId(asset.id, 'assetId');
    _requiredId(asset.assetCode, 'assetCode');

    if (asset.name.trim().isEmpty || asset.name.trim().length > 200) {
      throw ArgumentError('Varlık adı 1-200 karakter olmalıdır.');
    }

    if (asset.description != null && asset.description!.trim().length > 5000) {
      throw ArgumentError('Açıklama 5000 karakteri aşamaz.');
    }

    if (asset.isArchived || asset.isDestroyed) {
      throw StateError(
        'Arşivlenmiş veya imha edilmiş varlık genel güncellemeye açılamaz.',
      );
    }
  }

  void _validateTenant(String value) {
    if (value.trim() != tenantId.trim()) {
      throw StateError(
        'Üretim varlığı tenantId ile repository tenantId eşleşmiyor.',
      );
    }
  }

  static String _requiredId(String value, String fieldName) {
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned.contains('/')) {
      throw ArgumentError.value(value, fieldName, '$fieldName geçersiz.');
    }
    return cleaned;
  }

  static int _validateLimit(int value) {
    if (value < 1 || value > 500) {
      throw RangeError.range(value, 1, 500, 'limit');
    }
    return value;
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
