import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../models/ip_relationship_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_repository_ports.dart';

class IpRelationshipRepository implements IpRelationshipRepositoryPort {
  const IpRelationshipRepository({required IpFirestoreRefs refs})
    : _refs = refs;

  factory IpRelationshipRepository.instance({required String tenantId}) {
    return IpRelationshipRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpFirestoreRefs _refs;

  @override
  Future<String> create(IpRelationshipModel relationship) async {
    _validateTenant(relationship.tenantId);
    _validateRelationship(relationship);

    final existing = await findByRelationshipCode(
      brandId: relationship.brandId,
      relationshipCode: relationship.relationshipCode,
    );

    if (existing != null && existing.id != relationship.id.trim()) {
      throw StateError(
        'Bu ilişki kodu seçilen marka için zaten kullanılıyor: '
        '${relationship.relationshipCode}',
      );
    }

    if (relationship.id.trim().isNotEmpty) {
      final document = _refs.relationshipDocument(relationship.id);
      final snapshot = await document.get();

      if (snapshot.exists) {
        throw StateError(
          'Aynı kimlikle bir fikri mülkiyet ilişkisi zaten mevcut: '
          '${relationship.id}',
        );
      }

      await document.set(relationship.toCreateMap());

      return document.id;
    }

    final document = _refs.relationships.doc();

    await document.set(relationship.toCreateMap());

    return document.id;
  }

  @override
  Future<void> update(IpRelationshipModel relationship) async {
    _validateTenant(relationship.tenantId);
    _validateRelationship(relationship);

    final relationshipId = _validateRequiredId(
      relationship.id,
      fieldName: 'relationshipId',
    );

    final document = _refs.relationshipDocument(relationshipId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Güncellenecek fikri mülkiyet ilişkisi bulunamadı: '
        '$relationshipId',
      );
    }

    final existingRelationship = IpRelationshipModel.fromDocument(snapshot);

    _validateTenant(existingRelationship.tenantId);

    if (existingRelationship.brandId != relationship.brandId.trim()) {
      throw StateError('İlişkinin bağlı olduğu marka değiştirilemez.');
    }

    if (existingRelationship.relationshipCode !=
        relationship.relationshipCode.trim()) {
      throw StateError('İlişkinin ilişki kodu değiştirilemez.');
    }

    final actorId = _validateRequiredId(
      relationship.updatedBy ?? relationship.createdBy,
      fieldName: 'updatedBy',
    );

    await document.update(relationship.toUpdateMap(actorId: actorId));
  }

