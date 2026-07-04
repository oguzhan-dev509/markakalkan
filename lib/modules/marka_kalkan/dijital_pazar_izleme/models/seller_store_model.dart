import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class SellerStoreModel {
  const SellerStoreModel({
    required this.id,
    required this.tenantId,
    required this.sellerId,
    required this.sourceId,
    required this.storeName,
    required this.normalizedStoreName,
    required this.storeUrl,
    required this.reviewCount,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.storeStatus,
    required this.createdAt,
    this.platformStoreId,
    this.logoAssetId,
    this.rating,
    this.openedAt,
    this.closedAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String sellerId;
  final String sourceId;
  final String? platformStoreId;
  final String storeName;
  final String normalizedStoreName;
  final String storeUrl;
  final String? logoAssetId;
  final double? rating;
  final int reviewCount;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final MonitoringStoreStatus storeStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory SellerStoreModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Seller store document has no data: ${document.id}');
    }

    return SellerStoreModel.fromMap(id: document.id, data: data);
  }

  factory SellerStoreModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final firstSeenAt = MonitoringModelUtils.dateTimeFromValue(
      data['firstSeenAt'],
    );
    final lastSeenAt = MonitoringModelUtils.dateTimeFromValue(
      data['lastSeenAt'],
    );
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (firstSeenAt == null || lastSeenAt == null || createdAt == null) {
      throw StateError('Seller store timestamps are incomplete: $id');
    }

    return SellerStoreModel(
      id: id,
      tenantId: (data['tenantId'] ?? '').toString().trim(),
      sellerId: (data['sellerId'] ?? '').toString().trim(),
      sourceId: (data['sourceId'] ?? '').toString().trim(),
      platformStoreId: _nullableString(data['platformStoreId']),
      storeName: (data['storeName'] ?? '').toString().trim(),
      normalizedStoreName: (data['normalizedStoreName'] ?? '')
          .toString()
          .trim(),
      storeUrl: (data['storeUrl'] ?? '').toString().trim(),
      logoAssetId: _nullableString(data['logoAssetId']),
      rating: _nullableDouble(data['rating']),
      reviewCount: _intFromValue(data['reviewCount']),
      firstSeenAt: firstSeenAt,
      lastSeenAt: lastSeenAt,
      openedAt: MonitoringModelUtils.dateTimeFromValue(data['openedAt']),
      closedAt: MonitoringModelUtils.dateTimeFromValue(data['closedAt']),
      storeStatus: MonitoringStoreStatusX.fromValue(
        data['storeStatus']?.toString(),
      ),
      createdAt: createdAt,
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'sellerId': sellerId,
      'sourceId': sourceId,
      'platformStoreId': _cleanNullable(platformStoreId),
      'storeName': storeName.trim(),
      'normalizedStoreName': normalizedStoreName.trim().isEmpty
          ? MonitoringModelUtils.normalizedText(storeName)
          : normalizedStoreName.trim(),
      'storeUrl': storeUrl.trim(),
      'logoAssetId': _cleanNullable(logoAssetId),
      'rating': rating,
      'reviewCount': reviewCount,
      'firstSeenAt': Timestamp.fromDate(firstSeenAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'openedAt': openedAt == null ? null : Timestamp.fromDate(openedAt!),
      'closedAt': closedAt == null ? null : Timestamp.fromDate(closedAt!),
      'storeStatus': storeStatus.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'platformStoreId': _cleanNullable(platformStoreId),
      'storeName': storeName.trim(),
      'normalizedStoreName': normalizedStoreName.trim().isEmpty
          ? MonitoringModelUtils.normalizedText(storeName)
          : normalizedStoreName.trim(),
      'storeUrl': storeUrl.trim(),
      'logoAssetId': _cleanNullable(logoAssetId),
      'rating': rating,
      'reviewCount': reviewCount,
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'openedAt': openedAt == null ? null : Timestamp.fromDate(openedAt!),
      'closedAt': closedAt == null ? null : Timestamp.fromDate(closedAt!),
      'storeStatus': storeStatus.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
