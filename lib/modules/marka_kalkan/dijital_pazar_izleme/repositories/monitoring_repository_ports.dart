import '../constants/monitoring_enums.dart';
import '../models/crawl_job_model.dart';
import '../models/crawl_run_model.dart';
import '../models/monitored_page_model.dart';
import '../models/monitoring_event_model.dart';
import '../models/monitoring_signal_model.dart';
import '../models/page_snapshot_model.dart';
import '../models/signal_rule_model.dart';

abstract interface class CrawlJobRepositoryPort {
  Future<String> create(CrawlJobModel job);

  Future<void> update(CrawlJobModel job);

  Future<CrawlJobModel?> getById(String jobId);

  Future<CrawlJobModel?> findActiveForPage(String pageId);

  Future<List<CrawlJobModel>> listAll({
    String? profileId,
    String? sourceId,
    String? pageId,
    int limit = 200,
  });

  Stream<List<CrawlJobModel>> watchAll({
    String? profileId,
    String? sourceId,
    String? pageId,
    int limit = 200,
  });

  Future<void> updateStatus({
    required String jobId,
    required MonitoringCrawlJobStatus status,
    required String updatedBy,
  });

  Future<String> enqueueRun({
    required String jobId,
    required String requestedBy,
    required String requestKey,
    MonitoringCrawlTriggerType triggerType,
  });

  Future<void> archive({required String jobId, required String updatedBy});
}

abstract interface class CrawlRunRepositoryPort {
  Future<CrawlRunModel?> getById(String runId);

  Future<CrawlRunModel?> findByRequestKey(String requestKey);

  Future<List<CrawlRunModel>> listForJob(String jobId, {int limit = 100});

  Stream<List<CrawlRunModel>> watchForJob(String jobId, {int limit = 100});

  Future<List<CrawlRunModel>> listQueued({int limit = 100});
}

abstract interface class MonitoredPageRepositoryPort {
  Future<String> create(MonitoredPageModel page);

  Future<void> update(MonitoredPageModel page);

  Future<MonitoredPageModel?> getById(String pageId);

  Future<MonitoredPageModel?> findByNormalizedUrl({
    required String brandId,
    required String normalizedUrl,
  });

  Future<List<MonitoredPageModel>> listAll({
    String? brandId,
    String? sourceId,
    int limit = 200,
  });

  Stream<List<MonitoredPageModel>> watchAll({
    String? brandId,
    String? sourceId,
    int limit = 200,
  });

  Future<void> updateTrackingStatus({
    required String pageId,
    required MonitoringPageTrackingStatus trackingStatus,
    required String updatedBy,
  });

  Future<void> delete(String pageId);
}

abstract interface class PageSnapshotRepositoryPort {
  Future<String> create(PageSnapshotModel snapshot);

  Future<PageSnapshotCreateResult> createVersioned(PageSnapshotModel snapshot);

  Future<PageSnapshotModel?> getLatestForPage(String pageId);
}

abstract interface class MonitoringEventRepositoryPort {
  Future<List<String>> createBatch(List<MonitoringEventModel> events);
}

abstract interface class SignalRuleRepositoryPort {
  Future<List<SignalRuleModel>> listActive({
    String? brandId,
    String? sourceId,
    int limit = 200,
  });
}

abstract interface class MonitoringSignalRepositoryPort {
  Future<List<String>> createBatch(List<MonitoringSignalModel> signals);
}
