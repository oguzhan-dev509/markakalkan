import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../constants/ip_trade_secret_enums.dart';
import '../models/ip_trade_secret_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_trade_secret_repository_port.dart';

class IpTradeSecretRepository implements IpTradeSecretRepositoryPort {
  const IpTradeSecretRepository({required IpFirestoreRefs refs}) : _refs = refs;

  factory IpTradeSecretRepository.instance({required String tenantId}) {
    return IpTradeSecretRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpFirestoreRefs _refs;

  @override
  Future<String> create(IpTradeSecretModel tradeSecret) async {
    _validateTenant(tradeSecret.tenantId);
    _validateTradeSecret(tradeSecret);

    final existingCode = await findBySecretCode(
      brandId: tradeSecret.brandId,
      secretCode: tradeSecret.secretCode,
    );

    if (existingCode != null && existingCode.id != tradeSecret.id.trim()) {
      throw StateError(
        'Bu ticari sır kodu seçilen marka için zaten kullanılıyor: '
        '${tradeSecret.secretCode}',
      );
    }

    if (tradeSecret.id.trim().isNotEmpty) {
      final document = _refs.tradeSecretDocument(tradeSecret.id);
      final snapshot = await document.get();

      if (snapshot.exists) {
        throw StateError(
          'Aynı kimlikle bir ticari sır koruma dosyası zaten mevcut: '
          '${tradeSecret.id}',
        );
      }

      await document.set(tradeSecret.toCreateMap());

      return document.id;
    }

    final document = _refs.tradeSecrets.doc();

    await document.set(tradeSecret.toCreateMap());

    return document.id;
  }

  @override
  Future<void> update(IpTradeSecretModel tradeSecret) async {
    _validateTenant(tradeSecret.tenantId);
    _validateTradeSecret(tradeSecret);

    final tradeSecretId = _validateRequiredId(
      tradeSecret.id,
      fieldName: 'tradeSecretId',
    );

    final document = _refs.tradeSecretDocument(tradeSecretId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Güncellenecek ticari sır koruma dosyası bulunamadı: '
        '$tradeSecretId',
      );
    }

    final existing = IpTradeSecretModel.fromDocument(snapshot);

    _validateTenant(existing.tenantId);

    if (existing.brandId != tradeSecret.brandId.trim()) {
      throw StateError(
        'Ticari sır koruma dosyasının marka kimliği değiştirilemez.',
      );
    }

    if (existing.secretCode != tradeSecret.secretCode.trim()) {
      throw StateError('Ticari sır koruma dosyasının sır kodu değiştirilemez.');
    }

    final actorId = _validateRequiredId(
      tradeSecret.updatedBy ?? tradeSecret.createdBy,
      fieldName: 'updatedBy',
    );

    await document.update(tradeSecret.toUpdateMap(actorId: actorId));
  }

