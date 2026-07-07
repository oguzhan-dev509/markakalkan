import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/supply_security_enums.dart';

class SupplyPartnerModel {
  const SupplyPartnerModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.partnerCode,
    required this.legalName,
    required this.roles,
    required this.status,
    required this.verificationStatus,
    required this.riskLevel,
    required this.trustScore,
    required this.createdAt,
    required this.createdBy,
    this.tradeName,
    this.taxNumber,
    this.registrationNumber,
    this.countryCode,
    this.city,
    this.region,
    this.address,
    this.website,
    this.contactPersonName,
    this.email,
    this.phone,
    this.isCriticalPartner = false,
    this.contractManufacturingAuthorized = false,
    this.subcontractingAllowed = false,
    this.hasNda = false,
    this.auditRequired = false,
    this.lastAuditAt,
    this.nextAuditAt,
    this.certificateDocumentIds = const <String>[],
    this.relatedFacilityIds = const <String>[],
    this.relatedProductIds = const <String>[],
    this.productCategoryCodes = const <String>[],
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
  final String partnerCode;
  final String legalName;
  final String? tradeName;
  final String? taxNumber;
  final String? registrationNumber;
  final List<SupplyPartnerRole> roles;
  final SupplyPartnerStatus status;
  final SupplyPartnerVerificationStatus verificationStatus;
  final SupplyPartnerRiskLevel riskLevel;
  final int trustScore;
  final String? countryCode;
  final String? city;
  final String? region;
  final String? address;
  final String? website;
  final String? contactPersonName;
  final String? email;
  final String? phone;
  final bool isCriticalPartner;
  final bool contractManufacturingAuthorized;
  final bool subcontractingAllowed;
  final bool hasNda;
  final bool auditRequired;
  final DateTime? lastAuditAt;
  final DateTime? nextAuditAt;
  final List<String> certificateDocumentIds;
  final List<String> relatedFacilityIds;
  final List<String> relatedProductIds;
  final List<String> productCategoryCodes;
  final String? notes;
  final String? archiveReason;
  final DateTime? archivedAt;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory SupplyPartnerModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Tedarik güvenliği partner belgesi boş: ${document.id}');
    }

    return SupplyPartnerModel.fromMap(id: document.id, data: data);
  }

  factory SupplyPartnerModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = _dateTime(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Partner oluşturma tarihi eksik: $id');
    }

    final rawRoles = data['roles'];

    return SupplyPartnerModel(
      id: id.trim(),
      tenantId: _requiredString(data['tenantId']),
      brandId: _requiredString(data['brandId']),
      partnerCode: _requiredString(data['partnerCode']),
      legalName: _requiredString(data['legalName']),
      tradeName: _nullableString(data['tradeName']),
      taxNumber: _nullableString(data['taxNumber']),
      registrationNumber: _nullableString(data['registrationNumber']),
      roles: rawRoles is Iterable
          ? rawRoles
                .map((value) => SupplyPartnerRole.fromValue(value?.toString()))
                .toSet()
                .toList(growable: false)
          : const <SupplyPartnerRole>[],
      status: SupplyPartnerStatus.fromValue(data['status']?.toString()),
      verificationStatus: SupplyPartnerVerificationStatus.fromValue(
        data['verificationStatus']?.toString(),
      ),
      riskLevel: SupplyPartnerRiskLevel.fromValue(
        data['riskLevel']?.toString(),
      ),
      trustScore: _score(data['trustScore']),
      countryCode: _nullableString(data['countryCode'])?.toUpperCase(),
      city: _nullableString(data['city']),
      region: _nullableString(data['region']),
      address: _nullableString(data['address']),
      website: _nullableString(data['website']),
      contactPersonName: _nullableString(data['contactPersonName']),
      email: _nullableString(data['email'])?.toLowerCase(),
      phone: _nullableString(data['phone']),
      isCriticalPartner: data['isCriticalPartner'] == true,
      contractManufacturingAuthorized:
          data['contractManufacturingAuthorized'] == true,
      subcontractingAllowed: data['subcontractingAllowed'] == true,
      hasNda: data['hasNda'] == true,
      auditRequired: data['auditRequired'] == true,
      lastAuditAt: _dateTime(data['lastAuditAt']),
      nextAuditAt: _dateTime(data['nextAuditAt']),
      certificateDocumentIds: _stringList(data['certificateDocumentIds']),
      relatedFacilityIds: _stringList(data['relatedFacilityIds']),
      relatedProductIds: _stringList(data['relatedProductIds']),
      productCategoryCodes: _stringList(data['productCategoryCodes']),
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

  String get normalizedPartnerCode => partnerCode.trim().toUpperCase();

  bool get hasCompleteIdentity =>
      tenantId.trim().isNotEmpty &&
      brandId.trim().isNotEmpty &&
      partnerCode.trim().isNotEmpty &&
      legalName.trim().isNotEmpty;

  bool get isArchived =>
      status == SupplyPartnerStatus.archived || archivedAt != null;

  bool get hasManufacturingRole =>
      roles.contains(SupplyPartnerRole.manufacturer) ||
      roles.contains(SupplyPartnerRole.contractManufacturer);

  bool get hasOperationalRole =>
      hasManufacturingRole || roles.contains(SupplyPartnerRole.subcontractor);

  bool get isHighRisk =>
      riskLevel == SupplyPartnerRiskLevel.high ||
      riskLevel == SupplyPartnerRiskLevel.critical ||
      trustScore <= 35 ||
      status == SupplyPartnerStatus.blocked;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'partnerCode': partnerCode.trim(),
      'partnerCodeNormalized': normalizedPartnerCode,
      'legalName': legalName.trim(),
      'tradeName': _cleanNullable(tradeName),
      'taxNumber': _cleanNullable(taxNumber),
      'registrationNumber': _cleanNullable(registrationNumber),
      'roles': roles.map((item) => item.value).toSet().toList(growable: false),
      'status': status.value,
      'verificationStatus': verificationStatus.value,
      'riskLevel': riskLevel.value,
      'trustScore': trustScore.clamp(0, 100),
      'countryCode': _cleanNullable(countryCode)?.toUpperCase(),
      'city': _cleanNullable(city),
      'region': _cleanNullable(region),
      'address': _cleanNullable(address),
      'website': _cleanNullable(website),
      'contactPersonName': _cleanNullable(contactPersonName),
      'email': _cleanNullable(email)?.toLowerCase(),
      'phone': _cleanNullable(phone),
      'isCriticalPartner': isCriticalPartner,
      'contractManufacturingAuthorized': contractManufacturingAuthorized,
      'subcontractingAllowed': subcontractingAllowed,
      'hasNda': hasNda,
      'auditRequired': auditRequired,
      'lastAuditAt': _timestamp(lastAuditAt),
      'nextAuditAt': _timestamp(nextAuditAt),
      'certificateDocumentIds': _cleanStringList(certificateDocumentIds),
      'relatedFacilityIds': _cleanStringList(relatedFacilityIds),
      'relatedProductIds': _cleanStringList(relatedProductIds),
      'productCategoryCodes': _cleanStringList(productCategoryCodes),
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
      ..remove('partnerCode')
      ..remove('partnerCodeNormalized')
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

  static int _score(Object? value) {
    if (value is int) {
      return value.clamp(0, 100);
    }

    if (value is num) {
      return value.toInt().clamp(0, 100);
    }

    return 0;
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
