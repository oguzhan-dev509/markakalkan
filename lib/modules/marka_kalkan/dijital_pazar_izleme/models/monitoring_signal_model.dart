import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class MonitoringSignalModel {
  const MonitoringSignalModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.sourceId,
    required this.pageId,
    required this.eventId,
    required this.ruleId,
    required this.signalLevel,
    required this.status,
    required this.forwardingStatus,
    required this.title,
    required this.summary,
    required this.detectedAt,
    required this.createdAt,
    this.listingId,
    this.sellerId,
    this.storeId,
    this.eventType,
    this.eventCategory,
    this.ruleName,
    this.reviewedAt,
    this.reviewedBy,
    this.forwardedAt,
    this.forwardingError,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String sourceId;
  final String pageId;
  final String? listingId;
  final String? sellerId;
  final String? storeId;
  final String eventId;
  final String ruleId;
  final String? ruleName;
  final MonitoringEventType? eventType;
  final MonitoringEventCategory? eventCategory;
  final MonitoringSignalLevel signalLevel;
  final MonitoringSignalStatus status;
  final MonitoringSignalForwardingStatus forwardingStatus;
  final String title;
  final String summary;
  final DateTime detectedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final DateTime? forwardedAt;
  final String? forwardingError;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory MonitoringSignalModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Monitoring signal document has no data: ${document.id}',
      );
    }

    return MonitoringSignalModel.fromMap(id: document.id, data: data);
  }

  factory MonitoringSignalModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final detectedAt = MonitoringModelUtils.dateTimeFromValue(
      data['detectedAt'],
    );
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (detectedAt == null || createdAt == null) {
      throw StateError('Monitoring signal timestamps are incomplete: $id');
    }

    final eventTypeValue = data['eventType']?.toString();
    final eventCategoryValue = data['eventCategory']?.toString();

    return MonitoringSignalModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      sourceId: _requiredString(data['sourceId']),
      pageId: _requiredString(data['pageId']),
      listingId: _nullableString(data['listingId']),
      sellerId: _nullableString(data['sellerId']),
      storeId: _nullableString(data['storeId']),
      eventId: _requiredString(data['eventId']),
      ruleId: _requiredString(data['ruleId']),
      ruleName: _nullableString(data['ruleName']),
      eventType: eventTypeValue == null
          ? null
          : MonitoringEventTypeX.fromValue(eventTypeValue),
      eventCategory: eventCategoryValue == null
          ? null
          : MonitoringEventCategoryX.fromValue(eventCategoryValue),
      signalLevel: MonitoringSignalLevelX.fromValue(
        data['signalLevel']?.toString(),
      ),
      status: MonitoringSignalStatusX.fromValue(data['status']?.toString()),
      forwardingStatus: MonitoringSignalForwardingStatusX.fromValue(
        data['forwardingStatus']?.toString(),
      ),
      title: _requiredString(data['title']),
      summary: _requiredString(data['summary']),
      detectedAt: detectedAt,
      reviewedAt: MonitoringModelUtils.dateTimeFromValue(data['reviewedAt']),
      reviewedBy: _nullableString(data['reviewedBy']),
      forwardedAt: MonitoringModelUtils.dateTimeFromValue(data['forwardedAt']),
      forwardingError: _nullableString(data['forwardingError']),
      resolvedAt: MonitoringModelUtils.dateTimeFromValue(data['resolvedAt']),
      resolvedBy: _nullableString(data['resolvedBy']),
      resolutionNote: _nullableString(data['resolutionNote']),
      createdAt: createdAt,
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
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
      'eventId': eventId,
      'ruleId': ruleId,
      'ruleName': _cleanNullable(ruleName),
      'eventType': eventType?.value,
      'eventCategory': eventCategory?.value,
      'signalLevel': signalLevel.value,
      'status': status.value,
      'forwardingStatus': forwardingStatus.value,
      'title': title.trim(),
      'summary': summary.trim(),
      'detectedAt': Timestamp.fromDate(detectedAt),
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'reviewedBy': _cleanNullable(reviewedBy),
      'forwardedAt': forwardedAt == null
          ? null
          : Timestamp.fromDate(forwardedAt!),
      'forwardingError': _cleanNullable(forwardingError),
      'resolvedAt': resolvedAt == null ? null : Timestamp.fromDate(resolvedAt!),
      'resolvedBy': _cleanNullable(resolvedBy),
      'resolutionNote': _cleanNullable(resolutionNote),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toReviewUpdateMap({
    required MonitoringSignalStatus newStatus,
    required String reviewerId,
  }) {
    return <String, dynamic>{
      'status': newStatus.value,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewerId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': reviewerId.trim(),
    };
  }

  Map<String, dynamic> toForwardingUpdateMap({
    required MonitoringSignalForwardingStatus newStatus,
    String? errorMessage,
  }) {
    return <String, dynamic>{
      'forwardingStatus': newStatus.value,
      'forwardedAt': newStatus == MonitoringSignalForwardingStatus.forwarded
          ? FieldValue.serverTimestamp()
          : forwardedAt == null
          ? null
          : Timestamp.fromDate(forwardedAt!),
      'forwardingError': _cleanNullable(errorMessage),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toResolutionUpdateMap({
    required String resolverId,
    required String note,
  }) {
    return <String, dynamic>{
      'status': MonitoringSignalStatus.resolved.value,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': resolverId.trim(),
      'resolutionNote': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': resolverId.trim(),
    };
  }

  bool get isOpen {
    return status == MonitoringSignalStatus.newSignal ||
        status == MonitoringSignalStatus.underReview ||
        status == MonitoringSignalStatus.confirmed ||
        status == MonitoringSignalStatus.escalated;
  }

  bool get requiresImmediateAttention {
    return signalLevel == MonitoringSignalLevel.high ||
        signalLevel == MonitoringSignalLevel.critical;
  }

  bool get wasForwarded {
    return forwardingStatus == MonitoringSignalForwardingStatus.forwarded;
  }

  bool get hasForwardingFailure {
    return forwardingStatus == MonitoringSignalForwardingStatus.failed;
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
}
