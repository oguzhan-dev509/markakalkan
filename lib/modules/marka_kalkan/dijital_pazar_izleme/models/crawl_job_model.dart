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
    required this.name,
    required this.jobType,
    required this.targetType,
    required this.targetId,
    required this.scheduleType,
    required this.priority,
    required this.status,
    required this.lastRunStatus,
    required this.createdAt,
    required this.createdBy,
    this.description,
    this.pageId,
    this.targetUrl,
    this.triggerType = MonitoringCrawlTriggerType.scheduled,
    this.executionMode = MonitoringCrawlExecutionMode.queue,
    this.nextRunAt,
    this.lastRunAt,
    this.lastRunId,
    this.totalRunCount = 0,
    this.successCount = 0,
    this.partialSuccessCount = 0,
    this.failureCount = 0,
    this.blockedCount = 0,
    this.consecutiveFailureCount = 0,
    this.maxRetryCount = 3,
    this.retryDelayMinutes = 15,
    this.leaseOwner,
    this.leaseAcquiredAt,
    this.leaseExpiresAt,
    this.lastRequestedAt,
    this.lastRequestedBy,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String profileId;
  final String sourceId;

  final String name;
  final String? description;

  final MonitoringCrawlJobType jobType;
  final MonitoringCrawlTargetType targetType;

  final String targetId;
  final String? pageId;
  final String? targetUrl;

  final MonitoringScanFrequency scheduleType;
  final MonitoringCrawlTriggerType triggerType;
  final MonitoringCrawlExecutionMode executionMode;

  final MonitoringPriority priority;
  final MonitoringCrawlJobStatus status;

  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final String? lastRunId;
  final MonitoringCrawlLastRunStatus lastRunStatus;

  final int totalRunCount;
  final int successCount;
  final int partialSuccessCount;
  final int failureCount;
  final int blockedCount;
  final int consecutiveFailureCount;

  final int maxRetryCount;
  final int retryDelayMinutes;

  final String? leaseOwner;
  final DateTime? leaseAcquiredAt;
  final DateTime? leaseExpiresAt;

  final DateTime? lastRequestedAt;
  final String? lastRequestedBy;

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

    final targetId = _requiredString(data['targetId']);
    final pageId = _nullableString(data['pageId']);

    return CrawlJobModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      profileId: _requiredString(data['profileId']),
      sourceId: _requiredString(data['sourceId']),
      name: _requiredString(data['name']).isEmpty
          ? 'Tarama Görevi'
          : _requiredString(data['name']),
      description: _nullableString(data['description']),
      jobType: MonitoringCrawlJobTypeX.fromValue(data['jobType']?.toString()),
      targetType: MonitoringCrawlTargetTypeX.fromValue(
        data['targetType']?.toString(),
      ),
      targetId: targetId,
      pageId: pageId ?? (targetId.isEmpty ? null : targetId),
      targetUrl: _nullableString(data['targetUrl']),
      scheduleType: MonitoringScanFrequencyX.fromValue(
        data['scheduleType']?.toString(),
      ),
      triggerType: MonitoringCrawlTriggerTypeX.fromValue(
        data['triggerType']?.toString(),
      ),
      executionMode: MonitoringCrawlExecutionModeX.fromValue(
        data['executionMode']?.toString(),
      ),
      priority: MonitoringPriorityX.fromValue(data['priority']?.toString()),
      status: MonitoringCrawlJobStatusX.fromValue(data['status']?.toString()),
      nextRunAt: MonitoringModelUtils.dateTimeFromValue(data['nextRunAt']),
      lastRunAt: MonitoringModelUtils.dateTimeFromValue(data['lastRunAt']),
      lastRunId: _nullableString(data['lastRunId']),
      lastRunStatus: MonitoringCrawlLastRunStatusX.fromValue(
        data['lastRunStatus']?.toString(),
      ),
      totalRunCount: _nonNegativeInt(data['totalRunCount']),
      successCount: _nonNegativeInt(data['successCount']),
      partialSuccessCount: _nonNegativeInt(data['partialSuccessCount']),
      failureCount: _nonNegativeInt(data['failureCount']),
      blockedCount: _nonNegativeInt(data['blockedCount']),
      consecutiveFailureCount: _nonNegativeInt(
        data['consecutiveFailureCount'] ?? data['failureCount'],
      ),
      maxRetryCount: _boundedInt(
        data['maxRetryCount'],
        minimum: 0,
        maximum: 20,
        fallback: 3,
      ),
      retryDelayMinutes: _boundedInt(
        data['retryDelayMinutes'],
        minimum: 1,
        maximum: 1440,
        fallback: 15,
      ),
      leaseOwner: _nullableString(data['leaseOwner']),
      leaseAcquiredAt: MonitoringModelUtils.dateTimeFromValue(
        data['leaseAcquiredAt'],
      ),
      leaseExpiresAt: MonitoringModelUtils.dateTimeFromValue(
        data['leaseExpiresAt'],
      ),
      lastRequestedAt: MonitoringModelUtils.dateTimeFromValue(
        data['lastRequestedAt'],
      ),
      lastRequestedBy: _nullableString(data['lastRequestedBy']),
      createdAt: createdAt,
      createdBy: _requiredString(data['createdBy']),
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'profileId': profileId.trim(),
      'sourceId': sourceId.trim(),
      'name': name.trim(),
      'description': _cleanNullable(description),
      'jobType': jobType.value,
      'targetType': targetType.value,
      'targetId': targetId.trim(),
      'pageId': _cleanNullable(pageId),
      'targetUrl': _cleanNullable(targetUrl),
      'scheduleType': scheduleType.value,
      'triggerType': triggerType.value,
      'executionMode': executionMode.value,
      'priority': priority.value,
      'status': status.value,
      'nextRunAt': _timestampOrNull(nextRunAt),
      'lastRunAt': _timestampOrNull(lastRunAt),
      'lastRunId': _cleanNullable(lastRunId),
      'lastRunStatus': lastRunStatus.value,
      'totalRunCount': _nonNegative(totalRunCount),
      'successCount': _nonNegative(successCount),
      'partialSuccessCount': _nonNegative(partialSuccessCount),
      'failureCount': _nonNegative(failureCount),
      'blockedCount': _nonNegative(blockedCount),
      'consecutiveFailureCount': _nonNegative(consecutiveFailureCount),
      'maxRetryCount': _bounded(maxRetryCount, minimum: 0, maximum: 20),
      'retryDelayMinutes': _bounded(
        retryDelayMinutes,
        minimum: 1,
        maximum: 1440,
      ),
      'leaseOwner': _cleanNullable(leaseOwner),
      'leaseAcquiredAt': _timestampOrNull(leaseAcquiredAt),
      'leaseExpiresAt': _timestampOrNull(leaseExpiresAt),
      'lastRequestedAt': _timestampOrNull(lastRequestedAt),
      'lastRequestedBy': _cleanNullable(lastRequestedBy),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': _timestampOrNull(updatedAt),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    final map = toCreateMap();

    map
      ..remove('tenantId')
      ..remove('brandId')
      ..remove('createdAt')
      ..remove('createdBy')
      ..['updatedAt'] = FieldValue.serverTimestamp();

    return map;
  }

  CrawlJobModel copyWith({
    String? id,
    String? tenantId,
    String? brandId,
    String? profileId,
    String? sourceId,
    String? name,
    String? description,
    MonitoringCrawlJobType? jobType,
    MonitoringCrawlTargetType? targetType,
    String? targetId,
    String? pageId,
    String? targetUrl,
    MonitoringScanFrequency? scheduleType,
    MonitoringCrawlTriggerType? triggerType,
    MonitoringCrawlExecutionMode? executionMode,
    MonitoringPriority? priority,
    MonitoringCrawlJobStatus? status,
    DateTime? nextRunAt,
    DateTime? lastRunAt,
    String? lastRunId,
    MonitoringCrawlLastRunStatus? lastRunStatus,
    int? totalRunCount,
    int? successCount,
    int? partialSuccessCount,
    int? failureCount,
    int? blockedCount,
    int? consecutiveFailureCount,
    int? maxRetryCount,
    int? retryDelayMinutes,
    String? leaseOwner,
    DateTime? leaseAcquiredAt,
    DateTime? leaseExpiresAt,
    DateTime? lastRequestedAt,
    String? lastRequestedBy,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return CrawlJobModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      brandId: brandId ?? this.brandId,
      profileId: profileId ?? this.profileId,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      description: description ?? this.description,
      jobType: jobType ?? this.jobType,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      pageId: pageId ?? this.pageId,
      targetUrl: targetUrl ?? this.targetUrl,
      scheduleType: scheduleType ?? this.scheduleType,
      triggerType: triggerType ?? this.triggerType,
      executionMode: executionMode ?? this.executionMode,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastRunId: lastRunId ?? this.lastRunId,
      lastRunStatus: lastRunStatus ?? this.lastRunStatus,
      totalRunCount: totalRunCount ?? this.totalRunCount,
      successCount: successCount ?? this.successCount,
      partialSuccessCount: partialSuccessCount ?? this.partialSuccessCount,
      failureCount: failureCount ?? this.failureCount,
      blockedCount: blockedCount ?? this.blockedCount,
      consecutiveFailureCount:
          consecutiveFailureCount ?? this.consecutiveFailureCount,
      maxRetryCount: maxRetryCount ?? this.maxRetryCount,
      retryDelayMinutes: retryDelayMinutes ?? this.retryDelayMinutes,
      leaseOwner: leaseOwner ?? this.leaseOwner,
      leaseAcquiredAt: leaseAcquiredAt ?? this.leaseAcquiredAt,
      leaseExpiresAt: leaseExpiresAt ?? this.leaseExpiresAt,
      lastRequestedAt: lastRequestedAt ?? this.lastRequestedAt,
      lastRequestedBy: lastRequestedBy ?? this.lastRequestedBy,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  bool get isActive {
    return status == MonitoringCrawlJobStatus.active;
  }

  bool get isLeased {
    if (leaseOwner == null || leaseExpiresAt == null) {
      return false;
    }

    return leaseExpiresAt!.isAfter(DateTime.now());
  }

  bool get canRun {
    return isActive && !isLeased;
  }

  bool get hasRepeatedFailures {
    return consecutiveFailureCount >= maxRetryCount && maxRetryCount > 0;
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
    return _nonNegative(_intFromValue(value));
  }

  static int _boundedInt(
    dynamic value, {
    required int minimum,
    required int maximum,
    required int fallback,
  }) {
    final parsed = value == null ? fallback : _intFromValue(value);
    return _bounded(parsed, minimum: minimum, maximum: maximum);
  }

  static int _nonNegative(int value) {
    return value < 0 ? 0 : value;
  }

  static int _bounded(int value, {required int minimum, required int maximum}) {
    if (value < minimum) {
      return minimum;
    }

    if (value > maximum) {
      return maximum;
    }

    return value;
  }
}
