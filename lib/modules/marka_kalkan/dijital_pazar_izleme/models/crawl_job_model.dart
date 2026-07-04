import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class CrawlJobModel {
  const CrawlJobModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.profileId,
    required this.sourceId,
    required this.jobType,
    required this.targetType,
    required this.targetId,
    required this.scheduleType,
    required this.priority,
    required this.status,
    required this.lastRunStatus,
    required this.failureCount,
    required this.createdAt,
    required this.createdBy,
    this.nextRunAt,
    this.lastRunAt,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String profileId;
  final String sourceId;
  final MonitoringCrawlJobType jobType;
  final MonitoringCrawlTargetType targetType;
  final String targetId;
  final MonitoringScanFrequency scheduleType;
  final MonitoringPriority priority;
  final MonitoringCrawlJobStatus status;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final MonitoringCrawlLastRunStatus lastRunStatus;
  final int failureCount;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory CrawlJobModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Crawl job document has no data: ${document.id}');
    }

    return CrawlJobModel.fromMap(id: document.id, data: data);
  }

  factory CrawlJobModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Crawl job createdAt is missing: $id');
    }

    return CrawlJobModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      profileId: _requiredString(data['profileId']),
      sourceId: _requiredString(data['sourceId']),
      jobType: MonitoringCrawlJobTypeX.fromValue(data['jobType']?.toString()),
      targetType: MonitoringCrawlTargetTypeX.fromValue(
        data['targetType']?.toString(),
      ),
      targetId: _requiredString(data['targetId']),
      scheduleType: MonitoringScanFrequencyX.fromValue(
        data['scheduleType']?.toString(),
      ),
      priority: MonitoringPriorityX.fromValue(data['priority']?.toString()),
      status: MonitoringCrawlJobStatusX.fromValue(data['status']?.toString()),
      nextRunAt: MonitoringModelUtils.dateTimeFromValue(data['nextRunAt']),
      lastRunAt: MonitoringModelUtils.dateTimeFromValue(data['lastRunAt']),
      lastRunStatus: MonitoringCrawlLastRunStatusX.fromValue(
        data['lastRunStatus']?.toString(),
      ),
      failureCount: _intFromValue(data['failureCount']),
      createdAt: createdAt,
      createdBy: _requiredString(data['createdBy']),
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'brandId': brandId,
      'profileId': profileId,
      'sourceId': sourceId,
      'jobType': jobType.value,
      'targetType': targetType.value,
      'targetId': targetId,
      'scheduleType': scheduleType.value,
      'priority': priority.value,
      'status': status.value,
      'nextRunAt': nextRunAt == null ? null : Timestamp.fromDate(nextRunAt!),
      'lastRunAt': lastRunAt == null ? null : Timestamp.fromDate(lastRunAt!),
      'lastRunStatus': lastRunStatus.value,
      'failureCount': failureCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'updatedBy': updatedBy,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'profileId': profileId,
      'sourceId': sourceId,
      'jobType': jobType.value,
      'targetType': targetType.value,
      'targetId': targetId,
      'scheduleType': scheduleType.value,
      'priority': priority.value,
      'status': status.value,
      'nextRunAt': nextRunAt == null ? null : Timestamp.fromDate(nextRunAt!),
      'lastRunAt': lastRunAt == null ? null : Timestamp.fromDate(lastRunAt!),
      'lastRunStatus': lastRunStatus.value,
      'failureCount': failureCount,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  static String _requiredString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
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
}
