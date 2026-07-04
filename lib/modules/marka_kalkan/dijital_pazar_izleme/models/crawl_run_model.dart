import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class CrawlRunModel {
  const CrawlRunModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.profileId,
    required this.jobId,
    required this.sourceId,
    required this.targetId,
    required this.triggerType,
    required this.triggeredBy,
    required this.requestKey,
    required this.queuedAt,
    required this.runStatus,
    required this.itemsFound,
    required this.snapshotsCreated,
    required this.eventsCreated,
    required this.signalsCreated,
    required this.executionAttempt,
    required this.collectorVersion,
    required this.createdAt,
    this.pageId,
    this.startedAt,
    this.completedAt,
    this.workerId,
    this.httpStatus,
    this.bytesDownloaded,
    this.durationMs,
    this.errorCode,
    this.errorMessage,
    this.parserVersion,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String profileId;

  final String jobId;
  final String sourceId;
  final String targetId;
  final String? pageId;

  final MonitoringCrawlTriggerType triggerType;
  final String triggeredBy;
  final String requestKey;

  final DateTime queuedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  final MonitoringCrawlRunStatus runStatus;

  final String? workerId;
  final int executionAttempt;

  final int? httpStatus;
  final int itemsFound;
  final int snapshotsCreated;
  final int eventsCreated;
  final int signalsCreated;

  final int? bytesDownloaded;
  final int? durationMs;

  final String? errorCode;
  final String? errorMessage;

  final String collectorVersion;
  final String? parserVersion;

  final DateTime createdAt;

  factory CrawlRunModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Crawl run document has no data: ${document.id}');
    }

    return CrawlRunModel.fromMap(id: document.id, data: data);
  }

  factory CrawlRunModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);
    final queuedAt =
        MonitoringModelUtils.dateTimeFromValue(data['queuedAt']) ??
        MonitoringModelUtils.dateTimeFromValue(data['startedAt']) ??
        createdAt;

    if (createdAt == null || queuedAt == null) {
      throw StateError('Crawl run timestamps are incomplete: $id');
    }

    return CrawlRunModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      profileId: _requiredString(data['profileId']),
      jobId: _requiredString(data['jobId']),
      sourceId: _requiredString(data['sourceId']),
      targetId: _requiredString(data['targetId']),
      pageId: _nullableString(data['pageId']),
      triggerType: MonitoringCrawlTriggerTypeX.fromValue(
        data['triggerType']?.toString(),
      ),
      triggeredBy: _requiredString(data['triggeredBy']).isEmpty
          ? 'system'
          : _requiredString(data['triggeredBy']),
      requestKey: _requiredString(data['requestKey']).isEmpty
          ? id
          : _requiredString(data['requestKey']),
      queuedAt: queuedAt,
      startedAt: MonitoringModelUtils.dateTimeFromValue(data['startedAt']),
      completedAt: MonitoringModelUtils.dateTimeFromValue(data['completedAt']),
      runStatus: MonitoringCrawlRunStatusX.fromValue(
        data['runStatus']?.toString(),
      ),
      workerId: _nullableString(data['workerId']),
      executionAttempt: _positiveInt(data['executionAttempt'], fallback: 1),
      httpStatus: _nullableInt(data['httpStatus']),
      itemsFound: _nonNegativeInt(data['itemsFound']),
      snapshotsCreated: _nonNegativeInt(data['snapshotsCreated']),
      eventsCreated: _nonNegativeInt(data['eventsCreated']),
      signalsCreated: _nonNegativeInt(data['signalsCreated']),
      bytesDownloaded: _nullableNonNegativeInt(data['bytesDownloaded']),
      durationMs: _nullableNonNegativeInt(data['durationMs']),
      errorCode: _nullableString(data['errorCode']),
      errorMessage: _nullableString(data['errorMessage']),
      collectorVersion: _requiredString(data['collectorVersion']).isEmpty
          ? 'unknown'
          : _requiredString(data['collectorVersion']),
      parserVersion: _nullableString(data['parserVersion']),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'profileId': profileId.trim(),
      'jobId': jobId.trim(),
      'sourceId': sourceId.trim(),
      'targetId': targetId.trim(),
      'pageId': _cleanNullable(pageId),
      'triggerType': triggerType.value,
      'triggeredBy': triggeredBy.trim(),
      'requestKey': requestKey.trim(),
      'queuedAt': Timestamp.fromDate(queuedAt),
      'startedAt': _timestampOrNull(startedAt),
      'completedAt': _timestampOrNull(completedAt),
      'runStatus': runStatus.value,
      'workerId': _cleanNullable(workerId),
      'executionAttempt': executionAttempt < 1 ? 1 : executionAttempt,
      'httpStatus': httpStatus,
      'itemsFound': _nonNegative(itemsFound),
      'snapshotsCreated': _nonNegative(snapshotsCreated),
      'eventsCreated': _nonNegative(eventsCreated),
      'signalsCreated': _nonNegative(signalsCreated),
      'bytesDownloaded': bytesDownloaded == null
          ? null
          : _nonNegative(bytesDownloaded!),
      'durationMs': durationMs == null ? null : _nonNegative(durationMs!),
      'errorCode': _cleanNullable(errorCode),
      'errorMessage': _cleanNullable(errorMessage),
      'collectorVersion': collectorVersion.trim(),
      'parserVersion': _cleanNullable(parserVersion),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toCompletionMap() {
    return <String, dynamic>{
      'startedAt': _timestampOrNull(startedAt),
      'completedAt': _timestampOrNull(completedAt),
      'runStatus': runStatus.value,
      'workerId': _cleanNullable(workerId),
      'executionAttempt': executionAttempt < 1 ? 1 : executionAttempt,
      'httpStatus': httpStatus,
      'itemsFound': _nonNegative(itemsFound),
      'snapshotsCreated': _nonNegative(snapshotsCreated),
      'eventsCreated': _nonNegative(eventsCreated),
      'signalsCreated': _nonNegative(signalsCreated),
      'bytesDownloaded': bytesDownloaded == null
          ? null
          : _nonNegative(bytesDownloaded!),
      'durationMs': durationMs == null ? null : _nonNegative(durationMs!),
      'errorCode': _cleanNullable(errorCode),
      'errorMessage': _cleanNullable(errorMessage),
      'collectorVersion': collectorVersion.trim(),
      'parserVersion': _cleanNullable(parserVersion),
    };
  }

  CrawlRunModel copyWith({
    String? id,
    String? tenantId,
    String? brandId,
    String? profileId,
    String? jobId,
    String? sourceId,
    String? targetId,
    String? pageId,
    MonitoringCrawlTriggerType? triggerType,
    String? triggeredBy,
    String? requestKey,
    DateTime? queuedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    MonitoringCrawlRunStatus? runStatus,
    String? workerId,
    int? executionAttempt,
    int? httpStatus,
    int? itemsFound,
    int? snapshotsCreated,
    int? eventsCreated,
    int? signalsCreated,
    int? bytesDownloaded,
    int? durationMs,
    String? errorCode,
    String? errorMessage,
    String? collectorVersion,
    String? parserVersion,
    DateTime? createdAt,
  }) {
    return CrawlRunModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      brandId: brandId ?? this.brandId,
      profileId: profileId ?? this.profileId,
      jobId: jobId ?? this.jobId,
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      pageId: pageId ?? this.pageId,
      triggerType: triggerType ?? this.triggerType,
      triggeredBy: triggeredBy ?? this.triggeredBy,
      requestKey: requestKey ?? this.requestKey,
      queuedAt: queuedAt ?? this.queuedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      runStatus: runStatus ?? this.runStatus,
      workerId: workerId ?? this.workerId,
      executionAttempt: executionAttempt ?? this.executionAttempt,
      httpStatus: httpStatus ?? this.httpStatus,
      itemsFound: itemsFound ?? this.itemsFound,
      snapshotsCreated: snapshotsCreated ?? this.snapshotsCreated,
      eventsCreated: eventsCreated ?? this.eventsCreated,
      signalsCreated: signalsCreated ?? this.signalsCreated,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      durationMs: durationMs ?? this.durationMs,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      collectorVersion: collectorVersion ?? this.collectorVersion,
      parserVersion: parserVersion ?? this.parserVersion,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isQueued {
    return runStatus == MonitoringCrawlRunStatus.queued;
  }

  bool get isRunning {
    return runStatus == MonitoringCrawlRunStatus.running;
  }

  bool get isFinished {
    return runStatus == MonitoringCrawlRunStatus.success ||
        runStatus == MonitoringCrawlRunStatus.partialSuccess ||
        runStatus == MonitoringCrawlRunStatus.failed ||
        runStatus == MonitoringCrawlRunStatus.blocked ||
        runStatus == MonitoringCrawlRunStatus.cancelled;
  }

  bool get hasError {
    return runStatus == MonitoringCrawlRunStatus.failed ||
        runStatus == MonitoringCrawlRunStatus.blocked ||
        errorCode != null ||
        errorMessage != null;
  }

  Duration? get duration {
    if (durationMs != null) {
      return Duration(milliseconds: durationMs!);
    }

    if (startedAt == null || completedAt == null) {
      return null;
    }

    return completedAt!.difference(startedAt!);
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

  static int _positiveInt(dynamic value, {required int fallback}) {
    final parsed = value == null ? fallback : _intFromValue(value);
    return parsed < 1 ? fallback : parsed;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    return _intFromValue(value);
  }

  static int? _nullableNonNegativeInt(dynamic value) {
    if (value == null) {
      return null;
    }

    return _nonNegative(_intFromValue(value));
  }

  static int _nonNegative(int value) {
    return value < 0 ? 0 : value;
  }
}
