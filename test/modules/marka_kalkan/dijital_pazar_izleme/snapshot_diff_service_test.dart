import 'package:flutter_test/flutter_test.dart';

import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/constants/monitoring_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/models/page_snapshot_model.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/services/snapshot_diff_service.dart';

void main() {
  group('SnapshotDiffService', () {
    test('fiyat düşüşünü priceDecreased olayı olarak üretir', () {
      final previous = _snapshot(
        id: 'snapshot_previous',
        capturedAt: DateTime.utc(2026, 7, 4, 7),
        price: 100,
      );

      final current = _snapshot(
        id: 'snapshot_current',
        capturedAt: DateTime.utc(2026, 7, 4, 8),
        price: 60,
      );

      final events = SnapshotDiffService.compare(
        previous: previous,
        current: current,
        detectedAt: DateTime.utc(2026, 7, 4, 8, 1),
      );

      expect(events, hasLength(1));

      final event = events.single;

      expect(event.eventType, MonitoringEventType.priceDecreased);
      expect(event.eventCategory, MonitoringEventCategory.price);
      expect(event.severity, MonitoringEventSeverity.high);
      expect(event.oldValue, 100);
      expect(event.newValue, 60);
      expect(event.changeRate, closeTo(-0.40, 0.000001));
      expect(event.previousSnapshotId, 'snapshot_previous');
      expect(event.currentSnapshotId, 'snapshot_current');
    });

    test('satıcı değişikliğini sellerChanged olayı olarak üretir', () {
      final previous = _snapshot(
        id: 'snapshot_previous',
        capturedAt: DateTime.utc(2026, 7, 4, 7),
        sellerName: 'Eski Satıcı',
      );

      final current = _snapshot(
        id: 'snapshot_current',
        capturedAt: DateTime.utc(2026, 7, 4, 8),
        sellerName: 'Yeni Satıcı',
      );

      final events = SnapshotDiffService.compare(
        previous: previous,
        current: current,
        detectedAt: DateTime.utc(2026, 7, 4, 8, 1),
        sellerId: 'seller_1',
      );

      expect(events, hasLength(1));
      expect(events.single.eventType, MonitoringEventType.sellerChanged);
      expect(events.single.eventCategory, MonitoringEventCategory.seller);
      expect(events.single.severity, MonitoringEventSeverity.high);
      expect(events.single.sellerId, 'seller_1');
    });

    test('görsel seti değişikliğini imageChanged olayı olarak üretir', () {
      final previous = _snapshot(
        id: 'snapshot_previous',
        capturedAt: DateTime.utc(2026, 7, 4, 7),
        imageUrls: const <String>['https://example.com/image-1.jpg'],
      );

      final current = _snapshot(
        id: 'snapshot_current',
        capturedAt: DateTime.utc(2026, 7, 4, 8),
        imageUrls: const <String>[
          'https://example.com/image-1.jpg',
          'https://example.com/image-2.jpg',
        ],
      );

      final events = SnapshotDiffService.compare(
        previous: previous,
        current: current,
        detectedAt: DateTime.utc(2026, 7, 4, 8, 1),
      );

      expect(events, hasLength(1));
      expect(events.single.eventType, MonitoringEventType.imageChanged);
      expect(events.single.eventCategory, MonitoringEventCategory.media);
      expect(events.single.oldValue, hasLength(1));
      expect(events.single.newValue, hasLength(2));
    });

    test('engellenen sayfayı pageBlocked olayı olarak üretir', () {
      final previous = _snapshot(
        id: 'snapshot_previous',
        capturedAt: DateTime.utc(2026, 7, 4, 7),
        pageStatus: MonitoringPageStatus.active,
      );

      final current = _snapshot(
        id: 'snapshot_current',
        capturedAt: DateTime.utc(2026, 7, 4, 8),
        pageStatus: MonitoringPageStatus.blocked,
      );

      final events = SnapshotDiffService.compare(
        previous: previous,
        current: current,
        detectedAt: DateTime.utc(2026, 7, 4, 8, 1),
      );

      expect(events, hasLength(1));
      expect(events.single.eventType, MonitoringEventType.pageBlocked);
      expect(events.single.eventCategory, MonitoringEventCategory.technical);
      expect(events.single.severity, MonitoringEventSeverity.high);
      expect(events.single.oldValue, MonitoringPageStatus.active.value);
      expect(events.single.newValue, MonitoringPageStatus.blocked.value);
    });

    test('aynı snapshot içeriği için olay üretmez', () {
      final previous = _snapshot(
        id: 'snapshot_previous',
        capturedAt: DateTime.utc(2026, 7, 4, 7),
      );

      final current = _snapshot(
        id: 'snapshot_current',
        capturedAt: DateTime.utc(2026, 7, 4, 8),
      );

      final events = SnapshotDiffService.compare(
        previous: previous,
        current: current,
        detectedAt: DateTime.utc(2026, 7, 4, 8, 1),
      );

      expect(events, isEmpty);
    });

    test('farklı sayfalara ait snapshotları reddeder', () {
      final previous = _snapshot(
        id: 'snapshot_previous',
        pageId: 'page_1',
        capturedAt: DateTime.utc(2026, 7, 4, 7),
      );

      final current = _snapshot(
        id: 'snapshot_current',
        pageId: 'page_2',
        capturedAt: DateTime.utc(2026, 7, 4, 8),
      );

      expect(
        () => SnapshotDiffService.compare(
          previous: previous,
          current: current,
          detectedAt: DateTime.utc(2026, 7, 4, 8, 1),
        ),
        throwsArgumentError,
      );
    });
  });
}

PageSnapshotModel _snapshot({
  required String id,
  required DateTime capturedAt,
  String pageId = 'page_1',
  MonitoringPageStatus pageStatus = MonitoringPageStatus.active,
  double? price = 100,
  String? sellerName = 'Sabit Satıcı',
  String? storeName = 'Sabit Mağaza',
  List<String> imageUrls = const <String>['https://example.com/image-1.jpg'],
}) {
  return PageSnapshotModel(
    id: id,
    tenantId: 'tenant_1',
    brandId: 'brand_1',
    sourceId: 'source_1',
    pageId: pageId,
    crawlRunId: 'crawl_run_1',
    capturedAt: capturedAt,
    pageStatus: pageStatus,
    title: 'Örnek Ürün',
    description: 'Değişmeyen ürün açıklaması',
    price: price,
    currency: 'TRY',
    sellerName: sellerName,
    storeName: storeName,
    imageUrls: imageUrls,
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
