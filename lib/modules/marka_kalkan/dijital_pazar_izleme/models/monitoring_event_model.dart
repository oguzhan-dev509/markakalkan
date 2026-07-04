import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class MonitoringEventModel {
  const MonitoringEventModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.sourceId,
    required this.pageId,
    required this.eventType,
    required this.eventCategory,
    required this.previousSnapshotId,
    required this.currentSnapshotId,
    required this.severity,
    required this.status,
    required this.detectedAt,
    required this.createdBySystem,
    required this.createdAt,
    this.listingId,
    this.sellerId,
    this.storeId,
    this.oldValue,
    this.newValue,
    this.changeRate,
    this.summary,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String sourceId;
  final String pageId;
  final String? listingId;
  final String? sellerId;
  final String? storeId;
  final MonitoringEventType eventType;
  final MonitoringEventCategory eventCategory;
  final String previousSnapshotId;
  final String currentSnapshotId;
  final dynamic oldValue;
  final dynamic newValue;
  final double? changeRate;
  final MonitoringEventSeverity severity;
  final MonitoringEventStatus status;
  final String? summary;
  final DateTime detectedAt;
  final bool createdBySystem;
  final DateTime createdAt;

  factory MonitoringEventModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Monitoring event document has no data: ${document.id}');
    }

    return MonitoringEventModel.fromMap(id: document.id, data: data);
  }

  factory MonitoringEventModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final detectedAt = MonitoringModelUtils.dateTimeFromValue(
      data['detectedAt'],
    );
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (detectedAt == null || createdAt == null) {
      throw StateError('Monitoring event timestamps are incomplete: $id');
    }

    return MonitoringEventModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      sourceId: _requiredString(data['sourceId']),
      pageId: _requiredString(data['pageId']),
      listingId: _nullableString(data['listingId']),
      sellerId: _nullableString(data['sellerId']),
      storeId: _nullableString(data['storeId']),
      eventType: MonitoringEventTypeX.fromValue(data['eventType']?.toString()),
      eventCategory: MonitoringEventCategoryX.fromValue(
        data['eventCategory']?.toString(),
      ),
      previousSnapshotId: _requiredString(data['previousSnapshotId']),
      currentSnapshotId: _requiredString(data['currentSnapshotId']),
      oldValue: data['oldValue'],
      newValue: data['newValue'],
      changeRate: _nullableDouble(data['changeRate']),
      severity: MonitoringEventSeverityX.fromValue(
        data['severity']?.toString(),
      ),
      status: MonitoringEventStatusX.fromValue(data['status']?.toString()),
      summary: _nullableString(data['summary']),
      detectedAt: detectedAt,
      createdBySystem: MonitoringModelUtils.boolFromValue(
        data['createdBySystem'],
        defaultValue: true,
      ),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'brandId': brandId,
      'sourceId': sourceId,
      'pageId': pageId,
      'listingId': _cleanNullable(listingId),
      'sellerId': _cleanNullable(sellerId),
      'storeId': _cleanNullable(storeId),
      'eventType': eventType.value,
      'eventCategory': eventCategory.value,
      'previousSnapshotId': previousSnapshotId,
      'currentSnapshotId': currentSnapshotId,
      'oldValue': oldValue,
      'newValue': newValue,
      'changeRate': changeRate,
      'severity': severity.value,
      'status': status.value,
      'summary': _cleanNullable(summary),
      'detectedAt': Timestamp.fromDate(detectedAt),
      'createdBySystem': createdBySystem,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toReviewUpdateMap({
    required MonitoringEventStatus newStatus,
  }) {
    return <String, dynamic>{
      'status': newStatus.value,
      'reviewedAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isPriceEvent {
    return eventCategory == MonitoringEventCategory.price;
  }

  bool get isCritical {
    return severity == MonitoringEventSeverity.critical;
  }

  bool get requiresAttention {
    return severity == MonitoringEventSeverity.high ||
        severity == MonitoringEventSeverity.critical;
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

  static double? _nullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    return MonitoringModelUtils.doubleFromValue(value);
  }
}
