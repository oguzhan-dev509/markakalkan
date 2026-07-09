import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/supply_production_asset_enums.dart';

class SupplyProductionAssetModel {
  const SupplyProductionAssetModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.assetCode,
    required this.name,
    required this.assetClass,
    required this.assetType,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.partnerId,
    this.facilityId,
    this.description,
    this.manufacturer,
    this.modelNumber,
    this.serialNumber,
    this.internalReference,
    this.physicalLocation,
    this.digitalStorageReference,
    this.version,
    this.fileHash,
    this.confidentialityLevel,
    this.relatedProductIds = const <String>[],
    this.relatedIpAssetIds = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.destroyedAt,
    this.destroyedBy,
    this.destructionReason,
    this.destructionEvidenceDocumentIds = const <String>[],
    this.archivedAt,
    this.archivedBy,
    this.archiveReason,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String assetCode;
  final String name;
  final SupplyProductionAssetClass assetClass;
  final SupplyProductionAssetType assetType;
  final SupplyProductionAssetStatus status;
  final String? partnerId;
  final String? facilityId;
  final String? description;
  final String? manufacturer;
  final String? modelNumber;
  final String? serialNumber;
  final String? internalReference;
  final String? physicalLocation;
  final String? digitalStorageReference;
  final String? version;
  final String? fileHash;
  final String? confidentialityLevel;
  final List<String> relatedProductIds;
  final List<String> relatedIpAssetIds;
  final List<String> evidenceDocumentIds;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime? destroyedAt;
  final String? destroyedBy;
  final String? destructionReason;
  final List<String> destructionEvidenceDocumentIds;
  final DateTime? archivedAt;
  final String? archivedBy;
  final String? archiveReason;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory SupplyProductionAssetModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw StateError('Üretim varlığı belgesi veri içermiyor: ${document.id}');
    }
    return SupplyProductionAssetModel.fromMap(id: document.id, data: data);
  }

  factory SupplyProductionAssetModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = _dateTime(data['createdAt']);
    if (createdAt == null) {
      throw StateError('Üretim varlığı oluşturma tarihi eksik: $id');
    }
    return SupplyProductionAssetModel(
      id: id.trim(),
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      assetCode: _requiredString(data['assetCode']),
      name: _requiredString(data['name']),
      assetClass: SupplyProductionAssetClass.fromValue(
        data['assetClass']?.toString(),
      ),
      assetType: SupplyProductionAssetType.fromValue(
        data['assetType']?.toString(),
      ),
      status: SupplyProductionAssetStatus.fromValue(data['status']?.toString()),
      partnerId: _nullableString(data['partnerId']),
      facilityId: _nullableString(data['facilityId']),
      description: _nullableString(data['description']),
      manufacturer: _nullableString(data['manufacturer']),
      modelNumber: _nullableString(data['modelNumber']),
      serialNumber: _nullableString(data['serialNumber']),
      internalReference: _nullableString(data['internalReference']),
      physicalLocation: _nullableString(data['physicalLocation']),
      digitalStorageReference: _nullableString(data['digitalStorageReference']),
      version: _nullableString(data['version']),
      fileHash: _nullableString(data['fileHash']),
      confidentialityLevel: _nullableString(data['confidentialityLevel']),
      relatedProductIds: _stringList(data['relatedProductIds']),
      relatedIpAssetIds: _stringList(data['relatedIpAssetIds']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      notes: _nullableString(data['notes']),
      metadata: _map(data['metadata']),
      destroyedAt: _dateTime(data['destroyedAt']),
      destroyedBy: _nullableString(data['destroyedBy']),
      destructionReason: _nullableString(data['destructionReason']),
      destructionEvidenceDocumentIds: _stringList(
        data['destructionEvidenceDocumentIds'],
      ),
      archivedAt: _dateTime(data['archivedAt']),
      archivedBy: _nullableString(data['archivedBy']),
      archiveReason: _nullableString(data['archiveReason']),
      createdAt: createdAt,
      createdBy: _requiredString(data['createdBy']),
      updatedAt: _dateTime(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  String get normalizedAssetCode => assetCode.trim().toUpperCase();
  bool get isArchived =>
      status == SupplyProductionAssetStatus.archived || archivedAt != null;
  bool get isDestroyed =>
      status == SupplyProductionAssetStatus.destroyed || destroyedAt != null;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'assetCode': assetCode.trim(),
      'assetCodeNormalized': normalizedAssetCode,
      'name': name.trim(),
      'assetClass': assetClass.value,
      'assetType': assetType.value,
      'status': status.value,
      'partnerId': _cleanNullable(partnerId),
      'facilityId': _cleanNullable(facilityId),
      'description': _cleanNullable(description),
      'manufacturer': _cleanNullable(manufacturer),
      'modelNumber': _cleanNullable(modelNumber),
      'serialNumber': _cleanNullable(serialNumber),
      'internalReference': _cleanNullable(internalReference),
      'physicalLocation': _cleanNullable(physicalLocation),
      'digitalStorageReference': _cleanNullable(digitalStorageReference),
      'version': _cleanNullable(version),
      'fileHash': _cleanNullable(fileHash),
      'confidentialityLevel': _cleanNullable(confidentialityLevel),
      'relatedProductIds': _cleanStringList(relatedProductIds),
      'relatedIpAssetIds': _cleanStringList(relatedIpAssetIds),
      'evidenceDocumentIds': _cleanStringList(evidenceDocumentIds),
      'notes': _cleanNullable(notes),
      'metadata': Map<String, dynamic>.from(metadata),
      'destroyedAt': _timestamp(destroyedAt),
      'destroyedBy': _cleanNullable(destroyedBy),
      'destructionReason': _cleanNullable(destructionReason),
      'destructionEvidenceDocumentIds': _cleanStringList(
        destructionEvidenceDocumentIds,
      ),
      'archivedAt': _timestamp(archivedAt),
      'archivedBy': _cleanNullable(archivedBy),
      'archiveReason': _cleanNullable(archiveReason),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': _timestamp(updatedAt),
      'updatedBy': _cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toUpdateMap({required String actorId}) {
    final cleanedActorId = actorId.trim();
    if (cleanedActorId.isEmpty) {
      throw ArgumentError.value(actorId, 'actorId', 'actorId boş olamaz.');
    }
    final map = toMap()
      ..remove('tenantId')
      ..remove('brandId')
      ..remove('assetCode')
      ..remove('assetCodeNormalized')
      ..remove('status')
      ..remove('destroyedAt')
      ..remove('destroyedBy')
      ..remove('destructionReason')
      ..remove('destructionEvidenceDocumentIds')
      ..remove('archivedAt')
      ..remove('archivedBy')
      ..remove('archiveReason')
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
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Timestamp? _timestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) return const <String>[];
    return _cleanStringList(value.map((item) => item?.toString() ?? ''));
  }

  static List<String> _cleanStringList(Iterable<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
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
