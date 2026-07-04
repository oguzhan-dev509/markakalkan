import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../models/monitored_page_model.dart';
import 'monitoring_firestore_refs.dart';
import 'monitoring_repository_ports.dart';

class MonitoredPageRepository implements MonitoredPageRepositoryPort {
  const MonitoredPageRepository({required MonitoringFirestoreRefs refs})
    : _refs = refs;

  factory MonitoredPageRepository.instance({required String tenantId}) {
    return MonitoredPageRepository(
      refs: MonitoringFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final MonitoringFirestoreRefs _refs;

  @override
  Future<String> create(MonitoredPageModel page) async {
    _validateTenant(page.tenantId);
    _validatePage(page);

    final normalizedUrl = MonitoredPageModel.normalizeUrl(
      page.normalizedUrl.trim().isEmpty ? page.url : page.normalizedUrl,
    );

    final existing = await findByNormalizedUrl(
      brandId: page.brandId,
      normalizedUrl: normalizedUrl,
    );

    if (existing != null && existing.id != page.id.trim()) {
      throw StateError(
        'Bu URL seçilen marka profili için zaten izleniyor: '
        '${existing.title ?? existing.url}',
      );
    }

    final map = page.toCreateMap()
      ..['normalizedUrl'] = normalizedUrl
      ..['domain'] = page.domain?.trim().isNotEmpty == true
          ? page.domain!.trim().toLowerCase()
          : MonitoredPageModel.domainFromUrl(normalizedUrl);

    if (page.id.trim().isNotEmpty) {
      final document = _refs.monitoredPageDocument(page.id);

      final snapshot = await document.get();

      if (snapshot.exists) {
        throw StateError(
          'Aynı kimlikle bir izlenen sayfa zaten mevcut: ${page.id}',
        );
      }

      await document.set(map);

      return document.id;
    }

    final document = _refs.monitoredPages.doc();

    await document.set(map);

    return document.id;
  }

  @override
  Future<void> update(MonitoredPageModel page) async {
    _validateTenant(page.tenantId);
    _validatePage(page);

    final pageId = _validateRequiredId(page.id, fieldName: 'pageId');
    final document = _refs.monitoredPageDocument(pageId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Güncellenecek izlenen sayfa bulunamadı: $pageId');
    }

    final existingPage = MonitoredPageModel.fromDocument(snapshot);

    _validateTenant(existingPage.tenantId);

    if (existingPage.brandId != page.brandId) {
      throw StateError('İzlenen sayfanın bağlı marka profili değiştirilemez.');
    }

    if (existingPage.sourceId != page.sourceId) {
      throw StateError('İzlenen sayfanın bağlı kaynağı değiştirilemez.');
    }

    final normalizedUrl = MonitoredPageModel.normalizeUrl(
      page.normalizedUrl.trim().isEmpty ? page.url : page.normalizedUrl,
    );

    final duplicate = await findByNormalizedUrl(
      brandId: page.brandId,
      normalizedUrl: normalizedUrl,
    );

    if (duplicate != null && duplicate.id != pageId) {
      throw StateError(
        'Bu URL seçilen marka profili için başka bir kayıtta izleniyor.',
      );
    }

    final updateMap = page.toUpdateMap()
      ..['normalizedUrl'] = normalizedUrl
      ..['domain'] = page.domain?.trim().isNotEmpty == true
          ? page.domain!.trim().toLowerCase()
          : MonitoredPageModel.domainFromUrl(normalizedUrl);

    await document.update(updateMap);
  }

  @override
  Future<MonitoredPageModel?> getById(String pageId) async {
    final snapshot = await _refs.monitoredPageDocument(pageId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final page = MonitoredPageModel.fromDocument(snapshot);

    _validateTenant(page.tenantId);

    return page;
  }

  @override
  Future<MonitoredPageModel?> findByNormalizedUrl({
    required String brandId,
    required String normalizedUrl,
  }) async {
    final cleanedBrandId = _validateRequiredId(brandId, fieldName: 'brandId');

    final cleanedNormalizedUrl = MonitoredPageModel.normalizeUrl(normalizedUrl);

    if (cleanedNormalizedUrl.isEmpty) {
      return null;
    }

    final snapshot = await _refs
        .tenantQuery(_refs.monitoredPages)
        .where('brandId', isEqualTo: cleanedBrandId)
        .where('normalizedUrl', isEqualTo: cleanedNormalizedUrl)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return MonitoredPageModel.fromDocument(snapshot.docs.first);
  }

  @override
  Future<List<MonitoredPageModel>> listAll({
    String? brandId,
    String? sourceId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.monitoredPages);

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    final cleanedSourceId = _cleanOptionalId(sourceId, fieldName: 'sourceId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (cleanedSourceId != null) {
      query = query.where('sourceId', isEqualTo: cleanedSourceId);
    }

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    return snapshot.docs
        .map(MonitoredPageModel.fromDocument)
        .toList(growable: false);
  }

  @override
  Stream<List<MonitoredPageModel>> watchAll({
    String? brandId,
    String? sourceId,
    int limit = 200,
  }) {
    final safeLimit = _validateLimit(limit);

    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.monitoredPages);

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    final cleanedSourceId = _cleanOptionalId(sourceId, fieldName: 'sourceId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    if (cleanedSourceId != null) {
      query = query.where('sourceId', isEqualTo: cleanedSourceId);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MonitoredPageModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<List<MonitoredPageModel>> listActive({
    String? brandId,
    int limit = 200,
  }) async {
    final safeLimit = _validateLimit(limit);

    Query<Map<String, dynamic>> query = _refs
        .tenantQuery(_refs.monitoredPages)
        .where(
          'trackingStatus',
          isEqualTo: MonitoringPageTrackingStatus.active.value,
        );

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    final snapshot = await query
        .orderBy('riskScore', descending: true)
        .limit(safeLimit)
        .get();

    return snapshot.docs
        .map(MonitoredPageModel.fromDocument)
        .toList(growable: false);
  }

  Stream<List<MonitoredPageModel>> watchActive({
    String? brandId,
    int limit = 200,
  }) {
    final safeLimit = _validateLimit(limit);

    Query<Map<String, dynamic>> query = _refs
        .tenantQuery(_refs.monitoredPages)
        .where(
          'trackingStatus',
          isEqualTo: MonitoringPageTrackingStatus.active.value,
        );

    final cleanedBrandId = _cleanOptionalId(brandId, fieldName: 'brandId');

    if (cleanedBrandId != null) {
      query = query.where('brandId', isEqualTo: cleanedBrandId);
    }

    return query
        .orderBy('riskScore', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MonitoredPageModel.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Future<void> updateTrackingStatus({
    required String pageId,
    required MonitoringPageTrackingStatus trackingStatus,
    required String updatedBy,
  }) async {
    final document = _refs.monitoredPageDocument(pageId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('İzleme durumu güncellenecek sayfa bulunamadı: $pageId');
    }

    final page = MonitoredPageModel.fromDocument(snapshot);

    _validateTenant(page.tenantId);

    final cleanedUpdatedBy = _validateRequiredId(
      updatedBy,
      fieldName: 'updatedBy',
    );

    await document.update(<String, dynamic>{
      'trackingStatus': trackingStatus.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': cleanedUpdatedBy,
    });
  }

  Future<void> updateScanResult({
    required String pageId,
    required MonitoringPageStatus status,
    required DateTime scannedAt,
    required bool successful,
    String? snapshotId,
    String? crawlRunId,
    DateTime? nextScanAt,
  }) async {
    final document = _refs.monitoredPageDocument(pageId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Tarama sonucu güncellenecek sayfa bulunamadı: $pageId');
    }

    final page = MonitoredPageModel.fromDocument(snapshot);

    _validateTenant(page.tenantId);

    final data = <String, dynamic>{
      'status': status.value,
      'lastScannedAt': Timestamp.fromDate(scannedAt),
      'nextScanAt': nextScanAt == null ? null : Timestamp.fromDate(nextScanAt),
      'lastSnapshotId': _cleanNullable(snapshotId),
      'lastCrawlRunId': _cleanNullable(crawlRunId),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (successful) {
      data
        ..['lastSuccessfulScanAt'] = Timestamp.fromDate(scannedAt)
        ..['lastSeenAt'] = status == MonitoringPageStatus.active
            ? Timestamp.fromDate(scannedAt)
            : page.lastSeenAt == null
            ? null
            : Timestamp.fromDate(page.lastSeenAt!)
        ..['consecutiveFailureCount'] = 0;
    } else {
      data
        ..['lastFailedScanAt'] = Timestamp.fromDate(scannedAt)
        ..['consecutiveFailureCount'] = page.consecutiveFailureCount + 1;
    }

    if (status == MonitoringPageStatus.removed) {
      data['removedAt'] = Timestamp.fromDate(scannedAt);
    }

    if (status == MonitoringPageStatus.republished) {
      data['republishedAt'] = Timestamp.fromDate(scannedAt);
    }

    await document.update(data);
  }

  @override
  Future<void> delete(String pageId) async {
    final document = _refs.monitoredPageDocument(pageId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final page = MonitoredPageModel.fromDocument(snapshot);

    _validateTenant(page.tenantId);

    if (page.eventCount > 0 ||
        page.signalCount > 0 ||
        page.lastSnapshotId != null) {
      throw StateError(
        'Snapshot, olay veya sinyal geçmişi bulunan izlenen sayfa '
        'silinemez. Kaydı arşivleyin.',
      );
    }

    await document.delete();
  }

  void _validateTenant(String modelTenantId) {
    if (modelTenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Monitored page tenantId ile repository tenantId eşleşmiyor.',
      );
    }
  }

  static void _validatePage(MonitoredPageModel page) {
    if (page.tenantId.trim().isEmpty) {
      throw ArgumentError.value(
        page.tenantId,
        'tenantId',
        'tenantId boş olamaz.',
      );
    }

    if (page.brandId.trim().isEmpty) {
      throw ArgumentError.value(
        page.brandId,
        'brandId',
        'Marka profili seçilmelidir.',
      );
    }

    if (page.sourceId.trim().isEmpty) {
      throw ArgumentError.value(
        page.sourceId,
        'sourceId',
        'İzleme kaynağı seçilmelidir.',
      );
    }

    if (page.url.trim().isEmpty) {
      throw ArgumentError.value(
        page.url,
        'url',
        'İzlenecek sayfa adresi boş olamaz.',
      );
    }

    final normalizedUrl = MonitoredPageModel.normalizeUrl(page.url);
    final uri = Uri.tryParse(normalizedUrl);

    if (uri == null ||
        !uri.hasScheme ||
        !const <String>['http', 'https'].contains(uri.scheme) ||
        uri.host.trim().isEmpty) {
      throw ArgumentError.value(
        page.url,
        'url',
        'Geçerli bir HTTP veya HTTPS adresi girilmelidir.',
      );
    }

    if (page.title != null && page.title!.trim().length > 300) {
      throw ArgumentError.value(
        page.title,
        'title',
        'Sayfa başlığı 300 karakterden uzun olamaz.',
      );
    }

    if (page.notes != null && page.notes!.trim().length > 3000) {
      throw ArgumentError.value(
        page.notes,
        'notes',
        'Notlar 3000 karakterden uzun olamaz.',
      );
    }

    if (page.riskScore < 0 || page.riskScore > 100) {
      throw ArgumentError.value(
        page.riskScore,
        'riskScore',
        'Risk puanı 0 ile 100 arasında olmalıdır.',
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

  static String? _cleanOptionalId(String? value, {required String fieldName}) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return _validateRequiredId(cleaned, fieldName: fieldName);
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
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
