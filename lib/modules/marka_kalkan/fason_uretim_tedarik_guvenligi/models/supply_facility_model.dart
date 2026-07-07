import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/supply_facility_enums.dart';

class SupplyFacilityModel {
  const SupplyFacilityModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.partnerId,
    required this.facilityCode,
    required this.name,
    required this.facilityType,
    required this.status,
    required this.verificationStatus,
    required this.riskLevel,
    required this.authorizationStatus,
    required this.createdAt,
    required this.createdBy,
    this.parentFacilityId,
    this.countryCode,
    this.city,
    this.region,
    this.address,
    this.latitude,
    this.longitude,
    this.monthlyCapacity,
    this.capacityUnit,
    this.shiftCodes = const <SupplyShiftCode>[],
    this.relatedProductIds = const <String>[],
    this.productCategoryCodes = const <String>[],
    this.certificateDocumentIds = const <String>[],
    this.auditDocumentIds = const <String>[],
    this.isPrimaryFacility = false,
    this.isCriticalFacility = false,
    this.productionAuthorized = false,
    this.storageAuthorized = false,
    this.packagingAuthorized = false,
    this.labelPrintingAuthorized = false,
    this.destructionAuthorized = false,
    this.subcontractingObserved = false,
    this.suspiciousNightShiftObserved = false,
    this.capacityMismatchObserved = false,
    this.unregisteredShipmentObserved = false,
    this.auditRequired = false,
    this.lastAuditAt,
    this.nextAuditAt,
    this.lastVerifiedAt,
    this.riskReason,
    this.notes,
    this.archiveReason,
    this.archivedAt,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String partnerId;
  final String facilityCode;
  final String name;
  final SupplyFacilityType facilityType;
  final SupplyFacilityStatus status;
  final SupplyFacilityVerificationStatus verificationStatus;
  final SupplyFacilityRiskLevel riskLevel;
  final SupplyFacilityAuthorizationStatus authorizationStatus;

  final String? parentFacilityId;
  final String? countryCode;
  final String? city;
  final String? region;
  final String? address;
  final double? latitude;
  final double? longitude;

  final int? monthlyCapacity;
  final String? capacityUnit;
  final List<SupplyShiftCode> shiftCodes;
  final List<String> relatedProductIds;
  final List<String> productCategoryCodes;
  final List<String> certificateDocumentIds;
  final List<String> auditDocumentIds;

  final bool isPrimaryFacility;
  final bool isCriticalFacility;
  final bool productionAuthorized;
  final bool storageAuthorized;
  final bool packagingAuthorized;
  final bool labelPrintingAuthorized;
  final bool destructionAuthorized;

  final bool subcontractingObserved;
  final bool suspiciousNightShiftObserved;
  final bool capacityMismatchObserved;
  final bool unregisteredShipmentObserved;
  final bool auditRequired;

  final DateTime? lastAuditAt;
  final DateTime? nextAuditAt;
  final DateTime? lastVerifiedAt;

