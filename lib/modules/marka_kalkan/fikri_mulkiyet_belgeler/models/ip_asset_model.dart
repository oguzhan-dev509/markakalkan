import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../utils/ip_model_utils.dart';

class IpAssetModel {
  const IpAssetModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.assetCode,
    required this.title,
    required this.assetType,
    required this.status,
    required this.confidentialityLevel,
    required this.riskLevel,
    required this.createdAt,
    required this.createdBy,
    this.description,
    this.sector,
    this.category,
    this.subcategory,
    this.primaryOwnerName,
    this.primaryOwnerId,
    this.parentAssetId,
    this.originCountryCode,
    this.currentVersion = 1,
    this.tags = const <String>[],
    this.productIds = const <String>[],
    this.rightIds = const <String>[],
    this.documentIds = const <String>[],
    this.relationshipIds = const <String>[],
    this.monitoringProfileIds = const <String>[],
    this.targetCountryCodes = const <String>[],
    this.firstCreatedAt,
    this.firstPublicationAt,
    this.firstCommercialUseAt,
    this.lastEvidenceAt,
    this.lastRiskAssessmentAt,
    this.rightStrengthScore = 0,
    this.secretSecurityScore = 0,
    this.responseReadinessScore = 0,
    this.resilienceScore = 0,
    this.containsTradeSecret = false,
    this.requiresDualApproval = false,
    this.monitoringEnabled = false,
    this.evidenceIntegrityStatus = IpEvidenceIntegrityStatus.notAssessed,
    this.fingerprint,
    this.fingerprintAlgorithm,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;

  final String assetCode;
  final String title;
  final String? description;

  final IpAssetType assetType;
  final IpAssetStatus status;
  final IpConfidentialityLevel confidentialityLevel;
  final IpRiskLevel riskLevel;

  final String? sector;
  final String? category;
  final String? subcategory;

  final String? primaryOwnerName;
  final String? primaryOwnerId;
  final String? parentAssetId;
  final String? originCountryCode;

  final int currentVersion;

  final List<String> tags;
  final List<String> productIds;
  final List<String> rightIds;
  final List<String> documentIds;
  final List<String> relationshipIds;
  final List<String> monitoringProfileIds;
  final List<String> targetCountryCodes;

  final DateTime? firstCreatedAt;
  final DateTime? firstPublicationAt;
  final DateTime? firstCommercialUseAt;
  final DateTime? lastEvidenceAt;
  final DateTime? lastRiskAssessmentAt;

  final int rightStrengthScore;
  final int secretSecurityScore;
  final int responseReadinessScore;
  final int resilienceScore;

  final bool containsTradeSecret;
  final bool requiresDualApproval;
  final bool monitoringEnabled;

  final IpEvidenceIntegrityStatus evidenceIntegrityStatus;

