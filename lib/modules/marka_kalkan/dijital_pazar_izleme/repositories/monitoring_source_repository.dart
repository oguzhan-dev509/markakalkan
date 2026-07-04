import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../models/monitoring_source_model.dart';
import 'monitoring_firestore_refs.dart';

class MonitoringSourceRepository {
  const MonitoringSourceRepository({required MonitoringFirestoreRefs refs})
    : _refs = refs;

  factory MonitoringSourceRepository.instance({required String tenantId}) {
    return MonitoringSourceRepository(
      refs: MonitoringFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final MonitoringFirestoreRefs _refs;

  Future<String> create(MonitoringSourceModel source) async {
    _validateTenant(source.tenantId);
    _validateSource(source);

    if (source.id.trim().isNotEmpty) {
      final document = _refs.monitoringSourceDocument(source.id);

      await document.set(source.toCreateMap());

      return document.id;
    }

    final document = _refs.monitoringSources.doc();

    await document.set(source.toCreateMap());

    return document.id;
  }

  Future<void> update(MonitoringSourceModel source) async {
    _validateTenant(source.tenantId);
    _validateSource(source);

    final sourceId = _validateRequiredId(source.id, fieldName: 'sourceId');

    final document = _refs.monitoringSourceDocument(sourceId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Güncellenecek izleme kaynağı bulunamadı: $sourceId');
    }

    final existingSource = MonitoringSourceModel.fromDocument(snapshot);

    _validateTenant(existingSource.tenantId);

    await document.update(source.toUpdateMap());
  }

  Future<MonitoringSourceModel?> getById(String sourceId) async {
    final snapshot = await _refs.monitoringSourceDocument(sourceId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final source = MonitoringSourceModel.fromDocument(snapshot);

    _validateTenant(source.tenantId);

    return source;
  }

  Future<List<MonitoringSourceModel>> listAll({int limit = 100}) async {
    final safeLimit = _validateLimit(limit);

    final snapshot = await _refs
        .tenantQuery(_refs.monitoringSources)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    return snapshot.docs
        .map(MonitoringSourceModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringSourceModel>> listActive({int limit = 100}) async {
    final safeLimit = _validateLimit(limit);

    final snapshot = await _refs
        .tenantQuery(_refs.monitoringSources)
        .where('status', isEqualTo: MonitoringRecordStatus.active.value)
        .orderBy('priority', descending: false)
        .limit(safeLimit)
        .get();

    final sources =
        snapshot.docs
            .map(MonitoringSourceModel.fromDocument)
            .toList(growable: false)
          ..sort(
            (first, second) => _priorityRank(
              first.priority,
            ).compareTo(_priorityRank(second.priority)),
          );

    return List<MonitoringSourceModel>.unmodifiable(sources);
  }

  Stream<List<MonitoringSourceModel>> watchAll({int limit = 100}) {
    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.monitoringSources)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MonitoringSourceModel.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<List<MonitoringSourceModel>> watchActive({int limit = 100}) {
    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.monitoringSources)
        .where('status', isEqualTo: MonitoringRecordStatus.active.value)
        .orderBy('priority', descending: false)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MonitoringSourceModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> updateStatus({
    required String sourceId,
    required MonitoringRecordStatus status,
    required String updatedBy,
  }) async {
    final document = _refs.monitoringSourceDocument(sourceId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Durumu güncellenecek izleme kaynağı bulunamadı: $sourceId',
      );
    }

    final source = MonitoringSourceModel.fromDocument(snapshot);

    _validateTenant(source.tenantId);

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

  Future<void> updateHealth({
    required String sourceId,
    required MonitoringSourceHealthStatus healthStatus,
    required String updatedBy,
  }) async {
    final document = _refs.monitoringSourceDocument(sourceId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Sağlık durumu güncellenecek kaynak bulunamadı: $sourceId',
      );
    }

    final source = MonitoringSourceModel.fromDocument(snapshot);

    _validateTenant(source.tenantId);

    final cleanedUpdatedBy = _validateRequiredId(
      updatedBy,
      fieldName: 'updatedBy',
    );

    await document.update(<String, dynamic>{
      'healthStatus': healthStatus.value,
      'lastCheckedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': cleanedUpdatedBy,
    });
  }

  Future<void> delete(String sourceId) async {
    final document = _refs.monitoringSourceDocument(sourceId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final source = MonitoringSourceModel.fromDocument(snapshot);

    _validateTenant(source.tenantId);

    await document.delete();
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Monitoring source tenantId ile repository tenantId eşleşmiyor.',
      );
    }
  }

  static void _validateSource(MonitoringSourceModel source) {
    if (source.name.trim().isEmpty) {
      throw ArgumentError.value(source.name, 'name', 'Kaynak adı boş olamaz.');
    }

    if (source.baseUrl.trim().isEmpty) {
      throw ArgumentError.value(
        source.baseUrl,
        'baseUrl',
        'Kaynak adresi boş olamaz.',
      );
    }

    final normalizedUrl = source.baseUrl.contains('://')
        ? source.baseUrl.trim()
        : 'https://${source.baseUrl.trim()}';

    final uri = Uri.tryParse(normalizedUrl);

    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      throw ArgumentError.value(
        source.baseUrl,
        'baseUrl',
        'Geçerli bir kaynak adresi girilmelidir.',
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
