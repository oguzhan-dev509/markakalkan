import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../utils/ip_model_utils.dart';

class IpDocumentModel {
  const IpDocumentModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.documentCode,
    required this.title,
    required this.documentType,
    required this.status,
    required this.confidentialityLevel,
    required this.accessLevel,
    required this.integrityStatus,
    required this.riskLevel,
    required this.createdAt,
    required this.createdBy,
    this.description,
    this.primaryAssetId,
    this.primaryRightId,
    this.relatedAssetIds = const <String>[],
    this.relatedRightIds = const <String>[],
    this.relationshipIds = const <String>[],
    this.caseIds = const <String>[],
    this.authorizedUserIds = const <String>[],
    this.authorizedRoleIds = const <String>[],
    this.tags = const <String>[],
    this.fileName,
    this.originalFileName,
    this.storagePath,
    this.downloadUrl,
    this.mimeType,
    this.fileExtension,
    this.fileSizeBytes = 0,
    this.sha256Hash,
    this.hashAlgorithm = 'SHA-256',
    this.versionNumber = 1,
    this.parentDocumentId,
    this.previousVersionId,
    this.supersedingDocumentId,
    this.issuerName,
    this.issuerCountryCode,
    this.referenceNumber,
    this.languageCode,
    this.issueAt,
    this.validFromAt,
    this.expiryAt,
    this.signedAt,
    this.timestampedAt,
    this.notarizedAt,
    this.verifiedAt,
    this.retentionUntilAt,
    this.lastAccessedAt,
    this.isElectronicallySigned = false,
    this.isTimestamped = false,
    this.isNotarized = false,
    this.isEncrypted = false,
    this.isLocked = false,
    this.downloadAllowed = true,
    this.exportAllowed = true,
    this.requiresDualApproval = false,
    this.legalHoldActive = false,
    this.watermarkRequired = false,
    this.verifiedBy,
    this.encryptionKeyReference,
    this.timestampAuthority,
    this.signatureProvider,
    this.retentionPolicyCode,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;

  final String documentCode;
  final String title;
  final String? description;

  final IpDocumentType documentType;
  final IpDocumentStatus status;
  final IpConfidentialityLevel confidentialityLevel;
  final IpAccessLevel accessLevel;
  final IpEvidenceIntegrityStatus integrityStatus;
  final IpRiskLevel riskLevel;

  final String? primaryAssetId;
  final String? primaryRightId;

  final List<String> relatedAssetIds;
  final List<String> relatedRightIds;
  final List<String> relationshipIds;
  final List<String> caseIds;
  final List<String> authorizedUserIds;
  final List<String> authorizedRoleIds;
  final List<String> tags;

  final String? fileName;
  final String? originalFileName;
  final String? storagePath;
  final String? downloadUrl;
  final String? mimeType;
  final String? fileExtension;
  final int fileSizeBytes;

  final String? sha256Hash;
  final String hashAlgorithm;

  final int versionNumber;
  final String? parentDocumentId;
  final String? previousVersionId;
  final String? supersedingDocumentId;

  final String? issuerName;
  final String? issuerCountryCode;
  final String? referenceNumber;
  final String? languageCode;

  final DateTime? issueAt;
  final DateTime? validFromAt;
  final DateTime? expiryAt;
  final DateTime? signedAt;
  final DateTime? timestampedAt;
  final DateTime? notarizedAt;
  final DateTime? verifiedAt;
  final DateTime? retentionUntilAt;
  final DateTime? lastAccessedAt;

  final bool isElectronicallySigned;
  final bool isTimestamped;
  final bool isNotarized;
  final bool isEncrypted;
  final bool isLocked;
  final bool downloadAllowed;
  final bool exportAllowed;
  final bool requiresDualApproval;
  final bool legalHoldActive;
  final bool watermarkRequired;

