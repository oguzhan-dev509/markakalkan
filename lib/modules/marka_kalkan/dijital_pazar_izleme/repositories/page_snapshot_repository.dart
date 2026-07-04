import '../models/page_snapshot_model.dart';
import 'monitoring_repository_ports.dart';
import 'monitoring_firestore_refs.dart';

class PageSnapshotRepository implements PageSnapshotRepositoryPort {
  const PageSnapshotRepository({required MonitoringFirestoreRefs refs})
    : _refs = refs;

  factory PageSnapshotRepository.instance({required String tenantId}) {
    return PageSnapshotRepository(
      refs: MonitoringFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final MonitoringFirestoreRefs _refs;

  @override
  Future<String> create(PageSnapshotModel snapshot) async {
    _validateTenant(snapshot.tenantId);

    if (snapshot.id.trim().isNotEmpty) {
      final document = _refs.pageSnapshotDocument(snapshot.id);

      await document.set(snapshot.toCreateMap());

      return document.id;
    }

    final document = _refs.pageSnapshots.doc();

    await document.set(snapshot.toCreateMap());

    return document.id;
  }

  Future<PageSnapshotModel?> getById(String snapshotId) async {
    final document = await _refs.pageSnapshotDocument(snapshotId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    final snapshot = PageSnapshotModel.fromDocument(document);

    _validateTenant(snapshot.tenantId);

    return snapshot;
  }

  @override
  Future<PageSnapshotModel?> getLatestForPage(String pageId) async {
    final cleanedPageId = _validateRequiredId(pageId, fieldName: 'pageId');

    final query = await _refs
        .tenantQuery(_refs.pageSnapshots)
        .where('pageId', isEqualTo: cleanedPageId)
        .orderBy('capturedAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return PageSnapshotModel.fromDocument(query.docs.first);
  }

  Future<List<PageSnapshotModel>> listForPage({
    required String pageId,
    int limit = 50,
  }) async {
    final cleanedPageId = _validateRequiredId(pageId, fieldName: 'pageId');

    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.pageSnapshots)
        .where('pageId', isEqualTo: cleanedPageId)
        .orderBy('capturedAt', descending: true)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(PageSnapshotModel.fromDocument)
        .toList(growable: false);
  }

  Stream<List<PageSnapshotModel>> watchForPage({
    required String pageId,
    int limit = 50,
  }) {
    final cleanedPageId = _validateRequiredId(pageId, fieldName: 'pageId');

    final safeLimit = _validateLimit(limit);

    return _refs
        .tenantQuery(_refs.pageSnapshots)
        .where('pageId', isEqualTo: cleanedPageId)
        .orderBy('capturedAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (query) => query.docs
              .map(PageSnapshotModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<List<PageSnapshotModel>> listForCrawlRun({
    required String crawlRunId,
    int limit = 100,
  }) async {
    final cleanedRunId = _validateRequiredId(
      crawlRunId,
      fieldName: 'crawlRunId',
    );

    final safeLimit = _validateLimit(limit);

    final query = await _refs
        .tenantQuery(_refs.pageSnapshots)
        .where('crawlRunId', isEqualTo: cleanedRunId)
        .orderBy('capturedAt', descending: false)
        .limit(safeLimit)
        .get();

    return query.docs
        .map(PageSnapshotModel.fromDocument)
        .toList(growable: false);
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError('Snapshot tenantId ile repository tenantId eşleşmiyor.');
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
