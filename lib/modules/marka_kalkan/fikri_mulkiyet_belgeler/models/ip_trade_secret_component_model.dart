import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretComponentModel {
  const IpTradeSecretComponentModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.componentCode,
    required this.title,
    required this.componentType,
    required this.status,
    required this.criticality,
    required this.confidentialityLevel,
    required this.riskLevel,
    required this.storageMode,
    required this.createdAt,
    required this.createdBy,
    this.description,
    this.sequenceNumber = 0,
    this.parentComponentId,
    this.dependencyComponentIds = const <String>[],
    this.relatedAssetIds = const <String>[],
    this.relatedDocumentIds = const <String>[],
    this.authorizedUserIds = const <String>[],
    this.authorizedRoleIds = const <String>[],
    this.custodianUserIds = const <String>[],
    this.protectionMeasureCodes = const <String>[],
    this.componentFingerprint,
    this.hashAlgorithm,
    this.encryptedComponentReference,
    this.externalSecureSystemReference,
    this.dataLocation,
    this.ownerDepartment,
    this.firstProtectedAt,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.leakageSuspected = false,
    this.legalHoldActive = false,
    this.accessControlScore = 0,
    this.technicalProtectionScore = 0,
    this.operationalProtectionScore = 0,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String tradeSecretId;

  final String componentCode;
  final String title;
  final String? description;
  final int sequenceNumber;

  final IpTradeSecretComponentType componentType;
  final IpTradeSecretComponentStatus status;
  final IpTradeSecretComponentCriticality criticality;
  final IpConfidentialityLevel confidentialityLevel;
  final IpRiskLevel riskLevel;
  final IpTradeSecretComponentStorageMode storageMode;

  final String? parentComponentId;
  final List<String> dependencyComponentIds;
  final List<String> relatedAssetIds;
  final List<String> relatedDocumentIds;

  final List<String> authorizedUserIds;
  final List<String> authorizedRoleIds;
  final List<String> custodianUserIds;
  final List<String> protectionMeasureCodes;

  /// Bileşen içeriğinin kendisi değil, doğrulama parmak izidir.
  final String? componentFingerprint;
  final String? hashAlgorithm;

  /// Gerçek bileşen içeriğine ait güvenli sistem referanslarıdır.
  final String? encryptedComponentReference;
  final String? externalSecureSystemReference;

  final String? dataLocation;
  final String? ownerDepartment;

  final DateTime? firstProtectedAt;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  final bool leakageSuspected;
  final bool legalHoldActive;

  final int accessControlScore;
  final int technicalProtectionScore;
  final int operationalProtectionScore;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretComponentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Ticari sır bileşeni veri içermiyor: ${document.id}');
    }

    return IpTradeSecretComponentModel.fromMap(id: document.id, data: data);
  }

  factory IpTradeSecretComponentModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Ticari sır bileşeninin oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretComponentModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.requiredString(data['tradeSecretId']),
      componentCode: IpModelUtils.requiredString(data['componentCode']),
      title: IpModelUtils.requiredString(data['title']),
      description: IpModelUtils.nullableString(data['description']),
      sequenceNumber: _nonNegativeInt(data['sequenceNumber']),
      componentType: IpTradeSecretComponentType.fromValue(
        data['componentType']?.toString(),
      ),
      status: IpTradeSecretComponentStatus.fromValue(
        data['status']?.toString(),
      ),
      criticality: IpTradeSecretComponentCriticality.fromValue(
        data['criticality']?.toString(),
      ),
      confidentialityLevel: IpConfidentialityLevel.fromValue(
        data['confidentialityLevel']?.toString(),
      ),
      riskLevel: IpRiskLevel.fromValue(data['riskLevel']?.toString()),
      storageMode: IpTradeSecretComponentStorageMode.fromValue(
        data['storageMode']?.toString(),
      ),
      parentComponentId: IpModelUtils.nullableString(data['parentComponentId']),
      dependencyComponentIds: _stringList(data['dependencyComponentIds']),
      relatedAssetIds: _stringList(data['relatedAssetIds']),
      relatedDocumentIds: _stringList(data['relatedDocumentIds']),
      authorizedUserIds: _stringList(data['authorizedUserIds']),
      authorizedRoleIds: _stringList(data['authorizedRoleIds']),
      custodianUserIds: _stringList(data['custodianUserIds']),
      protectionMeasureCodes: _stringList(data['protectionMeasureCodes']),
      componentFingerprint: IpModelUtils.nullableString(
        data['componentFingerprint'],
      ),
      hashAlgorithm: IpModelUtils.nullableString(data['hashAlgorithm']),
      encryptedComponentReference: IpModelUtils.nullableString(
        data['encryptedComponentReference'],
      ),
      externalSecureSystemReference: IpModelUtils.nullableString(
        data['externalSecureSystemReference'],
      ),
      dataLocation: IpModelUtils.nullableString(data['dataLocation']),
      ownerDepartment: IpModelUtils.nullableString(data['ownerDepartment']),
      firstProtectedAt: IpModelUtils.dateTimeFromValue(
        data['firstProtectedAt'],
      ),
      lastReviewedAt: IpModelUtils.dateTimeFromValue(data['lastReviewedAt']),
      nextReviewAt: IpModelUtils.dateTimeFromValue(data['nextReviewAt']),
      leakageSuspected: data['leakageSuspected'] == true,
      legalHoldActive: data['legalHoldActive'] == true,
      accessControlScore: _score(data['accessControlScore']),
      technicalProtectionScore: _score(data['technicalProtectionScore']),
      operationalProtectionScore: _score(data['operationalProtectionScore']),
      notes: IpModelUtils.nullableString(data['notes']),
      metadata: IpModelUtils.mapFromValue(data['metadata']),
      createdAt: createdAt,
      createdBy: IpModelUtils.requiredString(data['createdBy']),
      updatedAt: IpModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: IpModelUtils.nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toMap() {
    _validate();

    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'tradeSecretId': tradeSecretId.trim(),
      'componentCode': componentCode.trim(),
      'title': title.trim(),
      'description': IpModelUtils.cleanNullable(description),
      'sequenceNumber': sequenceNumber,
      'componentType': componentType.value,
      'status': status.value,
      'criticality': criticality.value,
      'confidentialityLevel': confidentialityLevel.value,
      'riskLevel': riskLevel.value,
      'storageMode': storageMode.value,
      'parentComponentId': IpModelUtils.cleanNullable(parentComponentId),
      'dependencyComponentIds': _cleanList(dependencyComponentIds),
      'relatedAssetIds': _cleanList(relatedAssetIds),
      'relatedDocumentIds': _cleanList(relatedDocumentIds),
      'authorizedUserIds': _cleanList(authorizedUserIds),
      'authorizedRoleIds': _cleanList(authorizedRoleIds),
      'custodianUserIds': _cleanList(custodianUserIds),
      'protectionMeasureCodes': _cleanList(protectionMeasureCodes),
      'componentFingerprint': IpModelUtils.cleanNullable(componentFingerprint),
      'hashAlgorithm': IpModelUtils.cleanNullable(hashAlgorithm),
      'encryptedComponentReference': IpModelUtils.cleanNullable(
        encryptedComponentReference,
      ),
      'externalSecureSystemReference': IpModelUtils.cleanNullable(
        externalSecureSystemReference,
      ),
      'dataLocation': IpModelUtils.cleanNullable(dataLocation),
      'ownerDepartment': IpModelUtils.cleanNullable(ownerDepartment),
      'firstProtectedAt': IpModelUtils.timestampOrNull(firstProtectedAt),
      'lastReviewedAt': IpModelUtils.timestampOrNull(lastReviewedAt),
      'nextReviewAt': IpModelUtils.timestampOrNull(nextReviewAt),
      'leakageSuspected': leakageSuspected,
      'legalHoldActive': legalHoldActive,
      'accessControlScore': _validatedScore(
        accessControlScore,
        'accessControlScore',
      ),
      'technicalProtectionScore': _validatedScore(
        technicalProtectionScore,
        'technicalProtectionScore',
      ),
      'operationalProtectionScore': _validatedScore(
        operationalProtectionScore,
        'operationalProtectionScore',
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
    map.remove('tradeSecretId');
    map.remove('componentCode');
    map.remove('createdAt');
    map.remove('createdBy');

    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = cleanedActorId;

    return map;
  }

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        brandId.trim().isNotEmpty &&
        tradeSecretId.trim().isNotEmpty &&
        componentCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get isCriticalComponent {
    return criticality == IpTradeSecretComponentCriticality.critical ||
        riskLevel == IpRiskLevel.critical;
  }

  bool get hasControlledAccess {
    return authorizedUserIds.isNotEmpty || authorizedRoleIds.isNotEmpty;
  }

  bool get requiresImmediateReview {
    return leakageSuspected ||
        status == IpTradeSecretComponentStatus.compromised ||
        riskLevel == IpRiskLevel.critical ||
        nextReviewAt?.isBefore(DateTime.now().toUtc()) == true;
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError('Ticari sır bileşeninin zorunlu kimlik alanları eksik.');
    }

    if (sequenceNumber < 0) {
      throw RangeError.value(
        sequenceNumber,
        'sequenceNumber',
        'Sıra numarası negatif olamaz.',
      );
    }

    const prohibitedKeys = <String>{
      'formulaContent',
      'recipeContent',
      'secretContent',
      'plaintextSecret',
      'rawFormula',
      'rawRecipe',
      'ingredientValue',
      'ingredientAmount',
      'exactProportion',
      'processParameterValue',
      'sourceCodeContent',
      'algorithmContent',
      'datasetContent',
    };

    final leakedKeys = metadata.keys
        .where(prohibitedKeys.contains)
        .toList(growable: false);

    if (leakedKeys.isNotEmpty) {
      throw StateError(
        'Ticari sır bileşen içeriği metadata alanında açık metin '
        'tutulamaz: ${leakedKeys.join(', ')}',
      );
    }

    if (storageMode == IpTradeSecretComponentStorageMode.encryptedVault &&
        (encryptedComponentReference == null ||
            encryptedComponentReference!.trim().isEmpty)) {
      throw StateError(
        'Şifreli kasa modunda şifreli bileşen referansı zorunludur.',
      );
    }

    if (storageMode == IpTradeSecretComponentStorageMode.externalSecureSystem &&
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

  static int _nonNegativeInt(Object? value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
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
