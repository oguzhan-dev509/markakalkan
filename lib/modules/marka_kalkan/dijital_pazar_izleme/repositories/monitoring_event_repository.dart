import '../constants/monitoring_enums.dart';
import '../models/monitoring_event_model.dart';
import 'monitoring_repository_ports.dart';
import 'monitoring_firestore_refs.dart';

class MonitoringEventRepository implements MonitoringEventRepositoryPort {
  const MonitoringEventRepository({required MonitoringFirestoreRefs refs})
    : _refs = refs;

  factory MonitoringEventRepository.instance({required String tenantId}) {
    return MonitoringEventRepository(
      refs: MonitoringFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final MonitoringFirestoreRefs _refs;

  Future<String> create(MonitoringEventModel event) async {
    _validateTenant(event.tenantId);

    if (event.id.trim().isNotEmpty) {
      final document = _refs.monitoringEventDocument(event.id);

      await document.set(event.toCreateMap());

      return document.id;
    }

    final document = _refs.monitoringEvents.doc();

    await document.set(event.toCreateMap());

    return document.id;
  }

  @override
  Future<List<String>> createBatch(List<MonitoringEventModel> events) async {
    if (events.isEmpty) {
      return const <String>[];
    }

    final batch = _refs.monitoringEvents.firestore.batch();
    final ids = <String>[];

    for (final event in events) {
      _validateTenant(event.tenantId);

      final document = event.id.trim().isEmpty
          ? _refs.monitoringEvents.doc()
          : _refs.monitoringEventDocument(event.id);

      batch.set(document, event.toCreateMap());

      ids.add(document.id);
    }

    await batch.commit();

    return List<String>.unmodifiable(ids);
  }

  Future<MonitoringEventModel?> getById(String eventId) async {
    final document = await _refs.monitoringEventDocument(eventId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    final event = MonitoringEventModel.fromDocument(document);

    _validateTenant(event.tenantId);

    return event;
  }

  Future<List<MonitoringEventModel>> listForPage({
    required String pageId,
    int limit = 100,
  }) async {
    final cleanedPageId = _validateRequiredId(pageId, fieldName: 'pageId');

    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringEvents)
        .where('pageId', isEqualTo: cleanedPageId)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringEventModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringEventModel>> listByStatus({
    required MonitoringEventStatus status,
    int limit = 100,
  }) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringEvents)
        .where('status', isEqualTo: status.value)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringEventModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringEventModel>> listBySeverity({
    required MonitoringEventSeverity severity,
    int limit = 100,
  }) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringEvents)
        .where('severity', isEqualTo: severity.value)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringEventModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringEventModel>> listOpen({int limit = 100}) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringEvents)
        .where(
          'status',
          whereIn: <String>[
            MonitoringEventStatus.newEvent.value,
            MonitoringEventStatus.forwarded.value,
          ],
        )
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringEventModel.fromDocument)
        .toList(growable: false);
  }

  Stream<List<MonitoringEventModel>> watchRecent({int limit = 100}) {
    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.monitoringEvents)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (query) => query.docs
              .map(MonitoringEventModel.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<List<MonitoringEventModel>> watchForPage({
    required String pageId,
    int limit = 100,
  }) {
    final cleanedPageId = _validateRequiredId(pageId, fieldName: 'pageId');

    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.monitoringEvents)
        .where('pageId', isEqualTo: cleanedPageId)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (query) => query.docs
              .map(MonitoringEventModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> updateStatus({
    required String eventId,
    required MonitoringEventStatus status,
  }) async {
    final document = _refs.monitoringEventDocument(eventId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Güncellenecek izleme olayı bulunamadı: $eventId');
    }

    final event = MonitoringEventModel.fromDocument(snapshot);

    _validateTenant(event.tenantId);

    await document.update(event.toReviewUpdateMap(newStatus: status));
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError('Event tenantId ile repository tenantId eşleşmiyor.');
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
