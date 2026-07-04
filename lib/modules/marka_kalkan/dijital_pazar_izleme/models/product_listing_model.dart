import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class ProductListingModel {
  const ProductListingModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.sourceId,
    required this.pageId,
    required this.url,
    required this.title,
    required this.normalizedTitle,
    required this.category,
    required this.currency,
    required this.stockStatus,
    required this.mediaAssetIds,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.lastScannedAt,
    required this.listingStatus,
    required this.createdAt,
    this.productId,
    this.sellerId,
    this.storeId,
    this.platformListingId,
    this.claimedBrand,
    this.currentPrice,
    this.previousPrice,
    this.discountRate,
    this.rating,
    this.reviewCount = 0,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String? productId;
  final String sourceId;
  final String? sellerId;
  final String? storeId;
  final String pageId;
  final String? platformListingId;
  final String url;
  final String title;
  final String normalizedTitle;
  final String category;
  final String? claimedBrand;
  final double? currentPrice;
  final double? previousPrice;
  final String currency;
  final double? discountRate;
  final MonitoringStockStatus stockStatus;
  final double? rating;
  final int reviewCount;
  final List<String> mediaAssetIds;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final DateTime lastScannedAt;
  final MonitoringListingStatus listingStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory ProductListingModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Product listing document has no data: ${document.id}');
    }

    return ProductListingModel.fromMap(id: document.id, data: data);
  }

  factory ProductListingModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final firstSeenAt = MonitoringModelUtils.dateTimeFromValue(
      data['firstSeenAt'],
    );
    final lastSeenAt = MonitoringModelUtils.dateTimeFromValue(
      data['lastSeenAt'],
    );
    final lastScannedAt = MonitoringModelUtils.dateTimeFromValue(
      data['lastScannedAt'],
    );
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (firstSeenAt == null ||
        lastSeenAt == null ||
        lastScannedAt == null ||
        createdAt == null) {
      throw StateError('Product listing timestamps are incomplete: $id');
    }

    return ProductListingModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      productId: _nullableString(data['productId']),
      sourceId: _requiredString(data['sourceId']),
      sellerId: _nullableString(data['sellerId']),
      storeId: _nullableString(data['storeId']),
      pageId: _requiredString(data['pageId']),
      platformListingId: _nullableString(data['platformListingId']),
      url: _requiredString(data['url']),
      title: _requiredString(data['title']),
      normalizedTitle: _requiredString(data['normalizedTitle']),
      category: _requiredString(data['category']),
      claimedBrand: _nullableString(data['claimedBrand']),
      currentPrice: _nullableDouble(data['currentPrice']),
      previousPrice: _nullableDouble(data['previousPrice']),
      currency: (data['currency'] ?? 'TRY').toString().trim().toUpperCase(),
      discountRate: _nullableDouble(data['discountRate']),
      stockStatus: MonitoringStockStatusX.fromValue(
        data['stockStatus']?.toString(),
      ),
      rating: _nullableDouble(data['rating']),
      reviewCount: _intFromValue(data['reviewCount']),
      mediaAssetIds: MonitoringModelUtils.stringListFromValue(
        data['mediaAssetIds'],
      ),
      firstSeenAt: firstSeenAt,
      lastSeenAt: lastSeenAt,
      lastScannedAt: lastScannedAt,
      listingStatus: MonitoringListingStatusX.fromValue(
        data['listingStatus']?.toString(),
      ),
      createdAt: createdAt,
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'brandId': brandId,
      'productId': _cleanNullable(productId),
      'sourceId': sourceId,
      'sellerId': _cleanNullable(sellerId),
      'storeId': _cleanNullable(storeId),
      'pageId': pageId,
      'platformListingId': _cleanNullable(platformListingId),
      'url': url.trim(),
      'title': title.trim(),
      'normalizedTitle': normalizedTitle.trim().isEmpty
          ? MonitoringModelUtils.normalizedText(title)
          : normalizedTitle.trim(),
      'category': category.trim(),
      'claimedBrand': _cleanNullable(claimedBrand),
      'currentPrice': currentPrice,
      'previousPrice': previousPrice,
      'currency': currency.trim().toUpperCase(),
      'discountRate': discountRate,
      'stockStatus': stockStatus.value,
      'rating': rating,
      'reviewCount': reviewCount,
      'mediaAssetIds': mediaAssetIds,
      'firstSeenAt': Timestamp.fromDate(firstSeenAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'lastScannedAt': Timestamp.fromDate(lastScannedAt),
      'listingStatus': listingStatus.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'productId': _cleanNullable(productId),
      'sellerId': _cleanNullable(sellerId),
      'storeId': _cleanNullable(storeId),
      'platformListingId': _cleanNullable(platformListingId),
      'url': url.trim(),
      'title': title.trim(),
      'normalizedTitle': normalizedTitle.trim().isEmpty
          ? MonitoringModelUtils.normalizedText(title)
          : normalizedTitle.trim(),
      'category': category.trim(),
      'claimedBrand': _cleanNullable(claimedBrand),
      'currentPrice': currentPrice,
      'previousPrice': previousPrice,
      'currency': currency.trim().toUpperCase(),
      'discountRate': discountRate,
      'stockStatus': stockStatus.value,
      'rating': rating,
      'reviewCount': reviewCount,
      'mediaAssetIds': mediaAssetIds,
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'lastScannedAt': Timestamp.fromDate(lastScannedAt),
      'listingStatus': listingStatus.value,
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
