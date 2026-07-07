import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/supply_facility_enums.dart';
import '../models/supply_facility_model.dart';
import 'supply_security_firestore_refs.dart';

class SupplyFacilityRepository {
  const SupplyFacilityRepository({required SupplySecurityFirestoreRefs refs})
    : _refs = refs;

  factory SupplyFacilityRepository.instance({required String tenantId}) {
    return SupplyFacilityRepository(
      refs: SupplySecurityFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final SupplySecurityFirestoreRefs _refs;

  Future<String> create(SupplyFacilityModel facility) async {
    _validateTenant(facility.tenantId);
    _validateFacility(facility);

    final existing = await findByFacilityCode(
      brandId: facility.brandId,
      facilityCode: facility.facilityCode,
    );

    if (existing != null && existing.id != facility.id.trim()) {
      throw StateError(
        'Bu tesis kodu seçilen marka için zaten kullanılıyor: '
        '${facility.facilityCode}',
      );
    }

    final document = facility.id.trim().isEmpty
        ? _refs.facilities.doc()
        : _refs.facilityDocument(facility.id);

    if (facility.id.trim().isNotEmpty) {
      final snapshot = await document.get();

      if (snapshot.exists) {
        throw StateError(
          'Aynı kimlikle tedarik güvenliği tesisi zaten mevcut: '
          '${facility.id}',
        );
      }
    }

    await document.set(facility.toCreateMap());

    return document.id;
  }

  Future<void> update(SupplyFacilityModel facility) async {
    _validateTenant(facility.tenantId);
    _validateFacility(facility);

    final facilityId = _validateRequiredId(
      facility.id,
      fieldName: 'facilityId',
    );

    final document = _refs.facilityDocument(facilityId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Güncellenecek tesis bulunamadı: $facilityId');
    }

    final existing = SupplyFacilityModel.fromDocument(snapshot);

    _validateTenant(existing.tenantId);

    if (existing.brandId != facility.brandId.trim()) {
      throw StateError('Tesisin bağlı olduğu marka değiştirilemez.');
    }

    if (existing.partnerId != facility.partnerId.trim()) {
      throw StateError('Tesisin bağlı olduğu partner değiştirilemez.');
    }

    if (existing.normalizedFacilityCode != facility.normalizedFacilityCode) {
      throw StateError('Tesis kodu değiştirilemez.');
    }

    final actorId = _validateRequiredId(
      facility.updatedBy ?? facility.createdBy,
      fieldName: 'updatedBy',
    );

    await document.update(facility.toUpdateMap(actorId: actorId));
  }

  Future<SupplyFacilityModel?> getById(String facilityId) async {
    final snapshot = await _refs.facilityDocument(facilityId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final facility = SupplyFacilityModel.fromDocument(snapshot);
    _validateTenant(facility.tenantId);

    return facility;
  }

  Future<SupplyFacilityModel?> findByFacilityCode({
    required String brandId,
    required String facilityCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final normalizedCode = _validateRequiredText(
      facilityCode,
      fieldName: 'facilityCode',
    ).toUpperCase();

    final snapshot = await _refs
        .tenantQuery(_refs.facilities)
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('facilityCodeNormalized', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return SupplyFacilityModel.fromDocument(snapshot.docs.first);
  }

  Future<List<SupplyFacilityModel>> listAll({
    String? brandId,
    String? partnerId,
    SupplyFacilityType? facilityType,
    SupplyFacilityStatus? status,
    SupplyFacilityVerificationStatus? verificationStatus,
    SupplyFacilityRiskLevel? riskLevel,
    SupplyFacilityAuthorizationStatus? authorizationStatus,
    bool? isCriticalFacility,
    bool? auditRequired,
    int limit = 200,
  }) async {
    final snapshot = await _buildListQuery(
      brandId: brandId,
      partnerId: partnerId,
      facilityType: facilityType,
      status: status,
      verificationStatus: verificationStatus,
      riskLevel: riskLevel,
      authorizationStatus: authorizationStatus,
      isCriticalFacility: isCriticalFacility,
      auditRequired: auditRequired,
    ).orderBy('createdAt', descending: true).limit(_validateLimit(limit)).get();

    return snapshot.docs
        .map(SupplyFacilityModel.fromDocument)
        .toList(growable: false);
  }

  Stream<List<SupplyFacilityModel>> watchAll({
    String? brandId,
    String? partnerId,
    SupplyFacilityType? facilityType,
    SupplyFacilityStatus? status,
    SupplyFacilityVerificationStatus? verificationStatus,
    SupplyFacilityRiskLevel? riskLevel,
    SupplyFacilityAuthorizationStatus? authorizationStatus,
    bool? isCriticalFacility,
    bool? auditRequired,
    int limit = 200,
  }) {
    return _buildListQuery(
          brandId: brandId,
          partnerId: partnerId,
          facilityType: facilityType,
          status: status,
          verificationStatus: verificationStatus,
          riskLevel: riskLevel,
          authorizationStatus: authorizationStatus,
          isCriticalFacility: isCriticalFacility,
          auditRequired: auditRequired,
        )
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SupplyFacilityModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<List<SupplyFacilityModel>> listHighRisk({
    String? brandId,
    String? partnerId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final facilities = await listAll(
      brandId: brandId,
      partnerId: partnerId,
      limit: 500,
    );

    final matches =
        facilities
            .where((facility) => facility.isHighRisk)
            .toList(growable: false)
          ..sort((first, second) {
            final riskComparison = second.riskLevel.index.compareTo(
              first.riskLevel.index,
            );

            if (riskComparison != 0) {
              return riskComparison;
            }

            return first.name.compareTo(second.name);
          });

    return List<SupplyFacilityModel>.unmodifiable(matches.take(safeLimit));
  }

  Future<void> archive({
    required String facilityId,
    required String archiveReason,
    required String updatedBy,
  }) async {
    final reason = _validateRequiredText(
      archiveReason,
      fieldName: 'archiveReason',
    );

    final document = _refs.facilityDocument(facilityId);
    final facility = await _requireFacility(document);

    _validateTenant(facility.tenantId);

    await document.update(<String, dynamic>{
      'status': SupplyFacilityStatus.archived.value,
      'archiveReason': reason,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  Future<void> delete(String facilityId) async {
    final document = _refs.facilityDocument(facilityId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final facility = SupplyFacilityModel.fromDocument(snapshot);
    _validateTenant(facility.tenantId);

    if (!facility.isArchived) {
      throw StateError('Tesis kaydı silinmeden önce arşivlenmelidir.');
    }

    if (facility.relatedProductIds.isNotEmpty ||
        facility.certificateDocumentIds.isNotEmpty ||
        facility.auditDocumentIds.isNotEmpty) {
      throw StateError(
        'Ürün, sertifika veya denetim bağlantısı bulunan tesis silinemez.',
      );
    }

    await document.delete();
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    String? partnerId,
    SupplyFacilityType? facilityType,
    SupplyFacilityStatus? status,
    SupplyFacilityVerificationStatus? verificationStatus,
    SupplyFacilityRiskLevel? riskLevel,
    SupplyFacilityAuthorizationStatus? authorizationStatus,
    bool? isCriticalFacility,
    bool? auditRequired,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.facilities);

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    final cleanedPartnerId = _cleanOptionalId(
      partnerId,
      fieldName: 'partnerId',
    );

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (cleanedPartnerId != null) {
      query = query.where('partnerId', isEqualTo: cleanedPartnerId);
    }

    if (facilityType != null) {
      query = query.where('facilityType', isEqualTo: facilityType.value);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (verificationStatus != null) {
      query = query.where(
        'verificationStatus',
        isEqualTo: verificationStatus.value,
      );
    }

    if (riskLevel != null) {
      query = query.where('riskLevel', isEqualTo: riskLevel.value);
    }

    if (authorizationStatus != null) {
      query = query.where(
        'authorizationStatus',
        isEqualTo: authorizationStatus.value,
      );
    }

    if (isCriticalFacility != null) {
      query = query.where('isCriticalFacility', isEqualTo: isCriticalFacility);
    }

    if (auditRequired != null) {
      query = query.where('auditRequired', isEqualTo: auditRequired);
    }

    return query;
  }

  Future<SupplyFacilityModel> _requireFacility(
    DocumentReference<Map<String, dynamic>> document,
  ) async {
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('İşlem yapılacak tesis bulunamadı: ${document.id}');
    }

    return SupplyFacilityModel.fromDocument(snapshot);
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Supply facility tenantId ile repository tenantId eşleşmiyor.',
      );
    }
  }

  static void _validateFacility(SupplyFacilityModel facility) {
    if (!facility.hasCompleteIdentity) {
      throw ArgumentError(
        'tenantId, brandId, partnerId, facilityCode ve name zorunludur.',
      );
    }

    _validateRequiredId(facility.tenantId, fieldName: 'tenantId');
    _validateRequiredId(facility.brandId, fieldName: 'brandId');
    _validateRequiredId(facility.partnerId, fieldName: 'partnerId');
    _validateRequiredText(facility.facilityCode, fieldName: 'facilityCode');
    _validateRequiredText(facility.name, fieldName: 'name');

    if (facility.facilityCode.trim().length > 100) {
      throw ArgumentError.value(
        facility.facilityCode,
        'facilityCode',
        'Tesis kodu 100 karakterden uzun olamaz.',
      );
    }

    if (facility.name.trim().length > 300) {
      throw ArgumentError.value(
        facility.name,
        'name',
        'Tesis adı 300 karakterden uzun olamaz.',
      );
    }

    if (facility.latitude != null &&
        (facility.latitude! < -90 || facility.latitude! > 90)) {
      throw ArgumentError.value(
        facility.latitude,
        'latitude',
        'Enlem -90 ile 90 arasında olmalıdır.',
      );
    }

    if (facility.longitude != null &&
        (facility.longitude! < -180 || facility.longitude! > 180)) {
      throw ArgumentError.value(
        facility.longitude,
        'longitude',
        'Boylam -180 ile 180 arasında olmalıdır.',
      );
    }

    if ((facility.latitude == null) != (facility.longitude == null)) {
      throw ArgumentError(
        'Enlem ve boylam birlikte girilmeli veya ikisi de boş bırakılmalıdır.',
      );
    }

    if (facility.monthlyCapacity != null && facility.monthlyCapacity! < 0) {
      throw ArgumentError.value(
        facility.monthlyCapacity,
        'monthlyCapacity',
        'Aylık kapasite negatif olamaz.',
      );
    }

    if (facility.monthlyCapacity != null &&
        (facility.capacityUnit == null ||
            facility.capacityUnit!.trim().isEmpty)) {
      throw ArgumentError(
        'Aylık kapasite girildiğinde kapasite birimi zorunludur.',
      );
    }

    if (facility.lastAuditAt != null &&
        facility.nextAuditAt != null &&
        facility.nextAuditAt!.isBefore(facility.lastAuditAt!)) {
      throw ArgumentError(
        'Sonraki denetim tarihi son denetim tarihinden önce olamaz.',
      );
    }

    if (facility.riskLevel == SupplyFacilityRiskLevel.critical &&
        !facility.auditRequired) {
      throw ArgumentError(
        'Kritik risk seviyesindeki tesiste denetim zorunlu olmalıdır.',
      );
    }

    if (facility.authorizationStatus ==
            SupplyFacilityAuthorizationStatus.authorized &&
        !facility.productionAuthorized &&
        !facility.storageAuthorized &&
        !facility.packagingAuthorized &&
        !facility.labelPrintingAuthorized &&
        !facility.destructionAuthorized) {
      throw ArgumentError(
        'Yetkili tesiste en az bir operasyon yetkisi tanımlanmalıdır.',
      );
    }

    if (facility.facilityType == SupplyFacilityType.suspectedUnauthorizedSite &&
        facility.authorizationStatus ==
            SupplyFacilityAuthorizationStatus.authorized) {
      throw ArgumentError('Şüpheli yetkisiz üretim noktası authorized olamaz.');
    }

    if (facility.isArchived &&
        (facility.archiveReason == null ||
            facility.archiveReason!.trim().isEmpty)) {
      throw ArgumentError('Arşivlenen tesiste arşiv nedeni zorunludur.');
    }

    if (facility.notes != null && facility.notes!.trim().length > 5000) {
      throw ArgumentError.value(
        facility.notes,
        'notes',
        'Notlar 5000 karakterden uzun olamaz.',
      );
    }

    _validateMetadata(facility.metadata);
  }

  static void _validateMetadata(Map<String, dynamic> metadata) {
    const forbiddenTokens = <String>[
      'password',
      'passwd',
      'secret',
      'token',
      'credential',
      'apikey',
      'api_key',
      'accesskey',
      'access_key',
      'privatekey',
      'private_key',
      'formula',
      'recipe',
      'reçete',
      'formül',
    ];

    void inspect(Object? value, String path) {
      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString().toLowerCase();

          if (forbiddenTokens.any(key.contains)) {
            throw ArgumentError(
              'Metadata içinde hassas anahtar kullanılamaz: $path$key',
            );
          }

          inspect(entry.value, '$path$key.');
        }

        return;
      }

      if (value is Iterable) {
        var index = 0;

        for (final item in value) {
          inspect(item, '$path[$index].');
          index++;
        }
      }
    }

    inspect(metadata, 'metadata.');
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
}
