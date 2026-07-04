import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class BrandMonitoringProfileModel {
  const BrandMonitoringProfileModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.profileName,
    required this.brandName,
    required this.productIds,
    required this.categories,
    required this.includeKeywords,
    required this.excludeKeywords,
    required this.riskTypes,
    required this.prioritySourceIds,
    required this.targetRegions,
    required this.currency,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.createdBy,
    this.minimumPrice,
    this.maximumPrice,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String profileName;
  final String brandName;
  final List<String> productIds;
  final List<String> categories;
  final List<String> includeKeywords;
  final List<String> excludeKeywords;
  final List<String> riskTypes;
  final List<String> prioritySourceIds;
  final List<String> targetRegions;
  final double? minimumPrice;
  final double? maximumPrice;
  final String currency;
  final MonitoringRecordStatus status;
  final MonitoringPriority priority;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory BrandMonitoringProfileModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Brand monitoring profile document has no data: ${document.id}',
      );
    }

    return BrandMonitoringProfileModel.fromMap(id: document.id, data: data);
  }

  factory BrandMonitoringProfileModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Brand monitoring profile createdAt is missing: $id');
    }

    return BrandMonitoringProfileModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      profileName: _requiredString(data['profileName']),
      brandName: _requiredString(data['brandName']),
      productIds: MonitoringModelUtils.stringListFromValue(data['productIds']),
      categories: MonitoringModelUtils.stringListFromValue(data['categories']),
      includeKeywords: MonitoringModelUtils.stringListFromValue(
        data['includeKeywords'],
      ),
      excludeKeywords: MonitoringModelUtils.stringListFromValue(
        data['excludeKeywords'],
      ),
      riskTypes: MonitoringModelUtils.stringListFromValue(data['riskTypes']),
      prioritySourceIds: MonitoringModelUtils.stringListFromValue(
        data['prioritySourceIds'],
      ),
      targetRegions: MonitoringModelUtils.stringListFromValue(
        data['targetRegions'],
      ),
      minimumPrice: _nullableDouble(data['minimumPrice']),
      maximumPrice: _nullableDouble(data['maximumPrice']),
      currency: _requiredString(data['currency']).isEmpty
          ? 'TRY'
          : _requiredString(data['currency']).toUpperCase(),
      status: MonitoringRecordStatusX.fromValue(data['status']?.toString()),
      priority: MonitoringPriorityX.fromValue(data['priority']?.toString()),
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
      'profileName': profileName.trim(),
      'brandName': brandName.trim(),
      'productIds': _cleanList(productIds),
      'categories': _cleanList(categories),
      'includeKeywords': _cleanList(includeKeywords),
      'excludeKeywords': _cleanList(excludeKeywords),
      'riskTypes': _cleanList(riskTypes),
      'prioritySourceIds': _cleanList(prioritySourceIds),
      'targetRegions': _cleanList(targetRegions),
      'minimumPrice': minimumPrice,
      'maximumPrice': maximumPrice,
      'currency': currency.trim().toUpperCase(),
      'status': status.value,
      'priority': priority.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'profileName': profileName.trim(),
      'brandName': brandName.trim(),
      'productIds': _cleanList(productIds),
      'categories': _cleanList(categories),
      'includeKeywords': _cleanList(includeKeywords),
      'excludeKeywords': _cleanList(excludeKeywords),
      'riskTypes': _cleanList(riskTypes),
      'prioritySourceIds': _cleanList(prioritySourceIds),
      'targetRegions': _cleanList(targetRegions),
      'minimumPrice': minimumPrice,
      'maximumPrice': maximumPrice,
      'currency': currency.trim().toUpperCase(),
      'status': status.value,
      'priority': priority.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  BrandMonitoringProfileModel copyWith({
    String? id,
    String? tenantId,
    String? brandId,
    String? profileName,
    String? brandName,
    List<String>? productIds,
    List<String>? categories,
    List<String>? includeKeywords,
    List<String>? excludeKeywords,
    List<String>? riskTypes,
    List<String>? prioritySourceIds,
    List<String>? targetRegions,
    double? minimumPrice,
    double? maximumPrice,
    String? currency,
    MonitoringRecordStatus? status,
    MonitoringPriority? priority,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return BrandMonitoringProfileModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      brandId: brandId ?? this.brandId,
      profileName: profileName ?? this.profileName,
      brandName: brandName ?? this.brandName,
      productIds: productIds ?? this.productIds,
      categories: categories ?? this.categories,
      includeKeywords: includeKeywords ?? this.includeKeywords,
      excludeKeywords: excludeKeywords ?? this.excludeKeywords,
      riskTypes: riskTypes ?? this.riskTypes,
      prioritySourceIds: prioritySourceIds ?? this.prioritySourceIds,
      targetRegions: targetRegions ?? this.targetRegions,
      minimumPrice: minimumPrice ?? this.minimumPrice,
      maximumPrice: maximumPrice ?? this.maximumPrice,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      priority: priority ?? this.priority,
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

  static double? _nullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim().replaceAll(',', '.'));
  }

  static List<String> _cleanList(List<String> values) {
    final seen = <String>{};
    final cleaned = <String>[];

    for (final value in values) {
      final item = value.trim();

      if (item.isEmpty) {
        continue;
      }

      final normalized = item.toLowerCase();

      if (seen.add(normalized)) {
        cleaned.add(item);
      }
    }

    return cleaned;
  }
}
