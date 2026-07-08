import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/counterfeit_twin_enums.dart';
import '../models/counterfeit_twin_model.dart';
import 'counterfeit_twin_command_service.dart';
import 'counterfeit_twin_firestore_refs.dart';

class CounterfeitTwinRepository {
  CounterfeitTwinRepository({
    required CounterfeitTwinFirestoreRefs refs,
    CounterfeitTwinCommandService? commandService,
  }) : _refs = refs,
       _commandService = commandService ?? CounterfeitTwinCommandService();

  factory CounterfeitTwinRepository.instance({required String tenantId}) {
    return CounterfeitTwinRepository(
      refs: CounterfeitTwinFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final CounterfeitTwinFirestoreRefs _refs;
  final CounterfeitTwinCommandService _commandService;

  Future<CounterfeitTwinModel> create(CounterfeitTwinModel record) async {
    _validateRecord(record);

    final recordId = await _commandService.create(record);
    final created = await getById(recordId);

    if (created == null) {
      throw StateError(
        'Sahte ikiz kaydı oluşturuldu ancak tekrar okunamadı: $recordId',
      );
    }

    return created;
  }

  Future<void> update(
    CounterfeitTwinModel record, {
    required String actorId,
  }) async {
    _validateRecord(record);

    if (actorId.trim().isEmpty) {
      throw ArgumentError.value(actorId, 'actorId', 'actorId boş olamaz.');
    }

    await _commandService.update(record);
  }

  Future<CounterfeitTwinModel?> getById(String recordId) async {
    final document = await _refs.recordDocument(recordId).get();

    if (!document.exists) {
      return null;
    }

    final record = CounterfeitTwinModel.fromDocument(document);
    _validateTenant(record.tenantId);

    return record;
  }

  Future<CounterfeitTwinModel?> findByCode({
    required String brandId,
    required String recordCode,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');
    final normalizedCode = _normalizeCode(recordCode);

    final snapshot = await _refs.tenantRecords
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('recordCodeNormalized', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return CounterfeitTwinModel.fromDocument(snapshot.docs.first);
  }

  Future<List<CounterfeitTwinModel>> listAll({
    String? brandId,
    CounterfeitTwinStatus? status,
    CounterfeitTwinRiskLevel? riskLevel,
    CounterfeitTwinReviewStatus? reviewStatus,
    CounterfeitTwinCloneMethod? primaryCloneMethod,
    String? cloneFamilyId,
    String? waveId,
    int limit = 100,
  }) async {
    final query = _buildListQuery(
      brandId: brandId,
      status: status,
      riskLevel: riskLevel,
      reviewStatus: reviewStatus,
      primaryCloneMethod: primaryCloneMethod,
      cloneFamilyId: cloneFamilyId,
      waveId: waveId,
    );

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .get();

    return snapshot.docs
        .map(CounterfeitTwinModel.fromDocument)
        .toList(growable: false);
  }

  Stream<List<CounterfeitTwinModel>> watchAll({
    String? brandId,
    CounterfeitTwinStatus? status,
    CounterfeitTwinRiskLevel? riskLevel,
    CounterfeitTwinReviewStatus? reviewStatus,
    CounterfeitTwinCloneMethod? primaryCloneMethod,
    String? cloneFamilyId,
    String? waveId,
    int limit = 100,
  }) {
    final query = _buildListQuery(
      brandId: brandId,
      status: status,
      riskLevel: riskLevel,
      reviewStatus: reviewStatus,
      primaryCloneMethod: primaryCloneMethod,
      cloneFamilyId: cloneFamilyId,
      waveId: waveId,
    );

    return query
        .orderBy('createdAt', descending: true)
        .limit(_validateLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CounterfeitTwinModel.fromDocument)
              .toList(growable: false),
        );
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? brandId,
    CounterfeitTwinStatus? status,
    CounterfeitTwinRiskLevel? riskLevel,
    CounterfeitTwinReviewStatus? reviewStatus,
    CounterfeitTwinCloneMethod? primaryCloneMethod,
    String? cloneFamilyId,
    String? waveId,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantRecords;

    final cleanedBrandId = _cleanNullableId(brandId, fieldName: 'brandId');
    final cleanedCloneFamilyId = _cleanNullableId(
      cloneFamilyId,
      fieldName: 'cloneFamilyId',
    );
    final cleanedWaveId = _cleanNullableId(waveId, fieldName: 'waveId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (riskLevel != null) {
      query = query.where('riskLevel', isEqualTo: riskLevel.value);
    }

    if (reviewStatus != null) {
      query = query.where('reviewStatus', isEqualTo: reviewStatus.value);
    }

    if (primaryCloneMethod != null) {
      query = query.where(
        'primaryCloneMethod',
        isEqualTo: primaryCloneMethod.value,
      );
    }

    if (cleanedCloneFamilyId != null) {
      query = query.where('cloneFamilyId', isEqualTo: cleanedCloneFamilyId);
    }

    if (cleanedWaveId != null) {
      query = query.where('waveId', isEqualTo: cleanedWaveId);
    }

    return query;
  }

  void _validateRecord(CounterfeitTwinModel record) {
    _validateTenant(record.tenantId);
    _validateRequiredId(record.brandId, fieldName: 'brandId');
    _validateRequiredId(record.recordCode, fieldName: 'recordCode');

    if (record.title.trim().isEmpty) {
      throw ArgumentError.value(record.title, 'title', 'title boş olamaz.');
    }

    if (!record.hasValidScores) {
      throw ArgumentError(
        'Benzerlik ve anomali puanları 0 ile 100 arasında olmalıdır.',
      );
    }

    if (record.recurrenceCount < 0) {
      throw ArgumentError.value(
        record.recurrenceCount,
        'recurrenceCount',
        'recurrenceCount negatif olamaz.',
      );
    }
  }

  void _validateTenant(String tenantId) {
    if (tenantId.trim() != _refs.tenantId) {
      throw StateError('Sahte ikiz kaydı farklı tenant kapsamındadır.');
    }
  }

  static String _normalizeCode(String value) {
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

  static String? _cleanNullableId(String? value, {required String fieldName}) {
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
