import '../constants/monitoring_enums.dart';
import '../models/monitoring_signal_model.dart';
import 'monitoring_repository_ports.dart';
import 'monitoring_firestore_refs.dart';

class MonitoringSignalRepository implements MonitoringSignalRepositoryPort {
  const MonitoringSignalRepository({required MonitoringFirestoreRefs refs})
    : _refs = refs;

  factory MonitoringSignalRepository.instance({required String tenantId}) {
    return MonitoringSignalRepository(
      refs: MonitoringFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final MonitoringFirestoreRefs _refs;

  Future<String> create(MonitoringSignalModel signal) async {
    _validateTenant(signal.tenantId);

    if (signal.id.trim().isNotEmpty) {
      final document = _refs.monitoringSignalDocument(signal.id);

      await document.set(signal.toCreateMap());

      return document.id;
    }

    final document = _refs.monitoringSignals.doc();

    await document.set(signal.toCreateMap());

    return document.id;
  }

  @override
  Future<List<String>> createBatch(List<MonitoringSignalModel> signals) async {
    if (signals.isEmpty) {
      return const <String>[];
    }

    final batch = _refs.monitoringSignals.firestore.batch();
    final ids = <String>[];

    for (final signal in signals) {
      _validateTenant(signal.tenantId);

      final document = signal.id.trim().isEmpty
          ? _refs.monitoringSignals.doc()
          : _refs.monitoringSignalDocument(signal.id);

      batch.set(document, signal.toCreateMap());

      ids.add(document.id);
    }

    await batch.commit();

    return List<String>.unmodifiable(ids);
  }

  Future<MonitoringSignalModel?> getById(String signalId) async {
    final document = await _refs.monitoringSignalDocument(signalId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    final signal = MonitoringSignalModel.fromDocument(document);

    _validateTenant(signal.tenantId);

    return signal;
  }

  Future<List<MonitoringSignalModel>> listRecent({int limit = 100}) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringSignals)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringSignalModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringSignalModel>> listForEvent({
    required String eventId,
    int limit = 100,
  }) async {
    final cleanedEventId = _validateRequiredId(eventId, fieldName: 'eventId');

    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringSignals)
        .where('eventId', isEqualTo: cleanedEventId)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringSignalModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringSignalModel>> listForPage({
    required String pageId,
    int limit = 100,
  }) async {
    final cleanedPageId = _validateRequiredId(pageId, fieldName: 'pageId');

    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringSignals)
        .where('pageId', isEqualTo: cleanedPageId)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringSignalModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringSignalModel>> listByStatus({
    required MonitoringSignalStatus status,
    int limit = 100,
  }) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringSignals)
        .where('status', isEqualTo: status.value)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringSignalModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringSignalModel>> listByLevel({
    required MonitoringSignalLevel signalLevel,
    int limit = 100,
  }) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringSignals)
        .where('signalLevel', isEqualTo: signalLevel.value)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringSignalModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringSignalModel>> listOpen({int limit = 100}) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringSignals)
        .where(
          'status',
          whereIn: <String>[
            MonitoringSignalStatus.newSignal.value,
            MonitoringSignalStatus.underReview.value,
            MonitoringSignalStatus.confirmed.value,
            MonitoringSignalStatus.escalated.value,
          ],
        )
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringSignalModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<MonitoringSignalModel>> listForwardingFailures({
    int limit = 100,
  }) async {
    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.monitoringSignals)
        .where(
          'forwardingStatus',
          isEqualTo: MonitoringSignalForwardingStatus.failed.value,
        )
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(MonitoringSignalModel.fromDocument)
        .toList(growable: false);
  }

  Stream<List<MonitoringSignalModel>> watchRecent({int limit = 100}) {
    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.monitoringSignals)
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (query) => query.docs
              .map(MonitoringSignalModel.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<List<MonitoringSignalModel>> watchOpen({int limit = 100}) {
    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.monitoringSignals)
        .where(
          'status',
          whereIn: <String>[
            MonitoringSignalStatus.newSignal.value,
            MonitoringSignalStatus.underReview.value,
            MonitoringSignalStatus.confirmed.value,
            MonitoringSignalStatus.escalated.value,
          ],
        )
        .orderBy('detectedAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (query) => query.docs
              .map(MonitoringSignalModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> updateReviewStatus({
    required String signalId,
    required MonitoringSignalStatus status,
    required String reviewerId,
  }) async {
    final document = _refs.monitoringSignalDocument(signalId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('İncelenecek izleme sinyali bulunamadı: $signalId');
    }

    final signal = MonitoringSignalModel.fromDocument(snapshot);

    _validateTenant(signal.tenantId);

    final cleanedReviewerId = _validateRequiredId(
      reviewerId,
      fieldName: 'reviewerId',
    );

    await document.update(
      signal.toReviewUpdateMap(
        newStatus: status,
        reviewerId: cleanedReviewerId,
      ),
    );
  }

  Future<void> updateForwardingStatus({
    required String signalId,
    required MonitoringSignalForwardingStatus status,
    String? errorMessage,
  }) async {
    final document = _refs.monitoringSignalDocument(signalId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'İletim durumu güncellenecek sinyal bulunamadı: $signalId',
      );
    }

    final signal = MonitoringSignalModel.fromDocument(snapshot);

    _validateTenant(signal.tenantId);

    await document.update(
      signal.toForwardingUpdateMap(
        newStatus: status,
        errorMessage: errorMessage,
      ),
    );
  }

  Future<void> resolve({
    required String signalId,
    required String resolverId,
    required String note,
  }) async {
    final document = _refs.monitoringSignalDocument(signalId);

    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError(
        'Sonuçlandırılacak izleme sinyali bulunamadı: $signalId',
      );
    }

    final signal = MonitoringSignalModel.fromDocument(snapshot);

    _validateTenant(signal.tenantId);

    final cleanedResolverId = _validateRequiredId(
      resolverId,
      fieldName: 'resolverId',
    );

    final cleanedNote = note.trim();

    if (cleanedNote.isEmpty) {
      throw ArgumentError.value(note, 'note', 'Sonuçlandırma notu boş olamaz.');
    }

    await document.update(
      signal.toResolutionUpdateMap(
        resolverId: cleanedResolverId,
        note: cleanedNote,
      ),
    );
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError('Signal tenantId ile repository tenantId eşleşmiyor.');
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
