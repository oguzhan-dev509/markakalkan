import 'package:flutter_test/flutter_test.dart';

import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/constants/monitoring_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/monitoring_event_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/page_snapshot_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/signal_rule_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/services/signal_rule_engine.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/services/snapshot_diff_service.dart';

void main() {
  group('Dijital Pazar İzleme çekirdek zinciri', () {
    test('snapshot fiyat düşüşünü olaya ve yüksek sinyale dönüştürür', () {
      final previousSnapshot = _snapshot(
        id: 'snapshot_previous',
        price: 100,
        capturedAt: DateTime.utc(2026, 7, 4, 9),
      );

      final currentSnapshot = _snapshot(
        id: 'snapshot_current',
        price: 60,
        capturedAt: DateTime.utc(2026, 7, 4, 10),
      );

      final events = SnapshotDiffService.compare(
        previous: previousSnapshot,
        current: currentSnapshot,
        detectedAt: DateTime.utc(2026, 7, 4, 10, 1),
        listingId: 'listing_1',
        sellerId: 'seller_1',
        storeId: 'store_1',
      );

      expect(events, hasLength(1));

      final event = events.single;

      expect(event.eventType, MonitoringEventType.priceDecreased);
      expect(event.eventCategory, MonitoringEventCategory.price);
      expect(event.changeRate, closeTo(-0.40, 0.000001));
      expect(event.previousSnapshotId, 'snapshot_previous');
      expect(event.currentSnapshotId, 'snapshot_current');
      expect(event.listingId, 'listing_1');
      expect(event.sellerId, 'seller_1');
      expect(event.storeId, 'store_1');

      final persistedEvent = event.copyWithIdForTest('event_price_drop_1');

      final rule = SignalRuleModel(
        id: 'rule_large_price_drop',
        tenantId: 'tenant_1',
        brandId: 'brand_1',
        name: 'Büyük fiyat düşüşü',
        eventTypes: const <MonitoringEventType>[
          MonitoringEventType.priceDecreased,
        ],
        sourceIds: const <String>['source_1'],
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
        signalTitleTemplate:
            'Şüpheli fiyat düşüşü: {{oldValue}} → {{newValue}}',
        signalSummaryTemplate:
            '{{sourceId}} kaynağında {{changeRate}} oranında '
            'fiyat değişimi tespit edildi.',
        createdAt: DateTime.utc(2026, 7, 4, 8),
        createdBy: 'system',
      );

      final signals = SignalRuleEngine.evaluate(
        event: persistedEvent,
        rules: <SignalRuleModel>[rule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10, 2),
      );

      expect(signals, hasLength(1));

      final signal = signals.single;

      expect(signal.eventId, 'event_price_drop_1');
      expect(signal.ruleId, 'rule_large_price_drop');
      expect(signal.signalLevel, MonitoringSignalLevel.high);
      expect(signal.status, MonitoringSignalStatus.newSignal);
      expect(
        signal.forwardingStatus,
        MonitoringSignalForwardingStatus.notForwarded,
      );
      expect(signal.title, 'Şüpheli fiyat düşüşü: 100.0 → 60.0');
      expect(signal.tenantId, 'tenant_1');
      expect(signal.brandId, 'brand_1');
      expect(signal.sourceId, 'source_1');
      expect(signal.pageId, 'page_1');
      expect(signal.listingId, 'listing_1');
      expect(signal.sellerId, 'seller_1');
      expect(signal.storeId, 'store_1');
    });

    test('eşik altında kalan fiyat düşüşünde sinyal üretmez', () {
      final previousSnapshot = _snapshot(
        id: 'snapshot_previous',
        price: 100,
        capturedAt: DateTime.utc(2026, 7, 4, 9),
      );

      final currentSnapshot = _snapshot(
        id: 'snapshot_current',
        price: 90,
        capturedAt: DateTime.utc(2026, 7, 4, 10),
      );

      final events = SnapshotDiffService.compare(
        previous: previousSnapshot,
        current: currentSnapshot,
        detectedAt: DateTime.utc(2026, 7, 4, 10, 1),
      );

      expect(events, hasLength(1));
      expect(events.single.changeRate, closeTo(-0.10, 0.000001));

      final persistedEvent = events.single.copyWithIdForTest(
        'event_small_price_drop',
      );

      final rule = SignalRuleModel(
        id: 'rule_large_price_drop',
        tenantId: 'tenant_1',
        brandId: 'brand_1',
        name: 'Büyük fiyat düşüşü',
        eventTypes: const <MonitoringEventType>[
          MonitoringEventType.priceDecreased,
        ],
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
        createdAt: DateTime.utc(2026, 7, 4, 8),
        createdBy: 'system',
      );

      final signals = SignalRuleEngine.evaluate(
        event: persistedEvent,
        rules: <SignalRuleModel>[rule],
        evaluatedAt: DateTime.utc(2026, 7, 4, 10, 2),
      );

      expect(signals, isEmpty);
    });
  });
}

PageSnapshotModel _snapshot({
  required String id,
  required double price,
  required DateTime capturedAt,
}) {
  return PageSnapshotModel(
    id: id,
    tenantId: 'tenant_1',
    brandId: 'brand_1',
    sourceId: 'source_1',
    pageId: 'page_1',
    crawlRunId: 'crawl_run_1',
    capturedAt: capturedAt,
    pageStatus: MonitoringPageStatus.active,
    title: 'Örnek Ürün',
    description: 'Değişmeyen açıklama',
    price: price,
    currency: 'TRY',
    stockStatus: MonitoringStockStatus.inStock,
    sellerName: 'Satıcı Bir',
    storeName: 'Mağaza Bir',
    imageUrls: const <String>['https://example.com/product.jpg'],
    mediaAssetIds: const <String>[],
    contactSummary: const <String, int>{
      'phoneCount': 0,
      'emailCount': 0,
      'addressCount': 0,
    },
    parserVersion: '1.0.0',
    createdAt: capturedAt,
  );
}

extension MonitoringEventTestCopy on MonitoringEventModel {
  MonitoringEventModel copyWithIdForTest(String newId) {
    return MonitoringEventModel(
      id: newId,
      tenantId: tenantId,
      brandId: brandId,
      sourceId: sourceId,
      pageId: pageId,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
      eventType: eventType,
      eventCategory: eventCategory,
      previousSnapshotId: previousSnapshotId,
      currentSnapshotId: currentSnapshotId,
      oldValue: oldValue,
      newValue: newValue,
      changeRate: changeRate,
      severity: severity,
      status: status,
      summary: summary,
      detectedAt: detectedAt,
      createdBySystem: createdBySystem,
      createdAt: createdAt,
    );
  }
}
