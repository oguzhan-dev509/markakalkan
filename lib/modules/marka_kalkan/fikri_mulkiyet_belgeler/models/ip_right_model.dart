import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../utils/ip_model_utils.dart';

class IpRightModel {
  const IpRightModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.assetId,
    required this.rightCode,
    required this.title,
    required this.rightType,
    required this.status,
    required this.jurisdictionScope,
    required this.riskLevel,
    required this.createdAt,
    required this.createdBy,
    this.description,
    this.applicationNumber,
    this.registrationNumber,
    this.publicationNumber,
    this.priorityNumber,
    this.responsibleOffice,
    this.primaryCountryCode,
    this.regionCode,
    this.applicationAt,
    this.priorityAt,
    this.publicationAt,
    this.registrationAt,
    this.grantAt,
    this.lastRenewalAt,
    this.nextRenewalAt,
    this.expiryAt,
    this.oppositionDeadlineAt,
    this.annuityDeadlineAt,
    this.niceClasses = const <String>[],
    this.locarnoClasses = const <String>[],
    this.ipcClasses = const <String>[],
    this.goodsAndServices = const <String>[],
    this.claimsSummary = const <String>[],
    this.ownerNames = const <String>[],
    this.inventorNames = const <String>[],
    this.creatorNames = const <String>[],
    this.representativeNames = const <String>[],
    this.countryCodes = const <String>[],
    this.documentIds = const <String>[],
    this.relationshipIds = const <String>[],
    this.relatedRightIds = const <String>[],
    this.patentFamilyIds = const <String>[],
    this.pctApplicationNumber,
    this.madridRegistrationNumber,
    this.hagueRegistrationNumber,
    this.europeanApplicationNumber,
    this.renewalRequired = false,
    this.annuityRequired = false,
    this.oppositionActive = false,
    this.disputeActive = false,
    this.customsProtectionActive = false,
    this.monitoringEnabled = false,
    this.rightStrengthScore = 0,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String assetId;

  final String rightCode;
  final String title;
  final String? description;

  final IpRightType rightType;
  final IpRightStatus status;
  final IpJurisdictionScope jurisdictionScope;
  final IpRiskLevel riskLevel;

  final String? applicationNumber;
  final String? registrationNumber;
  final String? publicationNumber;
  final String? priorityNumber;

  final String? responsibleOffice;
  final String? primaryCountryCode;
  final String? regionCode;

  final DateTime? applicationAt;
  final DateTime? priorityAt;
  final DateTime? publicationAt;
  final DateTime? registrationAt;
  final DateTime? grantAt;
  final DateTime? lastRenewalAt;
  final DateTime? nextRenewalAt;
  final DateTime? expiryAt;
  final DateTime? oppositionDeadlineAt;
  final DateTime? annuityDeadlineAt;

  final List<String> niceClasses;
  final List<String> locarnoClasses;
  final List<String> ipcClasses;
  final List<String> goodsAndServices;
  final List<String> claimsSummary;

  final List<String> ownerNames;
  final List<String> inventorNames;
  final List<String> creatorNames;
  final List<String> representativeNames;

  final List<String> countryCodes;
  final List<String> documentIds;
  final List<String> relationshipIds;
  final List<String> relatedRightIds;
  final List<String> patentFamilyIds;

  final String? pctApplicationNumber;
  final String? madridRegistrationNumber;
  final String? hagueRegistrationNumber;
  final String? europeanApplicationNumber;

  final bool renewalRequired;
  final bool annuityRequired;
  final bool oppositionActive;
  final bool disputeActive;
  final bool customsProtectionActive;
  final bool monitoringEnabled;

