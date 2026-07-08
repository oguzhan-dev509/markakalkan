import 'package:cloud_functions/cloud_functions.dart';

import '../models/counterfeit_twin_model.dart';

class CounterfeitTwinCommandService {
  CounterfeitTwinCommandService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<String> create(CounterfeitTwinModel record) async {
    final callable = _functions.httpsCallable('createCounterfeitTwinRecord');
    final response = await callable.call<Map<String, dynamic>>(
      _payload(record, includeRecordId: false),
    );

    final recordId = response.data['recordId'];

    if (recordId is! String || recordId.trim().isEmpty) {
      throw StateError(
        'Sahte ikiz kaydı oluşturuldu ancak sunucu kayıt kimliği döndürmedi.',
      );
    }

    return recordId.trim();
  }

  Future<void> update(CounterfeitTwinModel record) async {
    final recordId = record.id.trim();

    if (recordId.isEmpty) {
      throw ArgumentError.value(record.id, 'record.id', 'recordId boş olamaz.');
    }

    final callable = _functions.httpsCallable('updateCounterfeitTwinRecord');
    await callable.call<void>(_payload(record, includeRecordId: true));
  }

  static Map<String, dynamic> _payload(
    CounterfeitTwinModel record, {
    required bool includeRecordId,
  }) {
    return <String, dynamic>{
      if (includeRecordId) 'recordId': record.id.trim(),
      if (!includeRecordId) 'recordCode': record.recordCode.trim(),
      'title': record.title.trim(),
      'status': record.status.value,
      'confidenceLevel': record.confidenceLevel.value,
      'riskLevel': record.riskLevel.value,
      'reviewStatus': record.reviewStatus.value,
      'primaryCloneMethod': record.primaryCloneMethod.value,
      'originalProductId': _cleanNullable(record.originalProductId),
      'originalIpAssetId': _cleanNullable(record.originalIpAssetId),
      'originalBrandName': _cleanNullable(record.originalBrandName),
      'originalProductName': _cleanNullable(record.originalProductName),
      'originalVariantName': _cleanNullable(record.originalVariantName),
      'suspectedBrandName': _cleanNullable(record.suspectedBrandName),
      'suspectedProductName': _cleanNullable(record.suspectedProductName),
      'suspectedVariantName': _cleanNullable(record.suspectedVariantName),
      'claimedManufacturer': _cleanNullable(record.claimedManufacturer),
      'countryCode': _cleanNullable(record.countryCode),
      'region': _cleanNullable(record.region),
      'cloneMethods': record.cloneMethods.map((item) => item.value).toList(),
      'visualSimilarityScore': record.visualSimilarityScore,
      'packagingSimilarityScore': record.packagingSimilarityScore,
      'logoSimilarityScore': record.logoSimilarityScore,
      'nameSimilarityScore': record.nameSimilarityScore,
      'textSimilarityScore': record.textSimilarityScore,
      'priceAnomalyScore': record.priceAnomalyScore,
      'overallSimilarityScore': record.overallSimilarityScore,
      'sourceIds': List<String>.from(record.sourceIds),
      'listingIds': List<String>.from(record.listingIds),
      'sellerIds': List<String>.from(record.sellerIds),
      'storeIds': List<String>.from(record.storeIds),
      'monitoredPageIds': List<String>.from(record.monitoredPageIds),
      'mediaAssetIds': List<String>.from(record.mediaAssetIds),
      'evidencePackageIds': List<String>.from(record.evidencePackageIds),
      'monitoringEventIds': List<String>.from(record.monitoringEventIds),
      'monitoringSignalIds': List<String>.from(record.monitoringSignalIds),
      'cloneFamilyId': _cleanNullable(record.cloneFamilyId),
      'waveId': _cleanNullable(record.waveId),
      'relatedTwinRecordIds': List<String>.from(record.relatedTwinRecordIds),
      'recurrenceCount': record.recurrenceCount,
      'firstSeenAt': _dateToIso(record.firstSeenAt),
      'lastSeenAt': _dateToIso(record.lastSeenAt),
      'dismissReason': _cleanNullable(record.dismissReason),
      'archiveReason': _cleanNullable(record.archiveReason),
      'notes': _cleanNullable(record.notes),
      'metadata': Map<String, dynamic>.from(record.metadata),
    };
  }

  static String? _dateToIso(DateTime? value) {
    return value?.toUtc().toIso8601String();
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
