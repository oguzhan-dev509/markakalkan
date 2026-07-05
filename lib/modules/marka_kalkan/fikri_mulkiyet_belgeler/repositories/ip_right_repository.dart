import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../models/ip_right_model.dart';
import 'ip_firestore_refs.dart';
import 'ip_repository_ports.dart';

class IpRightRepository implements IpRightRepositoryPort {
  const IpRightRepository({required IpFirestoreRefs refs}) : _refs = refs;

  factory IpRightRepository.instance({required String tenantId}) {
    return IpRightRepository(
      refs: IpFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpFirestoreRefs _refs;

  @override
  Future<String> create(IpRightModel right) async {
    _validateTenant(right.tenantId);
    _validateRight(right);

    final existingCode = await findByRightCode(
      brandId: right.brandId,
      rightCode: right.rightCode,
    );

    if (existingCode != null && existingCode.id != right.id.trim()) {
      throw StateError(
        'Bu hak kodu seçilen marka için zaten kullanılıyor: '
        '${right.rightCode}',
      );
    }

    final registrationNumber = right.registrationNumber?.trim();

    if (registrationNumber != null && registrationNumber.isNotEmpty) {
      final existingRegistration = await findByRegistrationNumber(
        registrationNumber: registrationNumber,
        primaryCountryCode: right.primaryCountryCode,
      );

      if (existingRegistration != null &&
          existingRegistration.id != right.id.trim()) {
        throw StateError(
          'Bu tescil numarası aynı ülke kapsamında zaten kayıtlı: '
          '$registrationNumber',
        );
      }
    }

    if (right.id.trim().isNotEmpty) {
      final document = _refs.rightDocument(right.id);
      final snapshot = await document.get();

      if (snapshot.exists) {
        throw StateError(
          'Aynı kimlikle bir fikri mülkiyet hakkı zaten mevcut: '
          '${right.id}',
        );
      }

      await document.set(right.toCreateMap());

      return document.id;
    }

    final document = _refs.rights.doc();

    await document.set(right.toCreateMap());

    return document.id;
  }

  @override
  Future<void> update(IpRightModel right) async {
    _validateTenant(right.tenantId);
    _validateRight(right);

    final rightId = _validateRequiredId(right.id, fieldName: 'rightId');

    final document = _refs.rightDocument(rightId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Güncellenecek fikri mülkiyet hakkı bulunamadı: $rightId',
      );
    }

    final existingRight = IpRightModel.fromDocument(snapshot);

    _validateTenant(existingRight.tenantId);

    if (existingRight.brandId != right.brandId.trim()) {
      throw StateError(
        'Fikri mülkiyet hakkının bağlı olduğu marka değiştirilemez.',
      );
    }

    if (existingRight.assetId != right.assetId.trim()) {
      throw StateError(
        'Fikri mülkiyet hakkının bağlı olduğu varlık değiştirilemez.',
      );
    }

    if (existingRight.rightCode != right.rightCode.trim()) {
      throw StateError('Fikri mülkiyet hakkının hak kodu değiştirilemez.');
    }

    final registrationNumber = right.registrationNumber?.trim();

    if (registrationNumber != null && registrationNumber.isNotEmpty) {
      final duplicate = await findByRegistrationNumber(
        registrationNumber: registrationNumber,
        primaryCountryCode: right.primaryCountryCode,
      );

      if (duplicate != null && duplicate.id != rightId) {
        throw StateError(
          'Bu tescil numarası aynı ülke kapsamında başka bir kayıtta '
          'kullanılıyor.',
        );
      }
    }

    final actorId = _validateRequiredId(
      right.updatedBy ?? right.createdBy,
      fieldName: 'updatedBy',
    );

    await document.update(right.toUpdateMap(actorId: actorId));
  }

  @override
  Future<IpRightModel?> getById(String rightId) async {
    final snapshot = await _refs.rightDocument(rightId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final right = IpRightModel.fromDocument(snapshot);

    _validateTenant(right.tenantId);

    return right;
  }

  @override
  Future<IpRightModel?> findByRightCode({
    required String brandId,
    required String rightCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final cleanedRightCode = _validateRequiredText(
      rightCode,
      fieldName: 'rightCode',
    );

    final snapshot = await _refs
        .tenantQuery(_refs.rights)
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('rightCode', isEqualTo: cleanedRightCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return IpRightModel.fromDocument(snapshot.docs.first);
  }

  @override
  Future<IpRightModel?> findByRegistrationNumber({
    required String registrationNumber,
    String? primaryCountryCode,
  }) async {
    final cleanedRegistrationNumber = _validateRequiredText(
      registrationNumber,
      fieldName: 'registrationNumber',
    );

    Query<Map<String, dynamic>> query = _refs
        .tenantQuery(_refs.rights)
        .where('registrationNumber', isEqualTo: cleanedRegistrationNumber);

    final cleanedCountryCode = _cleanOptionalCountryCode(primaryCountryCode);

    if (cleanedCountryCode != null) {
      query = query.where('primaryCountryCode', isEqualTo: cleanedCountryCode);
    }

    final snapshot = await query.limit(1).get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return IpRightModel.fromDocument(snapshot.docs.first);
  }

  @override
  Future<List<IpRightModel>> listAll({
    String? brandId,
    String? assetId,
    IpRightType? rightType,
    IpRightStatus? status,
    IpRiskLevel? riskLevel,
    String? countryCode,
    int limit = 200,
  }) async {
    final query = _buildListQuery(
      brandId: brandId,
      assetId: assetId,
      rightType: rightType,
      status: status,
      riskLevel: riskLevel,
      countryCode: countryCode,
    );

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .get();

    return snapshot.docs.map(IpRightModel.fromDocument).toList(growable: false);
  }

  @override
  Stream<List<IpRightModel>> watchAll({
    String? brandId,
    String? assetId,
    IpRightType? rightType,
    IpRightStatus? status,
    IpRiskLevel? riskLevel,
    String? countryCode,
    int limit = 200,
  }) {
    final query = _buildListQuery(
      brandId: brandId,
      assetId: assetId,
      rightType: rightType,
      status: status,
      riskLevel: riskLevel,
      countryCode: countryCode,
    );

    return query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(IpRightModel.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Future<List<IpRightModel>> listUpcomingDeadlines({
    String? brandId,
    int days = 90,
    int limit = 200,
  }) async {
    final safeDays = _validateDays(days);
    final safeLimit = _validateLimit(limit);

    final rights = await listAll(brandId: brandId, limit: 500);

    final now = DateTime.now();
    final threshold = now.add(Duration(days: safeDays));

    final matches =
        rights
            .where((right) {
              final deadlines = <DateTime?>[
                right.nextRenewalAt,
                right.oppositionDeadlineAt,
                right.annuityDeadlineAt,
                right.expiryAt,
              ];

              return deadlines.whereType<DateTime>().any(
                (date) => !date.isBefore(now) && !date.isAfter(threshold),
              );
            })
            .toList(growable: false)
          ..sort((first, second) {
            final firstDate = _nearestFutureDeadline(first, now);
            final secondDate = _nearestFutureDeadline(second, now);

            if (firstDate == null && secondDate == null) {
              return 0;
            }

            if (firstDate == null) {
              return 1;
            }

            if (secondDate == null) {
              return -1;
            }

            return firstDate.compareTo(secondDate);
          });

    return List<IpRightModel>.unmodifiable(matches.take(safeLimit));
  }

  @override
  Future<List<IpRightModel>> listProtectionGaps({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    final rights = await listAll(brandId: brandId, limit: 500);

    final matches =
        rights.where((right) => right.hasProtectionGap).toList(growable: false)
          ..sort((first, second) {
            final riskComparison = _riskRank(
              second.riskLevel,
            ).compareTo(_riskRank(first.riskLevel));

            if (riskComparison != 0) {
              return riskComparison;
            }

            return first.rightStrengthScore.compareTo(
              second.rightStrengthScore,
            );
          });

    return List<IpRightModel>.unmodifiable(matches.take(safeLimit));
  }

  @override
  Future<void> updateStatus({
    required String rightId,
    required IpRightStatus status,
    required String updatedBy,
  }) async {
    final document = _refs.rightDocument(rightId);
    final right = await _requireOwnedRight(document);

    _validateTenant(right.tenantId);

    await document.update(<String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<void> updateRightStrengthScore({
    required String rightId,
    required int score,
    required String updatedBy,
  }) async {
    _validateScore(score, fieldName: 'rightStrengthScore');

    final document = _refs.rightDocument(rightId);
    final right = await _requireOwnedRight(document);

    _validateTenant(right.tenantId);

    await document.update(<String, dynamic>{
      'rightStrengthScore': score,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _validateRequiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<void> delete(String rightId) async {
    final document = _refs.rightDocument(rightId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final right = IpRightModel.fromDocument(snapshot);

    _validateTenant(right.tenantId);

    if (right.documentIds.isNotEmpty ||
        right.relationshipIds.isNotEmpty ||
        right.relatedRightIds.isNotEmpty ||
        right.patentFamilyIds.isNotEmpty ||
        right.oppositionActive ||
        right.disputeActive ||
        right.customsProtectionActive) {
      throw StateError(
        'Belge, ilişki, hak ailesi, itiraz, uyuşmazlık veya gümrük '
        'koruması bulunan fikri mülkiyet hakkı silinemez. '
        'Kaydı arşivleyin veya durumunu güncelleyin.',
      );
    }

    await document.delete();
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    String? assetId,
    IpRightType? rightType,
    IpRightStatus? status,
    IpRiskLevel? riskLevel,
    String? countryCode,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.rights);

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    final cleanedAssetId = _cleanOptionalId(assetId, fieldName: 'assetId');

    final cleanedCountryCode = _cleanOptionalCountryCode(countryCode);

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (cleanedAssetId != null) {
      query = query.where('assetId', isEqualTo: cleanedAssetId);
    }

    if (rightType != null) {
      query = query.where('rightType', isEqualTo: rightType.value);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (riskLevel != null) {
      query = query.where('riskLevel', isEqualTo: riskLevel.value);
    }

    if (cleanedCountryCode != null) {
      query = query.where('primaryCountryCode', isEqualTo: cleanedCountryCode);
    }

    return query;
  }

  Future<IpRightModel> _requireOwnedRight(
    DocumentReference<Map<String, dynamic>> document,
  ) async {
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'İşlem yapılacak fikri mülkiyet hakkı bulunamadı: '
        '${document.id}',
      );
    }

    final right = IpRightModel.fromDocument(snapshot);

    _validateTenant(right.tenantId);

    return right;
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError('IP right tenantId ile repository tenantId eşleşmiyor.');
    }
  }

  static void _validateRight(IpRightModel right) {
    if (!right.hasCompleteIdentity) {
      throw ArgumentError(
        'Fikri mülkiyet hakkının tenantId, brandId, assetId, '
        'rightCode ve title alanları zorunludur.',
      );
    }

    _validateRequiredId(right.tenantId, fieldName: 'tenantId');
    _validateRequiredId(right.brandId, fieldName: 'brandId');
    _validateRequiredId(right.assetId, fieldName: 'assetId');
    _validateRequiredText(right.rightCode, fieldName: 'rightCode');
    _validateRequiredText(right.title, fieldName: 'title');

    if (right.rightCode.trim().length > 100) {
      throw ArgumentError.value(
        right.rightCode,
        'rightCode',
        'rightCode 100 karakterden uzun olamaz.',
      );
    }

    if (right.title.trim().length > 300) {
      throw ArgumentError.value(
        right.title,
        'title',
        'Başlık 300 karakterden uzun olamaz.',
      );
    }

    if (right.description != null && right.description!.trim().length > 5000) {
      throw ArgumentError.value(
        right.description,
        'description',
        'Açıklama 5000 karakterden uzun olamaz.',
      );
    }

    if (right.notes != null && right.notes!.trim().length > 5000) {
      throw ArgumentError.value(
        right.notes,
        'notes',
        'Notlar 5000 karakterden uzun olamaz.',
      );
    }

    _validateScore(right.rightStrengthScore, fieldName: 'rightStrengthScore');

    final countryCode = right.primaryCountryCode?.trim();

    if (countryCode != null &&
        countryCode.isNotEmpty &&
        countryCode.length > 3) {
      throw ArgumentError.value(
        right.primaryCountryCode,
        'primaryCountryCode',
        'Ülke kodu en fazla 3 karakter olmalıdır.',
      );
    }

    if (right.nextRenewalAt != null &&
        right.expiryAt != null &&
        right.nextRenewalAt!.isAfter(right.expiryAt!)) {
      throw ArgumentError('nextRenewalAt, expiryAt tarihinden sonra olamaz.');
    }

    if (right.registrationAt != null &&
        right.expiryAt != null &&
        right.registrationAt!.isAfter(right.expiryAt!)) {
      throw ArgumentError('registrationAt, expiryAt tarihinden sonra olamaz.');
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

  static int _validateDays(int value) {
    if (value < 1 || value > 3650) {
      throw ArgumentError.value(
        value,
        'days',
        'days 1 ile 3650 arasında olmalıdır.',
      );
    }

    return value;
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

  static String? _cleanOptionalCountryCode(String? value) {
    final cleaned = value?.trim().toUpperCase();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    if (cleaned.length > 3) {
      throw ArgumentError.value(
        value,
        'countryCode',
        'Ülke kodu en fazla 3 karakter olmalıdır.',
      );
    }

    return cleaned;
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

  static DateTime? _nearestFutureDeadline(IpRightModel right, DateTime now) {
    final dates =
        <DateTime?>[
              right.nextRenewalAt,
              right.oppositionDeadlineAt,
              right.annuityDeadlineAt,
              right.expiryAt,
            ]
            .whereType<DateTime>()
            .where((date) => !date.isBefore(now))
            .toList(growable: false)
          ..sort();

    return dates.isEmpty ? null : dates.first;
  }
}
