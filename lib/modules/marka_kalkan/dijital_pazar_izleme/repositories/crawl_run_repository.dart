import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../models/crawl_run_model.dart';
import 'monitoring_firestore_refs.dart';
import 'monitoring_repository_ports.dart';

class CrawlRunRepository implements CrawlRunRepositoryPort {
  const CrawlRunRepository({required MonitoringFirestoreRefs refs})
    : _refs = refs;

  factory CrawlRunRepository.instance({required String tenantId}) {
    return CrawlRunRepository(
      refs: MonitoringFirestoreRefs.instance(tenantId: tenantId),
    );
  }

  final MonitoringFirestoreRefs _refs;

  @override
  Future<CrawlRunModel?> getById(String runId) async {
    final snapshot = await _refs.crawlRunDocument(runId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final run = CrawlRunModel.fromDocument(snapshot);

    _validateTenant(run.tenantId);

    return run;
  }

  @override
  Future<CrawlRunModel?> findByRequestKey(String requestKey) async {
    final cleanedRequestKey = _requiredId(requestKey, fieldName: 'requestKey');

    final directDocumentId = _tenantSafeRunDocumentId(cleanedRequestKey);

    final directSnapshot = await _refs.crawlRuns.doc(directDocumentId).get();

    if (directSnapshot.exists && directSnapshot.data() != null) {
      final run = CrawlRunModel.fromDocument(directSnapshot);

      _validateTenant(run.tenantId);

      return run;
    }

    final querySnapshot = await _refs
        .tenantQuery(_refs.crawlRuns)
        .where('requestKey', isEqualTo: cleanedRequestKey)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    return CrawlRunModel.fromDocument(querySnapshot.docs.first);
  }

  @override
  Future<List<CrawlRunModel>> listForJob(
    String jobId, {
    int limit = 100,
  }) async {
    final snapshot = await _jobQuery(
      jobId,
    ).orderBy('queuedAt', descending: true).limit(_validatedLimit(limit)).get();

    return snapshot.docs
        .map(CrawlRunModel.fromDocument)
        .toList(growable: false);
  }

  @override
  Stream<List<CrawlRunModel>> watchForJob(String jobId, {int limit = 100}) {
    return _jobQuery(jobId)
        .orderBy('queuedAt', descending: true)
        .limit(_validatedLimit(limit))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CrawlRunModel.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Future<List<CrawlRunModel>> listQueued({int limit = 100}) async {
    final snapshot = await _refs
        .tenantQuery(_refs.crawlRuns)
        .where('runStatus', isEqualTo: MonitoringCrawlRunStatus.queued.value)
        .orderBy('queuedAt')
        .limit(_validatedLimit(limit))
        .get();

    return snapshot.docs
        .map(CrawlRunModel.fromDocument)
        .toList(growable: false);
  }

  Future<List<CrawlRunModel>> listRunning({int limit = 100}) async {
    final snapshot = await _refs
        .tenantQuery(_refs.crawlRuns)
        .where('runStatus', isEqualTo: MonitoringCrawlRunStatus.running.value)
        .orderBy('startedAt')
        .limit(_validatedLimit(limit))
        .get();

    return snapshot.docs
        .map(CrawlRunModel.fromDocument)
        .toList(growable: false);
  }

  Query<Map<String, dynamic>> _jobQuery(String jobId) {
    return _refs
        .tenantQuery(_refs.crawlRuns)
        .where('jobId', isEqualTo: _requiredId(jobId, fieldName: 'jobId'));
  }

  void _validateTenant(String tenantId) {
    if (tenantId.trim() != _refs.tenantId) {
      throw StateError(
        'Crawl run tenantId ile repository tenantId eşleşmiyor.',
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
