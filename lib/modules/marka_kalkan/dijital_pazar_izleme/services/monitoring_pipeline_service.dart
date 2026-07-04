import '../models/monitoring_event_model.dart';
import '../models/monitoring_signal_model.dart';
import '../models/page_snapshot_model.dart';
import '../repositories/monitoring_event_repository.dart';
import '../repositories/monitoring_signal_repository.dart';
import '../repositories/monitoring_repository_ports.dart';
import '../repositories/page_snapshot_repository.dart';
import '../repositories/signal_rule_repository.dart';
import 'signal_rule_engine.dart';
import 'snapshot_diff_service.dart';

class MonitoringPipelineResult {
  const MonitoringPipelineResult({
    required this.snapshotId,
    required this.previousSnapshotId,
    required this.eventIds,
    required this.signalIds,
  });

  final String snapshotId;
  final String? previousSnapshotId;
  final List<String> eventIds;
  final List<String> signalIds;

  int get eventCount => eventIds.length;

  int get signalCount => signalIds.length;

  bool get isFirstSnapshot => previousSnapshotId == null;

  bool get hasChanges => eventIds.isNotEmpty;

  bool get hasSignals => signalIds.isNotEmpty;
}

class MonitoringPipelineService {
  MonitoringPipelineService({
    required PageSnapshotRepositoryPort snapshotRepository,
    required MonitoringEventRepositoryPort eventRepository,
    required SignalRuleRepositoryPort ruleRepository,
    required MonitoringSignalRepositoryPort signalRepository,
    DateTime Function()? clock,
  }) : _snapshotRepository = snapshotRepository,
       _eventRepository = eventRepository,
       _ruleRepository = ruleRepository,
       _signalRepository = signalRepository,
       _clock = clock ?? DateTime.now;

  factory MonitoringPipelineService.instance({required String tenantId}) {
    return MonitoringPipelineService(
      snapshotRepository: PageSnapshotRepository.instance(tenantId: tenantId),
      eventRepository: MonitoringEventRepository.instance(tenantId: tenantId),
      ruleRepository: SignalRuleRepository.instance(tenantId: tenantId),
      signalRepository: MonitoringSignalRepository.instance(tenantId: tenantId),
    );
  }

  final PageSnapshotRepositoryPort _snapshotRepository;
  final MonitoringEventRepositoryPort _eventRepository;
  final SignalRuleRepositoryPort _ruleRepository;
  final MonitoringSignalRepositoryPort _signalRepository;
  final DateTime Function() _clock;

  Future<MonitoringPipelineResult> processSnapshot({
    required PageSnapshotModel snapshot,
    String? listingId,
    String? sellerId,
    String? storeId,
  }) async {
    final previousSnapshot = await _snapshotRepository.getLatestForPage(
      snapshot.pageId,
    );

    final snapshotForCreate = _copySnapshot(
      snapshot,
      previousSnapshotId: previousSnapshot?.id,
    );

    final snapshotId = await _snapshotRepository.create(snapshotForCreate);

    final persistedSnapshot = _copySnapshot(snapshotForCreate, id: snapshotId);

    if (previousSnapshot == null) {
      return MonitoringPipelineResult(
        snapshotId: snapshotId,
        previousSnapshotId: null,
        eventIds: const <String>[],
        signalIds: const <String>[],
      );
    }

    final detectedAt = _clock();

    final generatedEvents = SnapshotDiffService.compare(
      previous: previousSnapshot,
      current: persistedSnapshot,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    if (generatedEvents.isEmpty) {
      return MonitoringPipelineResult(
        snapshotId: snapshotId,
        previousSnapshotId: previousSnapshot.id,
        eventIds: const <String>[],
        signalIds: const <String>[],
      );
    }

    final eventIds = await _eventRepository.createBatch(generatedEvents);

    final persistedEvents = <MonitoringEventModel>[];

    for (var index = 0; index < generatedEvents.length; index++) {
      persistedEvents.add(
        _copyEvent(generatedEvents[index], id: eventIds[index]),
      );
    }

    final activeRules = await _ruleRepository.listActive(
      brandId: persistedSnapshot.brandId,
      sourceId: persistedSnapshot.sourceId,
    );

    final evaluatedAt = _clock();
    final generatedSignals = <MonitoringSignalModel>[];

    for (final event in persistedEvents) {
      generatedSignals.addAll(
        SignalRuleEngine.evaluate(
          event: event,
          rules: activeRules,
          evaluatedAt: evaluatedAt,
        ),
      );
    }

    final signalIds = generatedSignals.isEmpty
        ? const <String>[]
        : await _signalRepository.createBatch(generatedSignals);

    return MonitoringPipelineResult(
      snapshotId: snapshotId,
      previousSnapshotId: previousSnapshot.id,
      eventIds: List<String>.unmodifiable(eventIds),
      signalIds: List<String>.unmodifiable(signalIds),
    );
  }

  static PageSnapshotModel _copySnapshot(
    PageSnapshotModel source, {
    String? id,
    String? previousSnapshotId,
  }) {
    return PageSnapshotModel(
      id: id ?? source.id,
      tenantId: source.tenantId,
      brandId: source.brandId,
      sourceId: source.sourceId,
      pageId: source.pageId,
      crawlRunId: source.crawlRunId,
      previousSnapshotId: previousSnapshotId ?? source.previousSnapshotId,
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

  static MonitoringEventModel _copyEvent(
    MonitoringEventModel source, {
    required String id,
  }) {
    return MonitoringEventModel(
      id: id,
      tenantId: source.tenantId,
      brandId: source.brandId,
      sourceId: source.sourceId,
      pageId: source.pageId,
      listingId: source.listingId,
      sellerId: source.sellerId,
      storeId: source.storeId,
      eventType: source.eventType,
      eventCategory: source.eventCategory,
      previousSnapshotId: source.previousSnapshotId,
      currentSnapshotId: source.currentSnapshotId,
      oldValue: source.oldValue,
      newValue: source.newValue,
      changeRate: source.changeRate,
      severity: source.severity,
      status: source.status,
      summary: source.summary,
      detectedAt: source.detectedAt,
      createdBySystem: source.createdBySystem,
      createdAt: source.createdAt,
    );
  }
}
