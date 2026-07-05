import 'package:flutter_test/flutter_test.dart';

import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/constants/monitoring_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/monitoring_event_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/monitoring_signal_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/page_snapshot_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/signal_rule_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/repositories/monitoring_repository_ports.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/services/monitoring_pipeline_service.dart';

void main() {
  const tenantId = 'tenant-1';
  const brandId = 'brand-1';
  const sourceId = 'source-1';
  const pageId = 'page-1';

  final firstCapturedAt = DateTime.utc(2026, 7, 4, 8);
  final secondCapturedAt = DateTime.utc(2026, 7, 4, 9);
  final pipelineTime = DateTime.utc(2026, 7, 4, 10);

  group('MonitoringPipelineService', () {
    test('ilk snapshot kaydedilir, olay ve sinyal oluşturulmaz', () async {
      final environment = _TestEnvironment(
        rules: <SignalRuleModel>[
          _priceDropRule(id: 'rule-1', tenantId: tenantId),
        ],
        clock: pipelineTime,
      );

      final result = await environment.pipeline.processSnapshot(
        snapshot: _snapshot(
          tenantId: tenantId,
          brandId: brandId,
          sourceId: sourceId,
          pageId: pageId,
          capturedAt: firstCapturedAt,
          price: 100,
        ),
      );

      expect(result.snapshotId, 'snapshot-1');
      expect(result.previousSnapshotId, isNull);
      expect(result.isFirstSnapshot, isTrue);
      expect(result.eventCount, 0);
      expect(result.signalCount, 0);

      expect(environment.snapshots.saved, hasLength(1));
      expect(environment.events.saved, isEmpty);
      expect(environment.signals.saved, isEmpty);
    });

    test('değişiklik olmayan ikinci snapshot olay üretmez', () async {
      final environment = _TestEnvironment(
        rules: <SignalRuleModel>[
          _priceDropRule(id: 'rule-1', tenantId: tenantId),
        ],
        clock: pipelineTime,
      );

      await environment.pipeline.processSnapshot(
        snapshot: _snapshot(
          tenantId: tenantId,
          brandId: brandId,
          sourceId: sourceId,
          pageId: pageId,
          capturedAt: firstCapturedAt,
          price: 100,
        ),
      );

      final result = await environment.pipeline.processSnapshot(
        snapshot: _snapshot(
          tenantId: tenantId,
          brandId: brandId,
          sourceId: sourceId,
          pageId: pageId,
          capturedAt: secondCapturedAt,
          price: 100,
        ),
      );

      expect(result.snapshotId, 'snapshot-2');
      expect(result.previousSnapshotId, 'snapshot-1');
      expect(result.hasChanges, isFalse);
      expect(result.hasSignals, isFalse);

      expect(environment.snapshots.saved, hasLength(2));
      expect(environment.events.saved, isEmpty);
      expect(environment.signals.saved, isEmpty);
    });

    test(
      'fiyat düşüşü gerçek snapshot ve event kimlikleriyle sinyal üretir',
      () async {
        final environment = _TestEnvironment(
          rules: <SignalRuleModel>[
            _priceDropRule(id: 'rule-price-drop', tenantId: tenantId),
          ],
          clock: pipelineTime,
        );

        await environment.pipeline.processSnapshot(
          snapshot: _snapshot(
            tenantId: tenantId,
            brandId: brandId,
            sourceId: sourceId,
            pageId: pageId,
            capturedAt: firstCapturedAt,
            price: 100,
          ),
        );

        final result = await environment.pipeline.processSnapshot(
          snapshot: _snapshot(
            tenantId: tenantId,
            brandId: brandId,
            sourceId: sourceId,
            pageId: pageId,
            capturedAt: secondCapturedAt,
            price: 60,
          ),
          listingId: 'listing-1',
          sellerId: 'seller-1',
          storeId: 'store-1',
        );

        expect(result.snapshotId, 'snapshot-2');
        expect(result.previousSnapshotId, 'snapshot-1');

        final event = environment.events.saved.single;
        final signal = environment.signals.saved.single;

        expect(event.id, startsWith('evt_'));
        expect(result.eventIds, <String>[event.id]);
        expect(result.signalIds, <String>[signal.id]);

        expect(event.previousSnapshotId, 'snapshot-1');
        expect(event.currentSnapshotId, 'snapshot-2');
        expect(event.eventType, MonitoringEventType.priceDecreased);
        expect(event.oldValue, 100);
        expect(event.newValue, 60);
        expect(event.changeRate, closeTo(-0.4, 0.000001));
        expect(event.listingId, 'listing-1');
        expect(event.sellerId, 'seller-1');
        expect(event.storeId, 'store-1');

        expect(signal.id, isNotEmpty);
        expect(signal.eventId, event.id);
        expect(signal.ruleId, 'rule-price-drop');
        expect(signal.signalLevel, MonitoringSignalLevel.high);
        expect(signal.status, MonitoringSignalStatus.newSignal);
      },
    );

    test('eşleşmeyen kuralda olay oluşur fakat sinyal oluşmaz', () async {
      final environment = _TestEnvironment(
        rules: <SignalRuleModel>[
          SignalRuleModel(
            id: 'rule-page-blocked',
            tenantId: tenantId,
            name: 'Engellenen sayfa',
            eventTypes: const <MonitoringEventType>[
              MonitoringEventType.pageBlocked,
            ],
            conditions: const <SignalRuleConditionModel>[],
            signalLevel: MonitoringSignalLevel.high,
            status: MonitoringSignalRuleStatus.active,
            priority: MonitoringPriority.high,
            createdAt: pipelineTime,
            createdBy: 'system',
          ),
        ],
        clock: pipelineTime,
      );

      await environment.pipeline.processSnapshot(
        snapshot: _snapshot(
          tenantId: tenantId,
          brandId: brandId,
          sourceId: sourceId,
          pageId: pageId,
          capturedAt: firstCapturedAt,
          price: 100,
        ),
      );

      final result = await environment.pipeline.processSnapshot(
        snapshot: _snapshot(
          tenantId: tenantId,
          brandId: brandId,
          sourceId: sourceId,
          pageId: pageId,
          capturedAt: secondCapturedAt,
          price: 60,
        ),
      );

      expect(result.eventCount, 1);
      expect(result.signalCount, 0);

      expect(environment.events.saved, hasLength(1));
      expect(environment.signals.saved, isEmpty);
    });

    test('genel ve kaynak özel kurallar birlikte eşleşir', () async {
      final environment = _TestEnvironment(
        rules: <SignalRuleModel>[
          _priceDropRule(id: 'rule-general', tenantId: tenantId),
          _priceDropRule(
            id: 'rule-source',
            tenantId: tenantId,
            sourceIds: const <String>[sourceId],
          ),
        ],
        clock: pipelineTime,
      );

      await environment.pipeline.processSnapshot(
        snapshot: _snapshot(
          tenantId: tenantId,
          brandId: brandId,
          sourceId: sourceId,
          pageId: pageId,
          capturedAt: firstCapturedAt,
          price: 100,
        ),
      );

      final result = await environment.pipeline.processSnapshot(
        snapshot: _snapshot(
          tenantId: tenantId,
          brandId: brandId,
          sourceId: sourceId,
          pageId: pageId,
          capturedAt: secondCapturedAt,
          price: 60,
        ),
      );

      expect(result.eventCount, 1);
      expect(result.signalCount, 2);

      expect(
        environment.signals.saved.map((signal) => signal.ruleId).toSet(),
        <String>{'rule-general', 'rule-source'},
      );

      final persistedEventId = environment.events.saved.single.id;

      expect(persistedEventId, startsWith('evt_'));
      expect(
        environment.signals.saved.every(
          (signal) => signal.eventId == persistedEventId,
        ),
        isTrue,
      );
    });
  });
}

