import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class MonitoringSourceModel {
  const MonitoringSourceModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.name,
    required this.sourceType,
    required this.baseUrl,
    required this.accessMethod,
    required this.healthStatus,
    required this.termsReviewStatus,
    required this.status,
    required this.priority,
    required this.scanFrequency,
    required this.createdAt,
    required this.createdBy,
    this.notes,
    this.lastCheckedAt,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String name;
  final MonitoringSourceType sourceType;
  final String baseUrl;
  final MonitoringAccessMethod accessMethod;
  final MonitoringSourceHealthStatus healthStatus;
  final MonitoringTermsReviewStatus termsReviewStatus;
  final MonitoringRecordStatus status;
  final MonitoringPriority priority;
  final MonitoringScanFrequency scanFrequency;
  final String? notes;
  final DateTime? lastCheckedAt;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory MonitoringSourceModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Monitoring source document has no data: ${document.id}',
      );
    }

    return MonitoringSourceModel.fromMap(id: document.id, data: data);
  }

  factory MonitoringSourceModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Monitoring source createdAt is missing: $id');
    }

    return MonitoringSourceModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      name: _requiredString(data['name']),
      sourceType: MonitoringSourceTypeX.fromValue(
        data['sourceType']?.toString(),
      ),
      baseUrl: _requiredString(data['baseUrl']),
      accessMethod: MonitoringAccessMethodX.fromValue(
        data['accessMethod']?.toString(),
      ),
      healthStatus: MonitoringSourceHealthStatusX.fromValue(
        data['healthStatus']?.toString(),
      ),
      termsReviewStatus: MonitoringTermsReviewStatusX.fromValue(
        data['termsReviewStatus']?.toString(),
      ),
      status: MonitoringRecordStatusX.fromValue(data['status']?.toString()),
      priority: MonitoringPriorityX.fromValue(data['priority']?.toString()),
      scanFrequency: MonitoringScanFrequencyX.fromValue(
        data['scanFrequency']?.toString(),
      ),
      notes: _nullableString(data['notes']),
      lastCheckedAt: MonitoringModelUtils.dateTimeFromValue(
        data['lastCheckedAt'],
      ),
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
      'name': name.trim(),
      'sourceType': sourceType.value,
      'baseUrl': _normalizeUrl(baseUrl),
      'accessMethod': accessMethod.value,
      'healthStatus': healthStatus.value,
      'termsReviewStatus': termsReviewStatus.value,
      'status': status.value,
      'priority': priority.value,
      'scanFrequency': scanFrequency.value,
      'notes': _cleanNullable(notes),
      'lastCheckedAt': lastCheckedAt == null
          ? null
          : Timestamp.fromDate(lastCheckedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'name': name.trim(),
      'sourceType': sourceType.value,
      'baseUrl': _normalizeUrl(baseUrl),
      'accessMethod': accessMethod.value,
      'healthStatus': healthStatus.value,
      'termsReviewStatus': termsReviewStatus.value,
      'status': status.value,
      'priority': priority.value,
      'scanFrequency': scanFrequency.value,
      'notes': _cleanNullable(notes),
      'lastCheckedAt': lastCheckedAt == null
          ? null
          : Timestamp.fromDate(lastCheckedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  MonitoringSourceModel copyWith({
    String? id,
    String? tenantId,
    String? brandId,
    String? name,
    MonitoringSourceType? sourceType,
    String? baseUrl,
    MonitoringAccessMethod? accessMethod,
    MonitoringSourceHealthStatus? healthStatus,
    MonitoringTermsReviewStatus? termsReviewStatus,
    MonitoringRecordStatus? status,
    MonitoringPriority? priority,
    MonitoringScanFrequency? scanFrequency,
    String? notes,
    DateTime? lastCheckedAt,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return MonitoringSourceModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      brandId: brandId ?? this.brandId,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      baseUrl: baseUrl ?? this.baseUrl,
      accessMethod: accessMethod ?? this.accessMethod,
      healthStatus: healthStatus ?? this.healthStatus,
      termsReviewStatus: termsReviewStatus ?? this.termsReviewStatus,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      scanFrequency: scanFrequency ?? this.scanFrequency,
      notes: notes ?? this.notes,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
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

  static String _normalizeUrl(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';

    final uri = Uri.tryParse(withScheme);

    if (uri == null) {
      return trimmed;
    }

    final normalizedUri = uri.replace(path: uri.path == '/' ? '' : uri.path);

    return normalizedUri.hasFragment
        ? normalizedUri.removeFragment().toString()
        : normalizedUri.toString();
  }
}