  final int rightStrengthScore;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpRightModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Fikri mülkiyet hakkı belgesi veri içermiyor: ${document.id}',
      );
    }

    return IpRightModel.fromMap(id: document.id, data: data);
  }

  factory IpRightModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Fikri mülkiyet hakkı oluşturma tarihi eksik: $id');
    }

    return IpRightModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      assetId: IpModelUtils.requiredString(data['assetId']),
      rightCode: IpModelUtils.requiredString(data['rightCode']),
      title: IpModelUtils.requiredString(data['title']),
      description: IpModelUtils.nullableString(data['description']),
      rightType: IpRightType.fromValue(data['rightType']?.toString()),
      status: IpRightStatus.fromValue(data['status']?.toString()),
      jurisdictionScope: IpJurisdictionScope.fromValue(
        data['jurisdictionScope']?.toString(),
      ),
      riskLevel: IpRiskLevel.fromValue(data['riskLevel']?.toString()),
      applicationNumber: IpModelUtils.nullableString(data['applicationNumber']),
      registrationNumber: IpModelUtils.nullableString(
        data['registrationNumber'],
      ),
      publicationNumber: IpModelUtils.nullableString(data['publicationNumber']),
      priorityNumber: IpModelUtils.nullableString(data['priorityNumber']),
      responsibleOffice: IpModelUtils.nullableString(data['responsibleOffice']),
      primaryCountryCode: IpModelUtils.nullableString(
        data['primaryCountryCode'],
      ),
      regionCode: IpModelUtils.nullableString(data['regionCode']),
      applicationAt: IpModelUtils.dateTimeFromValue(data['applicationAt']),
      priorityAt: IpModelUtils.dateTimeFromValue(data['priorityAt']),
      publicationAt: IpModelUtils.dateTimeFromValue(data['publicationAt']),
      registrationAt: IpModelUtils.dateTimeFromValue(data['registrationAt']),
      grantAt: IpModelUtils.dateTimeFromValue(data['grantAt']),
      lastRenewalAt: IpModelUtils.dateTimeFromValue(data['lastRenewalAt']),
      nextRenewalAt: IpModelUtils.dateTimeFromValue(data['nextRenewalAt']),
      expiryAt: IpModelUtils.dateTimeFromValue(data['expiryAt']),
      oppositionDeadlineAt: IpModelUtils.dateTimeFromValue(
        data['oppositionDeadlineAt'],
      ),
      annuityDeadlineAt: IpModelUtils.dateTimeFromValue(
        data['annuityDeadlineAt'],
      ),
      niceClasses: IpModelUtils.stringListFromValue(data['niceClasses']),
      locarnoClasses: IpModelUtils.stringListFromValue(data['locarnoClasses']),
      ipcClasses: IpModelUtils.stringListFromValue(data['ipcClasses']),
      goodsAndServices: IpModelUtils.stringListFromValue(
        data['goodsAndServices'],
      ),
      claimsSummary: IpModelUtils.stringListFromValue(data['claimsSummary']),
      ownerNames: IpModelUtils.stringListFromValue(data['ownerNames']),
      inventorNames: IpModelUtils.stringListFromValue(data['inventorNames']),
      creatorNames: IpModelUtils.stringListFromValue(data['creatorNames']),
      representativeNames: IpModelUtils.stringListFromValue(
        data['representativeNames'],
      ),
      countryCodes: IpModelUtils.stringListFromValue(data['countryCodes']),
      documentIds: IpModelUtils.stringListFromValue(data['documentIds']),
      relationshipIds: IpModelUtils.stringListFromValue(
        data['relationshipIds'],
      ),
      relatedRightIds: IpModelUtils.stringListFromValue(
        data['relatedRightIds'],
      ),
      patentFamilyIds: IpModelUtils.stringListFromValue(
        data['patentFamilyIds'],
      ),
      pctApplicationNumber: IpModelUtils.nullableString(
        data['pctApplicationNumber'],
      ),
      madridRegistrationNumber: IpModelUtils.nullableString(
        data['madridRegistrationNumber'],
      ),
      hagueRegistrationNumber: IpModelUtils.nullableString(
        data['hagueRegistrationNumber'],
      ),
      europeanApplicationNumber: IpModelUtils.nullableString(
        data['europeanApplicationNumber'],
      ),
      renewalRequired: IpModelUtils.boolFromValue(data['renewalRequired']),
      annuityRequired: IpModelUtils.boolFromValue(data['annuityRequired']),
      oppositionActive: IpModelUtils.boolFromValue(data['oppositionActive']),
      disputeActive: IpModelUtils.boolFromValue(data['disputeActive']),
      customsProtectionActive: IpModelUtils.boolFromValue(
        data['customsProtectionActive'],
      ),
      monitoringEnabled: IpModelUtils.boolFromValue(data['monitoringEnabled']),
      rightStrengthScore: IpModelUtils.boundedScore(data['rightStrengthScore']),
      notes: IpModelUtils.nullableString(data['notes']),
      metadata: IpModelUtils.mapFromValue(data['metadata']),
      createdAt: createdAt,
      createdBy: IpModelUtils.requiredString(data['createdBy']),
      updatedAt: IpModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: IpModelUtils.nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'assetId': assetId.trim(),
      'rightCode': rightCode.trim(),
      'title': title.trim(),
      'description': IpModelUtils.cleanNullable(description),
      'rightType': rightType.value,
      'status': status.value,
      'jurisdictionScope': jurisdictionScope.value,
      'riskLevel': riskLevel.value,
      'applicationNumber': IpModelUtils.cleanNullable(applicationNumber),
      'registrationNumber': IpModelUtils.cleanNullable(registrationNumber),
      'publicationNumber': IpModelUtils.cleanNullable(publicationNumber),
      'priorityNumber': IpModelUtils.cleanNullable(priorityNumber),
      'responsibleOffice': IpModelUtils.cleanNullable(responsibleOffice),
      'primaryCountryCode': _countryCode(primaryCountryCode),
      'regionCode': IpModelUtils.cleanNullable(regionCode)?.toUpperCase(),
      'applicationAt': IpModelUtils.timestampOrNull(applicationAt),
      'priorityAt': IpModelUtils.timestampOrNull(priorityAt),
      'publicationAt': IpModelUtils.timestampOrNull(publicationAt),
      'registrationAt': IpModelUtils.timestampOrNull(registrationAt),
      'grantAt': IpModelUtils.timestampOrNull(grantAt),
      'lastRenewalAt': IpModelUtils.timestampOrNull(lastRenewalAt),
      'nextRenewalAt': IpModelUtils.timestampOrNull(nextRenewalAt),
      'expiryAt': IpModelUtils.timestampOrNull(expiryAt),
      'oppositionDeadlineAt': IpModelUtils.timestampOrNull(
        oppositionDeadlineAt,
      ),
      'annuityDeadlineAt': IpModelUtils.timestampOrNull(annuityDeadlineAt),
      'niceClasses': IpModelUtils.cleanStringList(niceClasses),
      'locarnoClasses': IpModelUtils.cleanStringList(locarnoClasses),
      'ipcClasses': IpModelUtils.cleanStringList(ipcClasses),
      'goodsAndServices': IpModelUtils.cleanStringList(goodsAndServices),
      'claimsSummary': IpModelUtils.cleanStringList(claimsSummary),
      'ownerNames': IpModelUtils.cleanStringList(ownerNames),
      'inventorNames': IpModelUtils.cleanStringList(inventorNames),
      'creatorNames': IpModelUtils.cleanStringList(creatorNames),
      'representativeNames': IpModelUtils.cleanStringList(representativeNames),
      'countryCodes': IpModelUtils.cleanStringList(
        countryCodes.map((item) => item.toUpperCase()),
      ),
      'documentIds': IpModelUtils.cleanStringList(documentIds),
      'relationshipIds': IpModelUtils.cleanStringList(relationshipIds),
      'relatedRightIds': IpModelUtils.cleanStringList(relatedRightIds),
      'patentFamilyIds': IpModelUtils.cleanStringList(patentFamilyIds),
      'pctApplicationNumber': IpModelUtils.cleanNullable(pctApplicationNumber),
      'madridRegistrationNumber': IpModelUtils.cleanNullable(
        madridRegistrationNumber,
      ),
      'hagueRegistrationNumber': IpModelUtils.cleanNullable(
        hagueRegistrationNumber,
      ),
      'europeanApplicationNumber': IpModelUtils.cleanNullable(
        europeanApplicationNumber,
      ),
      'renewalRequired': renewalRequired,
      'annuityRequired': annuityRequired,
      'oppositionActive': oppositionActive,
      'disputeActive': disputeActive,
      'customsProtectionActive': customsProtectionActive,
      'monitoringEnabled': monitoringEnabled,
      'rightStrengthScore': _score(rightStrengthScore),
      'notes': IpModelUtils.cleanNullable(notes),
      'metadata': Map<String, dynamic>.from(metadata),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': IpModelUtils.timestampOrNull(updatedAt),
      'updatedBy': IpModelUtils.cleanNullable(updatedBy),
    };
  }

  Map<String, dynamic> toCreateMap() {
    final map = toMap();

    map['createdAt'] = FieldValue.serverTimestamp();
    map['updatedAt'] = FieldValue.serverTimestamp();

    return map;
  }

  Map<String, dynamic> toUpdateMap({required String actorId}) {
    final map = toMap();

    map.remove('tenantId');
    map.remove('brandId');
    map.remove('assetId');
    map.remove('createdAt');
    map.remove('createdBy');

    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = actorId.trim();

    return map;
  }

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        brandId.trim().isNotEmpty &&
        assetId.trim().isNotEmpty &&
        rightCode.trim().isNotEmpty &&
        title.trim().isNotEmpty;
  }

  bool get isRegisteredOrGranted {
    return status == IpRightStatus.registered ||
        status == IpRightStatus.granted;
  }

  bool get hasInternationalRoute {
    return pctApplicationNumber != null ||
        madridRegistrationNumber != null ||
        hagueRegistrationNumber != null ||
        europeanApplicationNumber != null;
  }

  bool get hasActiveLegalChallenge {
    return oppositionActive ||
        disputeActive ||
        status == IpRightStatus.opposed ||
        status == IpRightStatus.disputed;
  }

  bool get isExpired {
    if (status == IpRightStatus.expired) {
      return true;
    }

    final value = expiryAt;

    return value != null && value.isBefore(DateTime.now());
  }

  bool get hasUpcomingDeadline {
    final now = DateTime.now();
    final threshold = now.add(const Duration(days: 90));

    final deadlines = <DateTime?>[
      nextRenewalAt,
      oppositionDeadlineAt,
      annuityDeadlineAt,
      expiryAt,
    ];

    return deadlines.whereType<DateTime>().any(
      (date) => date.isAfter(now) && date.isBefore(threshold),
    );
  }

  bool get hasProtectionGap {
    return rightStrengthScore < 60 ||
        isExpired ||
        riskLevel == IpRiskLevel.high ||
        riskLevel == IpRiskLevel.critical;
  }

  static int _score(int value) {
    if (value < 0) {
      return 0;
    }

    if (value > 100) {
      return 100;
    }

    return value;
  }

  static String? _countryCode(String? value) {
    return IpModelUtils.cleanNullable(value)?.toUpperCase();
  }
}
