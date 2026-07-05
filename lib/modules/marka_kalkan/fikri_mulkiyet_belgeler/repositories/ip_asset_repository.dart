import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../models/ip_asset_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_repository_ports.dart';

class IpAssetRepository implements IpAssetRepositoryPort {
  const IpAssetRepository({required IpFirestoreRefs refs}) : _refs = refs;

  factory IpAssetRepository.instance({required String tenantId}) {
    return IpAssetRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpFirestoreRefs _refs;

  @override
  Future<String> create(IpAssetModel asset) async {
    _validateTenant(asset.tenantId);
    _validateAsset(asset);

    final existing = await findByAssetCode(
      brandId: asset.brandId,
      assetCode: asset.assetCode,
    );

    if (existing != null && existing.id != asset.id.trim()) {
      throw StateError(
        'Bu varlık kodu seçilen marka için zaten kullanılıyor: '
        '${asset.assetCode}',
      );
    }

    if (asset.id.trim().isNotEmpty) {
      final document = _refs.assetDocument(asset.id);
      final snapshot = await document.get();

      if (snapshot.exists) {
        throw StateError(
          'Aynı kimlikle bir fikri varlık zaten mevcut: ${asset.id}',
        );
      }

      await document.set(asset.toCreateMap());

      return document.id;
    }

    final document = _refs.assets.doc();

    await document.set(asset.toCreateMap());

    return document.id;
  }

  @override
  Future<void> update(IpAssetModel asset) async {
    _validateTenant(asset.tenantId);
    _validateAsset(asset);

    final assetId = _validateRequiredId(asset.id, fieldName: 'assetId');

    final document = _refs.assetDocument(assetId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Güncellenecek fikri varlık bulunamadı: $assetId');
    }

    final existingAsset = IpAssetModel.fromDocument(snapshot);

    _validateTenant(existingAsset.tenantId);

    if (existingAsset.brandId != asset.brandId.trim()) {
      throw StateError('Fikri varlığın bağlı olduğu marka değiştirilemez.');
    }

    if (existingAsset.assetCode != asset.assetCode.trim()) {
      throw StateError('Fikri varlığın varlık kodu değiştirilemez.');
    }

    final actorId = _validateRequiredId(
      asset.updatedBy ?? asset.createdBy,
      fieldName: 'updatedBy',
    );

    await document.update(asset.toUpdateMap(actorId: actorId));
  }

  @override
  Future<IpAssetModel?> getById(String assetId) async {
    final snapshot = await _refs.assetDocument(assetId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final asset = IpAssetModel.fromDocument(snapshot);

    _validateTenant(asset.tenantId);

    return asset;
  }

  @override
  Future<IpAssetModel?> findByAssetCode({
    required String brandId,
    required String assetCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final cleanedAssetCode = _validateRequiredText(
      assetCode,
      fieldName: 'assetCode',
    );

    final snapshot = await _refs
        .tenantQuery(_refs.assets)
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('assetCode', isEqualTo: cleanedAssetCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return IpAssetModel.fromDocument(snapshot.docs.first);
  }

  @override
  Future<List<IpAssetModel>> listAll({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    int limit = 200,
  }) async {
    final query = _buildListQuery(
      brandId: brandId,
      assetType: assetType,
      status: status,
      riskLevel: riskLevel,
      containsTradeSecret: containsTradeSecret,
      monitoringEnabled: monitoringEnabled,
    );

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .get();

    return snapshot.docs.map(IpAssetModel.fromDocument).toList(growable: false);
  }

  @override
  Stream<List<IpAssetModel>> watchAll({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
    int limit = 200,
  }) {
    final query = _buildListQuery(
      brandId: brandId,
      assetType: assetType,
      status: status,
      riskLevel: riskLevel,
      containsTradeSecret: containsTradeSecret,
      monitoringEnabled: monitoringEnabled,
    );

    return query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(IpAssetModel.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Future<List<IpAssetModel>> listProtectionGaps({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final assets = await listAll(brandId: brandId, limit: 500);

    return List<IpAssetModel>.unmodifiable(
      assets.where((asset) => asset.hasProtectionGap).take(safeLimit),
    );
  }

  @override
  Future<List<IpAssetModel>> listImmediateAttention({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final assets = await listAll(brandId: brandId, limit: 500);

    final filtered =
        assets
            .where((asset) => asset.requiresImmediateAttention)
            .toList(growable: false)
          ..sort(
            (first, second) => _riskRank(
              second.riskLevel,
            ).compareTo(_riskRank(first.riskLevel)),
          );

    return List<IpAssetModel>.unmodifiable(filtered.take(safeLimit));
  }

  @override
  Future<void> updateStatus({
    required String assetId,
    required IpAssetStatus status,
    required String updatedBy,
  }) async {
    final document = _refs.assetDocument(assetId);
    final asset = await _requireOwnedAsset(document);

    _validateTenant(asset.tenantId);

    await document.update(<String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<void> updateScores({
    required String assetId,
    required int rightStrengthScore,
    required int secretSecurityScore,
    required int responseReadinessScore,
    required int resilienceScore,
    required String updatedBy,
  }) async {
    _validateScore(rightStrengthScore, fieldName: 'rightStrengthScore');
    _validateScore(secretSecurityScore, fieldName: 'secretSecurityScore');
    _validateScore(responseReadinessScore, fieldName: 'responseReadinessScore');
    _validateScore(resilienceScore, fieldName: 'resilienceScore');

    final document = _refs.assetDocument(assetId);
    final asset = await _requireOwnedAsset(document);

    _validateTenant(asset.tenantId);

    await document.update(<String, dynamic>{
      'rightStrengthScore': rightStrengthScore,
      'secretSecurityScore': secretSecurityScore,
      'responseReadinessScore': responseReadinessScore,
      'resilienceScore': resilienceScore,
      'lastRiskAssessmentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<void> delete(String assetId) async {
    final document = _refs.assetDocument(assetId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final asset = IpAssetModel.fromDocument(snapshot);

    _validateTenant(asset.tenantId);

    if (asset.rightIds.isNotEmpty ||
        asset.documentIds.isNotEmpty ||
        asset.relationshipIds.isNotEmpty ||
        asset.monitoringProfileIds.isNotEmpty) {
      throw StateError(
        'Hak, belge, ilişki veya izleme kaydı bulunan fikri varlık '
        'silinemez. Kaydı arşivleyin.',
      );
    }

    await document.delete();
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpRiskLevel? riskLevel,
    bool? containsTradeSecret,
    bool? monitoringEnabled,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.assets);

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (assetType != null) {
      query = query.where('assetType', isEqualTo: assetType.value);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (riskLevel != null) {
      query = query.where('riskLevel', isEqualTo: riskLevel.value);
    }

    if (containsTradeSecret != null) {
      query = query.where(
        'containsTradeSecret',
        isEqualTo: containsTradeSecret,
      );
    }

    if (monitoringEnabled != null) {
      query = query.where('monitoringEnabled', isEqualTo: monitoringEnabled);
    }

    return query;
  }

  Future<IpAssetModel> _requireOwnedAsset(
    DocumentReference<Map<String, dynamic>> document,
  ) async {
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'İşlem yapılacak fikri varlık bulunamadı: ${document.id}',
      );
    }

    final asset = IpAssetModel.fromDocument(snapshot);

    _validateTenant(asset.tenantId);

    return asset;
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError('IP asset tenantId ile repository tenantId eşleşmiyor.');
    }
  }

  static void _validateAsset(IpAssetModel asset) {
    if (!asset.hasCompleteIdentity) {
      throw ArgumentError(
        'Fikri varlığın tenantId, brandId, assetCode ve title '
        'alanları zorunludur.',
      );
    }

    _validateRequiredId(asset.tenantId, fieldName: 'tenantId');
    _validateRequiredId(asset.brandId, fieldName: 'brandId');
    _validateRequiredText(asset.assetCode, fieldName: 'assetCode');
    _validateRequiredText(asset.title, fieldName: 'title');

    if (asset.assetCode.trim().length > 100) {
      throw ArgumentError.value(
        asset.assetCode,
        'assetCode',
        'assetCode 100 karakterden uzun olamaz.',
      );
    }

    if (asset.title.trim().length > 300) {
      throw ArgumentError.value(
        asset.title,
        'title',
        'Başlık 300 karakterden uzun olamaz.',
      );
    }

    if (asset.description != null && asset.description!.trim().length > 5000) {
      throw ArgumentError.value(
        asset.description,
        'description',
        'Açıklama 5000 karakterden uzun olamaz.',
      );
    }

    if (asset.notes != null && asset.notes!.trim().length > 5000) {
      throw ArgumentError.value(
        asset.notes,
        'notes',
        'Notlar 5000 karakterden uzun olamaz.',
      );
    }

    _validateScore(asset.rightStrengthScore, fieldName: 'rightStrengthScore');
    _validateScore(asset.secretSecurityScore, fieldName: 'secretSecurityScore');
    _validateScore(
      asset.responseReadinessScore,
      fieldName: 'responseReadinessScore',
    );
    _validateScore(asset.resilienceScore, fieldName: 'resilienceScore');
  }

  static void _validateScore(int value, {required String fieldName}) {
    if (value < 0 || value > 100) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName 0 ile 100 arasında olmalıdır.',
      );
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

  static String? _cleanOptionalId(String? value, {required String fieldName}) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return _validateRequiredId(cleaned, fieldName: fieldName);
  }

  static int _validateLimit(int value) {
    if (value < 1 || value > 500) {
      throw ArgumentError.value(
        value,
        'limit',
        'limit 1 ile 500 arasında olmalıdır.',
      );
    }

    return value;
  }

  static int _riskRank(IpRiskLevel level) {
    return switch (level) {
      IpRiskLevel.informational => 0,
      IpRiskLevel.low => 1,
      IpRiskLevel.medium => 2,
      IpRiskLevel.high => 3,
      IpRiskLevel.critical => 4,
    };
  }
}
