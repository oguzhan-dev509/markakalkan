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
    this.externalPageId,
    this.listingId,
    this.storeId,
    this.lastSnapshotId,
    this.lastSuccessfulScanAt,
    this.lastFailedScanAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String sourceId;
  final MonitoringPageType pageType;
  final String url;
  final String normalizedUrl;
  final String? externalPageId;
  final String? listingId;
  final String? storeId;
  final MonitoringPageStatus status;
  final MonitoringScanFrequency scanFrequency;
  final MonitoringPriority priority;
  final String? lastSnapshotId;
  final DateTime? lastSuccessfulScanAt;
  final DateTime? lastFailedScanAt;
  final int consecutiveFailureCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

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
      url: _requiredString(data['url']),
      normalizedUrl: _requiredString(data['normalizedUrl']),
      externalPageId: _nullableString(data['externalPageId']),
      listingId: _nullableString(data['listingId']),
      storeId: _nullableString(data['storeId']),
      status: MonitoringPageStatusX.fromValue(data['status']?.toString()),
      scanFrequency: MonitoringScanFrequencyX.fromValue(
        data['scanFrequency']?.toString(),
      ),
      priority: MonitoringPriorityX.fromValue(data['priority']?.toString()),
      lastSnapshotId: _nullableString(data['lastSnapshotId']),
      lastSuccessfulScanAt: MonitoringModelUtils.dateTimeFromValue(
        data['lastSuccessfulScanAt'],
      ),
      lastFailedScanAt: MonitoringModelUtils.dateTimeFromValue(
        data['lastFailedScanAt'],
      ),
      consecutiveFailureCount: _intFromValue(data['consecutiveFailureCount']),
      createdAt: createdAt,
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'brandId': brandId,
      'sourceId': sourceId,
      'pageType': pageType.value,
      'url': url.trim(),
      'normalizedUrl': normalizedUrl.trim().isEmpty
          ? _normalizeUrl(url)
          : normalizedUrl.trim(),
      'externalPageId': _cleanNullable(externalPageId),
      'listingId': _cleanNullable(listingId),
      'storeId': _cleanNullable(storeId),
      'status': status.value,
      'scanFrequency': scanFrequency.value,
      'priority': priority.value,
      'lastSnapshotId': _cleanNullable(lastSnapshotId),
      'lastSuccessfulScanAt': lastSuccessfulScanAt == null
          ? null
          : Timestamp.fromDate(lastSuccessfulScanAt!),
      'lastFailedScanAt': lastFailedScanAt == null
          ? null
          : Timestamp.fromDate(lastFailedScanAt!),
      'consecutiveFailureCount': consecutiveFailureCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'pageType': pageType.value,
      'url': url.trim(),
      'normalizedUrl': normalizedUrl.trim().isEmpty
          ? _normalizeUrl(url)
          : normalizedUrl.trim(),
      'externalPageId': _cleanNullable(externalPageId),
      'listingId': _cleanNullable(listingId),
      'storeId': _cleanNullable(storeId),
      'status': status.value,
      'scanFrequency': scanFrequency.value,
      'priority': priority.value,
      'lastSnapshotId': _cleanNullable(lastSnapshotId),
      'lastSuccessfulScanAt': lastSuccessfulScanAt == null
          ? null
          : Timestamp.fromDate(lastSuccessfulScanAt!),
      'lastFailedScanAt': lastFailedScanAt == null
          ? null
          : Timestamp.fromDate(lastFailedScanAt!),
      'consecutiveFailureCount': consecutiveFailureCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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

  static int _intFromValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _normalizeUrl(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(trimmed);

    if (uri == null) {
      return trimmed;
    }

    return uri
        .replace(
          fragment: '',
          queryParameters: uri.queryParameters.isEmpty
              ? null
              : uri.queryParameters,
        )
        .toString();
  }
}
