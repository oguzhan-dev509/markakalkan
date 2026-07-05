import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_enums.dart';
import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretAccessGrantModel {
  const IpTradeSecretAccessGrantModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.grantCode,
    required this.subjectType,
    required this.subjectId,
    required this.subjectName,
    required this.accessLevel,
    required this.status,
    required this.grantBasis,
    required this.validFrom,
    required this.createdAt,
    required this.createdBy,
    this.componentIds = const <String>[],
    this.relationshipId,
    this.departmentId,
    this.roleId,
    this.organizationId,
    this.reason,
    this.ndaDocumentIds = const <String>[],
    this.contractDocumentIds = const <String>[],
    this.approvalDocumentIds = const <String>[],
    this.approvedByUserIds = const <String>[],
    this.validUntil,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.suspendedAt,
    this.revokedAt,
    this.revokedBy,
    this.revocationReason,
    this.requiresDualApproval = false,
    this.dualApprovalCompleted = false,
    this.viewAllowed = true,
    this.downloadAllowed = false,
    this.printAllowed = false,
    this.exportAllowed = false,
    this.copyAllowed = false,
    this.onwardDisclosureAllowed = false,
    this.offlineAccessAllowed = false,
    this.watermarkRequired = true,
    this.deviceRestricted = false,
    this.locationRestricted = false,
    this.allowedDeviceIds = const <String>[],
    this.allowedLocationCodes = const <String>[],
    this.ipAllowlist = const <String>[],
    this.sessionTimeLimitMinutes,
    this.accessRiskScore = 0,
    this.legalProtectionScore = 0,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String brandId;
  final String tradeSecretId;
  final List<String> componentIds;

  final String grantCode;
  final IpTradeSecretAccessSubjectType subjectType;
  final String subjectId;
  final String subjectName;

  final String? relationshipId;
  final String? departmentId;
  final String? roleId;
  final String? organizationId;

  final IpAccessLevel accessLevel;
  final IpTradeSecretAccessGrantStatus status;
  final IpTradeSecretAccessGrantBasis grantBasis;
  final String? reason;

  final List<String> ndaDocumentIds;
  final List<String> contractDocumentIds;
  final List<String> approvalDocumentIds;
  final List<String> approvedByUserIds;

  final DateTime validFrom;
  final DateTime? validUntil;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final DateTime? suspendedAt;
  final DateTime? revokedAt;

  final String? revokedBy;
  final String? revocationReason;

  final bool requiresDualApproval;
  final bool dualApprovalCompleted;

  final bool viewAllowed;
  final bool downloadAllowed;
  final bool printAllowed;
  final bool exportAllowed;
  final bool copyAllowed;
  final bool onwardDisclosureAllowed;
  final bool offlineAccessAllowed;
  final bool watermarkRequired;

  final bool deviceRestricted;
  final bool locationRestricted;
  final List<String> allowedDeviceIds;
  final List<String> allowedLocationCodes;
  final List<String> ipAllowlist;
  final int? sessionTimeLimitMinutes;

  final int accessRiskScore;
  final int legalProtectionScore;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretAccessGrantModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır erişim yetkisi veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretAccessGrantModel.fromMap(id: document.id, data: data);
  }

  factory IpTradeSecretAccessGrantModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final validFrom = IpModelUtils.dateTimeFromValue(data['validFrom']);
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (validFrom == null) {
      throw StateError(
        'Ticari sır erişim yetkisinin başlangıç tarihi eksik: $id',
      );
    }

    if (createdAt == null) {
      throw StateError(
        'Ticari sır erişim yetkisinin oluşturma tarihi eksik: $id',
      );
    }

    return IpTradeSecretAccessGrantModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.requiredString(data['tradeSecretId']),
      componentIds: _stringList(data['componentIds']),
      grantCode: IpModelUtils.requiredString(data['grantCode']),
      subjectType: IpTradeSecretAccessSubjectType.fromValue(
        data['subjectType']?.toString(),
      ),
      subjectId: IpModelUtils.requiredString(data['subjectId']),
      subjectName: IpModelUtils.requiredString(data['subjectName']),
      relationshipId: IpModelUtils.nullableString(data['relationshipId']),
      departmentId: IpModelUtils.nullableString(data['departmentId']),
      roleId: IpModelUtils.nullableString(data['roleId']),
      organizationId: IpModelUtils.nullableString(data['organizationId']),
      accessLevel: IpAccessLevel.fromValue(data['accessLevel']?.toString()),
      status: IpTradeSecretAccessGrantStatus.fromValue(
        data['status']?.toString(),
      ),
      grantBasis: IpTradeSecretAccessGrantBasis.fromValue(
        data['grantBasis']?.toString(),
      ),
      reason: IpModelUtils.nullableString(data['reason']),
      ndaDocumentIds: _stringList(data['ndaDocumentIds']),
      contractDocumentIds: _stringList(data['contractDocumentIds']),
      approvalDocumentIds: _stringList(data['approvalDocumentIds']),
      approvedByUserIds: _stringList(data['approvedByUserIds']),
      validFrom: validFrom,
      validUntil: IpModelUtils.dateTimeFromValue(data['validUntil']),
      lastReviewedAt: IpModelUtils.dateTimeFromValue(data['lastReviewedAt']),
      nextReviewAt: IpModelUtils.dateTimeFromValue(data['nextReviewAt']),
      suspendedAt: IpModelUtils.dateTimeFromValue(data['suspendedAt']),
      revokedAt: IpModelUtils.dateTimeFromValue(data['revokedAt']),
      revokedBy: IpModelUtils.nullableString(data['revokedBy']),
      revocationReason: IpModelUtils.nullableString(data['revocationReason']),
      requiresDualApproval: data['requiresDualApproval'] == true,
      dualApprovalCompleted: data['dualApprovalCompleted'] == true,
      viewAllowed: data['viewAllowed'] != false,
      downloadAllowed: data['downloadAllowed'] == true,
      printAllowed: data['printAllowed'] == true,
      exportAllowed: data['exportAllowed'] == true,
      copyAllowed: data['copyAllowed'] == true,
      onwardDisclosureAllowed: data['onwardDisclosureAllowed'] == true,
      offlineAccessAllowed: data['offlineAccessAllowed'] == true,
      watermarkRequired: data['watermarkRequired'] != false,
      deviceRestricted: data['deviceRestricted'] == true,
      locationRestricted: data['locationRestricted'] == true,
      allowedDeviceIds: _stringList(data['allowedDeviceIds']),
      allowedLocationCodes: _stringList(data['allowedLocationCodes']),
      ipAllowlist: _stringList(data['ipAllowlist']),
      sessionTimeLimitMinutes: _nullablePositiveInt(
        data['sessionTimeLimitMinutes'],
      ),
      accessRiskScore: _score(data['accessRiskScore']),
      legalProtectionScore: _score(data['legalProtectionScore']),
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
      'componentIds': _cleanList(componentIds),
      'grantCode': grantCode.trim(),
      'subjectType': subjectType.value,
      'subjectId': subjectId.trim(),
      'subjectName': subjectName.trim(),
      'relationshipId': IpModelUtils.cleanNullable(relationshipId),
      'departmentId': IpModelUtils.cleanNullable(departmentId),
      'roleId': IpModelUtils.cleanNullable(roleId),
      'organizationId': IpModelUtils.cleanNullable(organizationId),
      'accessLevel': accessLevel.value,
      'status': status.value,
      'grantBasis': grantBasis.value,
      'reason': IpModelUtils.cleanNullable(reason),
      'ndaDocumentIds': _cleanList(ndaDocumentIds),
      'contractDocumentIds': _cleanList(contractDocumentIds),
      'approvalDocumentIds': _cleanList(approvalDocumentIds),
      'approvedByUserIds': _cleanList(approvedByUserIds),
      'validFrom': Timestamp.fromDate(validFrom),
      'validUntil': IpModelUtils.timestampOrNull(validUntil),
      'lastReviewedAt': IpModelUtils.timestampOrNull(lastReviewedAt),
      'nextReviewAt': IpModelUtils.timestampOrNull(nextReviewAt),
      'suspendedAt': IpModelUtils.timestampOrNull(suspendedAt),
      'revokedAt': IpModelUtils.timestampOrNull(revokedAt),
      'revokedBy': IpModelUtils.cleanNullable(revokedBy),
      'revocationReason': IpModelUtils.cleanNullable(revocationReason),
      'requiresDualApproval': requiresDualApproval,
      'dualApprovalCompleted': dualApprovalCompleted,
      'viewAllowed': viewAllowed,
      'downloadAllowed': downloadAllowed,
      'printAllowed': printAllowed,
      'exportAllowed': exportAllowed,
      'copyAllowed': copyAllowed,
      'onwardDisclosureAllowed': onwardDisclosureAllowed,
      'offlineAccessAllowed': offlineAccessAllowed,
      'watermarkRequired': watermarkRequired,
      'deviceRestricted': deviceRestricted,
      'locationRestricted': locationRestricted,
      'allowedDeviceIds': _cleanList(allowedDeviceIds),
      'allowedLocationCodes': _cleanList(allowedLocationCodes),
      'ipAllowlist': _cleanList(ipAllowlist),
      'sessionTimeLimitMinutes': sessionTimeLimitMinutes,
      'accessRiskScore': _validatedScore(accessRiskScore, 'accessRiskScore'),
      'legalProtectionScore': _validatedScore(
        legalProtectionScore,
        'legalProtectionScore',
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
    map.remove('grantCode');
    map.remove('subjectType');
    map.remove('subjectId');
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
        grantCode.trim().isNotEmpty &&
        subjectId.trim().isNotEmpty &&
        subjectName.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get isActive {
    final now = DateTime.now().toUtc();
    final expiry = validUntil;

    return status == IpTradeSecretAccessGrantStatus.active &&
        !isRevoked &&
        !validFrom.isAfter(now) &&
        (expiry == null || expiry.isAfter(now));
  }

  bool get isExpired {
    final expiry = validUntil;
    return expiry != null && !expiry.isAfter(DateTime.now().toUtc());
  }

  bool get isRevoked {
    return status == IpTradeSecretAccessGrantStatus.revoked ||
        revokedAt != null;
  }

  bool get hasLegalFoundation {
    return ndaDocumentIds.isNotEmpty ||
        contractDocumentIds.isNotEmpty ||
        approvalDocumentIds.isNotEmpty ||
        grantBasis == IpTradeSecretAccessGrantBasis.ownership ||
        grantBasis == IpTradeSecretAccessGrantBasis.legalObligation;
  }

  bool get grantsSensitiveOperations {
    return downloadAllowed ||
        printAllowed ||
        exportAllowed ||
        copyAllowed ||
        onwardDisclosureAllowed ||
        offlineAccessAllowed;
  }

  bool get requiresImmediateReview {
    return isExpired ||
        isRevoked ||
        accessRiskScore >= 80 ||
        nextReviewAt?.isBefore(DateTime.now().toUtc()) == true ||
        (requiresDualApproval && !dualApprovalCompleted);
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır erişim yetkisinin zorunlu kimlik alanları eksik.',
      );
    }

    final expiry = validUntil;

    if (expiry != null && expiry.isBefore(validFrom)) {
      throw StateError('Erişim bitiş tarihi başlangıç tarihinden önce olamaz.');
    }

    if (requiresDualApproval &&
        status == IpTradeSecretAccessGrantStatus.active &&
        !dualApprovalCompleted) {
      throw StateError(
        'Çift onay gerektiren erişim, ikinci onay tamamlanmadan '
        'aktif hâle getirilemez.',
      );
    }

    if (deviceRestricted && allowedDeviceIds.isEmpty) {
      throw StateError(
        'Cihaz kısıtlı erişimde en az bir izinli cihaz zorunludur.',
      );
    }

    if (locationRestricted && allowedLocationCodes.isEmpty) {
      throw StateError(
        'Konum kısıtlı erişimde en az bir izinli konum zorunludur.',
      );
    }

    final sessionLimit = sessionTimeLimitMinutes;

    if (sessionLimit != null && sessionLimit <= 0) {
      throw RangeError.value(
        sessionLimit,
        'sessionTimeLimitMinutes',
        'Oturum süresi sıfırdan büyük olmalıdır.',
      );
    }

    final revokedByValue = revokedBy;

    if (status == IpTradeSecretAccessGrantStatus.revoked &&
        (revokedAt == null ||
            revokedByValue == null ||
            revokedByValue.trim().isEmpty)) {
      throw StateError(
        'İptal edilen erişimde iptal tarihi ve iptal eden kişi zorunludur.',
      );
    }

    const prohibitedKeys = <String>{
      'formulaContent',
      'recipeContent',
      'secretContent',
      'plaintextSecret',
      'rawFormula',
      'rawRecipe',
      'sourceCodeContent',
      'algorithmContent',
      'datasetContent',
      'componentContent',
      'decryptionKey',
      'encryptionKey',
      'password',
      'credential',
    };

    final leakedKeys = metadata.keys
        .where(prohibitedKeys.contains)
        .toList(growable: false);

    if (leakedKeys.isNotEmpty) {
      throw StateError(
        'Ticari sır içeriği veya erişim anahtarı metadata alanında '
        'tutulamaz: ${leakedKeys.join(', ')}',
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

  static int? _nullablePositiveInt(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return null;
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
