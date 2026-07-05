import '../constants/ip_enums.dart';
import '../models/ip_asset_inventory_filter.dart';
import '../models/ip_asset_inventory_summary.dart';
import '../models/ip_asset_model.dart';
import '../repositories/ip_asset_repository.dart';
import '../repositories/ip_repository_ports.dart';

class IpAssetInventoryService {
  IpAssetInventoryService({
    required String tenantId,
    required IpAssetRepositoryPort repository,
    DateTime Function()? clock,
  }) : _tenantId = _validateRequiredId(tenantId, fieldName: 'tenantId'),
       _repository = repository,
       _clock = clock ?? DateTime.now;

  factory IpAssetInventoryService.instance({required String tenantId}) {
    final cleanedTenantId = _validateRequiredId(
      tenantId,
      fieldName: 'tenantId',
    );

    return IpAssetInventoryService(
      tenantId: cleanedTenantId,
      repository: IpAssetRepository.instance(tenantId: cleanedTenantId),
    );
  }

  final String _tenantId;
  final IpAssetRepositoryPort _repository;
  final DateTime Function() _clock;

  String get tenantId => _tenantId;

  Stream<IpAssetInventorySnapshot> watchInventory({
    IpAssetInventoryFilter filter = const IpAssetInventoryFilter(),
  }) {
    final normalizedFilter = filter.normalized();

    return _repository
        .watchAll(brandId: normalizedFilter.brandId, limit: 500)
        .map(
          (assets) => _buildSnapshot(assets: assets, filter: normalizedFilter),
        );
  }

  Future<IpAssetInventorySnapshot> loadInventory({
    IpAssetInventoryFilter filter = const IpAssetInventoryFilter(),
  }) async {
    final normalizedFilter = filter.normalized();

    final assets = await _repository.listAll(
      brandId: normalizedFilter.brandId,
      limit: 500,
    );

    return _buildSnapshot(assets: assets, filter: normalizedFilter);
  }

  Future<IpAssetModel?> getById(String assetId) async {
    final asset = await _repository.getById(
      _validateRequiredId(assetId, fieldName: 'assetId'),
    );

    if (asset != null) {
      _validateOwnedAsset(asset);
    }

    return asset;
  }

  Future<IpAssetModel?> findByAssetCode({
    required String brandId,
    required String assetCode,
  }) async {
    final asset = await _repository.findByAssetCode(
      brandId: _validateRequiredId(brandId, fieldName: 'brandId'),
      assetCode: _validateRequiredText(assetCode, fieldName: 'assetCode'),
    );

    if (asset != null) {
      _validateOwnedAsset(asset);
    }

    return asset;
  }

  Future<String> createAsset(IpAssetModel asset) async {
    _validateOwnedAsset(asset);

    if (!asset.hasCompleteIdentity) {
      throw StateError(
        'Fikri varlığın tenant, marka, kod ve başlık bilgileri '
        'eksiksiz olmalıdır.',
      );
    }

    return _repository.create(asset);
  }

  Future<void> updateAsset(IpAssetModel asset) async {
    _validateOwnedAsset(asset);

    if (asset.id.trim().isEmpty) {
      throw ArgumentError.value(
        asset.id,
        'asset.id',
        'Güncellenecek varlığın kimliği boş olamaz.',
      );
    }

    await _repository.update(asset);
  }

  Future<void> updateStatus({
    required String assetId,
    required IpAssetStatus status,
    required String actorId,
  }) {
    return _repository.updateStatus(
      assetId: _validateRequiredId(assetId, fieldName: 'assetId'),
      status: status,
      updatedBy: _validateRequiredId(actorId, fieldName: 'actorId'),
    );
  }

  Future<void> updateScores({
    required String assetId,
    required int rightStrengthScore,
    required int secretSecurityScore,
    required int responseReadinessScore,
    required int resilienceScore,
    required String actorId,
  }) {
    return _repository.updateScores(
      assetId: _validateRequiredId(assetId, fieldName: 'assetId'),
      rightStrengthScore: rightStrengthScore,
      secretSecurityScore: secretSecurityScore,
      responseReadinessScore: responseReadinessScore,
      resilienceScore: resilienceScore,
      updatedBy: _validateRequiredId(actorId, fieldName: 'actorId'),
    );
  }

  Future<void> deleteAsset(String assetId) async {
    final cleanedAssetId = _validateRequiredId(assetId, fieldName: 'assetId');

    final asset = await _repository.getById(cleanedAssetId);

    if (asset == null) {
      return;
    }

    _validateOwnedAsset(asset);

    if (asset.rightIds.isNotEmpty ||
        asset.documentIds.isNotEmpty ||
        asset.relationshipIds.isNotEmpty ||
        asset.monitoringProfileIds.isNotEmpty) {
      throw StateError(
        'Hak, belge, ilişki veya izleme bağlantısı bulunan fikri '
        'varlık kalıcı olarak silinemez. Kaydı arşivleyin.',
      );
    }

    await _repository.delete(cleanedAssetId);
  }

  Future<List<IpAssetModel>> loadProtectionGaps({
    String? brandId,
    int limit = 200,
  }) async {
    final assets = await _repository.listProtectionGaps(
      brandId: _cleanOptionalId(brandId),
      limit: limit,
    );

    _validateOwnedAssets(assets);

    return List<IpAssetModel>.unmodifiable(assets);
  }

  Future<List<IpAssetModel>> loadImmediateAttention({
    String? brandId,
    int limit = 200,
  }) async {
    final assets = await _repository.listImmediateAttention(
      brandId: _cleanOptionalId(brandId),
      limit: limit,
    );

    _validateOwnedAssets(assets);

    return List<IpAssetModel>.unmodifiable(assets);
  }

  IpAssetInventorySnapshot _buildSnapshot({
    required List<IpAssetModel> assets,
    required IpAssetInventoryFilter filter,
  }) {
    _validateOwnedAssets(assets);

    final immutableAssets = List<IpAssetModel>.unmodifiable(assets);
    final summary = IpAssetInventorySummary.fromAssets(immutableAssets);

    return IpAssetInventorySnapshot(
      assets: filter.apply(immutableAssets),
      summary: summary,
      filter: filter,
      generatedAt: _clock(),
    );
  }

  void _validateOwnedAssets(Iterable<IpAssetModel> assets) {
    for (final asset in assets) {
      _validateOwnedAsset(asset);
    }
  }

  void _validateOwnedAsset(IpAssetModel asset) {
    if (asset.tenantId.trim() != _tenantId) {
      throw StateError('Fikri varlık farklı tenant hesabına ait: ${asset.id}');
    }
  }

  static String _validateRequiredId(String value, {required String fieldName}) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    if (cleaned.contains('/')) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName "/" karakteri içeremez.',
      );
    }

    return cleaned;
  }

  static String _validateRequiredText(
    String value, {
    required String fieldName,
  }) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName boş olamaz.');
    }

    return cleaned;
  }

  static String? _cleanOptionalId(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return _validateRequiredId(cleaned, fieldName: 'brandId');
  }
}
