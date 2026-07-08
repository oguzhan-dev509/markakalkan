import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/counterfeit_twin_enums.dart';

class CounterfeitTwinModel {
  const CounterfeitTwinModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.recordCode,
    required this.title,
    required this.status,
    required this.confidenceLevel,
    required this.riskLevel,
    required this.reviewStatus,
    required this.primaryCloneMethod,
    required this.createdAt,
    required this.createdBy,
    this.originalProductId,
    this.originalIpAssetId,
    this.originalBrandName,
    this.originalProductName,
    this.originalVariantName,
    this.suspectedBrandName,
    this.suspectedProductName,
    this.suspectedVariantName,
    this.claimedManufacturer,
    this.countryCode,
    this.region,
    this.cloneMethods = const <CounterfeitTwinCloneMethod>[],
    this.visualSimilarityScore = 0,
    this.packagingSimilarityScore = 0,
    this.logoSimilarityScore = 0,
    this.nameSimilarityScore = 0,
    this.textSimilarityScore = 0,
    this.priceAnomalyScore = 0,
    this.overallSimilarityScore = 0,
    this.sourceIds = const <String>[],
    this.listingIds = const <String>[],
    this.sellerIds = const <String>[],
    this.storeIds = const <String>[],
    this.monitoredPageIds = const <String>[],
    this.mediaAssetIds = const <String>[],
    this.evidencePackageIds = const <String>[],
    this.monitoringEventIds = const <String>[],
    this.monitoringSignalIds = const <String>[],
    this.cloneFamilyId,
    this.waveId,
    this.relatedTwinRecordIds = const <String>[],
    this.recurrenceCount = 0,
    this.firstSeenAt,
    this.lastSeenAt,
    this.confirmedAt,
    this.dismissedAt,
    this.dismissReason,
    this.archivedAt,
    this.archiveReason,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String recordCode;
  final String title;

  final CounterfeitTwinStatus status;
  final CounterfeitTwinConfidenceLevel confidenceLevel;
  final CounterfeitTwinRiskLevel riskLevel;
  final CounterfeitTwinReviewStatus reviewStatus;
  final CounterfeitTwinCloneMethod primaryCloneMethod;

  final String? originalProductId;
  final String? originalIpAssetId;
  final String? originalBrandName;
  final String? originalProductName;
  final String? originalVariantName;

  final String? suspectedBrandName;
  final String? suspectedProductName;
  final String? suspectedVariantName;
  final String? claimedManufacturer;
  final String? countryCode;
  final String? region;

  final List<CounterfeitTwinCloneMethod> cloneMethods;

  final int visualSimilarityScore;
  final int packagingSimilarityScore;
  final int logoSimilarityScore;
  final int nameSimilarityScore;
  final int textSimilarityScore;
  final int priceAnomalyScore;
  final int overallSimilarityScore;

  final List<String> sourceIds;
  final List<String> listingIds;
  final List<String> sellerIds;
  final List<String> storeIds;
  final List<String> monitoredPageIds;
  final List<String> mediaAssetIds;
  final List<String> evidencePackageIds;
  final List<String> monitoringEventIds;
  final List<String> monitoringSignalIds;

