import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class CrawlRunModel {
  const CrawlRunModel({
    required this.id,
    required this.tenantId,
    required this.jobId,
    required this.sourceId,
    required this.targetId,
    required this.startedAt,
    required this.runStatus,
    required this.itemsFound,
    required this.snapshotsCreated,
    required this.eventsCreated,
    required this.signalsCreated,
    required this.collectorVersion,
    required this.createdAt,
    this.completedAt,
    this.httpStatus,
    this.errorCode,
    this.errorMessage,
  });

  final String id;
  final String tenantId;
  final String jobId;
  final String sourceId;
  final String targetId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final MonitoringCrawlRunStatus runStatus;
  final int? httpStatus;
  final int itemsFound;
  final int snapshotsCreated;
  final int eventsCreated;
  final int signalsCreated;
  final String? errorCode;
  final String? errorMessage;
  final String collectorVersion;
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
    final startedAt = MonitoringModelUtils.dateTimeFromValue(data['startedAt']);
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (startedAt == null || createdAt == null) {
      throw StateError('Crawl run timestamps are incomplete: $id');
    }

    return CrawlRunModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      jobId: _requiredString(data['jobId']),
      sourceId: _requiredString(data['sourceId']),
      targetId: _requiredString(data['targetId']),
      startedAt: startedAt,
      completedAt: MonitoringModelUtils.dateTimeFromValue(data['completedAt']),
      runStatus: MonitoringCrawlRunStatusX.fromValue(
        data['runStatus']?.toString(),
      ),
      httpStatus: _nullableInt(data['httpStatus']),
      itemsFound: _intFromValue(data['itemsFound']),
      snapshotsCreated: _intFromValue(data['snapshotsCreated']),
      eventsCreated: _intFromValue(data['eventsCreated']),
      signalsCreated: _intFromValue(data['signalsCreated']),
      errorCode: _nullableString(data['errorCode']),
      errorMessage: _nullableString(data['errorMessage']),
      collectorVersion: _requiredString(data['collectorVersion']),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'jobId': jobId,
      'sourceId': sourceId,
      'targetId': targetId,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'runStatus': runStatus.value,
      'httpStatus': httpStatus,
      'itemsFound': itemsFound,
      'snapshotsCreated': snapshotsCreated,
      'eventsCreated': eventsCreated,
      'signalsCreated': signalsCreated,
      'errorCode': _cleanNullable(errorCode),
      'errorMessage': _cleanNullable(errorMessage),
      'collectorVersion': collectorVersion.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'runStatus': runStatus.value,
      'httpStatus': httpStatus,
      'itemsFound': itemsFound,
      'snapshotsCreated': snapshotsCreated,
      'eventsCreated': eventsCreated,
      'signalsCreated': signalsCreated,
      'errorCode': _cleanNullable(errorCode),
      'errorMessage': _cleanNullable(errorMessage),
      'collectorVersion': collectorVersion.trim(),
    };
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
    if (completedAt == null) {
      return null;
    }

    return completedAt!.difference(startedAt);
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

  static int? _nullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}
