import '../constants/monitoring_enums.dart';
import '../models/monitoring_event_model.dart';
import '../models/page_snapshot_model.dart';
import 'snapshot_fingerprint_service.dart';

abstract final class SnapshotDiffService {
  static List<MonitoringEventModel> compare({
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    String? listingId,
    String? sellerId,
    String? storeId,
  }) {
    _validateSnapshotPair(previous: previous, current: current);

    final events = <MonitoringEventModel>[];

    _comparePageStatus(
      events: events,
      previous: previous,
      current: current,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    _comparePrice(
      events: events,
      previous: previous,
      current: current,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    _compareTitle(
      events: events,
      previous: previous,
      current: current,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    _compareDescription(
      events: events,
      previous: previous,
      current: current,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    _compareImages(
      events: events,
      previous: previous,
      current: current,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    _compareSeller(
      events: events,
      previous: previous,
      current: current,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    _compareStore(
      events: events,
      previous: previous,
      current: current,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    _compareStock(
      events: events,
      previous: previous,
      current: current,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    _compareContacts(
      events: events,
      previous: previous,
      current: current,
      detectedAt: detectedAt,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
    );

    return List<MonitoringEventModel>.unmodifiable(events);
  }

  static void _validateSnapshotPair({
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
  }) {
    if (previous.pageId != current.pageId) {
      throw ArgumentError(
        'Snapshots belong to different pages: '
        '${previous.pageId} != ${current.pageId}',
      );
    }

    if (previous.tenantId != current.tenantId) {
      throw ArgumentError('Snapshots belong to different tenants.');
    }

    if (previous.brandId != current.brandId) {
      throw ArgumentError('Snapshots belong to different brands.');
    }

    if (previous.sourceId != current.sourceId) {
      throw ArgumentError('Snapshots belong to different sources.');
    }

    if (current.capturedAt.isBefore(previous.capturedAt)) {
      throw ArgumentError(
        'Current snapshot cannot be older than previous snapshot.',
      );
    }
  }

  static void _comparePageStatus({
    required List<MonitoringEventModel> events,
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
  }) {
    if (previous.pageStatus == current.pageStatus) {
      return;
    }

    MonitoringEventType? eventType;
    MonitoringEventSeverity severity = MonitoringEventSeverity.medium;

    if (current.pageStatus == MonitoringPageStatus.blocked) {
      eventType = MonitoringEventType.pageBlocked;
      severity = MonitoringEventSeverity.high;
    } else if (current.pageStatus == MonitoringPageStatus.redirected) {
      eventType = MonitoringEventType.pageRedirected;
      severity = MonitoringEventSeverity.high;
    } else if (_isUnavailable(previous.pageStatus) &&
        current.pageStatus == MonitoringPageStatus.active) {
      eventType = MonitoringEventType.pageRecovered;
      severity = MonitoringEventSeverity.medium;
    } else if (current.pageStatus == MonitoringPageStatus.removed) {
      eventType = MonitoringEventType.listingRemoved;
      severity = MonitoringEventSeverity.high;
    } else if (previous.pageStatus == MonitoringPageStatus.removed &&
        current.pageStatus == MonitoringPageStatus.active) {
      eventType = MonitoringEventType.listingRepublished;
      severity = MonitoringEventSeverity.high;
    }

    if (eventType == null) {
      return;
    }

    events.add(
      _event(
        previous: previous,
        current: current,
        eventType: eventType,
        category: MonitoringEventCategory.technical,
        severity: severity,
        oldValue: previous.pageStatus.value,
        newValue: current.pageStatus.value,
        summary:
            'Sayfa durumu ${previous.pageStatus.value} değerinden '
            '${current.pageStatus.value} değerine değişti.',
        detectedAt: detectedAt,
        listingId: listingId,
        sellerId: sellerId,
        storeId: storeId,
      ),
    );
  }

  static void _comparePrice({
    required List<MonitoringEventModel> events,
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
  }) {
    final oldPrice = previous.price;
    final newPrice = current.price;

    if (oldPrice == null || newPrice == null || oldPrice == newPrice) {
      return;
    }

    final changeRate = oldPrice == 0 ? null : (newPrice - oldPrice) / oldPrice;

    final decreased = newPrice < oldPrice;
    final severity = _priceSeverity(changeRate);

    events.add(
      _event(
        previous: previous,
        current: current,
        eventType: decreased
            ? MonitoringEventType.priceDecreased
            : MonitoringEventType.priceIncreased,
        category: MonitoringEventCategory.price,
        severity: severity,
        oldValue: oldPrice,
        newValue: newPrice,
        changeRate: changeRate,
        summary: decreased
            ? 'Fiyat $oldPrice değerinden $newPrice değerine düştü.'
            : 'Fiyat $oldPrice değerinden $newPrice değerine yükseldi.',
        detectedAt: detectedAt,
        listingId: listingId,
        sellerId: sellerId,
        storeId: storeId,
      ),
    );
  }

  static void _compareTitle({
    required List<MonitoringEventModel> events,
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
  }) {
    final oldValue = _normalizeText(previous.title);
    final newValue = _normalizeText(current.title);

    if (oldValue == newValue) {
      return;
    }

    events.add(
      _event(
        previous: previous,
        current: current,
        eventType: MonitoringEventType.titleChanged,
        category: MonitoringEventCategory.content,
        severity: MonitoringEventSeverity.medium,
        oldValue: previous.title,
        newValue: current.title,
        summary: 'Ürün veya sayfa başlığı değişti.',
        detectedAt: detectedAt,
        listingId: listingId,
        sellerId: sellerId,
        storeId: storeId,
      ),
    );
  }

  static void _compareDescription({
    required List<MonitoringEventModel> events,
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
  }) {
    final oldHash = previous.textHash;
    final newHash = current.textHash;

    final changed = oldHash != null && newHash != null
        ? oldHash != newHash
        : _normalizeText(previous.description) !=
              _normalizeText(current.description);

    if (!changed) {
      return;
    }

    events.add(
      _event(
        previous: previous,
        current: current,
        eventType: MonitoringEventType.descriptionChanged,
        category: MonitoringEventCategory.content,
        severity: MonitoringEventSeverity.low,
        oldValue: previous.description,
        newValue: current.description,
        summary: 'Sayfa açıklaması veya metin içeriği değişti.',
        detectedAt: detectedAt,
        listingId: listingId,
        sellerId: sellerId,
        storeId: storeId,
      ),
    );
  }

  static void _compareImages({
    required List<MonitoringEventModel> events,
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
  }) {
    final oldHash = previous.imageSetHash;
    final newHash = current.imageSetHash;

    final changed = oldHash != null && newHash != null
        ? oldHash != newHash
        : !_sameStringSet(previous.imageUrls, current.imageUrls);

    if (!changed) {
      return;
    }

    events.add(
      _event(
        previous: previous,
        current: current,
        eventType: MonitoringEventType.imageChanged,
        category: MonitoringEventCategory.media,
        severity: MonitoringEventSeverity.medium,
        oldValue: previous.imageUrls,
        newValue: current.imageUrls,
        summary: 'Sayfadaki görsel seti değişti.',
        detectedAt: detectedAt,
        listingId: listingId,
        sellerId: sellerId,
        storeId: storeId,
      ),
    );
  }

  static void _compareSeller({
    required List<MonitoringEventModel> events,
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
  }) {
    if (_normalizeText(previous.sellerName) ==
        _normalizeText(current.sellerName)) {
      return;
    }

    events.add(
      _event(
        previous: previous,
        current: current,
        eventType: MonitoringEventType.sellerChanged,
        category: MonitoringEventCategory.seller,
        severity: MonitoringEventSeverity.high,
        oldValue: previous.sellerName,
        newValue: current.sellerName,
        summary: 'İlanın görünen satıcısı değişti.',
        detectedAt: detectedAt,
        listingId: listingId,
        sellerId: sellerId,
        storeId: storeId,
      ),
    );
  }

  static void _compareStore({
    required List<MonitoringEventModel> events,
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
  }) {
    if (_normalizeText(previous.storeName) ==
        _normalizeText(current.storeName)) {
      return;
    }

    events.add(
      _event(
        previous: previous,
        current: current,
        eventType: MonitoringEventType.storeNameChanged,
        category: MonitoringEventCategory.store,
        severity: MonitoringEventSeverity.high,
        oldValue: previous.storeName,
        newValue: current.storeName,
        summary: 'Mağaza adı değişti.',
        detectedAt: detectedAt,
        listingId: listingId,
        sellerId: sellerId,
        storeId: storeId,
      ),
    );
  }

  static void _compareStock({
    required List<MonitoringEventModel> events,
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
  }) {
    if (previous.stockStatus == current.stockStatus) {
      return;
    }

    events.add(
      _event(
        previous: previous,
        current: current,
        eventType: MonitoringEventType.stockChanged,
        category: MonitoringEventCategory.availability,
        severity: MonitoringEventSeverity.low,
        oldValue: previous.stockStatus?.value,
        newValue: current.stockStatus?.value,
        summary: 'Stok durumu değişti.',
        detectedAt: detectedAt,
        listingId: listingId,
        sellerId: sellerId,
        storeId: storeId,
      ),
    );
  }

  static void _compareContacts({
    required List<MonitoringEventModel> events,
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
  }) {
    if (_sameIntMap(previous.contactSummary, current.contactSummary)) {
      return;
    }

    events.add(
      _event(
        previous: previous,
        current: current,
        eventType: MonitoringEventType.contactChanged,
        category: MonitoringEventCategory.identity,
        severity: MonitoringEventSeverity.high,
        oldValue: previous.contactSummary,
        newValue: current.contactSummary,
        summary: 'Sayfadaki iletişim bilgisi özeti değişti.',
        detectedAt: detectedAt,
        listingId: listingId,
        sellerId: sellerId,
        storeId: storeId,
      ),
    );
  }

  static MonitoringEventModel _event({
    required PageSnapshotModel previous,
    required PageSnapshotModel current,
    required MonitoringEventType eventType,
    required MonitoringEventCategory category,
    required MonitoringEventSeverity severity,
    required dynamic oldValue,
    required dynamic newValue,
    required String summary,
    required DateTime detectedAt,
    required String? listingId,
    required String? sellerId,
    required String? storeId,
    double? changeRate,
  }) {
    return MonitoringEventModel(
      id: SnapshotFingerprintService.deterministicEventId(
        tenantId: current.tenantId,
        pageId: current.pageId,
        currentSnapshotId: current.id,
        eventType: eventType.value,
      ),
      tenantId: current.tenantId,
      brandId: current.brandId,
      sourceId: current.sourceId,
      pageId: current.pageId,
      listingId: listingId,
      sellerId: sellerId,
      storeId: storeId,
      eventType: eventType,
      eventCategory: category,
      previousSnapshotId: previous.id,
      currentSnapshotId: current.id,
      oldValue: oldValue,
      newValue: newValue,
      changeRate: changeRate,
      severity: severity,
      status: MonitoringEventStatus.newEvent,
      summary: summary,
      detectedAt: detectedAt,
      createdBySystem: true,
      createdAt: detectedAt,
    );
  }

  static MonitoringEventSeverity _priceSeverity(double? changeRate) {
    if (changeRate == null) {
      return MonitoringEventSeverity.medium;
    }

    final absoluteRate = changeRate.abs();

    if (absoluteRate >= 0.50) {
      return MonitoringEventSeverity.critical;
    }

    if (absoluteRate >= 0.30) {
      return MonitoringEventSeverity.high;
    }

    if (absoluteRate >= 0.10) {
      return MonitoringEventSeverity.medium;
    }

    return MonitoringEventSeverity.low;
  }

  static bool _isUnavailable(MonitoringPageStatus status) {
    return status == MonitoringPageStatus.removed ||
        status == MonitoringPageStatus.blocked ||
        status == MonitoringPageStatus.error ||
        status == MonitoringPageStatus.inactive;
  }

  static String _normalizeText(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _sameStringSet(List<String> first, List<String> second) {
    final firstSet = first.map((item) => item.trim()).toSet();
    final secondSet = second.map((item) => item.trim()).toSet();

    return firstSet.length == secondSet.length &&
        firstSet.containsAll(secondSet);
  }

  static bool _sameIntMap(Map<String, int> first, Map<String, int> second) {
    if (first.length != second.length) {
      return false;
    }

    for (final entry in first.entries) {
      if (second[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }
}
