import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../models/crawl_job_model.dart';
import '../models/crawl_run_model.dart';
import 'monitoring_firestore_refs.dart';
import 'monitoring_repository_ports.dart';

class CrawlJobRepository implements CrawlJobRepositoryPort {
  CrawlJobRepository({
    required MonitoringFirestoreRefs refs,
    FirebaseFirestore? firestore,
  }) : _refs = refs,
       _firestore = firestore ?? FirebaseFirestore.instance;

  factory CrawlJobRepository.instance({required String tenantId}) {
    return CrawlJobRepository(
      refs: MonitoringFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final MonitoringFirestoreRefs _refs;
  final FirebaseFirestore _firestore;

  @override
  Future<String> create(CrawlJobModel job) async {
    _validateTenant(job.tenantId);
    _validateJob(job);

    final pageId = _requiredId(job.pageId ?? job.targetId, fieldName: 'pageId');

    final duplicate = await findActiveForPage(pageId);

    if (duplicate != null && duplicate.id != job.id.trim()) {
      throw StateError(
        'Bu izlenen sayfa için zaten aktif bir tarama görevi var: '
        '${duplicate.name}',
      );
    }

    final document = job.id.trim().isEmpty
        ? _refs.crawlJobs.doc()
        : _refs.crawlJobDocument(job.id);

    if (job.id.trim().isNotEmpty) {
      final existing = await document.get();

      if (existing.exists) {
        throw StateError(
          'Aynı kimlikle bir tarama görevi zaten mevcut: ${job.id}',
        );
      }
    }

    await document.set(
      job.toCreateMap()
        ..['pageId'] = pageId
        ..['targetId'] = job.targetId.trim().isEmpty
            ? pageId
            : job.targetId.trim(),
    );

    return document.id;
  }

  @override
  Future<void> update(CrawlJobModel job) async {
    _validateTenant(job.tenantId);
    _validateJob(job);

    final jobId = _requiredId(job.id, fieldName: 'jobId');
    final document = _refs.crawlJobDocument(jobId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Güncellenecek tarama görevi bulunamadı: $jobId');
    }

    final current = CrawlJobModel.fromDocument(snapshot);

    _validateTenant(current.tenantId);

    if (current.brandId != job.brandId) {
      throw StateError('Görevin marka bağlantısı değiştirilemez.');
    }

    if (current.profileId != job.profileId) {
      throw StateError('Görevin izleme profili değiştirilemez.');
    }

    if (current.sourceId != job.sourceId) {
      throw StateError('Görevin kaynak bağlantısı değiştirilemez.');
    }

    final pageId = _requiredId(job.pageId ?? job.targetId, fieldName: 'pageId');

    final duplicate = await findActiveForPage(pageId);

    if (duplicate != null && duplicate.id != jobId) {
      throw StateError(
        'Bu izlenen sayfa için başka bir aktif görev bulunuyor.',
      );
    }

    await document.update(
      job.toUpdateMap()
        ..['pageId'] = pageId
        ..['targetId'] = job.targetId.trim().isEmpty
            ? pageId
            : job.targetId.trim(),
    );
  }

  @override
  Future<CrawlJobModel?> getById(String jobId) async {
    final snapshot = await _refs.crawlJobDocument(jobId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final job = CrawlJobModel.fromDocument(snapshot);

    _validateTenant(job.tenantId);

    return job;
  }

  @override
  Future<CrawlJobModel?> findActiveForPage(String pageId) async {
    final cleanedPageId = _requiredId(pageId, fieldName: 'pageId');

    final snapshot = await _refs
        .tenantQuery(_refs.crawlJobs)
        .where('pageId', isEqualTo: cleanedPageId)
        .where('status', whereIn: const <String>['draft', 'active', 'paused'])
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return CrawlJobModel.fromDocument(snapshot.docs.first);
  }

  @override
  Future<List<CrawlJobModel>> listAll({
    String? profileId,
    String? sourceId,
    String? pageId,
    int limit = 200,
  }) async {
    final query = _buildListQuery(
      profileId: profileId,
      sourceId: sourceId,
      pageId: pageId,
    );

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_validatedLimit(limit))
        .get();

    return snapshot.docs
        .map(CrawlJobModel.fromDocument)
        .toList(growable: false);
  }

  @override
  Stream<List<CrawlJobModel>> watchAll({
    String? profileId,
    String? sourceId,
    String? pageId,
    int limit = 200,
  }) {
    final query = _buildListQuery(
      profileId: profileId,
      sourceId: sourceId,
      pageId: pageId,
    );

    return query
        .orderBy('createdAt', descending: true)
        .limit(_validatedLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CrawlJobModel.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Future<void> updateStatus({
    required String jobId,
    required MonitoringCrawlJobStatus status,
    required String updatedBy,
  }) async {
    final document = _refs.crawlJobDocument(jobId);
    final snapshot = await document.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Durumu güncellenecek tarama görevi bulunamadı: $jobId');
    }

    final job = CrawlJobModel.fromDocument(snapshot);

    _validateTenant(job.tenantId);

    if (job.isLeased) {
      throw StateError(
        'Kuyrukta veya çalışmakta olan görevin durumu değiştirilemez. '
        'Önce mevcut çalışma tamamlanmalı ya da lease süresi dolmalıdır.',
      );
    }

    await document.update(<String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _requiredId(updatedBy, fieldName: 'updatedBy'),
    });
  }

  @override
  Future<String> enqueueRun({
    required String jobId,
    required String requestedBy,
    required String requestKey,
    MonitoringCrawlTriggerType triggerType = MonitoringCrawlTriggerType.manual,
  }) async {
    final cleanedJobId = _requiredId(jobId, fieldName: 'jobId');
    final cleanedRequestedBy = _requiredId(
      requestedBy,
      fieldName: 'requestedBy',
    );
    final cleanedRequestKey = _normalizeRequestKey(requestKey);
    final runDocumentId = _tenantSafeRunDocumentId(cleanedRequestKey);

    final jobDocument = _refs.crawlJobDocument(cleanedJobId);
    final runDocument = _refs.crawlRuns.doc(runDocumentId);

    return _firestore.runTransaction<String>((transaction) async {
      final jobSnapshot = await transaction.get(jobDocument);
      final runSnapshot = await transaction.get(runDocument);

      if (runSnapshot.exists && runSnapshot.data() != null) {
        final existingRun = CrawlRunModel.fromDocument(runSnapshot);
        _validateTenant(existingRun.tenantId);

        return existingRun.id;
      }

      if (!jobSnapshot.exists || jobSnapshot.data() == null) {
        throw StateError(
          'Kuyruğa alınacak tarama görevi bulunamadı: $cleanedJobId',
        );
      }

      final job = CrawlJobModel.fromDocument(jobSnapshot);

      _validateTenant(job.tenantId);

      if (job.status != MonitoringCrawlJobStatus.active) {
        throw StateError('Yalnız aktif tarama görevleri kuyruğa alınabilir.');
      }

      final now = DateTime.now();

      if (job.leaseOwner != null &&
          job.leaseExpiresAt != null &&
          job.leaseExpiresAt!.isAfter(now)) {
        throw StateError(
          'Bu görev zaten kuyrukta veya başka bir çalışma tarafından '
          'yürütülüyor.',
        );
      }

      final queueLeaseExpiresAt = now.add(const Duration(minutes: 30));
      final queueLeaseOwner = 'queue:${runDocument.id}';

      final run = CrawlRunModel(
        id: runDocument.id,
        tenantId: job.tenantId,
        brandId: job.brandId,
        profileId: job.profileId,
        jobId: job.id,
        sourceId: job.sourceId,
        targetId: job.targetId,
        pageId: job.pageId,
        triggerType: triggerType,
        triggeredBy: cleanedRequestedBy,
        requestKey: cleanedRequestKey,
        queuedAt: now,
        runStatus: MonitoringCrawlRunStatus.queued,
        itemsFound: 0,
        snapshotsCreated: 0,
        eventsCreated: 0,
        signalsCreated: 0,
        executionAttempt: 1,
        collectorVersion: 'pending',
        createdAt: now,
      );

      final runCreateMap = run.toCreateMap()
        ..['queuedAt'] = FieldValue.serverTimestamp()
        ..['createdAt'] = FieldValue.serverTimestamp();

      transaction.set(runDocument, runCreateMap);

      transaction.update(jobDocument, <String, dynamic>{
        'lastRequestedAt': FieldValue.serverTimestamp(),
        'lastRequestedBy': cleanedRequestedBy,
        'triggerType': triggerType.value,
        'leaseOwner': queueLeaseOwner,
        'leaseAcquiredAt': FieldValue.serverTimestamp(),
        'leaseExpiresAt': Timestamp.fromDate(queueLeaseExpiresAt),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': cleanedRequestedBy,
      });

      return runDocument.id;
    });
  }

  @override
  Future<void> archive({required String jobId, required String updatedBy}) {
    return updateStatus(
      jobId: jobId,
      status: MonitoringCrawlJobStatus.archived,
      updatedBy: updatedBy,
    );
  }

  Query<Map<String, dynamic>> _buildListQuery({
    String? profileId,
    String? sourceId,
    String? pageId,
  }) {
    Query<Map<String, dynamic>> query = _refs.tenantQuery(_refs.crawlJobs);

    final cleanedProfileId = _optionalId(profileId, fieldName: 'profileId');
    final cleanedSourceId = _optionalId(sourceId, fieldName: 'sourceId');
    final cleanedPageId = _optionalId(pageId, fieldName: 'pageId');

    if (cleanedProfileId != null) {
      query = query.where('profileId', isEqualTo: cleanedProfileId);
    }

    if (cleanedSourceId != null) {
      query = query.where('sourceId', isEqualTo: cleanedSourceId);
    }

    if (cleanedPageId != null) {
      query = query.where('pageId', isEqualTo: cleanedPageId);
    }

    return query;
  }

  void _validateTenant(String tenantId) {
    if (tenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Crawl job tenantId ile repository tenantId eşleşmiyor.',
      );
    }
  }

  static void _validateJob(CrawlJobModel job) {
    if (job.tenantId.trim().isEmpty) {
      throw ArgumentError.value(
        job.tenantId,
        'tenantId',
        'tenantId boş olamaz.',
      );
    }

    if (job.brandId.trim().isEmpty) {
      throw ArgumentError.value(
        job.brandId,
        'brandId',
        'Marka bağlantısı zorunludur.',
      );
    }

    if (job.profileId.trim().isEmpty) {
      throw ArgumentError.value(
        job.profileId,
        'profileId',
        'İzleme profili zorunludur.',
      );
    }

    if (job.sourceId.trim().isEmpty) {
      throw ArgumentError.value(
        job.sourceId,
        'sourceId',
        'İzleme kaynağı zorunludur.',
      );
    }

    if (job.name.trim().length < 2 || job.name.trim().length > 200) {
      throw ArgumentError.value(
        job.name,
        'name',
        'Görev adı 2 ile 200 karakter arasında olmalıdır.',
      );
    }

    if (job.description != null && job.description!.trim().length > 2000) {
      throw ArgumentError.value(
        job.description,
        'description',
        'Görev açıklaması 2000 karakterden uzun olamaz.',
      );
    }

    if (job.maxRetryCount < 0 || job.maxRetryCount > 20) {
      throw ArgumentError.value(
        job.maxRetryCount,
        'maxRetryCount',
        'Azami tekrar sayısı 0 ile 20 arasında olmalıdır.',
      );
    }

    if (job.retryDelayMinutes < 1 || job.retryDelayMinutes > 1440) {
      throw ArgumentError.value(
        job.retryDelayMinutes,
        'retryDelayMinutes',
        'Tekrar gecikmesi 1 ile 1440 dakika arasında olmalıdır.',
      );
    }
  }

  String _tenantSafeRunDocumentId(String requestKey) {
    final tenantPart = _refs.tenantId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    final availableLength = 480 - tenantPart.length - 2;
    final safeRequestPart = requestKey.length > availableLength
        ? requestKey.substring(0, availableLength)
        : requestKey;

    return '${tenantPart}__$safeRequestPart';
  }

  static String _normalizeRequestKey(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    if (cleaned.isEmpty) {
      throw ArgumentError.value(value, 'requestKey', 'requestKey boş olamaz.');
    }

    if (cleaned.length > 240) {
      throw ArgumentError.value(
        value,
        'requestKey',
        'requestKey 240 karakterden uzun olamaz.',
      );
    }

    return cleaned;
  }

  static String _requiredId(String value, {required String fieldName}) {
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

  static String? _optionalId(String? value, {required String fieldName}) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return _requiredId(cleaned, fieldName: fieldName);
  }

  static int _validatedLimit(int value) {
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
