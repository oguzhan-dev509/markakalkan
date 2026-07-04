import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class ProductModel {
  const ProductModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.name,
    required this.normalizedName,
    required this.category,
    required this.currency,
    required this.referenceImageIds,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.sku,
    this.barcode,
    this.modelNumber,
    this.referencePrice,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String name;
  final String normalizedName;
  final String category;
  final String? sku;
  final String? barcode;
  final String? modelNumber;
  final double? referencePrice;
  final String currency;
  final List<String> referenceImageIds;
  final MonitoringProductStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory ProductModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Product document has no data: ${document.id}');
    }

    return ProductModel.fromMap(id: document.id, data: data);
  }

  factory ProductModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Product createdAt is missing: $id');
    }

    final referencePriceValue = data['referencePrice'];

    return ProductModel(
      id: id,
      tenantId: (data['tenantId'] ?? '').toString().trim(),
      brandId: (data['brandId'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
      normalizedName: (data['normalizedName'] ?? '').toString().trim(),
      category: (data['category'] ?? '').toString().trim(),
      sku: _nullableString(data['sku']),
      barcode: _nullableString(data['barcode']),
      modelNumber: _nullableString(data['modelNumber']),
      referencePrice: referencePriceValue == null
          ? null
          : MonitoringModelUtils.doubleFromValue(referencePriceValue),
      currency: (data['currency'] ?? 'TRY').toString().trim().toUpperCase(),
      referenceImageIds: MonitoringModelUtils.stringListFromValue(
        data['referenceImageIds'],
      ),
      status: MonitoringProductStatusX.fromValue(data['status']?.toString()),
      createdAt: createdAt,
      createdBy: (data['createdBy'] ?? '').toString().trim(),
      updatedAt: MonitoringModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'brandId': brandId,
      'name': name.trim(),
      'normalizedName': normalizedName.trim().isEmpty
          ? MonitoringModelUtils.normalizedText(name)
          : normalizedName.trim(),
      'category': category.trim(),
      'sku': _cleanNullable(sku),
      'barcode': _cleanNullable(barcode),
      'modelNumber': _cleanNullable(modelNumber),
      'referencePrice': referencePrice,
      'currency': currency.trim().toUpperCase(),
      'referenceImageIds': referenceImageIds,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'updatedBy': updatedBy,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'name': name.trim(),
      'normalizedName': normalizedName.trim().isEmpty
          ? MonitoringModelUtils.normalizedText(name)
          : normalizedName.trim(),
      'category': category.trim(),
      'sku': _cleanNullable(sku),
      'barcode': _cleanNullable(barcode),
      'modelNumber': _cleanNullable(modelNumber),
      'referencePrice': referencePrice,
      'currency': currency.trim().toUpperCase(),
      'referenceImageIds': referenceImageIds,
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}