  @override
  Future<IpRelationshipModel?> getById(String relationshipId) async {
    final snapshot = await _refs.relationshipDocument(relationshipId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final relationship = IpRelationshipModel.fromDocument(snapshot);

    _validateTenant(relationship.tenantId);

    return relationship;
  }

  @override
  Future<IpRelationshipModel?> findByRelationshipCode({
    required String brandId,
    required String relationshipCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final cleanedRelationshipCode = _validateRequiredText(
      relationshipCode,
      fieldName: 'relationshipCode',
    );

    final snapshot = await _refs
        .tenantQuery(_refs.relationships)
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('relationshipCode', isEqualTo: cleanedRelationshipCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return IpRelationshipModel.fromDocument(snapshot.docs.first);
  }

  @override
  Future<List<IpRelationshipModel>> listAll({
    String? brandId,
    String? assetId,
    IpRelationshipType? relationshipType,
    IpRelationshipStatus? status,
    IpAccessLevel? accessLevel,
    IpRiskLevel? riskLevel,
    bool? accessRevoked,
    bool? hasNda,
    int limit = 200,
  }) async {
    final query = _buildListQuery(
      brandId: brandId,
      assetId: assetId,
      relationshipType: relationshipType,
      status: status,
      accessLevel: accessLevel,
      riskLevel: riskLevel,
      accessRevoked: accessRevoked,
      hasNda: hasNda,
    );

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .get();

    return snapshot.docs
        .map(IpRelationshipModel.fromDocument)
        .toList(growable: false);
  }

  @override
  Stream<List<IpRelationshipModel>> watchAll({
    String? brandId,
    String? assetId,
    IpRelationshipType? relationshipType,
    IpRelationshipStatus? status,
    IpAccessLevel? accessLevel,
    IpRiskLevel? riskLevel,
    bool? accessRevoked,
    bool? hasNda,
    int limit = 200,
  }) {
    final query = _buildListQuery(
      brandId: brandId,
      assetId: assetId,
      relationshipType: relationshipType,
      status: status,
      accessLevel: accessLevel,
      riskLevel: riskLevel,
      accessRevoked: accessRevoked,
      hasNda: hasNda,
    );

    return query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(IpRelationshipModel.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Future<List<IpRelationshipModel>> listHighRisk({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final relationships = await listAll(brandId: brandId, limit: 500);

    final matches =
        relationships
            .where((relationship) => relationship.isHighRiskRelationship)
            .toList(growable: false)
          ..sort((first, second) {
            final riskComparison = second.riskScore.compareTo(first.riskScore);

            if (riskComparison != 0) {
              return riskComparison;
            }

            return first.trustScore.compareTo(second.trustScore);
          });

    return List<IpRelationshipModel>.unmodifiable(matches.take(safeLimit));
  }

  @override
  Future<List<IpRelationshipModel>> listActiveAccess({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final relationships = await listAll(
      brandId: brandId,
      accessRevoked: false,
      limit: 500,
    );

    final matches =
        relationships
            .where((relationship) => relationship.hasActiveAccess)
            .toList(growable: false)
          ..sort(
            (first, second) => second.riskScore.compareTo(first.riskScore),
          );

    return List<IpRelationshipModel>.unmodifiable(matches.take(safeLimit));
  }

  @override
  Future<List<IpRelationshipModel>> listMissingOrExpiredNda({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final relationships = await listAll(brandId: brandId, limit: 500);

    final matches =
        relationships
            .where((relationship) => relationship.ndaMissingOrExpired)
            .toList(growable: false)
          ..sort((first, second) {
            final activeComparison = (second.hasActiveAccess ? 1 : 0).compareTo(
              first.hasActiveAccess ? 1 : 0,
            );

            if (activeComparison != 0) {
              return activeComparison;
            }

            return second.riskScore.compareTo(first.riskScore);
          });

    return List<IpRelationshipModel>.unmodifiable(matches.take(safeLimit));
  }

  @override
  Future<List<IpRelationshipModel>> listImmediateReview({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final relationships = await listAll(brandId: brandId, limit: 500);

    final matches =
        relationships
            .where((relationship) => relationship.requiresImmediateReview)
            .toList(growable: false)
          ..sort((first, second) {
            final riskComparison = second.riskScore.compareTo(first.riskScore);

            if (riskComparison != 0) {
              return riskComparison;
            }

            return first.trustScore.compareTo(second.trustScore);
          });

    return List<IpRelationshipModel>.unmodifiable(matches.take(safeLimit));
  }

  @override
  Future<void> updateStatus({
    required String relationshipId,
    required IpRelationshipStatus status,
    required String updatedBy,
  }) async {
    final document = _refs.relationshipDocument(relationshipId);
    final relationship = await _requireOwnedRelationship(document);

    _validateTenant(relationship.tenantId);

    await document.update(<String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<void> updateRisk({
    required String relationshipId,
    required IpRiskLevel riskLevel,
    required int riskScore,
    required int trustScore,
    required String updatedBy,
    String? riskReason,
  }) async {
    _validateScore(riskScore, fieldName: 'riskScore');
    _validateScore(trustScore, fieldName: 'trustScore');

    final document = _refs.relationshipDocument(relationshipId);
    final relationship = await _requireOwnedRelationship(document);

    _validateTenant(relationship.tenantId);

    await document.update(<String, dynamic>{
      'riskLevel': riskLevel.value,
      'riskScore': riskScore,
      'trustScore': trustScore,
      'riskReason': _cleanNullable(riskReason),
      'lastReviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<void> revokeAccess({
    required String relationshipId,
    required String revokedBy,
  }) async {
    final document = _refs.relationshipDocument(relationshipId);
    final relationship = await _requireOwnedRelationship(document);

    _validateTenant(relationship.tenantId);

    final cleanedRevokedBy = _validateRequiredId(
      revokedBy,
      fieldName: 'revokedBy',
    );

    await document.update(<String, dynamic>{
      'accessRevoked': true,
      'accessLevel': IpAccessLevel.none.value,
      'accessRevokedAt': FieldValue.serverTimestamp(),
      'revokedBy': cleanedRevokedBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': cleanedRevokedBy,
    });
  }

  @override
  Future<void> delete(String relationshipId) async {
    final document = _refs.relationshipDocument(relationshipId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final relationship = IpRelationshipModel.fromDocument(snapshot);

    _validateTenant(relationship.tenantId);

    if (relationship.hasActiveAccess) {
      throw StateError(
        'Aktif erişimi bulunan ilişki kaydı silinemez. '
        'Önce erişimi iptal edin.',
      );
    }

    if (relationship.relatedAssetIds.isNotEmpty ||
        relationship.relatedRightIds.isNotEmpty ||
        relationship.relatedDocumentIds.isNotEmpty ||
        relationship.relatedProductIds.isNotEmpty ||
        relationship.relatedCaseIds.isNotEmpty) {
      throw StateError(
        'Varlık, hak, belge, ürün veya vaka bağlantısı bulunan '
        'ilişki kaydı silinemez. Kaydı sona erdirin.',
      );
    }

    if (relationship.status == IpRelationshipStatus.active ||
        relationship.status == IpRelationshipStatus.highRisk ||
        relationship.status == IpRelationshipStatus.underReview) {
      throw StateError(
        'Aktif, yüksek riskli veya incelemedeki ilişki kaydı '
        'silinemez. Önce durumunu sona erdirin.',
      );
    }

    await document.delete();
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    String? assetId,
    IpRelationshipType? relationshipType,
    IpRelationshipStatus? status,
    IpAccessLevel? accessLevel,
    IpRiskLevel? riskLevel,
    bool? accessRevoked,
    bool? hasNda,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.relationships);

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    final cleanedAssetId = _cleanOptionalId(assetId, fieldName: 'assetId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (cleanedAssetId != null) {
      query = query.where('relatedAssetIds', arrayContains: cleanedAssetId);
    }

    if (relationshipType != null) {
      query = query.where(
        'relationshipType',
        isEqualTo: relationshipType.value,
      );
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (accessLevel != null) {
      query = query.where('accessLevel', isEqualTo: accessLevel.value);
    }

    if (riskLevel != null) {
      query = query.where('riskLevel', isEqualTo: riskLevel.value);
    }

    if (accessRevoked != null) {
      query = query.where('accessRevoked', isEqualTo: accessRevoked);
    }

    if (hasNda != null) {
      query = query.where('hasNda', isEqualTo: hasNda);
    }

    return query;
  }

  Future<IpRelationshipModel> _requireOwnedRelationship(
    DocumentReference<Map<String, dynamic>> document,
  ) async {
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'İşlem yapılacak fikri mülkiyet ilişkisi bulunamadı: '
        '${document.id}',
      );
    }

    final relationship = IpRelationshipModel.fromDocument(snapshot);

    _validateTenant(relationship.tenantId);

    return relationship;
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError(
        'IP relationship tenantId ile repository tenantId eşleşmiyor.',
      );
    }
  }

  static void _validateRelationship(IpRelationshipModel relationship) {
    if (!relationship.hasCompleteIdentity) {
      throw ArgumentError(
        'İlişkinin tenantId, brandId, relationshipCode ve '
        'subjectName alanları zorunludur.',
      );
    }

    _validateRequiredId(relationship.tenantId, fieldName: 'tenantId');
    _validateRequiredId(relationship.brandId, fieldName: 'brandId');
    _validateRequiredText(
      relationship.relationshipCode,
      fieldName: 'relationshipCode',
    );
    _validateRequiredText(relationship.subjectName, fieldName: 'subjectName');

    if (relationship.relationshipCode.trim().length > 100) {
      throw ArgumentError.value(
        relationship.relationshipCode,
        'relationshipCode',
        'relationshipCode 100 karakterden uzun olamaz.',
      );
    }

    if (relationship.subjectName.trim().length > 300) {
      throw ArgumentError.value(
        relationship.subjectName,
        'subjectName',
        'Kişi veya kuruluş adı 300 karakterden uzun olamaz.',
      );
    }

    if (relationship.notes != null &&
        relationship.notes!.trim().length > 5000) {
      throw ArgumentError.value(
        relationship.notes,
        'notes',
        'Notlar 5000 karakterden uzun olamaz.',
      );
    }

    _validateScore(relationship.riskScore, fieldName: 'riskScore');
    _validateScore(relationship.trustScore, fieldName: 'trustScore');

    if (relationship.accessStartedAt != null &&
        relationship.accessEndsAt != null &&
        relationship.accessStartedAt!.isAfter(relationship.accessEndsAt!)) {
      throw ArgumentError(
        'accessStartedAt, accessEndsAt tarihinden sonra olamaz.',
      );
    }

    if (relationship.relationshipStartedAt != null &&
        relationship.relationshipEndedAt != null &&
        relationship.relationshipStartedAt!.isAfter(
          relationship.relationshipEndedAt!,
        )) {
      throw ArgumentError(
        'relationshipStartedAt, relationshipEndedAt tarihinden '
        'sonra olamaz.',
      );
    }

    if (relationship.hasNda && relationship.ndaSignedAt == null) {
      throw ArgumentError('NDA bulunan ilişkide ndaSignedAt alanı zorunludur.');
    }

    if (relationship.accessRevoked && relationship.accessRevokedAt == null) {
      throw ArgumentError(
        'Erişimi iptal edilmiş ilişkide accessRevokedAt '
        'alanı zorunludur.',
      );
    }

    if (relationship.accessRevoked &&
        relationship.accessLevel != IpAccessLevel.none) {
      throw ArgumentError(
        'Erişimi iptal edilmiş ilişkide accessLevel none olmalıdır.',
      );
    }
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

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
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
}
