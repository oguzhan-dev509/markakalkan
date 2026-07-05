import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../utils/ip_model_utils.dart';

class IpRelationshipModel {
  const IpRelationshipModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.relationshipCode,
    required this.subjectName,
    required this.relationshipType,
    required this.status,
    required this.accessLevel,
    required this.riskLevel,
    required this.createdAt,
    required this.createdBy,
    this.subjectId,
    this.subjectType,
    this.organizationName,
    this.taxOrRegistrationNumber,
    this.countryCode,
    this.city,
    this.email,
    this.phone,
    this.contactPersonName,
    this.relatedAssetIds = const <String>[],
    this.relatedRightIds = const <String>[],
    this.relatedDocumentIds = const <String>[],
    this.relatedProductIds = const <String>[],
    this.relatedCaseIds = const <String>[],
    this.grantedPermissionCodes = const <String>[],
    this.restrictedActionCodes = const <String>[],
    this.allowedChannelCodes = const <String>[],
    this.accessStartedAt,
    this.accessEndsAt,
    this.relationshipStartedAt,
    this.relationshipEndedAt,
    this.lastReviewedAt,
    this.lastAccessAt,
    this.ndaSignedAt,
    this.ndaExpiresAt,
    this.dataDeletionDueAt,
    this.accessRevokedAt,
    this.hasNda = false,
    this.hasIpAssignment = false,
    this.hasConfidentialityClause = false,
    this.hasDataDeletionObligation = false,
    this.subcontractingAllowed = false,
    this.downloadAllowed = false,
    this.exportAllowed = false,
    this.remoteAccessAllowed = false,
    this.personalDeviceAllowed = false,
    this.accessRevoked = false,
    this.competitorRelationshipKnown = false,
    this.incidentHistoryExists = false,
    this.requiresDualApproval = false,
    this.riskScore = 0,
    this.trustScore = 0,
    this.riskReason,
    this.accessPurpose,
    this.dataLocation,
    this.storageProvider,
    this.contractNumber,
    this.primaryAgreementDocumentId,
    this.ndaDocumentId,
    this.assignmentDocumentId,
    this.terminationDocumentId,
    this.revokedBy,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;

  final String relationshipCode;
  final String subjectName;
  final String? subjectId;
  final String? subjectType;
  final String? organizationName;
  final String? taxOrRegistrationNumber;

  final IpRelationshipType relationshipType;
  final IpRelationshipStatus status;
  final IpAccessLevel accessLevel;
  final IpRiskLevel riskLevel;

  final String? countryCode;
  final String? city;
  final String? email;
  final String? phone;
  final String? contactPersonName;

  final List<String> relatedAssetIds;
  final List<String> relatedRightIds;
  final List<String> relatedDocumentIds;
  final List<String> relatedProductIds;
  final List<String> relatedCaseIds;

  final List<String> grantedPermissionCodes;
  final List<String> restrictedActionCodes;
  final List<String> allowedChannelCodes;

  final DateTime? accessStartedAt;
  final DateTime? accessEndsAt;
  final DateTime? relationshipStartedAt;
  final DateTime? relationshipEndedAt;
  final DateTime? lastReviewedAt;
  final DateTime? lastAccessAt;
  final DateTime? ndaSignedAt;
  final DateTime? ndaExpiresAt;
  final DateTime? dataDeletionDueAt;
  final DateTime? accessRevokedAt;

  final bool hasNda;
  final bool hasIpAssignment;
  final bool hasConfidentialityClause;
  final bool hasDataDeletionObligation;
  final bool subcontractingAllowed;
  final bool downloadAllowed;
  final bool exportAllowed;
  final bool remoteAccessAllowed;
  final bool personalDeviceAllowed;
  final bool accessRevoked;
  final bool competitorRelationshipKnown;
  final bool incidentHistoryExists;
  final bool requiresDualApproval;

  final int riskScore;
  final int trustScore;

  final String? riskReason;
  final String? accessPurpose;
  final String? dataLocation;
  final String? storageProvider;
  final String? contractNumber;

