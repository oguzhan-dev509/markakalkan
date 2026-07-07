import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/supply_facility_enums.dart';
import '../constants/supply_security_enums.dart';
import '../models/supply_partner_model.dart';
import 'supply_security_firestore_refs.dart';

class SupplyPartnerRepository {
  const SupplyPartnerRepository({required SupplySecurityFirestoreRefs refs})
    : _refs = refs;

  factory SupplyPartnerRepository.instance({required String tenantId}) {
    return SupplyPartnerRepository(
      refs: SupplySecurityFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final SupplySecurityFirestoreRefs _refs;

  Future<String> create(SupplyPartnerModel partner) async {
    _validateTenant(partner.tenantId);
    _validatePartner(partner);

    final existing = await findByPartnerCode(
      brandId: partner.brandId,
      partnerCode: partner.partnerCode,
    );

    if (existing != null && existing.id != partner.id.trim()) {
      throw StateError(
        'Bu partner kodu seçilen marka için zaten kullanılıyor: '
        '${partner.partnerCode}',
      );
    }

    final document = partner.id.trim().isEmpty
        ? _refs.partners.doc()
        : _refs.partnerDocument(partner.id);

    if (partner.id.trim().isNotEmpty) {
      final snapshot = await document.get();

      if (snapshot.exists) {
        throw StateError(
          'Aynı kimlikle tedarik güvenliği partneri zaten mevcut: '
          '${partner.id}',
        );
      }
    }

    await document.set(partner.toCreateMap());

    return document.id;
  }

  Future<void> update(SupplyPartnerModel partner) async {
    _validateTenant(partner.tenantId);
    _validatePartner(partner);

    final partnerId = _validateRequiredId(partner.id, fieldName: 'partnerId');

    final document = _refs.partnerDocument(partnerId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Güncellenecek partner bulunamadı: $partnerId');
    }

    final existing = SupplyPartnerModel.fromDocument(snapshot);

    _validateTenant(existing.tenantId);

    if (existing.brandId != partner.brandId.trim()) {
      throw StateError('Partnerin bağlı olduğu marka değiştirilemez.');
    }

    if (existing.normalizedPartnerCode != partner.normalizedPartnerCode) {
      throw StateError('Partner kodu değiştirilemez.');
    }

    final actorId = _validateRequiredId(
      partner.updatedBy ?? partner.createdBy,
      fieldName: 'updatedBy',
    );

    await document.update(partner.toUpdateMap(actorId: actorId));
  }

  Future<SupplyPartnerModel?> getById(String partnerId) async {
    final snapshot = await _refs.partnerDocument(partnerId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final partner = SupplyPartnerModel.fromDocument(snapshot);
    _validateTenant(partner.tenantId);

    return partner;
  }

  Future<SupplyPartnerModel?> findByPartnerCode({
    required String brandId,
    required String partnerCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final normalizedCode = _validateRequiredText(
      partnerCode,
      fieldName: 'partnerCode',
    ).toUpperCase();

    final snapshot = await _refs
        .tenantQuery(_refs.partners)
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('partnerCodeNormalized', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return SupplyPartnerModel.fromDocument(snapshot.docs.first);
  }

  Future<List<SupplyPartnerModel>> listAll({
    String? brandId,
    SupplyPartnerRole? role,
    SupplyPartnerStatus? status,
    SupplyPartnerVerificationStatus? verificationStatus,
    SupplyPartnerRiskLevel? riskLevel,
    bool? isCriticalPartner,
    bool? auditRequired,
    int limit = 200,
  }) async {
    final snapshot = await _buildListQuery(
      brandId: brandId,
      role: role,
      status: status,
      verificationStatus: verificationStatus,
      riskLevel: riskLevel,
      isCriticalPartner: isCriticalPartner,
      auditRequired: auditRequired,
    ).orderBy('createdAt', descending: true).limit(_validateLimit(limit)).get();

    return snapshot.docs
        .map(SupplyPartnerModel.fromDocument)
        .toList(growable: false);
  }

  Stream<List<SupplyPartnerModel>> watchAll({
    String? brandId,
    SupplyPartnerRole? role,
    SupplyPartnerStatus? status,
    SupplyPartnerVerificationStatus? verificationStatus,
    SupplyPartnerRiskLevel? riskLevel,
    bool? isCriticalPartner,
    bool? auditRequired,
    int limit = 200,
  }) {
    return _buildListQuery(
          brandId: brandId,
          role: role,
          status: status,
          verificationStatus: verificationStatus,
          riskLevel: riskLevel,
          isCriticalPartner: isCriticalPartner,
          auditRequired: auditRequired,
        )
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SupplyPartnerModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<List<SupplyPartnerModel>> listHighRisk({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);
    final partners = await listAll(brandId: brandId, limit: 500);

    final matches =
        partners.where((partner) => partner.isHighRisk).toList(growable: false)
          ..sort((first, second) {
            final riskComparison = second.riskLevel.index.compareTo(
              first.riskLevel.index,
            );

            if (riskComparison != 0) {
              return riskComparison;
            }

            return first.trustScore.compareTo(second.trustScore);
          });

    return List<SupplyPartnerModel>.unmodifiable(matches.take(safeLimit));
  }

  Future<void> archive({
    required String partnerId,
    required String archiveReason,
    required String updatedBy,
  }) async {
    final reason = _validateRequiredText(
      archiveReason,
      fieldName: 'archiveReason',
    );

    final document = _refs.partnerDocument(partnerId);
    final partner = await _requirePartner(document);

    _validateTenant(partner.tenantId);

    final facilitiesSnapshot = await _refs.tenantQuery(_refs.facilities).get();

    final hasActiveFacility = facilitiesSnapshot.docs.any((facilityDocument) {
      final data = facilityDocument.data();

      return data['partnerId'] == partnerId &&
          data['status'] != SupplyFacilityStatus.archived.value;
    });

    if (hasActiveFacility) {
      throw StateError(
        'Bağlı aktif tesisi bulunan partner arşivlenemez. '
        'Önce bağlı tesisleri arşivleyin.',
      );
    }

    await document.update(<String, dynamic>{
      'status': SupplyPartnerStatus.archived.value,
      'archiveReason': reason,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  Future<void> delete(String partnerId) async {
    final document = _refs.partnerDocument(partnerId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final partner = SupplyPartnerModel.fromDocument(snapshot);
    _validateTenant(partner.tenantId);

    if (!partner.isArchived) {
      throw StateError('Partner kaydı silinmeden önce arşivlenmelidir.');
    }

    if (partner.relatedFacilityIds.isNotEmpty ||
        partner.relatedProductIds.isNotEmpty ||
        partner.certificateDocumentIds.isNotEmpty) {
      throw StateError(
        'Tesis, ürün veya belge bağlantısı bulunan partner silinemez.',
      );
    }

    await document.delete();
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    SupplyPartnerRole? role,
    SupplyPartnerStatus? status,
    SupplyPartnerVerificationStatus? verificationStatus,
    SupplyPartnerRiskLevel? riskLevel,
    bool? isCriticalPartner,
    bool? auditRequired,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.partners);

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (role != null) {
      query = query.where('roles', arrayContains: role.value);
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

    if (isCriticalPartner != null) {
      query = query.where('isCriticalPartner', isEqualTo: isCriticalPartner);
    }

    if (auditRequired != null) {
      query = query.where('auditRequired', isEqualTo: auditRequired);
    }

    return query;
  }

  Future<SupplyPartnerModel> _requirePartner(
    DocumentReference<Map<String, dynamic>> document,
  ) async {
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('İşlem yapılacak partner bulunamadı: ${document.id}');
    }

    return SupplyPartnerModel.fromDocument(snapshot);
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Supply partner tenantId ile repository tenantId eşleşmiyor.',
      );
    }
  }

  static void _validatePartner(SupplyPartnerModel partner) {
    if (!partner.hasCompleteIdentity) {
      throw ArgumentError(
        'tenantId, brandId, partnerCode ve legalName zorunludur.',
      );
    }

    _validateRequiredId(partner.tenantId, fieldName: 'tenantId');
    _validateRequiredId(partner.brandId, fieldName: 'brandId');
    _validateRequiredText(partner.partnerCode, fieldName: 'partnerCode');
    _validateRequiredText(partner.legalName, fieldName: 'legalName');

    if (partner.partnerCode.trim().length > 100) {
      throw ArgumentError.value(
        partner.partnerCode,
        'partnerCode',
        'Partner kodu 100 karakterden uzun olamaz.',
      );
    }

    if (partner.legalName.trim().length > 300) {
      throw ArgumentError.value(
        partner.legalName,
        'legalName',
        'Yasal unvan 300 karakterden uzun olamaz.',
      );
    }

    if (partner.status == SupplyPartnerStatus.active && partner.roles.isEmpty) {
      throw ArgumentError('Aktif partnerde en az bir rol zorunludur.');
    }

    if (partner.trustScore < 0 || partner.trustScore > 100) {
      throw ArgumentError.value(
        partner.trustScore,
        'trustScore',
        'Güven skoru 0 ile 100 arasında olmalıdır.',
      );
    }

    if (partner.contractManufacturingAuthorized &&
        !partner.hasManufacturingRole) {
      throw ArgumentError(
        'Fason üretim yetkisi yalnız üretici veya fason üretici '
        'rolünde verilebilir.',
      );
    }

    if (partner.subcontractingAllowed && !partner.hasOperationalRole) {
      throw ArgumentError(
        'Alt yüklenici izni yalnız üretici, fason üretici veya '
        'alt yüklenici rolünde verilebilir.',
      );
    }

    if (partner.riskLevel == SupplyPartnerRiskLevel.critical &&
        !partner.auditRequired) {
      throw ArgumentError('Kritik risk seviyesinde denetim zorunlu olmalıdır.');
    }

    if (partner.lastAuditAt != null &&
        partner.nextAuditAt != null &&
        partner.nextAuditAt!.isBefore(partner.lastAuditAt!)) {
      throw ArgumentError(
        'Sonraki denetim tarihi son denetim tarihinden önce olamaz.',
      );
    }

    if (partner.isArchived &&
        (partner.archiveReason == null ||
            partner.archiveReason!.trim().isEmpty)) {
      throw ArgumentError('Arşivlenen partnerde arşiv nedeni zorunludur.');
    }

    if (partner.notes != null && partner.notes!.trim().length > 5000) {
      throw ArgumentError.value(
        partner.notes,
        'notes',
        'Notlar 5000 karakterden uzun olamaz.',
      );
    }

    _validateMetadata(partner.metadata);
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
