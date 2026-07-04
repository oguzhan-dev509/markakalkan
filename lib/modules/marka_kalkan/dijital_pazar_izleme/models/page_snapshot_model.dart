import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monitoring_enums.dart';
import '../utils/monitoring_model_utils.dart';

class PageSnapshotModel {
  const PageSnapshotModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.sourceId,
    required this.pageId,
    required this.crawlRunId,
    required this.capturedAt,
    required this.pageStatus,
    required this.imageUrls,
    required this.mediaAssetIds,
    required this.contactSummary,
    required this.parserVersion,
    required this.createdAt,
    this.versionNumber = 1,
    this.previousSnapshotId,
    this.title,
    this.description,
    this.price,
    this.currency,
    this.stockStatus,
    this.sellerName,
    this.storeName,
    this.textHash,
    this.contentHash,
    this.imageSetHash,
    this.htmlArchivePath,
    this.screenshotAssetId,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String sourceId;
  final String pageId;
  final String crawlRunId;
  final String? previousSnapshotId;
  final int versionNumber;
  final DateTime capturedAt;
  final MonitoringPageStatus pageStatus;
  final String? title;
  final String? description;
  final double? price;
  final String? currency;
  final MonitoringStockStatus? stockStatus;
  final String? sellerName;
  final String? storeName;
  final List<String> imageUrls;
  final List<String> mediaAssetIds;
  final Map<String, int> contactSummary;
  final String? textHash;
  final String? contentHash;
  final String? imageSetHash;
  final String? htmlArchivePath;
  final String? screenshotAssetId;
  final String parserVersion;
  final DateTime createdAt;

  factory PageSnapshotModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Page snapshot document has no data: ${document.id}');
    }

    return PageSnapshotModel.fromMap(id: document.id, data: data);
  }

  factory PageSnapshotModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final capturedAt = MonitoringModelUtils.dateTimeFromValue(
      data['capturedAt'],
    );
    final createdAt = MonitoringModelUtils.dateTimeFromValue(data['createdAt']);

    if (capturedAt == null || createdAt == null) {
      throw StateError('Page snapshot timestamps are incomplete: $id');
    }

    final stockStatusValue = data['stockStatus']?.toString();

    return PageSnapshotModel(
      id: id,
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      sourceId: _requiredString(data['sourceId']),
      pageId: _requiredString(data['pageId']),
      crawlRunId: _requiredString(data['crawlRunId']),
      previousSnapshotId: _nullableString(data['previousSnapshotId']),
      versionNumber: _positiveInt(data['versionNumber']),
      capturedAt: capturedAt,
      pageStatus: MonitoringPageStatusX.fromValue(
        data['pageStatus']?.toString(),
      ),
      title: _nullableString(data['title']),
      description: _nullableString(data['description']),
      price: _nullableDouble(data['price']),
      currency: _nullableString(data['currency'])?.toUpperCase(),
      stockStatus: stockStatusValue == null
          ? null
          : MonitoringStockStatusX.fromValue(stockStatusValue),
      sellerName: _nullableString(data['sellerName']),
      storeName: _nullableString(data['storeName']),
      imageUrls: MonitoringModelUtils.stringListFromValue(data['imageUrls']),
      mediaAssetIds: MonitoringModelUtils.stringListFromValue(
        data['mediaAssetIds'],
      ),
      contactSummary: _contactSummaryFromValue(data['contactSummary']),
      textHash: _nullableString(data['textHash']),
      contentHash: _nullableString(data['contentHash']),
      imageSetHash: _nullableString(data['imageSetHash']),
      htmlArchivePath: _nullableString(data['htmlArchivePath']),
      screenshotAssetId: _nullableString(data['screenshotAssetId']),
      parserVersion: _requiredString(data['parserVersion']),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'brandId': brandId,
      'sourceId': sourceId,
      'pageId': pageId,
      'crawlRunId': crawlRunId,
      'previousSnapshotId': _cleanNullable(previousSnapshotId),
      'versionNumber': versionNumber < 1 ? 1 : versionNumber,
      'capturedAt': Timestamp.fromDate(capturedAt),
      'pageStatus': pageStatus.value,
      'title': _cleanNullable(title),
      'description': _cleanNullable(description),
      'price': price,
      'currency': _cleanNullable(currency)?.toUpperCase(),
      'stockStatus': stockStatus?.value,
      'sellerName': _cleanNullable(sellerName),
      'storeName': _cleanNullable(storeName),
      'imageUrls': imageUrls,
      'mediaAssetIds': mediaAssetIds,
      'contactSummary': contactSummary,
      'textHash': _cleanNullable(textHash),
      'contentHash': _cleanNullable(contentHash),
      'imageSetHash': _cleanNullable(imageSetHash),
      'htmlArchivePath': _cleanNullable(htmlArchivePath),
      'screenshotAssetId': _cleanNullable(screenshotAssetId),
      'parserVersion': parserVersion.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get hasPreviousSnapshot {
    return previousSnapshotId != null && previousSnapshotId!.trim().isNotEmpty;
  }

  bool get hasPrice {
    return price != null;
  }

  bool get hasScreenshot {
    return screenshotAssetId != null && screenshotAssetId!.trim().isNotEmpty;
  }

  bool get hasArchivedHtml {
    return htmlArchivePath != null && htmlArchivePath!.trim().isNotEmpty;
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

  static Map<String, int> _contactSummaryFromValue(dynamic value) {
    if (value is! Map) {
      return const <String, int>{
        'phoneCount': 0,
        'emailCount': 0,
        'addressCount': 0,
      };
    }

    return <String, int>{
      'phoneCount': _intFromValue(value['phoneCount']),
      'emailCount': _intFromValue(value['emailCount']),
      'addressCount': _intFromValue(value['addressCount']),
    };
  }

  static int _positiveInt(dynamic value) {
    final parsed = _intFromValue(value);
    return parsed < 1 ? 1 : parsed;
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

class PageSnapshotCreateResult {
  const PageSnapshotCreateResult({
    required this.snapshot,
    required this.previousSnapshot,
    required this.wasCreated,
  });

  final PageSnapshotModel snapshot;
  final PageSnapshotModel? previousSnapshot;
  final bool wasCreated;

  String get snapshotId => snapshot.id;

  String? get previousSnapshotId => previousSnapshot?.id;

  bool get isFirstSnapshot => previousSnapshot == null;
}
