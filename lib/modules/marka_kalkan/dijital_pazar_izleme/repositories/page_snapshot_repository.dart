import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../models/page_snapshot_model.dart';
import '../services/snapshot_fingerprint_service.dart';
import 'monitoring_firestore_refs.dart';
import 'monitoring_repository_ports.dart';

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
    final result = await createVersioned(snapshot);
    return result.snapshotId;
  }

  @override
  Future<PageSnapshotCreateResult> createVersioned(
    PageSnapshotModel snapshot,
  ) async {
    _validateTenant(snapshot.tenantId);

    final prepared = SnapshotFingerprintService.prepare(snapshot);

    final snapshotId = SnapshotFingerprintService.deterministicSnapshotId(
      tenantId: prepared.tenantId,
      pageId: prepared.pageId,
      crawlRunId: prepared.crawlRunId,
    );

    final snapshotDocument = _refs.pageSnapshotDocument(snapshotId);
    final pageDocument = _refs.monitoredPageDocument(prepared.pageId);

    return _refs.pageSnapshots.firestore.runTransaction((transaction) async {
      final pageRead = await transaction.get(pageDocument);

      if (!pageRead.exists || pageRead.data() == null) {
        throw StateError(
          'Snapshot için izlenen sayfa bulunamadı: ${prepared.pageId}',
        );
      }

      final pageData = pageRead.data()!;

      if (pageData['tenantId']?.toString().trim() != _refs.tenantId) {
        throw StateError('İzlenen sayfa farklı tenant kaydına ait.');
      }

      final existingRead = await transaction.get(snapshotDocument);

      if (existingRead.exists && existingRead.data() != null) {
        final existing = PageSnapshotModel.fromDocument(existingRead);

        _validateTenant(existing.tenantId);

        PageSnapshotModel? previous;

        if (existing.previousSnapshotId != null) {
          final previousRead = await transaction.get(
            _refs.pageSnapshotDocument(existing.previousSnapshotId!),
          );

          if (previousRead.exists && previousRead.data() != null) {
            previous = PageSnapshotModel.fromDocument(previousRead);
          }
        }

        return PageSnapshotCreateResult(
          snapshot: existing,
          previousSnapshot: previous,
          wasCreated: false,
        );
      }

      final previousSnapshotId = _nullableString(pageData['lastSnapshotId']);

      PageSnapshotModel? previousSnapshot;
      var versionNumber = 1;

      if (previousSnapshotId != null) {
        final previousRead = await transaction.get(
          _refs.pageSnapshotDocument(previousSnapshotId),
        );

        if (previousRead.exists && previousRead.data() != null) {
          previousSnapshot = PageSnapshotModel.fromDocument(previousRead);
          _validateTenant(previousSnapshot.tenantId);
          versionNumber = previousSnapshot.versionNumber + 1;
        }
      }

      final persisted = _copySnapshot(
        prepared,
        id: snapshotId,
        previousSnapshotId: previousSnapshot?.id,
        versionNumber: versionNumber,
      );

      transaction.set(snapshotDocument, persisted.toCreateMap());

      transaction.update(pageDocument, <String, dynamic>{
        'previousSnapshotId': previousSnapshot?.id,
        'lastSnapshotId': snapshotId,
        'lastCrawlRunId': prepared.crawlRunId,
        'lastScannedAt': Timestamp.fromDate(prepared.capturedAt),
        'lastSuccessfulScanAt': Timestamp.fromDate(prepared.capturedAt),
        'lastFailedScanAt': null,
        'consecutiveFailureCount': 0,
        'status': prepared.pageStatus.value,
        'sellerName': prepared.sellerName,
        'storeName': prepared.storeName,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': null,
      });

      return PageSnapshotCreateResult(
        snapshot: persisted,
        previousSnapshot: previousSnapshot,
        wasCreated: true,
      );
    });
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
        .orderBy('versionNumber', descending: true)
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
        .orderBy('versionNumber', descending: true)
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
        .orderBy('versionNumber', descending: true)
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
        .orderBy('capturedAt')
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

  static PageSnapshotModel _copySnapshot(
    PageSnapshotModel source, {
    required String id,
    required String? previousSnapshotId,
    required int versionNumber,
  }) {
    return PageSnapshotModel(
      id: id,
      tenantId: source.tenantId,
      brandId: source.brandId,
      sourceId: source.sourceId,
      pageId: source.pageId,
      crawlRunId: source.crawlRunId,
      previousSnapshotId: previousSnapshotId,
      versionNumber: versionNumber,
      capturedAt: source.capturedAt,
      pageStatus: source.pageStatus,
      title: source.title,
      description: source.description,
      price: source.price,
      currency: source.currency,
      stockStatus: source.stockStatus,
      sellerName: source.sellerName,
      storeName: source.storeName,
      imageUrls: source.imageUrls,
      mediaAssetIds: source.mediaAssetIds,
      contactSummary: source.contactSummary,
      textHash: source.textHash,
      contentHash: source.contentHash,
      imageSetHash: source.imageSetHash,
      htmlArchivePath: source.htmlArchivePath,
      screenshotAssetId: source.screenshotAssetId,
      parserVersion: source.parserVersion,
      createdAt: source.createdAt,
    );
  }

  static String? _nullableString(dynamic value) {
    final cleaned = value?.toString().trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
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