  final String? riskReason;
  final String? notes;
  final String? archiveReason;
  final DateTime? archivedAt;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory SupplyFacilityModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Tesis belgesi veri içermiyor: ${document.id}');
    }

    return SupplyFacilityModel.fromMap(id: document.id, data: data);
  }

  factory SupplyFacilityModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = _dateTime(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Tesis oluşturma tarihi eksik: $id');
    }

    return SupplyFacilityModel(
      id: id.trim(),
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      partnerId: _requiredString(data['partnerId']),
      facilityCode: _requiredString(data['facilityCode']),
      name: _requiredString(data['name']),
      facilityType: SupplyFacilityType.fromValue(
        data['facilityType']?.toString(),
      ),
      status: SupplyFacilityStatus.fromValue(data['status']?.toString()),
      verificationStatus: SupplyFacilityVerificationStatus.fromValue(
        data['verificationStatus']?.toString(),
      ),
      riskLevel: SupplyFacilityRiskLevel.fromValue(
        data['riskLevel']?.toString(),
      ),
      authorizationStatus: SupplyFacilityAuthorizationStatus.fromValue(
        data['authorizationStatus']?.toString(),
      ),
      parentFacilityId: _nullableString(data['parentFacilityId']),
      countryCode: _nullableString(data['countryCode'])?.toUpperCase(),
      city: _nullableString(data['city']),
      region: _nullableString(data['region']),
      address: _nullableString(data['address']),
      latitude: _double(data['latitude']),
      longitude: _double(data['longitude']),
      monthlyCapacity: _nullableInt(data['monthlyCapacity']),
      capacityUnit: _nullableString(data['capacityUnit']),
      shiftCodes: _enumList<SupplyShiftCode>(
        data['shiftCodes'],
        SupplyShiftCode.fromValue,
      ),
      relatedProductIds: _stringList(data['relatedProductIds']),
      productCategoryCodes: _stringList(data['productCategoryCodes']),
      certificateDocumentIds: _stringList(data['certificateDocumentIds']),
      auditDocumentIds: _stringList(data['auditDocumentIds']),
      isPrimaryFacility: data['isPrimaryFacility'] == true,
      isCriticalFacility: data['isCriticalFacility'] == true,
      productionAuthorized: data['productionAuthorized'] == true,
      storageAuthorized: data['storageAuthorized'] == true,
      packagingAuthorized: data['packagingAuthorized'] == true,
      labelPrintingAuthorized: data['labelPrintingAuthorized'] == true,
      destructionAuthorized: data['destructionAuthorized'] == true,
      subcontractingObserved: data['subcontractingObserved'] == true,
      suspiciousNightShiftObserved:
          data['suspiciousNightShiftObserved'] == true,
      capacityMismatchObserved: data['capacityMismatchObserved'] == true,
      unregisteredShipmentObserved:
          data['unregisteredShipmentObserved'] == true,
      auditRequired: data['auditRequired'] == true,
      lastAuditAt: _dateTime(data['lastAuditAt']),
      nextAuditAt: _dateTime(data['nextAuditAt']),
      lastVerifiedAt: _dateTime(data['lastVerifiedAt']),
      riskReason: _nullableString(data['riskReason']),
      notes: _nullableString(data['notes']),
      archiveReason: _nullableString(data['archiveReason']),
      archivedAt: _dateTime(data['archivedAt']),
      metadata: _map(data['metadata']),
      createdAt: createdAt,
      createdBy: _requiredString(data['createdBy']),
      updatedAt: _dateTime(data['updatedAt']),
      updatedBy: _nullableString(data['updatedBy']),
    );
  }

  String get normalizedFacilityCode => facilityCode.trim().toUpperCase();

  bool get hasCompleteIdentity =>
      tenantId.trim().isNotEmpty &&
      brandId.trim().isNotEmpty &&
      partnerId.trim().isNotEmpty &&
      facilityCode.trim().isNotEmpty &&
      name.trim().isNotEmpty;

  bool get isArchived =>
      status == SupplyFacilityStatus.archived || archivedAt != null;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isUnauthorizedOrSuspicious =>
      authorizationStatus == SupplyFacilityAuthorizationStatus.unauthorized ||
      authorizationStatus == SupplyFacilityAuthorizationStatus.revoked ||
      facilityType == SupplyFacilityType.suspectedUnauthorizedSite ||
      subcontractingObserved ||
      suspiciousNightShiftObserved ||
      capacityMismatchObserved ||
      unregisteredShipmentObserved;

  bool get isHighRisk =>
      riskLevel == SupplyFacilityRiskLevel.high ||
      riskLevel == SupplyFacilityRiskLevel.critical ||
      status == SupplyFacilityStatus.blocked ||
      isUnauthorizedOrSuspicious;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'partnerId': partnerId.trim(),
      'facilityCode': facilityCode.trim(),
      'facilityCodeNormalized': normalizedFacilityCode,
      'name': name.trim(),
      'facilityType': facilityType.value,
      'status': status.value,
      'verificationStatus': verificationStatus.value,
      'riskLevel': riskLevel.value,
      'authorizationStatus': authorizationStatus.value,
      'parentFacilityId': _cleanNullable(parentFacilityId),
      'countryCode': _cleanNullable(countryCode)?.toUpperCase(),
      'city': _cleanNullable(city),
      'region': _cleanNullable(region),
      'address': _cleanNullable(address),
      'latitude': latitude,
      'longitude': longitude,
      'monthlyCapacity': monthlyCapacity,
      'capacityUnit': _cleanNullable(capacityUnit),
      'shiftCodes': shiftCodes
          .map((item) => item.value)
          .toSet()
          .toList(growable: false),
      'relatedProductIds': _cleanStringList(relatedProductIds),
      'productCategoryCodes': _cleanStringList(productCategoryCodes),
      'certificateDocumentIds': _cleanStringList(certificateDocumentIds),
      'auditDocumentIds': _cleanStringList(auditDocumentIds),
      'isPrimaryFacility': isPrimaryFacility,
      'isCriticalFacility': isCriticalFacility,
      'productionAuthorized': productionAuthorized,
      'storageAuthorized': storageAuthorized,
      'packagingAuthorized': packagingAuthorized,
      'labelPrintingAuthorized': labelPrintingAuthorized,
      'destructionAuthorized': destructionAuthorized,
      'subcontractingObserved': subcontractingObserved,
      'suspiciousNightShiftObserved': suspiciousNightShiftObserved,
      'capacityMismatchObserved': capacityMismatchObserved,
      'unregisteredShipmentObserved': unregisteredShipmentObserved,
      'auditRequired': auditRequired,
      'lastAuditAt': _timestamp(lastAuditAt),
      'nextAuditAt': _timestamp(nextAuditAt),
      'lastVerifiedAt': _timestamp(lastVerifiedAt),
      'riskReason': _cleanNullable(riskReason),
      'notes': _cleanNullable(notes),
      'archiveReason': _cleanNullable(archiveReason),
      'archivedAt': _timestamp(archivedAt),
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
    final map = toMap()
      ..remove('tenantId')
      ..remove('brandId')
      ..remove('partnerId')
      ..remove('facilityCode')
      ..remove('facilityCodeNormalized')
      ..remove('createdAt')
      ..remove('createdBy');

    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = actorId.trim();
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

  static int? _nullableInt(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return null;
  }

  static double? _double(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static Timestamp? _timestamp(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }

  static List<T> _enumList<T>(Object? value, T Function(String?) parser) {
    if (value is! Iterable) {
      return <T>[];
    }

    return value
        .map((item) => parser(item?.toString()))
        .toSet()
        .toList(growable: false);
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