  final String? verifiedBy;
  final String? encryptionKeyReference;
  final String? timestampAuthority;
  final String? signatureProvider;
  final String? retentionPolicyCode;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpDocumentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Fikri mülkiyet belgesi veri içermiyor: ${document.id}');
    }

    return IpDocumentModel.fromMap(id: document.id, data: data);
  }

  factory IpDocumentModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Fikri mülkiyet belgesi oluşturma tarihi eksik: $id');
    }

    return IpDocumentModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      documentCode: IpModelUtils.requiredString(data['documentCode']),
      title: IpModelUtils.requiredString(data['title']),
      description: IpModelUtils.nullableString(data['description']),
      documentType: IpDocumentType.fromValue(data['documentType']?.toString()),
      status: IpDocumentStatus.fromValue(data['status']?.toString()),
      confidentialityLevel: IpConfidentialityLevel.fromValue(
        data['confidentialityLevel']?.toString(),
      ),
      accessLevel: IpAccessLevel.fromValue(data['accessLevel']?.toString()),
      integrityStatus: IpEvidenceIntegrityStatus.fromValue(
        data['integrityStatus']?.toString(),
      ),
      riskLevel: IpRiskLevel.fromValue(data['riskLevel']?.toString()),
      primaryAssetId: IpModelUtils.nullableString(data['primaryAssetId']),
      primaryRightId: IpModelUtils.nullableString(data['primaryRightId']),
      relatedAssetIds: IpModelUtils.stringListFromValue(
        data['relatedAssetIds'],
      ),
      relatedRightIds: IpModelUtils.stringListFromValue(
        data['relatedRightIds'],
      ),
      relationshipIds: IpModelUtils.stringListFromValue(
        data['relationshipIds'],
      ),
      caseIds: IpModelUtils.stringListFromValue(data['caseIds']),
      authorizedUserIds: IpModelUtils.stringListFromValue(
        data['authorizedUserIds'],
      ),
      authorizedRoleIds: IpModelUtils.stringListFromValue(
        data['authorizedRoleIds'],
      ),
      tags: IpModelUtils.stringListFromValue(data['tags']),
      fileName: IpModelUtils.nullableString(data['fileName']),
      originalFileName: IpModelUtils.nullableString(data['originalFileName']),
      storagePath: IpModelUtils.nullableString(data['storagePath']),
      downloadUrl: IpModelUtils.nullableString(data['downloadUrl']),
      mimeType: IpModelUtils.nullableString(data['mimeType']),
      fileExtension: IpModelUtils.nullableString(data['fileExtension']),
      fileSizeBytes: _nonNegativeInt(data['fileSizeBytes']),
      sha256Hash: IpModelUtils.nullableString(data['sha256Hash']),
      hashAlgorithm:
          IpModelUtils.nullableString(data['hashAlgorithm']) ?? 'SHA-256',
      versionNumber: _positiveVersion(data['versionNumber']),
      parentDocumentId: IpModelUtils.nullableString(data['parentDocumentId']),
      previousVersionId: IpModelUtils.nullableString(data['previousVersionId']),
      supersedingDocumentId: IpModelUtils.nullableString(
        data['supersedingDocumentId'],
      ),
      issuerName: IpModelUtils.nullableString(data['issuerName']),
      issuerCountryCode: IpModelUtils.nullableString(data['issuerCountryCode']),
      referenceNumber: IpModelUtils.nullableString(data['referenceNumber']),
      languageCode: IpModelUtils.nullableString(data['languageCode']),
      issueAt: IpModelUtils.dateTimeFromValue(data['issueAt']),
      validFromAt: IpModelUtils.dateTimeFromValue(data['validFromAt']),
      expiryAt: IpModelUtils.dateTimeFromValue(data['expiryAt']),
      signedAt: IpModelUtils.dateTimeFromValue(data['signedAt']),
      timestampedAt: IpModelUtils.dateTimeFromValue(data['timestampedAt']),
      notarizedAt: IpModelUtils.dateTimeFromValue(data['notarizedAt']),
      verifiedAt: IpModelUtils.dateTimeFromValue(data['verifiedAt']),
      retentionUntilAt: IpModelUtils.dateTimeFromValue(
        data['retentionUntilAt'],
      ),
      lastAccessedAt: IpModelUtils.dateTimeFromValue(data['lastAccessedAt']),
      isElectronicallySigned: IpModelUtils.boolFromValue(
        data['isElectronicallySigned'],
      ),
      isTimestamped: IpModelUtils.boolFromValue(data['isTimestamped']),
      isNotarized: IpModelUtils.boolFromValue(data['isNotarized']),
      isEncrypted: IpModelUtils.boolFromValue(data['isEncrypted']),
      isLocked: IpModelUtils.boolFromValue(data['isLocked']),
      downloadAllowed: IpModelUtils.boolFromValue(
        data['downloadAllowed'],
        fallback: true,
      ),
      exportAllowed: IpModelUtils.boolFromValue(
        data['exportAllowed'],
        fallback: true,
      ),
      requiresDualApproval: IpModelUtils.boolFromValue(
        data['requiresDualApproval'],
      ),
      legalHoldActive: IpModelUtils.boolFromValue(data['legalHoldActive']),
      watermarkRequired: IpModelUtils.boolFromValue(data['watermarkRequired']),
      verifiedBy: IpModelUtils.nullableString(data['verifiedBy']),
      encryptionKeyReference: IpModelUtils.nullableString(
        data['encryptionKeyReference'],
      ),
      timestampAuthority: IpModelUtils.nullableString(
        data['timestampAuthority'],
      ),
      signatureProvider: IpModelUtils.nullableString(data['signatureProvider']),
      retentionPolicyCode: IpModelUtils.nullableString(
        data['retentionPolicyCode'],
      ),
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
      'documentCode': documentCode.trim(),
      'title': title.trim(),
      'description': IpModelUtils.cleanNullable(description),
      'documentType': documentType.value,
      'status': status.value,
      'confidentialityLevel': confidentialityLevel.value,
      'accessLevel': accessLevel.value,
      'integrityStatus': integrityStatus.value,
      'riskLevel': riskLevel.value,
      'primaryAssetId': IpModelUtils.cleanNullable(primaryAssetId),
      'primaryRightId': IpModelUtils.cleanNullable(primaryRightId),
      'relatedAssetIds': IpModelUtils.cleanStringList(relatedAssetIds),
      'relatedRightIds': IpModelUtils.cleanStringList(relatedRightIds),
      'relationshipIds': IpModelUtils.cleanStringList(relationshipIds),
      'caseIds': IpModelUtils.cleanStringList(caseIds),
      'authorizedUserIds': IpModelUtils.cleanStringList(authorizedUserIds),
      'authorizedRoleIds': IpModelUtils.cleanStringList(authorizedRoleIds),
      'tags': IpModelUtils.cleanStringList(tags),
      'fileName': IpModelUtils.cleanNullable(fileName),
      'originalFileName': IpModelUtils.cleanNullable(originalFileName),
      'storagePath': IpModelUtils.cleanNullable(storagePath),
      'downloadUrl': IpModelUtils.cleanNullable(downloadUrl),
      'mimeType': IpModelUtils.cleanNullable(mimeType),
      'fileExtension': IpModelUtils.cleanNullable(fileExtension)?.toLowerCase(),
      'fileSizeBytes': fileSizeBytes < 0 ? 0 : fileSizeBytes,
      'sha256Hash': IpModelUtils.cleanNullable(sha256Hash),
      'hashAlgorithm': IpModelUtils.cleanNullable(hashAlgorithm) ?? 'SHA-256',
      'versionNumber': versionNumber < 1 ? 1 : versionNumber,
      'parentDocumentId': IpModelUtils.cleanNullable(parentDocumentId),
      'previousVersionId': IpModelUtils.cleanNullable(previousVersionId),
      'supersedingDocumentId': IpModelUtils.cleanNullable(
        supersedingDocumentId,
      ),
      'issuerName': IpModelUtils.cleanNullable(issuerName),
      'issuerCountryCode': _countryCode(issuerCountryCode),
      'referenceNumber': IpModelUtils.cleanNullable(referenceNumber),
      'languageCode': IpModelUtils.cleanNullable(languageCode)?.toLowerCase(),
      'issueAt': IpModelUtils.timestampOrNull(issueAt),
      'validFromAt': IpModelUtils.timestampOrNull(validFromAt),
      'expiryAt': IpModelUtils.timestampOrNull(expiryAt),
      'signedAt': IpModelUtils.timestampOrNull(signedAt),
      'timestampedAt': IpModelUtils.timestampOrNull(timestampedAt),
      'notarizedAt': IpModelUtils.timestampOrNull(notarizedAt),
      'verifiedAt': IpModelUtils.timestampOrNull(verifiedAt),
      'retentionUntilAt': IpModelUtils.timestampOrNull(retentionUntilAt),
      'lastAccessedAt': IpModelUtils.timestampOrNull(lastAccessedAt),
      'isElectronicallySigned': isElectronicallySigned,
      'isTimestamped': isTimestamped,
      'isNotarized': isNotarized,
      'isEncrypted': isEncrypted,
      'isLocked': isLocked,
      'downloadAllowed': downloadAllowed,
      'exportAllowed': exportAllowed,
      'requiresDualApproval': requiresDualApproval,
      'legalHoldActive': legalHoldActive,
      'watermarkRequired': watermarkRequired,
      'verifiedBy': IpModelUtils.cleanNullable(verifiedBy),
      'encryptionKeyReference': IpModelUtils.cleanNullable(
        encryptionKeyReference,
      ),
      'timestampAuthority': IpModelUtils.cleanNullable(timestampAuthority),
      'signatureProvider': IpModelUtils.cleanNullable(signatureProvider),
      'retentionPolicyCode': IpModelUtils.cleanNullable(retentionPolicyCode),
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
        documentCode.trim().isNotEmpty &&
        title.trim().isNotEmpty;
  }

  bool get hasFileReference {
    return (storagePath != null && storagePath!.trim().isNotEmpty) ||
        (downloadUrl != null && downloadUrl!.trim().isNotEmpty);
  }

  bool get hasCryptographicFingerprint {
    return sha256Hash != null && sha256Hash!.trim().isNotEmpty;
  }

  bool get isExpired {
    if (status == IpDocumentStatus.expired) {
      return true;
    }

    final value = expiryAt;

    return value != null && value.isBefore(DateTime.now());
  }

  bool get requiresRestrictedHandling {
    return confidentialityLevel == IpConfidentialityLevel.tradeSecret ||
        confidentialityLevel == IpConfidentialityLevel.highlyConfidential ||
        confidentialityLevel == IpConfidentialityLevel.restricted ||
        requiresDualApproval ||
        isLocked;
  }

  bool get isEvidenceReady {
    final integrityReady =
        integrityStatus == IpEvidenceIntegrityStatus.fingerprinted ||
        integrityStatus == IpEvidenceIntegrityStatus.timestamped ||
        integrityStatus == IpEvidenceIntegrityStatus.signed ||
        integrityStatus == IpEvidenceIntegrityStatus.verified;

    return hasFileReference &&
        hasCryptographicFingerprint &&
        integrityReady &&
        status != IpDocumentStatus.quarantined;
  }

  bool get hasIntegrityConcern {
    return integrityStatus == IpEvidenceIntegrityStatus.compromised ||
        status == IpDocumentStatus.quarantined;
  }

  bool get retentionDeadlinePassed {
    final value = retentionUntilAt;

    return value != null && value.isBefore(DateTime.now()) && !legalHoldActive;
  }

  static int _positiveVersion(dynamic value) {
    final parsed = IpModelUtils.intFromValue(value, fallback: 1);

    return parsed < 1 ? 1 : parsed;
  }

  static int _nonNegativeInt(dynamic value) {
    final parsed = IpModelUtils.intFromValue(value);

    return parsed < 0 ? 0 : parsed;
  }

  static String? _countryCode(String? value) {
    return IpModelUtils.cleanNullable(value)?.toUpperCase();
  }
}