  final String? primaryAgreementDocumentId;
  final String? ndaDocumentId;
  final String? assignmentDocumentId;
  final String? terminationDocumentId;
  final String? revokedBy;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpRelationshipModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Fikri mülkiyet ilişki belgesi veri içermiyor: ${document.id}',
      );
    }

    return IpRelationshipModel.fromMap(id: document.id, data: data);
  }

  factory IpRelationshipModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError(
        'Fikri mülkiyet ilişki kaydı oluşturma tarihi eksik: $id',
      );
    }

    return IpRelationshipModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      relationshipCode: IpModelUtils.requiredString(data['relationshipCode']),
      subjectName: IpModelUtils.requiredString(data['subjectName']),
      subjectId: IpModelUtils.nullableString(data['subjectId']),
      subjectType: IpModelUtils.nullableString(data['subjectType']),
      organizationName: IpModelUtils.nullableString(data['organizationName']),
      taxOrRegistrationNumber: IpModelUtils.nullableString(
        data['taxOrRegistrationNumber'],
      ),
      relationshipType: IpRelationshipType.fromValue(
        data['relationshipType']?.toString(),
      ),
      status: IpRelationshipStatus.fromValue(data['status']?.toString()),
      accessLevel: IpAccessLevel.fromValue(data['accessLevel']?.toString()),
      riskLevel: IpRiskLevel.fromValue(data['riskLevel']?.toString()),
      countryCode: IpModelUtils.nullableString(data['countryCode']),
      city: IpModelUtils.nullableString(data['city']),
      email: IpModelUtils.nullableString(data['email']),
      phone: IpModelUtils.nullableString(data['phone']),
      contactPersonName: IpModelUtils.nullableString(data['contactPersonName']),
      relatedAssetIds: IpModelUtils.stringListFromValue(
        data['relatedAssetIds'],
      ),
      relatedRightIds: IpModelUtils.stringListFromValue(
        data['relatedRightIds'],
      ),
      relatedDocumentIds: IpModelUtils.stringListFromValue(
        data['relatedDocumentIds'],
      ),
      relatedProductIds: IpModelUtils.stringListFromValue(
        data['relatedProductIds'],
      ),
      relatedCaseIds: IpModelUtils.stringListFromValue(data['relatedCaseIds']),
      grantedPermissionCodes: IpModelUtils.stringListFromValue(
        data['grantedPermissionCodes'],
      ),
      restrictedActionCodes: IpModelUtils.stringListFromValue(
        data['restrictedActionCodes'],
      ),
      allowedChannelCodes: IpModelUtils.stringListFromValue(
        data['allowedChannelCodes'],
      ),
      accessStartedAt: IpModelUtils.dateTimeFromValue(data['accessStartedAt']),
      accessEndsAt: IpModelUtils.dateTimeFromValue(data['accessEndsAt']),
      relationshipStartedAt: IpModelUtils.dateTimeFromValue(
        data['relationshipStartedAt'],
      ),
      relationshipEndedAt: IpModelUtils.dateTimeFromValue(
        data['relationshipEndedAt'],
      ),
      lastReviewedAt: IpModelUtils.dateTimeFromValue(data['lastReviewedAt']),
      lastAccessAt: IpModelUtils.dateTimeFromValue(data['lastAccessAt']),
      ndaSignedAt: IpModelUtils.dateTimeFromValue(data['ndaSignedAt']),
      ndaExpiresAt: IpModelUtils.dateTimeFromValue(data['ndaExpiresAt']),
      dataDeletionDueAt: IpModelUtils.dateTimeFromValue(
        data['dataDeletionDueAt'],
      ),
      accessRevokedAt: IpModelUtils.dateTimeFromValue(data['accessRevokedAt']),
      hasNda: IpModelUtils.boolFromValue(data['hasNda']),
      hasIpAssignment: IpModelUtils.boolFromValue(data['hasIpAssignment']),
      hasConfidentialityClause: IpModelUtils.boolFromValue(
        data['hasConfidentialityClause'],
      ),
      hasDataDeletionObligation: IpModelUtils.boolFromValue(
        data['hasDataDeletionObligation'],
      ),
      subcontractingAllowed: IpModelUtils.boolFromValue(
        data['subcontractingAllowed'],
      ),
      downloadAllowed: IpModelUtils.boolFromValue(data['downloadAllowed']),
      exportAllowed: IpModelUtils.boolFromValue(data['exportAllowed']),
      remoteAccessAllowed: IpModelUtils.boolFromValue(
        data['remoteAccessAllowed'],
      ),
      personalDeviceAllowed: IpModelUtils.boolFromValue(
        data['personalDeviceAllowed'],
      ),
      accessRevoked: IpModelUtils.boolFromValue(data['accessRevoked']),
      competitorRelationshipKnown: IpModelUtils.boolFromValue(
        data['competitorRelationshipKnown'],
      ),
      incidentHistoryExists: IpModelUtils.boolFromValue(
        data['incidentHistoryExists'],
      ),
      requiresDualApproval: IpModelUtils.boolFromValue(
        data['requiresDualApproval'],
      ),
      riskScore: IpModelUtils.boundedScore(data['riskScore']),
      trustScore: IpModelUtils.boundedScore(data['trustScore']),
      riskReason: IpModelUtils.nullableString(data['riskReason']),
      accessPurpose: IpModelUtils.nullableString(data['accessPurpose']),
      dataLocation: IpModelUtils.nullableString(data['dataLocation']),
      storageProvider: IpModelUtils.nullableString(data['storageProvider']),
      contractNumber: IpModelUtils.nullableString(data['contractNumber']),
      primaryAgreementDocumentId: IpModelUtils.nullableString(
        data['primaryAgreementDocumentId'],
      ),
      ndaDocumentId: IpModelUtils.nullableString(data['ndaDocumentId']),
      assignmentDocumentId: IpModelUtils.nullableString(
        data['assignmentDocumentId'],
      ),
      terminationDocumentId: IpModelUtils.nullableString(
        data['terminationDocumentId'],
      ),
      revokedBy: IpModelUtils.nullableString(data['revokedBy']),
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
      'relationshipCode': relationshipCode.trim(),
      'subjectName': subjectName.trim(),
      'subjectId': IpModelUtils.cleanNullable(subjectId),
      'subjectType': IpModelUtils.cleanNullable(subjectType),
      'organizationName': IpModelUtils.cleanNullable(organizationName),
      'taxOrRegistrationNumber': IpModelUtils.cleanNullable(
        taxOrRegistrationNumber,
      ),
      'relationshipType': relationshipType.value,
      'status': status.value,
      'accessLevel': accessLevel.value,
      'riskLevel': riskLevel.value,
      'countryCode': _countryCode(countryCode),
      'city': IpModelUtils.cleanNullable(city),
      'email': IpModelUtils.cleanNullable(email)?.toLowerCase(),
      'phone': IpModelUtils.cleanNullable(phone),
      'contactPersonName': IpModelUtils.cleanNullable(contactPersonName),
      'relatedAssetIds': IpModelUtils.cleanStringList(relatedAssetIds),
      'relatedRightIds': IpModelUtils.cleanStringList(relatedRightIds),
      'relatedDocumentIds': IpModelUtils.cleanStringList(relatedDocumentIds),
      'relatedProductIds': IpModelUtils.cleanStringList(relatedProductIds),
      'relatedCaseIds': IpModelUtils.cleanStringList(relatedCaseIds),
      'grantedPermissionCodes': IpModelUtils.cleanStringList(
        grantedPermissionCodes,
      ),
      'restrictedActionCodes': IpModelUtils.cleanStringList(
        restrictedActionCodes,
      ),
      'allowedChannelCodes': IpModelUtils.cleanStringList(allowedChannelCodes),
      'accessStartedAt': IpModelUtils.timestampOrNull(accessStartedAt),
      'accessEndsAt': IpModelUtils.timestampOrNull(accessEndsAt),
      'relationshipStartedAt': IpModelUtils.timestampOrNull(
        relationshipStartedAt,
      ),
      'relationshipEndedAt': IpModelUtils.timestampOrNull(relationshipEndedAt),
      'lastReviewedAt': IpModelUtils.timestampOrNull(lastReviewedAt),
      'lastAccessAt': IpModelUtils.timestampOrNull(lastAccessAt),
      'ndaSignedAt': IpModelUtils.timestampOrNull(ndaSignedAt),
      'ndaExpiresAt': IpModelUtils.timestampOrNull(ndaExpiresAt),
      'dataDeletionDueAt': IpModelUtils.timestampOrNull(dataDeletionDueAt),
      'accessRevokedAt': IpModelUtils.timestampOrNull(accessRevokedAt),
      'hasNda': hasNda,
      'hasIpAssignment': hasIpAssignment,
      'hasConfidentialityClause': hasConfidentialityClause,
      'hasDataDeletionObligation': hasDataDeletionObligation,
      'subcontractingAllowed': subcontractingAllowed,
      'downloadAllowed': downloadAllowed,
      'exportAllowed': exportAllowed,
      'remoteAccessAllowed': remoteAccessAllowed,
      'personalDeviceAllowed': personalDeviceAllowed,
      'accessRevoked': accessRevoked,
      'competitorRelationshipKnown': competitorRelationshipKnown,
      'incidentHistoryExists': incidentHistoryExists,
      'requiresDualApproval': requiresDualApproval,
      'riskScore': _score(riskScore),
      'trustScore': _score(trustScore),
      'riskReason': IpModelUtils.cleanNullable(riskReason),
      'accessPurpose': IpModelUtils.cleanNullable(accessPurpose),
      'dataLocation': IpModelUtils.cleanNullable(dataLocation),
      'storageProvider': IpModelUtils.cleanNullable(storageProvider),
      'contractNumber': IpModelUtils.cleanNullable(contractNumber),
      'primaryAgreementDocumentId': IpModelUtils.cleanNullable(
        primaryAgreementDocumentId,
      ),
      'ndaDocumentId': IpModelUtils.cleanNullable(ndaDocumentId),
      'assignmentDocumentId': IpModelUtils.cleanNullable(assignmentDocumentId),
      'terminationDocumentId': IpModelUtils.cleanNullable(
        terminationDocumentId,
      ),
      'revokedBy': IpModelUtils.cleanNullable(revokedBy),
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
    map.remove('createdAt');
    map.remove('createdBy');

    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = actorId.trim();

    return map;
  }

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        brandId.trim().isNotEmpty &&
        relationshipCode.trim().isNotEmpty &&
        subjectName.trim().isNotEmpty;
  }

  bool get hasActiveAccess {
    if (accessRevoked || accessLevel == IpAccessLevel.none) {
      return false;
    }

    final now = DateTime.now();

    if (accessStartedAt != null && accessStartedAt!.isAfter(now)) {
      return false;
    }

    if (accessEndsAt != null && accessEndsAt!.isBefore(now)) {
      return false;
    }

    return status == IpRelationshipStatus.active ||
        status == IpRelationshipStatus.highRisk;
  }

  bool get ndaMissingOrExpired {
    if (!hasNda) {
      return true;
    }

    final expiry = ndaExpiresAt;

    return expiry != null && expiry.isBefore(DateTime.now());
  }

  bool get dataDeletionOverdue {
    final dueAt = dataDeletionDueAt;

    return hasDataDeletionObligation &&
        dueAt != null &&
        dueAt.isBefore(DateTime.now()) &&
        !accessRevoked;
  }

  bool get isHighRiskRelationship {
    return status == IpRelationshipStatus.highRisk ||
        riskLevel == IpRiskLevel.high ||
        riskLevel == IpRiskLevel.critical ||
        riskScore >= 70 ||
        incidentHistoryExists ||
        competitorRelationshipKnown;
  }

  bool get hasExcessiveAccess {
    return accessLevel == IpAccessLevel.download ||
        accessLevel == IpAccessLevel.export ||
        accessLevel == IpAccessLevel.administrator ||
        downloadAllowed ||
        exportAllowed;
  }

  bool get requiresImmediateReview {
    return isHighRiskRelationship &&
        (hasActiveAccess || ndaMissingOrExpired || hasExcessiveAccess);
  }

  bool get hasContractualProtection {
    return hasNda ||
        hasIpAssignment ||
        hasConfidentialityClause ||
        primaryAgreementDocumentId != null;
  }

  bool get isFormerInternalActor {
    return relationshipType == IpRelationshipType.formerEmployee;
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