  final String? cloneFamilyId;
  final String? waveId;
  final List<String> relatedTwinRecordIds;
  final int recurrenceCount;

  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final DateTime? confirmedAt;
  final DateTime? dismissedAt;
  final String? dismissReason;
  final DateTime? archivedAt;
  final String? archiveReason;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory CounterfeitTwinModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Sahte ikiz belgesi veri içermiyor: ${document.id}');
    }

    return CounterfeitTwinModel.fromMap(id: document.id, data: data);
  }

  factory CounterfeitTwinModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = _dateTime(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Sahte ikiz oluşturma tarihi eksik: $id');
    }

    return CounterfeitTwinModel(
      id: id.trim(),
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      recordCode: _requiredString(data['recordCode']),
      title: _requiredString(data['title']),
      status: CounterfeitTwinStatus.fromValue(data['status']?.toString()),
      confidenceLevel: CounterfeitTwinConfidenceLevel.fromValue(
        data['confidenceLevel']?.toString(),
      ),
      riskLevel: CounterfeitTwinRiskLevel.fromValue(
        data['riskLevel']?.toString(),
      ),
      reviewStatus: CounterfeitTwinReviewStatus.fromValue(
        data['reviewStatus']?.toString(),
      ),
      primaryCloneMethod: CounterfeitTwinCloneMethod.fromValue(
        data['primaryCloneMethod']?.toString(),
      ),
      originalProductId: _nullableString(data['originalProductId']),
      originalIpAssetId: _nullableString(data['originalIpAssetId']),
      originalBrandName: _nullableString(data['originalBrandName']),
      originalProductName: _nullableString(data['originalProductName']),
      originalVariantName: _nullableString(data['originalVariantName']),
      suspectedBrandName: _nullableString(data['suspectedBrandName']),
      suspectedProductName: _nullableString(data['suspectedProductName']),
      suspectedVariantName: _nullableString(data['suspectedVariantName']),
      claimedManufacturer: _nullableString(data['claimedManufacturer']),
      countryCode: _nullableString(data['countryCode']),
      region: _nullableString(data['region']),
      cloneMethods: _cloneMethodList(data['cloneMethods']),
      visualSimilarityScore: _intValue(data['visualSimilarityScore']),
      packagingSimilarityScore: _intValue(data['packagingSimilarityScore']),
      logoSimilarityScore: _intValue(data['logoSimilarityScore']),
      nameSimilarityScore: _intValue(data['nameSimilarityScore']),
      textSimilarityScore: _intValue(data['textSimilarityScore']),
      priceAnomalyScore: _intValue(data['priceAnomalyScore']),
      overallSimilarityScore: _intValue(data['overallSimilarityScore']),
      sourceIds: _stringList(data['sourceIds']),
      listingIds: _stringList(data['listingIds']),
      sellerIds: _stringList(data['sellerIds']),
      storeIds: _stringList(data['storeIds']),
      monitoredPageIds: _stringList(data['monitoredPageIds']),
      mediaAssetIds: _stringList(data['mediaAssetIds']),
      evidencePackageIds: _stringList(data['evidencePackageIds']),
      monitoringEventIds: _stringList(data['monitoringEventIds']),
      monitoringSignalIds: _stringList(data['monitoringSignalIds']),
      cloneFamilyId: _nullableString(data['cloneFamilyId']),
      waveId: _nullableString(data['waveId']),
      relatedTwinRecordIds: _stringList(data['relatedTwinRecordIds']),
      recurrenceCount: _intValue(data['recurrenceCount']),
      firstSeenAt: _dateTime(data['firstSeenAt']),
      lastSeenAt: _dateTime(data['lastSeenAt']),
      confirmedAt: _dateTime(data['confirmedAt']),
      dismissedAt: _dateTime(data['dismissedAt']),
      dismissReason: _nullableString(data['dismissReason']),
      archivedAt: _dateTime(data['archivedAt']),
      archiveReason: _nullableString(data['archiveReason']),
      notes: _nullableString(data['notes']),
      metadata: _map(data['metadata']),
      createdAt: createdAt,
      createdBy: _requiredString(data['createdBy']),
      updatedAt: _dateTime(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  String get normalizedRecordCode => recordCode.trim().toUpperCase();

  bool get isConfirmed => status == CounterfeitTwinStatus.confirmed;

  bool get isDismissed => status == CounterfeitTwinStatus.dismissed;

  bool get isArchived =>
      status == CounterfeitTwinStatus.archived || archivedAt != null;

  bool get isHighRisk =>
      riskLevel == CounterfeitTwinRiskLevel.high ||
      riskLevel == CounterfeitTwinRiskLevel.critical;

  bool get hasWaveLink =>
      (cloneFamilyId != null && cloneFamilyId!.trim().isNotEmpty) ||
      (waveId != null && waveId!.trim().isNotEmpty) ||
      recurrenceCount > 0 ||
      relatedTwinRecordIds.isNotEmpty;

  bool get hasDigitalEvidence =>
      listingIds.isNotEmpty ||
      monitoredPageIds.isNotEmpty ||
      mediaAssetIds.isNotEmpty ||
      evidencePackageIds.isNotEmpty ||
      monitoringEventIds.isNotEmpty ||
      monitoringSignalIds.isNotEmpty;

  bool get hasValidScores => <int>[
    visualSimilarityScore,
    packagingSimilarityScore,
    logoSimilarityScore,
    nameSimilarityScore,
    textSimilarityScore,
    priceAnomalyScore,
    overallSimilarityScore,
  ].every((score) => score >= 0 && score <= 100);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'recordCode': recordCode.trim(),
      'recordCodeNormalized': normalizedRecordCode,
      'title': title.trim(),
      'status': status.value,
      'confidenceLevel': confidenceLevel.value,
      'riskLevel': riskLevel.value,
      'reviewStatus': reviewStatus.value,
      'primaryCloneMethod': primaryCloneMethod.value,
      'originalProductId': _cleanNullable(originalProductId),
      'originalIpAssetId': _cleanNullable(originalIpAssetId),
      'originalBrandName': _cleanNullable(originalBrandName),
      'originalProductName': _cleanNullable(originalProductName),
      'originalVariantName': _cleanNullable(originalVariantName),
      'suspectedBrandName': _cleanNullable(suspectedBrandName),
      'suspectedProductName': _cleanNullable(suspectedProductName),
      'suspectedVariantName': _cleanNullable(suspectedVariantName),
      'claimedManufacturer': _cleanNullable(claimedManufacturer),
      'countryCode': _cleanNullable(countryCode)?.toUpperCase(),
      'region': _cleanNullable(region),
      'cloneMethods': _cleanCloneMethods(cloneMethods),
      'visualSimilarityScore': visualSimilarityScore,
      'packagingSimilarityScore': packagingSimilarityScore,
      'logoSimilarityScore': logoSimilarityScore,
      'nameSimilarityScore': nameSimilarityScore,
      'textSimilarityScore': textSimilarityScore,
      'priceAnomalyScore': priceAnomalyScore,
      'overallSimilarityScore': overallSimilarityScore,
      'sourceIds': _cleanStringList(sourceIds),
      'listingIds': _cleanStringList(listingIds),
      'sellerIds': _cleanStringList(sellerIds),
      'storeIds': _cleanStringList(storeIds),
      'monitoredPageIds': _cleanStringList(monitoredPageIds),
      'mediaAssetIds': _cleanStringList(mediaAssetIds),
      'evidencePackageIds': _cleanStringList(evidencePackageIds),
      'monitoringEventIds': _cleanStringList(monitoringEventIds),
      'monitoringSignalIds': _cleanStringList(monitoringSignalIds),
      'cloneFamilyId': _cleanNullable(cloneFamilyId),
      'waveId': _cleanNullable(waveId),
      'relatedTwinRecordIds': _cleanStringList(relatedTwinRecordIds),
      'recurrenceCount': recurrenceCount,
      'firstSeenAt': _timestamp(firstSeenAt),
      'lastSeenAt': _timestamp(lastSeenAt),
      'confirmedAt': _timestamp(confirmedAt),
      'dismissedAt': _timestamp(dismissedAt),
      'dismissReason': _cleanNullable(dismissReason),
      'archivedAt': _timestamp(archivedAt),
      'archiveReason': _cleanNullable(archiveReason),
      'notes': _cleanNullable(notes),
      'metadata': Map<String, dynamic>.from(metadata),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': _timestamp(updatedAt),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  Map<String, dynamic> toUpdateMap({required String actorId}) {
    final cleanedActorId = actorId.trim();

    if (cleanedActorId.isEmpty) {
      throw ArgumentError.value(actorId, 'actorId', 'actorId boş olamaz.');
    }

    final map = toMap()
      ..remove('tenantId')
      ..remove('brandId')
      ..remove('recordCode')
      ..remove('recordCodeNormalized')
      ..remove('createdAt')
      ..remove('createdBy');

    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = cleanedActorId;

    return map;
  }

  static String _requiredString(Object? value) {
    final cleaned = value?.toString().trim() ?? '';

    if (cleaned.isEmpty) {
      throw const FormatException('Zorunlu metin alanı boş olamaz.');
    }

    return cleaned;
  }

  static String? _nullableString(Object? value) {
    final cleaned = value?.toString().trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static Timestamp? _timestamp(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return _cleanStringList(value.map((item) => item?.toString() ?? ''));
  }

  static List<String> _cleanStringList(Iterable<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static List<CounterfeitTwinCloneMethod> _cloneMethodList(Object? value) {
    if (value is! Iterable) {
      return const <CounterfeitTwinCloneMethod>[];
    }

    final seen = <CounterfeitTwinCloneMethod>{};

    for (final item in value) {
      seen.add(CounterfeitTwinCloneMethod.fromValue(item?.toString()));
    }

    return seen.toList(growable: false);
  }

  static List<String> _cleanCloneMethods(
    Iterable<CounterfeitTwinCloneMethod> values,
  ) {
    final seen = <String>{};

    for (final item in values) {
      seen.add(item.value);
    }

    return seen.toList(growable: false);
  }

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const <String, dynamic>{};
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