  final String? fingerprint;
  final String? fingerprintAlgorithm;
  final String? notes;

  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpAssetModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Fikri mülkiyet varlığı belgesi veri içermiyor: ${document.id}',
      );
    }

    return IpAssetModel.fromMap(id: document.id, data: data);
  }

  factory IpAssetModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Fikri mülkiyet varlığı oluşturma tarihi eksik: $id');
    }

    return IpAssetModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      assetCode: IpModelUtils.requiredString(data['assetCode']),
      title: IpModelUtils.requiredString(data['title']),
      description: IpModelUtils.nullableString(data['description']),
      assetType: IpAssetType.fromValue(data['assetType']?.toString()),
      status: IpAssetStatus.fromValue(data['status']?.toString()),
      confidentialityLevel: IpConfidentialityLevel.fromValue(
        data['confidentialityLevel']?.toString(),
      ),
      riskLevel: IpRiskLevel.fromValue(data['riskLevel']?.toString()),
      sector: IpModelUtils.nullableString(data['sector']),
      category: IpModelUtils.nullableString(data['category']),
      subcategory: IpModelUtils.nullableString(data['subcategory']),
      primaryOwnerName: IpModelUtils.nullableString(data['primaryOwnerName']),
      primaryOwnerId: IpModelUtils.nullableString(data['primaryOwnerId']),
      parentAssetId: IpModelUtils.nullableString(data['parentAssetId']),
      originCountryCode: IpModelUtils.nullableString(data['originCountryCode']),
      currentVersion: _positiveVersion(data['currentVersion']),
      tags: IpModelUtils.stringListFromValue(data['tags']),
      productIds: IpModelUtils.stringListFromValue(data['productIds']),
      rightIds: IpModelUtils.stringListFromValue(data['rightIds']),
      documentIds: IpModelUtils.stringListFromValue(data['documentIds']),
      relationshipIds: IpModelUtils.stringListFromValue(
        data['relationshipIds'],
      ),
      monitoringProfileIds: IpModelUtils.stringListFromValue(
        data['monitoringProfileIds'],
      ),
      targetCountryCodes: IpModelUtils.stringListFromValue(
        data['targetCountryCodes'],
      ),
      firstCreatedAt: IpModelUtils.dateTimeFromValue(data['firstCreatedAt']),
      firstPublicationAt: IpModelUtils.dateTimeFromValue(
        data['firstPublicationAt'],
      ),
      firstCommercialUseAt: IpModelUtils.dateTimeFromValue(
        data['firstCommercialUseAt'],
      ),
      lastEvidenceAt: IpModelUtils.dateTimeFromValue(data['lastEvidenceAt']),
      lastRiskAssessmentAt: IpModelUtils.dateTimeFromValue(
        data['lastRiskAssessmentAt'],
      ),
      rightStrengthScore: IpModelUtils.boundedScore(data['rightStrengthScore']),
      secretSecurityScore: IpModelUtils.boundedScore(
        data['secretSecurityScore'],
      ),
      responseReadinessScore: IpModelUtils.boundedScore(
        data['responseReadinessScore'],
      ),
      resilienceScore: IpModelUtils.boundedScore(data['resilienceScore']),
      containsTradeSecret: IpModelUtils.boolFromValue(
        data['containsTradeSecret'],
      ),
      requiresDualApproval: IpModelUtils.boolFromValue(
        data['requiresDualApproval'],
      ),
      monitoringEnabled: IpModelUtils.boolFromValue(data['monitoringEnabled']),
      evidenceIntegrityStatus: IpEvidenceIntegrityStatus.fromValue(
        data['evidenceIntegrityStatus']?.toString(),
      ),
      fingerprint: IpModelUtils.nullableString(data['fingerprint']),
      fingerprintAlgorithm: IpModelUtils.nullableString(
        data['fingerprintAlgorithm'],
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
      'assetCode': assetCode.trim(),
      'title': title.trim(),
      'description': IpModelUtils.cleanNullable(description),
      'assetType': assetType.value,
      'status': status.value,
      'confidentialityLevel': confidentialityLevel.value,
      'riskLevel': riskLevel.value,
      'sector': IpModelUtils.cleanNullable(sector),
      'category': IpModelUtils.cleanNullable(category),
      'subcategory': IpModelUtils.cleanNullable(subcategory),
      'primaryOwnerName': IpModelUtils.cleanNullable(primaryOwnerName),
      'primaryOwnerId': IpModelUtils.cleanNullable(primaryOwnerId),
      'parentAssetId': IpModelUtils.cleanNullable(parentAssetId),
      'originCountryCode': _normalizeCountryCode(originCountryCode),
      'currentVersion': currentVersion < 1 ? 1 : currentVersion,
      'tags': IpModelUtils.cleanStringList(tags),
      'productIds': IpModelUtils.cleanStringList(productIds),
      'rightIds': IpModelUtils.cleanStringList(rightIds),
      'documentIds': IpModelUtils.cleanStringList(documentIds),
      'relationshipIds': IpModelUtils.cleanStringList(relationshipIds),
      'monitoringProfileIds': IpModelUtils.cleanStringList(
        monitoringProfileIds,
      ),
      'targetCountryCodes': IpModelUtils.cleanStringList(
        targetCountryCodes.map((item) => item.toUpperCase()),
      ),
      'firstCreatedAt': IpModelUtils.timestampOrNull(firstCreatedAt),
      'firstPublicationAt': IpModelUtils.timestampOrNull(firstPublicationAt),
      'firstCommercialUseAt': IpModelUtils.timestampOrNull(
        firstCommercialUseAt,
      ),
      'lastEvidenceAt': IpModelUtils.timestampOrNull(lastEvidenceAt),
      'lastRiskAssessmentAt': IpModelUtils.timestampOrNull(
        lastRiskAssessmentAt,
      ),
      'rightStrengthScore': _boundedScore(rightStrengthScore),
      'secretSecurityScore': _boundedScore(secretSecurityScore),
      'responseReadinessScore': _boundedScore(responseReadinessScore),
      'resilienceScore': _boundedScore(resilienceScore),
      'containsTradeSecret': containsTradeSecret,
      'requiresDualApproval': requiresDualApproval,
      'monitoringEnabled': monitoringEnabled,
      'evidenceIntegrityStatus': evidenceIntegrityStatus.value,
      'fingerprint': IpModelUtils.cleanNullable(fingerprint),
      'fingerprintAlgorithm': IpModelUtils.cleanNullable(fingerprintAlgorithm),
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

  IpAssetModel copyWith({
    String? id,
    String? tenantId,
    String? brandId,
    String? assetCode,
    String? title,
    String? description,
    IpAssetType? assetType,
    IpAssetStatus? status,
    IpConfidentialityLevel? confidentialityLevel,
    IpRiskLevel? riskLevel,
    String? sector,
    String? category,
    String? subcategory,
    String? primaryOwnerName,
    String? primaryOwnerId,
    String? parentAssetId,
    String? originCountryCode,
    int? currentVersion,
    List<String>? tags,
    List<String>? productIds,
    List<String>? rightIds,
    List<String>? documentIds,
    List<String>? relationshipIds,
    List<String>? monitoringProfileIds,
    List<String>? targetCountryCodes,
    DateTime? firstCreatedAt,
    DateTime? firstPublicationAt,
    DateTime? firstCommercialUseAt,
    DateTime? lastEvidenceAt,
    DateTime? lastRiskAssessmentAt,
    int? rightStrengthScore,
    int? secretSecurityScore,
    int? responseReadinessScore,
    int? resilienceScore,
    bool? containsTradeSecret,
    bool? requiresDualApproval,
    bool? monitoringEnabled,
    IpEvidenceIntegrityStatus? evidenceIntegrityStatus,
    String? fingerprint,
    String? fingerprintAlgorithm,
    String? notes,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return IpAssetModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      brandId: brandId ?? this.brandId,
      assetCode: assetCode ?? this.assetCode,
      title: title ?? this.title,
      description: description ?? this.description,
      assetType: assetType ?? this.assetType,
      status: status ?? this.status,
      confidentialityLevel: confidentialityLevel ?? this.confidentialityLevel,
      riskLevel: riskLevel ?? this.riskLevel,
      sector: sector ?? this.sector,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      primaryOwnerName: primaryOwnerName ?? this.primaryOwnerName,
      primaryOwnerId: primaryOwnerId ?? this.primaryOwnerId,
      parentAssetId: parentAssetId ?? this.parentAssetId,
      originCountryCode: originCountryCode ?? this.originCountryCode,
      currentVersion: currentVersion ?? this.currentVersion,
      tags: tags ?? this.tags,
      productIds: productIds ?? this.productIds,
      rightIds: rightIds ?? this.rightIds,
      documentIds: documentIds ?? this.documentIds,
      relationshipIds: relationshipIds ?? this.relationshipIds,
      monitoringProfileIds: monitoringProfileIds ?? this.monitoringProfileIds,
      targetCountryCodes: targetCountryCodes ?? this.targetCountryCodes,
      firstCreatedAt: firstCreatedAt ?? this.firstCreatedAt,
      firstPublicationAt: firstPublicationAt ?? this.firstPublicationAt,
      firstCommercialUseAt: firstCommercialUseAt ?? this.firstCommercialUseAt,
      lastEvidenceAt: lastEvidenceAt ?? this.lastEvidenceAt,
      lastRiskAssessmentAt: lastRiskAssessmentAt ?? this.lastRiskAssessmentAt,
      rightStrengthScore: rightStrengthScore ?? this.rightStrengthScore,
      secretSecurityScore: secretSecurityScore ?? this.secretSecurityScore,
      responseReadinessScore:
          responseReadinessScore ?? this.responseReadinessScore,
      resilienceScore: resilienceScore ?? this.resilienceScore,
      containsTradeSecret: containsTradeSecret ?? this.containsTradeSecret,
      requiresDualApproval: requiresDualApproval ?? this.requiresDualApproval,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      evidenceIntegrityStatus:
          evidenceIntegrityStatus ?? this.evidenceIntegrityStatus,
      fingerprint: fingerprint ?? this.fingerprint,
      fingerprintAlgorithm: fingerprintAlgorithm ?? this.fingerprintAlgorithm,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        brandId.trim().isNotEmpty &&
        assetCode.trim().isNotEmpty &&
        title.trim().isNotEmpty;
  }

  bool get isSecretAsset {
    return containsTradeSecret ||
        confidentialityLevel == IpConfidentialityLevel.tradeSecret ||
        assetType == IpAssetType.formula ||
        assetType == IpAssetType.tradeSecret ||
        assetType == IpAssetType.knowHow;
  }

  bool get hasFingerprint {
    return fingerprint != null && fingerprint!.trim().isNotEmpty;
  }

  bool get hasProtectionGap {
    return status == IpAssetStatus.exposed ||
        rightStrengthScore < 60 ||
        secretSecurityScore < 60 ||
        responseReadinessScore < 60;
  }

  bool get requiresImmediateAttention {
    return riskLevel == IpRiskLevel.critical ||
        riskLevel == IpRiskLevel.high ||
        evidenceIntegrityStatus == IpEvidenceIntegrityStatus.compromised;
  }

  static int _positiveVersion(dynamic value) {
    final parsed = IpModelUtils.intFromValue(value, fallback: 1);

    return parsed < 1 ? 1 : parsed;
  }

  static int _boundedScore(int value) {
    if (value < 0) {
      return 0;
    }

    if (value > 100) {
      return 100;
    }

    return value;
  }

  static String? _normalizeCountryCode(String? value) {
    final cleaned = IpModelUtils.cleanNullable(value);

    return cleaned?.toUpperCase();
  }
}
