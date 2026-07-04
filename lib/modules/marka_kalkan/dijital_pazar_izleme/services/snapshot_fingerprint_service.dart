import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../constants/monitoring_enums.dart';
import '../models/page_snapshot_model.dart';

abstract final class SnapshotFingerprintService {
  static PageSnapshotModel prepare(PageSnapshotModel source) {
    final normalizedTitle = _normalizeText(source.title);
    final normalizedDescription = _normalizeText(source.description);

    final normalizedImages =
        source.imageUrls
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    final normalizedMediaAssetIds =
        source.mediaAssetIds
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    final normalizedContacts = <String, int>{
      'phoneCount': _nonNegative(source.contactSummary['phoneCount']),
      'emailCount': _nonNegative(source.contactSummary['emailCount']),
      'addressCount': _nonNegative(source.contactSummary['addressCount']),
    };

    final textHash = _sha256(normalizedDescription);
    final imageSetHash = _sha256(jsonEncode(normalizedImages));

    final canonicalContent = <String, dynamic>{
      'pageStatus': source.pageStatus.value,
      'title': normalizedTitle,
      'description': normalizedDescription,
      'price': source.price,
      'currency': source.currency?.trim().toUpperCase(),
      'stockStatus': source.stockStatus?.value,
      'sellerName': _normalizeText(source.sellerName),
      'storeName': _normalizeText(source.storeName),
      'imageUrls': normalizedImages,
      'mediaAssetIds': normalizedMediaAssetIds,
      'contactSummary': normalizedContacts,
    };

    return PageSnapshotModel(
      id: source.id,
      tenantId: source.tenantId.trim(),
      brandId: source.brandId.trim(),
      sourceId: source.sourceId.trim(),
      pageId: source.pageId.trim(),
      crawlRunId: source.crawlRunId.trim(),
      previousSnapshotId: source.previousSnapshotId,
      versionNumber: source.versionNumber,
      capturedAt: source.capturedAt,
      pageStatus: source.pageStatus,
      title: _cleanNullable(source.title),
      description: _cleanNullable(source.description),
      price: source.price,
      currency: _cleanNullable(source.currency)?.toUpperCase(),
      stockStatus: source.stockStatus,
      sellerName: _cleanNullable(source.sellerName),
      storeName: _cleanNullable(source.storeName),
      imageUrls: List<String>.unmodifiable(normalizedImages),
      mediaAssetIds: List<String>.unmodifiable(normalizedMediaAssetIds),
      contactSummary: Map<String, int>.unmodifiable(normalizedContacts),
      textHash: textHash,
      contentHash: _sha256(jsonEncode(canonicalContent)),
      imageSetHash: imageSetHash,
      htmlArchivePath: _cleanNullable(source.htmlArchivePath),
      screenshotAssetId: _cleanNullable(source.screenshotAssetId),
      parserVersion: source.parserVersion.trim(),
      createdAt: source.createdAt,
    );
  }

  static String deterministicSnapshotId({
    required String tenantId,
    required String pageId,
    required String crawlRunId,
  }) {
    final seed = [tenantId.trim(), pageId.trim(), crawlRunId.trim()].join('|');

    return 'snap_${_sha256(seed)}';
  }

  static String deterministicEventId({
    required String tenantId,
    required String pageId,
    required String currentSnapshotId,
    required String eventType,
  }) {
    final seed = [
      tenantId.trim(),
      pageId.trim(),
      currentSnapshotId.trim(),
      eventType.trim(),
    ].join('|');

    return 'evt_${_sha256(seed)}';
  }

  static String _sha256(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  static String _normalizeText(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  static int _nonNegative(int? value) {
    final safeValue = value ?? 0;
    return safeValue < 0 ? 0 : safeValue;
  }
}