class _TestEnvironment {
  _TestEnvironment({
    required List<SignalRuleModel> rules,
    required DateTime clock,
  }) : snapshots = _FakePageSnapshotRepository(),
       events = _FakeMonitoringEventRepository(),
       ruleRepository = _FakeSignalRuleRepository(rules),
       signals = _FakeMonitoringSignalRepository() {
    pipeline = MonitoringPipelineService(
      snapshotRepository: snapshots,
      eventRepository: events,
      ruleRepository: ruleRepository,
      signalRepository: signals,
      clock: () => clock,
    );
  }

  final _FakePageSnapshotRepository snapshots;
  final _FakeMonitoringEventRepository events;
  final _FakeSignalRuleRepository ruleRepository;
  final _FakeMonitoringSignalRepository signals;

  late final MonitoringPipelineService pipeline;
}

class _FakePageSnapshotRepository implements PageSnapshotRepositoryPort {
  final List<PageSnapshotModel> saved = <PageSnapshotModel>[];

  @override
  Future<String> create(PageSnapshotModel snapshot) async {
    final id = snapshot.id.trim().isEmpty
        ? 'snapshot-${saved.length + 1}'
        : snapshot.id.trim();

    saved.add(_copySnapshot(snapshot, id: id));

    return id;
  }

  @override
  Future<PageSnapshotCreateResult> createVersioned(
    PageSnapshotModel snapshot,
  ) async {
    final previousSnapshot = await getLatestForPage(snapshot.pageId);
    final snapshotId = await create(snapshot);

    final persistedSnapshot = saved.lastWhere((item) => item.id == snapshotId);

    return PageSnapshotCreateResult(
      snapshot: persistedSnapshot,
      previousSnapshot: previousSnapshot,
      wasCreated: true,
    );
  }

  @override
  Future<PageSnapshotModel?> getLatestForPage(String pageId) async {
    final matches =
        saved
            .where((snapshot) => snapshot.pageId == pageId)
            .toList(growable: false)
          ..sort(
            (first, second) => second.capturedAt.compareTo(first.capturedAt),
          );

    return matches.isEmpty ? null : matches.first;
  }
}

class _FakeMonitoringEventRepository implements MonitoringEventRepositoryPort {
  final List<MonitoringEventModel> saved = <MonitoringEventModel>[];

