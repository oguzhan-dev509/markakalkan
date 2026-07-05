import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../constants/ip_trade_secret_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretModel {
  const IpTradeSecretModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.secretCode,
    required this.title,
    required this.secretType,
    required this.status,
    required this.confidentialityLevel,
    required this.riskLevel,
    required this.protectionMode,
    required this.disclosureScope,
    required this.legalBasisStatus,
    required this.compartmentalizationLevel,
    required this.economicValueLevel,
    required this.createdAt,
    required this.createdBy,
    this.description,
    this.primaryAssetId,
    this.relatedAssetIds = const <String>[],
    this.relatedDocumentIds = const <String>[],
    this.ndaDocumentIds = const <String>[],
    this.contractDocumentIds = const <String>[],
    this.evidenceRecordIds = const <String>[],
    this.protectionMeasureCodes = const <String>[],
    this.custodianUserIds = const <String>[],
    this.authorizedUserIds = const <String>[],
    this.authorizedPartnerIds = const <String>[],
    this.ownerDepartment,
    this.secretFingerprint,
    this.hashAlgorithm,
    this.encryptedSecretReference,
    this.externalSecureSystemReference,
    this.firstProtectedAt,
    this.lastAccessReviewAt,
    this.nextAccessReviewAt,
    this.lastRiskAssessmentAt,
    this.lastDisclosureAt,
    this.leakageSuspected = false,
    this.legalHoldActive = false,
    this.accessControlScore = 0,
    this.legalProtectionScore = 0,
    this.technicalProtectionScore = 0,
    this.operationalProtectionScore = 0,
    this.secretSecurityScore = 0,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;

  final String secretCode;
  final String title;
  final String? description;

  final IpTradeSecretType secretType;
  final IpTradeSecretStatus status;
  final IpConfidentialityLevel confidentialityLevel;
  final IpRiskLevel riskLevel;
  final IpSecretProtectionMode protectionMode;
  final IpSecretDisclosureScope disclosureScope;
  final IpSecretLegalBasisStatus legalBasisStatus;
  final IpSecretCompartmentalizationLevel compartmentalizationLevel;
  final IpSecretEconomicValueLevel economicValueLevel;

  final String? primaryAssetId;
  final List<String> relatedAssetIds;
  final List<String> relatedDocumentIds;
  final List<String> ndaDocumentIds;
  final List<String> contractDocumentIds;
  final List<String> evidenceRecordIds;

  final List<String> protectionMeasureCodes;
  final List<String> custodianUserIds;
  final List<String> authorizedUserIds;
  final List<String> authorizedPartnerIds;

  final String? ownerDepartment;

  /// Gizli içeriğin kendisi değil, doğrulama amacıyla üretilmiş parmak izidir.
  final String? secretFingerprint;
  final String? hashAlgorithm;

  /// Gerçek sır içeriğinin bulunduğu şifreli veya harici sistem referansıdır.
  final String? encryptedSecretReference;
  final String? externalSecureSystemReference;

  final DateTime? firstProtectedAt;
  final DateTime? lastAccessReviewAt;
  final DateTime? nextAccessReviewAt;
  final DateTime? lastRiskAssessmentAt;
  final DateTime? lastDisclosureAt;

  final bool leakageSuspected;
  final bool legalHoldActive;

  final int accessControlScore;
  final int legalProtectionScore;
  final int technicalProtectionScore;
  final int operationalProtectionScore;
  final int secretSecurityScore;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır koruma dosyası veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretModel.fromMap(id: document.id, data: data);
  }

  factory IpTradeSecretModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError(
        'Ticari sır koruma dosyasının oluşturma tarihi eksik: $id',
      );
    }

    return IpTradeSecretModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      secretCode: IpModelUtils.requiredString(data['secretCode']),
      title: IpModelUtils.requiredString(data['title']),
      description: IpModelUtils.nullableString(data['description']),
      secretType: IpTradeSecretType.fromValue(data['secretType']?.toString()),
      status: IpTradeSecretStatus.fromValue(data['status']?.toString()),
      confidentialityLevel: IpConfidentialityLevel.fromValue(
        data['confidentialityLevel']?.toString(),
      ),
      riskLevel: IpRiskLevel.fromValue(data['riskLevel']?.toString()),
      protectionMode: IpSecretProtectionMode.fromValue(
        data['protectionMode']?.toString(),
      ),
      disclosureScope: IpSecretDisclosureScope.fromValue(
        data['disclosureScope']?.toString(),
      ),
      legalBasisStatus: IpSecretLegalBasisStatus.fromValue(
        data['legalBasisStatus']?.toString(),
      ),
      compartmentalizationLevel: IpSecretCompartmentalizationLevel.fromValue(
        data['compartmentalizationLevel']?.toString(),
      ),
      economicValueLevel: IpSecretEconomicValueLevel.fromValue(
        data['economicValueLevel']?.toString(),
      ),
      primaryAssetId: IpModelUtils.nullableString(data['primaryAssetId']),
      relatedAssetIds: _stringList(data['relatedAssetIds']),
      relatedDocumentIds: _stringList(data['relatedDocumentIds']),
      ndaDocumentIds: _stringList(data['ndaDocumentIds']),
      contractDocumentIds: _stringList(data['contractDocumentIds']),
      evidenceRecordIds: _stringList(data['evidenceRecordIds']),
      protectionMeasureCodes: _stringList(data['protectionMeasureCodes']),
      custodianUserIds: _stringList(data['custodianUserIds']),
      authorizedUserIds: _stringList(data['authorizedUserIds']),
      authorizedPartnerIds: _stringList(data['authorizedPartnerIds']),
      ownerDepartment: IpModelUtils.nullableString(data['ownerDepartment']),
      secretFingerprint: IpModelUtils.nullableString(data['secretFingerprint']),
      hashAlgorithm: IpModelUtils.nullableString(data['hashAlgorithm']),
      encryptedSecretReference: IpModelUtils.nullableString(
        data['encryptedSecretReference'],
      ),
      externalSecureSystemReference: IpModelUtils.nullableString(
        data['externalSecureSystemReference'],
      ),
      firstProtectedAt: IpModelUtils.dateTimeFromValue(
        data['firstProtectedAt'],
      ),
      lastAccessReviewAt: IpModelUtils.dateTimeFromValue(
        data['lastAccessReviewAt'],
      ),
      nextAccessReviewAt: IpModelUtils.dateTimeFromValue(
        data['nextAccessReviewAt'],
      ),
      lastRiskAssessmentAt: IpModelUtils.dateTimeFromValue(
        data['lastRiskAssessmentAt'],
      ),
      lastDisclosureAt: IpModelUtils.dateTimeFromValue(
        data['lastDisclosureAt'],
      ),
      leakageSuspected: data['leakageSuspected'] == true,
      legalHoldActive: data['legalHoldActive'] == true,
      accessControlScore: _score(data['accessControlScore']),
      legalProtectionScore: _score(data['legalProtectionScore']),
      technicalProtectionScore: _score(data['technicalProtectionScore']),
      operationalProtectionScore: _score(data['operationalProtectionScore']),
      secretSecurityScore: _score(data['secretSecurityScore']),
      notes: IpModelUtils.nullableString(data['notes']),
      metadata: IpModelUtils.mapFromValue(data['metadata']),
      createdAt: createdAt,
      createdBy: IpModelUtils.requiredString(data['createdBy']),
      updatedAt: IpModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: IpModelUtils.nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toMap() {
    _validateNoPlaintextSecretLeak();

    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'secretCode': secretCode.trim(),
      'title': title.trim(),
      'description': IpModelUtils.cleanNullable(description),
      'secretType': secretType.value,
      'status': status.value,
      'confidentialityLevel': confidentialityLevel.value,
      'riskLevel': riskLevel.value,
      'protectionMode': protectionMode.value,
      'disclosureScope': disclosureScope.value,
      'legalBasisStatus': legalBasisStatus.value,
      'compartmentalizationLevel': compartmentalizationLevel.value,
      'economicValueLevel': economicValueLevel.value,
      'primaryAssetId': IpModelUtils.cleanNullable(primaryAssetId),
      'relatedAssetIds': _cleanList(relatedAssetIds),
      'relatedDocumentIds': _cleanList(relatedDocumentIds),
      'ndaDocumentIds': _cleanList(ndaDocumentIds),
      'contractDocumentIds': _cleanList(contractDocumentIds),
      'evidenceRecordIds': _cleanList(evidenceRecordIds),
      'protectionMeasureCodes': _cleanList(protectionMeasureCodes),
      'custodianUserIds': _cleanList(custodianUserIds),
      'authorizedUserIds': _cleanList(authorizedUserIds),
      'authorizedPartnerIds': _cleanList(authorizedPartnerIds),
      'ownerDepartment': IpModelUtils.cleanNullable(ownerDepartment),
      'secretFingerprint': IpModelUtils.cleanNullable(secretFingerprint),
      'hashAlgorithm': IpModelUtils.cleanNullable(hashAlgorithm),
      'encryptedSecretReference': IpModelUtils.cleanNullable(
        encryptedSecretReference,
      ),
      'externalSecureSystemReference': IpModelUtils.cleanNullable(
        externalSecureSystemReference,
      ),
      'firstProtectedAt': IpModelUtils.timestampOrNull(firstProtectedAt),
      'lastAccessReviewAt': IpModelUtils.timestampOrNull(lastAccessReviewAt),
      'nextAccessReviewAt': IpModelUtils.timestampOrNull(nextAccessReviewAt),
      'lastRiskAssessmentAt': IpModelUtils.timestampOrNull(
        lastRiskAssessmentAt,
      ),
      'lastDisclosureAt': IpModelUtils.timestampOrNull(lastDisclosureAt),
      'leakageSuspected': leakageSuspected,
      'legalHoldActive': legalHoldActive,
      'accessControlScore': _validatedScore(
        accessControlScore,
        'accessControlScore',
      ),
      'legalProtectionScore': _validatedScore(
        legalProtectionScore,
        'legalProtectionScore',
      ),
      'technicalProtectionScore': _validatedScore(
        technicalProtectionScore,
        'technicalProtectionScore',
      ),
      'operationalProtectionScore': _validatedScore(
        operationalProtectionScore,
        'operationalProtectionScore',
      ),
      'secretSecurityScore': _validatedScore(
        secretSecurityScore,
        'secretSecurityScore',
      ),
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
    final cleanedActorId = actorId.trim();

    if (cleanedActorId.isEmpty) {
      throw ArgumentError.value(
        actorId,
        'actorId',
        'Güncelleme aktörü boş olamaz.',
      );
    }

    final map = toMap();

    map.remove('tenantId');
    map.remove('brandId');
    map.remove('secretCode');
    map.remove('createdAt');
    map.remove('createdBy');

    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = cleanedActorId;

    return map;
  }

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        brandId.trim().isNotEmpty &&
        secretCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get hasVerifiedLegalFoundation {
    return legalBasisStatus == IpSecretLegalBasisStatus.verified &&
        (ndaDocumentIds.isNotEmpty || contractDocumentIds.isNotEmpty);
  }

  bool get hasControlledAccess {
    return authorizedUserIds.isNotEmpty &&
        compartmentalizationLevel != IpSecretCompartmentalizationLevel.none;
  }

  bool get requiresImmediateReview {
    return leakageSuspected ||
        status == IpTradeSecretStatus.compromised ||
        riskLevel == IpRiskLevel.critical ||
        nextAccessReviewAt?.isBefore(DateTime.now().toUtc()) == true;
  }

  bool get storesPlaintextSecretContent => false;

  void _validateNoPlaintextSecretLeak() {
    const prohibitedKeys = <String>{
      'formulaContent',
      'recipeContent',
      'secretContent',
      'plaintextSecret',
      'rawFormula',
      'rawRecipe',
      'sourceCodeContent',
      'algorithmContent',
    };

    final leakedKeys = metadata.keys
        .where((key) => prohibitedKeys.contains(key))
        .toList(growable: false);

    if (leakedKeys.isNotEmpty) {
      throw StateError(
        'Ticari sır içeriği metadata alanında açık metin tutulamaz: '
        '${leakedKeys.join(', ')}',
      );
    }

    if (protectionMode == IpSecretProtectionMode.encryptedVault &&
        (encryptedSecretReference == null ||
            encryptedSecretReference!.trim().isEmpty)) {
      throw StateError(
        'Şifreli kasa koruma modunda şifreli sır referansı zorunludur.',
      );
    }

    if (protectionMode == IpSecretProtectionMode.externalSecureSystem &&
        (externalSecureSystemReference == null ||
            externalSecureSystemReference!.trim().isEmpty)) {
      throw StateError(
        'Harici güvenli sistem modunda sistem referansı zorunludur.',
      );
    }
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static List<String> _cleanList(List<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static int _score(Object? value) {
    if (value is int) {
      return value.clamp(0, 100);
    }

    if (value is num) {
      return value.round().clamp(0, 100);
    }

    return 0;
  }

  static int _validatedScore(int value, String fieldName) {
    if (value < 0 || value > 100) {
      throw RangeError.range(
        value,
        0,
        100,
        fieldName,
        '$fieldName 0–100 aralığında olmalıdır.',
      );
    }

    return value;
  }
}
