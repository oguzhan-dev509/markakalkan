import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_creation_priority_enums.dart';
import '../models/ip_creation_priority_record_model.dart';
import '../models/ip_creation_priority_version_model.dart';
import 'ip_creation_priority_command_service.dart';
import 'ip_creation_priority_firestore_refs.dart';

class IpCreationPriorityRepository {
  IpCreationPriorityRepository({
    required IpCreationPriorityFirestoreRefs refs,
    IpCreationPriorityCommandService? commandService,
  }) : _refs = refs,
       _commandService = commandService ?? IpCreationPriorityCommandService();

  factory IpCreationPriorityRepository.instance({required String tenantId}) {
    return IpCreationPriorityRepository(
      refs: IpCreationPriorityFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final IpCreationPriorityFirestoreRefs _refs;
  final IpCreationPriorityCommandService _commandService;

  Future<String> ensureOwnerIdentity() {
    return _commandService.ensureOwnerIdentity();
  }

  Future<IpCreationPriorityRecordModel> createDraft({
    required IpCreationPriorityRecordModel record,
    required IpCreationPriorityVersionModel version,
  }) async {
    _validateDraftPair(record: record, version: version);

    final result = await _commandService.createDraft(
      record: record,
      version: version,
    );

    final created = await getRecordById(result.recordId);

    if (created == null) {
      throw StateError(
        'Yaratım öncelik taslağı oluşturuldu ancak tekrar okunamadı.',
      );
    }

    return created;
  }

  Future<void> updateDraft({
    required IpCreationPriorityRecordModel record,
    required IpCreationPriorityVersionModel version,
  }) async {
    _validateDraftPair(record: record, version: version);

    if (record.id.trim().isEmpty || version.id.trim().isEmpty) {
      throw ArgumentError(
        'Taslak güncelleme için kayıt ve sürüm kimlikleri zorunludur.',
      );
    }

    await _commandService.updateDraft(record: record, version: version);
  }

  Future<String> sealRecord({
    required IpCreationPriorityRecordModel record,
  }) async {
    _validateTenant(record.tenantId);

    final recordId = _validateRequiredId(record.id, fieldName: 'recordId');
    final versionId = _validateRequiredId(
      record.activeVersionId ?? '',
      fieldName: 'activeVersionId',
    );

    if (record.status != IpCreationPriorityStatus.draft ||
        record.sealStatus != IpCreationSealStatus.unsealed) {
      throw StateError('Yalnız mühürlenmemiş taslak kayıt mühürlenebilir.');
    }

    return _commandService.sealRecord(recordId: recordId, versionId: versionId);
  }

  Future<IpCreationPriorityRecordModel> createVersion({
    required IpCreationPriorityRecordModel record,
    required IpCreationPriorityVersionModel version,
  }) async {
    _validateTenant(record.tenantId);
    _validateTenant(version.tenantId);

    if (record.isArchived || !record.isSealed) {
      throw StateError(
        'Yeni sürüm yalnız mühürlenmiş ve aktif kayda eklenebilir.',
      );
    }

    final result = await _commandService.createVersion(
      record: record,
      version: version,
    );

    final updated = await getRecordById(result.recordId);

    if (updated == null) {
      throw StateError(
        'Yeni sürüm oluşturuldu ancak ana kayıt tekrar okunamadı.',
      );
    }

    return updated;
  }

  Future<IpCreationPriorityRecordModel?> getRecordById(String recordId) async {
    final snapshot = await _refs.recordDocument(recordId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final record = IpCreationPriorityRecordModel.fromDocument(snapshot);

    _validateTenant(record.tenantId);

    return record;
  }

  Future<IpCreationPriorityVersionModel?> getVersionById(
    String versionId,
  ) async {
    final snapshot = await _refs.versionDocument(versionId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final version = IpCreationPriorityVersionModel.fromDocument(snapshot);

    _validateTenant(version.tenantId);

    return version;
  }

  Future<IpCreationPriorityRecordModel?> findRecordByCode({
    required String brandId,
    required String recordCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final normalizedCode = _normalizeRecordCode(recordCode);

    final snapshot = await _refs.tenantRecords
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('recordCodeNormalized', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final record = IpCreationPriorityRecordModel.fromDocument(
      snapshot.docs.first,
    );

    _validateTenant(record.tenantId);

    return record;
  }

  Future<List<IpCreationPriorityRecordModel>> listRecords({
    String? brandId,
    IpCreationType? creationType,
    IpCreationPriorityStatus? status,
    IpCreationConfidentialityLevel? confidentialityLevel,
    IpCreationSealStatus? sealStatus,
    int limit = 100,
  }) async {
    final query = _buildRecordQuery(
      brandId: brandId,
      creationType: creationType,
      status: status,
      confidentialityLevel: confidentialityLevel,
      sealStatus: sealStatus,
    );

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .get();

    return snapshot.docs
        .map(IpCreationPriorityRecordModel.fromDocument)
        .toList(growable: false);
  }

  Stream<List<IpCreationPriorityRecordModel>> watchRecords({
    String? brandId,
    IpCreationType? creationType,
    IpCreationPriorityStatus? status,
    IpCreationConfidentialityLevel? confidentialityLevel,
    IpCreationSealStatus? sealStatus,
    int limit = 100,
  }) {
    final query = _buildRecordQuery(
      brandId: brandId,
      creationType: creationType,
      status: status,
      confidentialityLevel: confidentialityLevel,
      sealStatus: sealStatus,
    );

    return query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(IpCreationPriorityRecordModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<List<IpCreationPriorityVersionModel>> listVersions({
    required String recordId,
    int limit = 100,
  }) async {
    final cleanedRecordId = _validateRequiredId(
      recordId,
      fieldName: 'recordId',
    );

    final snapshot = await _refs
        .versionsForRecord(cleanedRecordId)
        .orderBy('versionNumber')
        .limit(_validateLimit(limit))
        .get();

    final versions = snapshot.docs
        .map(IpCreationPriorityVersionModel.fromDocument)
        .toList(growable: false);

    for (final version in versions) {
      _validateTenant(version.tenantId);

      if (version.recordId.trim() != cleanedRecordId) {
        throw StateError('Yaratım öncelik sürümü farklı kayıt kapsamındadır.');
      }
    }

    return versions;
  }

  Stream<List<IpCreationPriorityVersionModel>> watchVersions({
    required String recordId,
    int limit = 100,
  }) {
    final cleanedRecordId = _validateRequiredId(
      recordId,
      fieldName: 'recordId',
    );

    return _refs
        .versionsForRecord(cleanedRecordId)
        .orderBy('versionNumber')
        .limit(_validateLimit(limit))
        .snapshots()
        .map((snapshot) {
          final versions = snapshot.docs
              .map(IpCreationPriorityVersionModel.fromDocument)
              .toList(growable: false);

          for (final version in versions) {
            _validateTenant(version.tenantId);

            if (version.recordId.trim() != cleanedRecordId) {
              throw StateError(
                'Yaratım öncelik sürümü farklı kayıt kapsamındadır.',
              );
            }
          }

          return versions;
        });
  }

  Future<IpCreationPriorityVersionModel?> getActiveVersion(
    IpCreationPriorityRecordModel record,
  ) async {
    _validateTenant(record.tenantId);

    final activeVersionId = record.activeVersionId?.trim();

    if (activeVersionId == null || activeVersionId.isEmpty) {
      return null;
    }

    final version = await getVersionById(activeVersionId);

    if (version == null) {
      return null;
    }

    if (version.recordId.trim() != record.id.trim()) {
      throw StateError('Aktif sürüm, yaratım öncelik kaydıyla eşleşmiyor.');
    }

    return version;
  }

  Query<Map<String, dynamic>> _buildRecordQuery({
    String? brandId,
    IpCreationType? creationType,
    IpCreationPriorityStatus? status,
    IpCreationConfidentialityLevel? confidentialityLevel,
    IpCreationSealStatus? sealStatus,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantRecords;

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (creationType != null) {
      query = query.where('creationType', isEqualTo: creationType.value);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (confidentialityLevel != null) {
      query = query.where(
        'confidentialityLevel',
        isEqualTo: confidentialityLevel.value,
      );
    }

    if (sealStatus != null) {
      query = query.where('sealStatus', isEqualTo: sealStatus.value);
    }

    return query;
  }

  void _validateDraftPair({
    required IpCreationPriorityRecordModel record,
    required IpCreationPriorityVersionModel version,
  }) {
    _validateTenant(record.tenantId);
    _validateTenant(version.tenantId);

    if (!record.hasCompleteIdentity) {
      throw ArgumentError(
        'Yaratım öncelik kaydının zorunlu kimlik alanları eksik.',
      );
    }

    if (!version.hasCompleteIdentity) {
      throw ArgumentError(
        'Yaratım öncelik sürümünün zorunlu kimlik alanları eksik.',
      );
    }

    if (record.status != IpCreationPriorityStatus.draft ||
        record.sealStatus != IpCreationSealStatus.unsealed) {
      throw StateError('Yalnız mühürlenmemiş taslak kayıt yazılabilir.');
    }

    if (version.versionNumber != 1 ||
        version.sealStatus != IpCreationSealStatus.unsealed) {
      throw StateError(
        'Taslak yazma işlemi yalnız mühürlenmemiş ilk sürüm içindir.',
      );
    }

    final recordId = record.id.trim();
    final versionRecordId = version.recordId.trim();

    if (recordId.isNotEmpty && versionRecordId != recordId) {
      throw StateError('Taslak sürüm, yaratım öncelik kaydıyla eşleşmiyor.');
    }
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Yaratım Öncelik Sicili kaydı farklı tenant kapsamındadır.',
      );
    }
  }

  static String _normalizeRecordCode(String value) {
    final cleaned = value.trim().toUpperCase();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, 'recordCode', 'recordCode boş olamaz.');
    }

    return cleaned;
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

  static String? _cleanOptionalId(String? value, {required String fieldName}) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return _validateRequiredId(cleaned, fieldName: fieldName);
  }

  static int _validateLimit(int value) {
    if (value < 1 || value > 500) {
      throw RangeError.range(value, 1, 500, 'limit');
    }

    return value;
  }
}