  @override
  Future<IpTradeSecretModel?> getById(String tradeSecretId) async {
    final snapshot = await _refs.tradeSecretDocument(tradeSecretId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final tradeSecret = IpTradeSecretModel.fromDocument(snapshot);

    _validateTenant(tradeSecret.tenantId);

    return tradeSecret;
  }

  @override
  Future<IpTradeSecretModel?> findBySecretCode({
    required String brandId,
    required String secretCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final cleanedSecretCode = _validateRequiredText(
      secretCode,
      fieldName: 'secretCode',
    );

    final snapshot = await _refs
        .tenantQuery(_refs.tradeSecrets)
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('secretCode', isEqualTo: cleanedSecretCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return IpTradeSecretModel.fromDocument(snapshot.docs.first);
  }

  @override
  Future<List<IpTradeSecretModel>> listAll({
    String? brandId,
    String? primaryAssetId,
    IpTradeSecretType? secretType,
    IpTradeSecretStatus? status,
    IpRiskLevel? riskLevel,
    IpSecretProtectionMode? protectionMode,
    bool? leakageSuspected,
    bool? legalHoldActive,
    int limit = 200,
  }) async {
    final query = _buildListQuery(
      brandId: brandId,
      primaryAssetId: primaryAssetId,
      secretType: secretType,
      status: status,
      riskLevel: riskLevel,
      protectionMode: protectionMode,
      leakageSuspected: leakageSuspected,
      legalHoldActive: legalHoldActive,
    );

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .get();

    return snapshot.docs
        .map(IpTradeSecretModel.fromDocument)
        .toList(growable: false);
  }

  @override
  Stream<List<IpTradeSecretModel>> watchAll({
    String? brandId,
    String? primaryAssetId,
    IpTradeSecretType? secretType,
    IpTradeSecretStatus? status,
    IpRiskLevel? riskLevel,
    IpSecretProtectionMode? protectionMode,
    bool? leakageSuspected,
    bool? legalHoldActive,
    int limit = 200,
  }) {
    final query = _buildListQuery(
      brandId: brandId,
      primaryAssetId: primaryAssetId,
      secretType: secretType,
      status: status,
      riskLevel: riskLevel,
      protectionMode: protectionMode,
      leakageSuspected: leakageSuspected,
      legalHoldActive: legalHoldActive,
    );

    return query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(IpTradeSecretModel.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Future<void> updateStatus({
    required String tradeSecretId,
    required IpTradeSecretStatus status,
    required String updatedBy,
  }) async {
    await _updateControlledFields(
      tradeSecretId: tradeSecretId,
      updatedBy: updatedBy,
      values: <String, dynamic>{'status': status.value},
    );
  }

  @override
  Future<void> markLeakageSuspected({
    required String tradeSecretId,
    required String updatedBy,
  }) async {
    await _updateControlledFields(
      tradeSecretId: tradeSecretId,
      updatedBy: updatedBy,
      values: <String, dynamic>{
        'leakageSuspected': true,
        'status': IpTradeSecretStatus.compromised.value,
      },
    );
  }

  @override
  Future<void> clearLeakageSuspicion({
    required String tradeSecretId,
    required String updatedBy,
  }) async {
    await _updateControlledFields(
      tradeSecretId: tradeSecretId,
      updatedBy: updatedBy,
      values: <String, dynamic>{
        'leakageSuspected': false,
        'status': IpTradeSecretStatus.underReview.value,
      },
    );
  }

  @override
  Future<void> activateLegalHold({
    required String tradeSecretId,
    required String updatedBy,
  }) async {
    await _updateControlledFields(
      tradeSecretId: tradeSecretId,
      updatedBy: updatedBy,
      values: <String, dynamic>{'legalHoldActive': true},
    );
  }

  @override
  Future<void> releaseLegalHold({
    required String tradeSecretId,
    required String updatedBy,
  }) async {
    await _updateControlledFields(
      tradeSecretId: tradeSecretId,
      updatedBy: updatedBy,
      values: <String, dynamic>{'legalHoldActive': false},
    );
  }

  @override
  Future<void> delete(String tradeSecretId) async {
    final document = _refs.tradeSecretDocument(tradeSecretId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final tradeSecret = IpTradeSecretModel.fromDocument(snapshot);

    _validateTenant(tradeSecret.tenantId);

    if (tradeSecret.legalHoldActive) {
      throw StateError(
        'Hukuki muhafaza altındaki ticari sır koruma dosyası silinemez.',
      );
    }

    await document.delete();
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    String? primaryAssetId,
    IpTradeSecretType? secretType,
    IpTradeSecretStatus? status,
    IpRiskLevel? riskLevel,
    IpSecretProtectionMode? protectionMode,
    bool? leakageSuspected,
    bool? legalHoldActive,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.tradeSecrets);

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    final cleanedAssetId = _cleanOptionalId(
      primaryAssetId,
      fieldName: 'primaryAssetId',
    );

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (cleanedAssetId != null) {
      query = query.where('primaryAssetId', isEqualTo: cleanedAssetId);
    }

    if (secretType != null) {
      query = query.where('secretType', isEqualTo: secretType.value);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (riskLevel != null) {
      query = query.where('riskLevel', isEqualTo: riskLevel.value);
    }

    if (protectionMode != null) {
      query = query.where('protectionMode', isEqualTo: protectionMode.value);
    }

    if (leakageSuspected != null) {
      query = query.where('leakageSuspected', isEqualTo: leakageSuspected);
    }

    if (legalHoldActive != null) {
      query = query.where('legalHoldActive', isEqualTo: legalHoldActive);
    }

    return query;
  }

  Future<void> _updateControlledFields({
    required String tradeSecretId,
    required String updatedBy,
    required Map<String, dynamic> values,
  }) async {
    final cleanedTradeSecretId = _validateRequiredId(
      tradeSecretId,
      fieldName: 'tradeSecretId',
    );

    final cleanedUpdatedBy = _validateRequiredId(
      updatedBy,
      fieldName: 'updatedBy',
    );

    final document = _refs.tradeSecretDocument(cleanedTradeSecretId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Ticari sır koruma dosyası bulunamadı: $cleanedTradeSecretId',
      );
    }

    final existing = IpTradeSecretModel.fromDocument(snapshot);

    _validateTenant(existing.tenantId);

    await document.update(<String, dynamic>{
      ...values,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': cleanedUpdatedBy,
    });
  }

  void _validateTenant(String tenantId) {
    if (tenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Ticari sır koruma dosyasının tenant kimliği repository '
        'tenant kimliğiyle eşleşmiyor.',
      );
    }
  }

  static void _validateTradeSecret(IpTradeSecretModel tradeSecret) {
    if (!tradeSecret.hasCompleteIdentity) {
      throw StateError(
        'Ticari sır koruma dosyasının zorunlu kimlik alanları eksik.',
      );
    }

    tradeSecret.toMap();
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
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return _validateRequiredId(value, fieldName: fieldName);
  }

  static int _validateLimit(int limit) {
    if (limit < 1 || limit > 500) {
      throw RangeError.range(
        limit,
        1,
        500,
        'limit',
        'limit 1–500 aralığında olmalıdır.',
      );
    }

    return limit;
  }
}
