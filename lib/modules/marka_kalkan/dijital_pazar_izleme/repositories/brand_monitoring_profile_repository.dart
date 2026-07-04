import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../models/brand_monitoring_profile_model.dart';
import 'monitoring_firestore_refs.dart';

class BrandMonitoringProfileRepository {
  const BrandMonitoringProfileRepository({
    required MonitoringFirestoreRefs refs,
  }) : _refs = refs;

  factory BrandMonitoringProfileRepository.instance({
    required String tenantId,
  }) {
    return BrandMonitoringProfileRepository(
      refs: MonitoringFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final MonitoringFirestoreRefs _refs;

  Future<String> create(BrandMonitoringProfileModel profile) async {
    _validateTenant(profile.tenantId);
    _validateProfile(profile);

    if (profile.id.trim().isNotEmpty) {
      final document = _refs.brandMonitoringProfileDocument(profile.id);

      await document.set(profile.toCreateMap());

      return document.id;
    }

    final document = _refs.brandMonitoringProfiles.doc();

    await document.set(profile.toCreateMap());

    return document.id;
  }

  Future<void> update(BrandMonitoringProfileModel profile) async {
    _validateTenant(profile.tenantId);
    _validateProfile(profile);

    final profileId = _validateRequiredId(profile.id, fieldName: 'profileId');

    final document = _refs.brandMonitoringProfileDocument(profileId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Güncellenecek marka izleme profili bulunamadı: $profileId',
      );
    }

    final existingProfile = BrandMonitoringProfileModel.fromDocument(snapshot);

    _validateTenant(existingProfile.tenantId);

    await document.update(profile.toUpdateMap());
  }

  Future<BrandMonitoringProfileModel?> getById(String profileId) async {
    final document = await _refs
        .brandMonitoringProfileDocument(profileId)
        .get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    final profile = BrandMonitoringProfileModel.fromDocument(document);

    _validateTenant(profile.tenantId);

    return profile;
  }

  Future<List<BrandMonitoringProfileModel>> listAll({int limit = 100}) async {
    final safeLimit = _validateLimit(limit);

    final snapshot = await _refs
        .tenantQuery(_refs.brandMonitoringProfiles)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    return snapshot.docs
        .map(BrandMonitoringProfileModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<BrandMonitoringProfileModel>> listActive({
    int limit = 100,
  }) async {
    final safeLimit = _validateLimit(limit);

    final snapshot = await _refs
        .tenantQuery(_refs.brandMonitoringProfiles)
        .where('status', isEqualTo: MonitoringRecordStatus.active.value)
        .orderBy('priority', descending: false)
        .limit(safeLimit)
        .get();

    final profiles =
        snapshot.docs
            .map(BrandMonitoringProfileModel.fromDocument)
            .toList(growable: false)
          ..sort(
            (first, second) => _priorityRank(
              first.priority,
            ).compareTo(_priorityRank(second.priority)),
          );

    return List<BrandMonitoringProfileModel>.unmodifiable(profiles);
  }

  Stream<List<BrandMonitoringProfileModel>> watchAll({int limit = 100}) {
    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.brandMonitoringProfiles)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BrandMonitoringProfileModel.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<List<BrandMonitoringProfileModel>> watchActive({int limit = 100}) {
    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.brandMonitoringProfiles)
        .where('status', isEqualTo: MonitoringRecordStatus.active.value)
        .orderBy('priority', descending: false)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BrandMonitoringProfileModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> updateStatus({
    required String profileId,
    required MonitoringRecordStatus status,
    required String updatedBy,
  }) async {
    final document = _refs.brandMonitoringProfileDocument(profileId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Durumu güncellenecek marka izleme profili bulunamadı: $profileId',
      );
    }

    final profile = BrandMonitoringProfileModel.fromDocument(snapshot);

    _validateTenant(profile.tenantId);

    final cleanedUpdatedBy = _validateRequiredId(
      updatedBy,
      fieldName: 'updatedBy',
    );

    await document.update(<String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': cleanedUpdatedBy,
    });
  }

  Future<void> delete(String profileId) async {
    final document = _refs.brandMonitoringProfileDocument(profileId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final profile = BrandMonitoringProfileModel.fromDocument(snapshot);

    _validateTenant(profile.tenantId);

    await document.delete();
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Brand monitoring profile tenantId ile repository tenantId eşleşmiyor.',
      );
    }
  }

  static void _validateProfile(BrandMonitoringProfileModel profile) {
    if (profile.profileName.trim().isEmpty) {
      throw ArgumentError.value(
        profile.profileName,
        'profileName',
        'profileName boş olamaz.',
      );
    }

    if (profile.brandName.trim().isEmpty) {
      throw ArgumentError.value(
        profile.brandName,
        'brandName',
        'brandName boş olamaz.',
      );
    }

    if (profile.minimumPrice != null && profile.minimumPrice! < 0) {
      throw ArgumentError.value(
        profile.minimumPrice,
        'minimumPrice',
        'minimumPrice negatif olamaz.',
      );
    }

    if (profile.maximumPrice != null && profile.maximumPrice! < 0) {
      throw ArgumentError.value(
        profile.maximumPrice,
        'maximumPrice',
        'maximumPrice negatif olamaz.',
      );
    }

    if (profile.minimumPrice != null &&
        profile.maximumPrice != null &&
        profile.minimumPrice! > profile.maximumPrice!) {
      throw ArgumentError(
        'minimumPrice, maximumPrice değerinden büyük olamaz.',
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

  static int _priorityRank(MonitoringPriority priority) {
    switch (priority) {
      case MonitoringPriority.critical:
        return 0;
      case MonitoringPriority.high:
        return 1;
      case MonitoringPriority.normal:
        return 2;
      case MonitoringPriority.low:
        return 3;
    }
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