  @override
  Future<List<String>> createBatch(List<MonitoringEventModel> events) async {
    final ids = <String>[];

    for (final event in events) {
      final id = event.id.trim().isEmpty
          ? 'event-${saved.length + 1}'
          : event.id.trim();

      ids.add(id);
      saved.add(_copyEvent(event, id: id));
    }

    return List<String>.unmodifiable(ids);
  }
}

class _FakeSignalRuleRepository implements SignalRuleRepositoryPort {
  _FakeSignalRuleRepository(this.rules);

  final List<SignalRuleModel> rules;

  @override
  Future<List<SignalRuleModel>> listActive({
    String? brandId,
    String? sourceId,
    int limit = 200,
  }) async {
    return rules
        .where(
          (rule) =>
              rule.isActive &&
              (brandId == null ||
                  rule.brandId == null ||
                  rule.brandId == brandId) &&
              (sourceId == null || rule.appliesToSource(sourceId)),
        )
        .take(limit)
        .toList(growable: false);
  }
}

class _FakeMonitoringSignalRepository
    implements MonitoringSignalRepositoryPort {
  final List<MonitoringSignalModel> saved = <MonitoringSignalModel>[];

  @override
  Future<List<String>> createBatch(List<MonitoringSignalModel> signals) async {
    final ids = <String>[];

    for (final signal in signals) {
      final id = signal.id.trim().isEmpty
          ? 'signal-${saved.length + 1}'
          : signal.id.trim();

      ids.add(id);
      saved.add(_copySignal(signal, id: id));
    }

    return List<String>.unmodifiable(ids);
  }
}

PageSnapshotModel _snapshot({
  required String tenantId,
  required String brandId,
  required String sourceId,
  required String pageId,
  required DateTime capturedAt,
  required double price,
}) {
  return PageSnapshotModel(
    id: '',
    tenantId: tenantId,
    brandId: brandId,
    sourceId: sourceId,
    pageId: pageId,
    crawlRunId: 'crawl-run-1',
    capturedAt: capturedAt,
    pageStatus: MonitoringPageStatus.active,
    title: 'Örnek ürün',
    description: 'Örnek ürün açıklaması',
    price: price,
    currency: 'TRY',
    imageUrls: const <String>[],
    mediaAssetIds: const <String>[],
    contactSummary: const <String, int>{
      'phoneCount': 0,
      'emailCount': 0,
      'addressCount': 0,
    },
    parserVersion: 'test-parser-1',
    createdAt: capturedAt,
  );
}

SignalRuleModel _priceDropRule({
  required String id,
  required String tenantId,
  List<String> sourceIds = const <String>[],
}) {
  return SignalRuleModel(
    id: id,
    tenantId: tenantId,
    name: 'Yüksek fiyat düşüşü',
    eventTypes: const <MonitoringEventType>[MonitoringEventType.priceDecreased],
    sourceIds: sourceIds,
    conditions: const <SignalRuleConditionModel>[
      SignalRuleConditionModel(
        field: 'changeRate',
        operator: MonitoringSignalRuleOperator.lessThanOrEqual,
        value: -0.30,
      ),
    ],
    signalLevel: MonitoringSignalLevel.high,
    status: MonitoringSignalRuleStatus.active,
    priority: MonitoringPriority.high,
    signalTitleTemplate: '{{ruleName}}',
    signalSummaryTemplate:
        '{{oldValue}} fiyatından {{newValue}} fiyatına düştü.',
    createdAt: DateTime.utc(2026, 7, 4),
    createdBy: 'system',
  );
}

PageSnapshotModel _copySnapshot(
  PageSnapshotModel source, {
  required String id,
}) {
  return PageSnapshotModel(
    id: id,
    tenantId: source.tenantId,
    brandId: source.brandId,
    sourceId: source.sourceId,
    pageId: source.pageId,
    crawlRunId: source.crawlRunId,
    previousSnapshotId: source.previousSnapshotId,
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

MonitoringEventModel _copyEvent(
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

MonitoringSignalModel _copySignal(
  MonitoringSignalModel source, {
  required String id,
}) {
  return MonitoringSignalModel(
    id: id,
    tenantId: source.tenantId,
    brandId: source.brandId,
    sourceId: source.sourceId,
    pageId: source.pageId,
    listingId: source.listingId,
    sellerId: source.sellerId,
    storeId: source.storeId,
    eventId: source.eventId,
    ruleId: source.ruleId,
    ruleName: source.ruleName,
    eventType: source.eventType,
    eventCategory: source.eventCategory,
    signalLevel: source.signalLevel,
    status: source.status,
    forwardingStatus: source.forwardingStatus,
    title: source.title,
    summary: source.summary,
    detectedAt: source.detectedAt,
    reviewedAt: source.reviewedAt,
    reviewedBy: source.reviewedBy,
    forwardedAt: source.forwardedAt,
    forwardingError: source.forwardingError,
    resolvedAt: source.resolvedAt,
    resolvedBy: source.resolvedBy,
    resolutionNote: source.resolutionNote,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
    updatedBy: source.updatedBy,
  );
}
