import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class MonitoredPageModel {
  const MonitoredPageModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.sourceId,
    required this.pageType,
    required this.url,
    required this.normalizedUrl,
    required this.status,
    required this.scanFrequency,
    required this.priority,
    required this.consecutiveFailureCount,
    required this.createdAt,
    this.title,
    this.domain,
    this.platform,
    this.marketplace,
    this.externalPageId,
    this.listingId,
    this.sellerId,
    this.storeId,
    this.sellerName,
    this.storeName,
    this.productName,
    this.productBrand,
    this.trackingStatus = MonitoringPageTrackingStatus.active,
    this.discoveryMethod = MonitoringPageDiscoveryMethod.manual,
    this.firstSeenAt,
    this.lastSeenAt,
    this.lastScannedAt,
    this.nextScanAt,
    this.removedAt,
    this.republishedAt,
    this.lastSnapshotId,
    this.previousSnapshotId,
    this.lastCrawlJobId,
    this.lastCrawlRunId,
    this.lastSuccessfulScanAt,
    this.lastFailedScanAt,
    this.riskScore = 0,
    this.riskLevel = MonitoringSignalLevel.info,
    this.eventCount = 0,
    this.signalCount = 0,
    this.openSignalCount = 0,
    this.tags = const <String>[],
    this.notes,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String sourceId;

  final MonitoringPageType pageType;

  final String? title;
  final String url;
  final String normalizedUrl;
  final String? domain;
  final String? platform;
  final String? marketplace;

  final String? externalPageId;
  final String? listingId;
  final String? sellerId;
  final String? storeId;

  final String? sellerName;
  final String? storeName;
  final String? productName;
  final String? productBrand;

  final MonitoringPageStatus status;
  final MonitoringPageTrackingStatus trackingStatus;
  final MonitoringPageDiscoveryMethod discoveryMethod;
  final MonitoringScanFrequency scanFrequency;
  final MonitoringPriority priority;

  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final DateTime? lastScannedAt;
  final DateTime? nextScanAt;
  final DateTime? removedAt;
  final DateTime? republishedAt;

  final String? lastSnapshotId;
  final String? previousSnapshotId;
  final String? lastCrawlJobId;
  final String? lastCrawlRunId;

  final DateTime? lastSuccessfulScanAt;
  final DateTime? lastFailedScanAt;
  final int consecutiveFailureCount;

  final int riskScore;
  final MonitoringSignalLevel riskLevel;

  final int eventCount;
  final int signalCount;
  final int openSignalCount;

  final List<String> tags;
  final String? notes;

  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory MonitoredPageModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Monitored page document has no data: ${document.id}');
    }

    return MonitoredPageModel.fromMap(id: document.id, data: data);
  }

  factory MonitoredPageModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Monitored page createdAt is missing: $id');
    }

    return MonitoredPageModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      sourceId: _requiredString(data['sourceId']),
      pageType: MonitoringPageTypeX.fromValue(data['pageType']?.toString()),
      title: _nullableString(data['title']),
      url: _requiredString(data['url']),
      normalizedUrl: _requiredString(data['normalizedUrl']),
      domain: _nullableString(data['domain']),
      platform: _nullableString(data['platform']),
      marketplace: _nullableString(data['marketplace']),
      externalPageId: _nullableString(data['externalPageId']),
      listingId: _nullableString(data['listingId']),
      sellerId: _nullableString(data['sellerId']),
      storeId: _nullableString(data['storeId']),
      sellerName: _nullableString(data['sellerName']),
      storeName: _nullableString(data['storeName']),
      productName: _nullableString(data['productName']),
      productBrand: _nullableString(data['productBrand']),
      status: MonitoringPageStatusX.fromValue(data['status']?.toString()),
      trackingStatus: MonitoringPageTrackingStatusX.fromValue(
        data['trackingStatus']?.toString(),
      ),
      discoveryMethod: MonitoringPageDiscoveryMethodX.fromValue(
        data['discoveryMethod']?.toString(),
      ),
      scanFrequency: MonitoringScanFrequencyX.fromValue(
        data['scanFrequency']?.toString(),
      ),
      priority: MonitoringPriorityX.fromValue(data['priority']?.toString()),
      firstSeenAt: MonitoringModelUtils.dateTimeFromValue(data['firstSeenAt']),
      lastSeenAt: MonitoringModelUtils.dateTimeFromValue(data['lastSeenAt']),
      lastScannedAt: MonitoringModelUtils.dateTimeFromValue(
        data['lastScannedAt'],
      ),
      nextScanAt: MonitoringModelUtils.dateTimeFromValue(data['nextScanAt']),
      removedAt: MonitoringModelUtils.dateTimeFromValue(data['removedAt']),
      republishedAt: MonitoringModelUtils.dateTimeFromValue(
        data['republishedAt'],
      ),
      lastSnapshotId: _nullableString(data['lastSnapshotId']),
      previousSnapshotId: _nullableString(data['previousSnapshotId']),
      lastCrawlJobId: _nullableString(data['lastCrawlJobId']),
      lastCrawlRunId: _nullableString(data['lastCrawlRunId']),
      lastSuccessfulScanAt: MonitoringModelUtils.dateTimeFromValue(
        data['lastSuccessfulScanAt'],
      ),
      lastFailedScanAt: MonitoringModelUtils.dateTimeFromValue(
        data['lastFailedScanAt'],
      ),
      consecutiveFailureCount: _intFromValue(data['consecutiveFailureCount']),
      riskScore: _boundedRiskScore(data['riskScore']),
      riskLevel: MonitoringSignalLevelX.fromValue(
        data['riskLevel']?.toString(),
      ),
      eventCount: _nonNegativeInt(data['eventCount']),
      signalCount: _nonNegativeInt(data['signalCount']),
      openSignalCount: _nonNegativeInt(data['openSignalCount']),
      tags: MonitoringModelUtils.stringListFromValue(data['tags']),
      notes: _nullableString(data['notes']),
      createdBy: _nullableString(data['createdBy']),
      createdAt: createdAt,
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    final cleanedUrl = url.trim();
    final cleanedNormalizedUrl = normalizedUrl.trim().isEmpty
        ? normalizeUrl(cleanedUrl)
        : normalizedUrl.trim();

    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'sourceId': sourceId.trim(),
      'pageType': pageType.value,
      'title': _cleanNullable(title),
      'url': cleanedUrl,
      'normalizedUrl': cleanedNormalizedUrl,
      'domain': _cleanNullable(domain) ?? domainFromUrl(cleanedNormalizedUrl),
      'platform': _cleanNullable(platform),
      'marketplace': _cleanNullable(marketplace),
      'externalPageId': _cleanNullable(externalPageId),
      'listingId': _cleanNullable(listingId),
      'sellerId': _cleanNullable(sellerId),
      'storeId': _cleanNullable(storeId),
      'sellerName': _cleanNullable(sellerName),
      'storeName': _cleanNullable(storeName),
      'productName': _cleanNullable(productName),
      'productBrand': _cleanNullable(productBrand),
      'status': status.value,
      'trackingStatus': trackingStatus.value,
      'discoveryMethod': discoveryMethod.value,
      'scanFrequency': scanFrequency.value,
      'priority': priority.value,
      'firstSeenAt': _timestampOrNull(firstSeenAt),
      'lastSeenAt': _timestampOrNull(lastSeenAt),
      'lastScannedAt': _timestampOrNull(lastScannedAt),
      'nextScanAt': _timestampOrNull(nextScanAt),
      'removedAt': _timestampOrNull(removedAt),
      'republishedAt': _timestampOrNull(republishedAt),
      'lastSnapshotId': _cleanNullable(lastSnapshotId),
      'previousSnapshotId': _cleanNullable(previousSnapshotId),
      'lastCrawlJobId': _cleanNullable(lastCrawlJobId),
      'lastCrawlRunId': _cleanNullable(lastCrawlRunId),
      'lastSuccessfulScanAt': _timestampOrNull(lastSuccessfulScanAt),
      'lastFailedScanAt': _timestampOrNull(lastFailedScanAt),
      'consecutiveFailureCount': consecutiveFailureCount < 0
          ? 0
          : consecutiveFailureCount,
      'riskScore': riskScore.clamp(0, 100),
      'riskLevel': riskLevel.value,
      'eventCount': eventCount < 0 ? 0 : eventCount,
      'signalCount': signalCount < 0 ? 0 : signalCount,
      'openSignalCount': openSignalCount < 0 ? 0 : openSignalCount,
      'tags': _cleanStringList(tags),
      'notes': _cleanNullable(notes),
      'createdBy': _cleanNullable(createdBy),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    final map = toCreateMap();

    map
      ..remove('tenantId')
      ..remove('brandId')
      ..remove('sourceId')
      ..remove('createdAt')
      ..remove('createdBy')
      ..['updatedAt'] = FieldValue.serverTimestamp();

    return map;
  }

  MonitoredPageModel copyWith({
    String? id,
    String? tenantId,
    String? brandId,
    String? sourceId,
    MonitoringPageType? pageType,
    String? title,
    String? url,
    String? normalizedUrl,
    String? domain,
    String? platform,
    String? marketplace,
    String? externalPageId,
    String? listingId,
    String? sellerId,
    String? storeId,
    String? sellerName,
    String? storeName,
    String? productName,
    String? productBrand,
    MonitoringPageStatus? status,
    MonitoringPageTrackingStatus? trackingStatus,
    MonitoringPageDiscoveryMethod? discoveryMethod,
    MonitoringScanFrequency? scanFrequency,
    MonitoringPriority? priority,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    DateTime? lastScannedAt,
    DateTime? nextScanAt,
    DateTime? removedAt,
    DateTime? republishedAt,
    String? lastSnapshotId,
    String? previousSnapshotId,
    String? lastCrawlJobId,
    String? lastCrawlRunId,
    DateTime? lastSuccessfulScanAt,
    DateTime? lastFailedScanAt,
    int? consecutiveFailureCount,
    int? riskScore,
    MonitoringSignalLevel? riskLevel,
    int? eventCount,
    int? signalCount,
    int? openSignalCount,
    List<String>? tags,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return MonitoredPageModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      brandId: brandId ?? this.brandId,
      sourceId: sourceId ?? this.sourceId,
      pageType: pageType ?? this.pageType,
      title: title ?? this.title,
      url: url ?? this.url,
      normalizedUrl: normalizedUrl ?? this.normalizedUrl,
      domain: domain ?? this.domain,
      platform: platform ?? this.platform,
      marketplace: marketplace ?? this.marketplace,
      externalPageId: externalPageId ?? this.externalPageId,
      listingId: listingId ?? this.listingId,
      sellerId: sellerId ?? this.sellerId,
      storeId: storeId ?? this.storeId,
      sellerName: sellerName ?? this.sellerName,
      storeName: storeName ?? this.storeName,
      productName: productName ?? this.productName,
      productBrand: productBrand ?? this.productBrand,
      status: status ?? this.status,
      trackingStatus: trackingStatus ?? this.trackingStatus,
      discoveryMethod: discoveryMethod ?? this.discoveryMethod,
      scanFrequency: scanFrequency ?? this.scanFrequency,
      priority: priority ?? this.priority,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      nextScanAt: nextScanAt ?? this.nextScanAt,
      removedAt: removedAt ?? this.removedAt,
      republishedAt: republishedAt ?? this.republishedAt,
      lastSnapshotId: lastSnapshotId ?? this.lastSnapshotId,
      previousSnapshotId: previousSnapshotId ?? this.previousSnapshotId,
      lastCrawlJobId: lastCrawlJobId ?? this.lastCrawlJobId,
      lastCrawlRunId: lastCrawlRunId ?? this.lastCrawlRunId,
      lastSuccessfulScanAt: lastSuccessfulScanAt ?? this.lastSuccessfulScanAt,
      lastFailedScanAt: lastFailedScanAt ?? this.lastFailedScanAt,
      consecutiveFailureCount:
          consecutiveFailureCount ?? this.consecutiveFailureCount,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      eventCount: eventCount ?? this.eventCount,
      signalCount: signalCount ?? this.signalCount,
      openSignalCount: openSignalCount ?? this.openSignalCount,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  bool get isActivelyMonitored {
    return trackingStatus == MonitoringPageTrackingStatus.active;
  }

  bool get isAvailable {
    return status == MonitoringPageStatus.active;
  }

  bool get hasOpenSignals {
    return openSignalCount > 0;
  }

  bool get isHighRisk {
    return riskLevel == MonitoringSignalLevel.high ||
        riskLevel == MonitoringSignalLevel.critical;
  }

  static String normalizeUrl(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(candidate);

    if (uri == null || uri.host.trim().isEmpty) {
      return trimmed;
    }

    final filteredQuery = <String, String>{};

    for (final entry in uri.queryParameters.entries) {
      final key = entry.key.toLowerCase();

      if (key.startsWith('utm_') ||
          key == 'fbclid' ||
          key == 'gclid' ||
          key == 'ref' ||
          key == 'source') {
        continue;
      }

      filteredQuery[entry.key] = entry.value;
    }

    var path = uri.path;

    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    return uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          path: path,
          fragment: '',
          queryParameters: filteredQuery.isEmpty ? null : filteredQuery,
        )
        .toString();
  }

  static String? domainFromUrl(String value) {
    final normalized = normalizeUrl(value);
    final uri = Uri.tryParse(normalized);
    final host = uri?.host.trim().toLowerCase();

    if (host == null || host.isEmpty) {
      return null;
    }

    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static String _requiredString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  static Timestamp? _timestampOrNull(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }

  static int _intFromValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _nonNegativeInt(dynamic value) {
    final parsed = _intFromValue(value);
    return parsed < 0 ? 0 : parsed;
  }

  static int _boundedRiskScore(dynamic value) {
    return _intFromValue(value).clamp(0, 100);
  }

  static List<String> _cleanStringList(List<String> values) {
    final cleaned = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    cleaned.sort();
    return cleaned;
  }
}
