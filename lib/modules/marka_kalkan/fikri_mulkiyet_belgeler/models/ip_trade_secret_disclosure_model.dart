import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretDisclosureModel {
  const IpTradeSecretDisclosureModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.disclosureCode,
    required this.recipientType,
    required this.recipientId,
    required this.recipientName,
    required this.status,
    required this.channel,
    required this.purpose,
    required this.disclosedAt,
    required this.disclosedBy,
    required this.createdAt,
    required this.createdBy,
    this.componentIds = const <String>[],
    this.accessGrantId,
    this.recipientOrganizationId,
    this.recipientCountryCode,
    this.recipientContact,
    this.reason,
    this.scopeDescription,
    this.ndaDocumentIds = const <String>[],
    this.contractDocumentIds = const <String>[],
    this.approvalDocumentIds = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.approvedByUserIds = const <String>[],
    this.requiresApproval = true,
    this.approvalCompleted = false,
    this.returnOrDestructionRequired = false,
    this.returnOrDestructionCompleted = false,
    this.returnOrDestructionDueAt,
    this.returnOrDestructionCompletedAt,
    this.watermarkApplied = false,
    this.encryptedTransferUsed = false,
    this.recipientIdentityVerified = false,
    this.recipientAcknowledgementReceived = false,
    this.onwardDisclosureAllowed = false,
    this.personalDataIncluded = false,
    this.crossBorderTransfer = false,
    this.exportControlReviewRequired = false,
    this.exportControlReviewCompleted = false,
    this.disclosureRiskScore = 0,
    this.legalProtectionScore = 0,
    this.reviewDueAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
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
  final String? accessGrantId;

  final String disclosureCode;

  final IpTradeSecretDisclosureRecipientType recipientType;
  final String recipientId;
  final String recipientName;
  final String? recipientOrganizationId;
  final String? recipientCountryCode;
  final String? recipientContact;

  final IpTradeSecretDisclosureStatus status;
  final IpTradeSecretDisclosureChannel channel;
  final IpTradeSecretDisclosurePurpose purpose;

  final String? reason;
  final String? scopeDescription;

  final List<String> ndaDocumentIds;
  final List<String> contractDocumentIds;
  final List<String> approvalDocumentIds;
  final List<String> evidenceDocumentIds;
  final List<String> approvedByUserIds;

  final DateTime disclosedAt;
  final String disclosedBy;

  final bool requiresApproval;
  final bool approvalCompleted;

  final bool returnOrDestructionRequired;
  final bool returnOrDestructionCompleted;
  final DateTime? returnOrDestructionDueAt;
  final DateTime? returnOrDestructionCompletedAt;

  final bool watermarkApplied;
  final bool encryptedTransferUsed;
  final bool recipientIdentityVerified;
  final bool recipientAcknowledgementReceived;
  final bool onwardDisclosureAllowed;

  final bool personalDataIncluded;
  final bool crossBorderTransfer;
  final bool exportControlReviewRequired;
  final bool exportControlReviewCompleted;

  final int disclosureRiskScore;
  final int legalProtectionScore;

  final DateTime? reviewDueAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretDisclosureModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır açıklama kaydı veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretDisclosureModel.fromMap(id: document.id, data: data);
  }

  factory IpTradeSecretDisclosureModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final disclosedAt = IpModelUtils.dateTimeFromValue(data['disclosedAt']);

    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (disclosedAt == null) {
      throw StateError('Ticari sır açıklama tarihi eksik: $id');
    }

    if (createdAt == null) {
      throw StateError(
        'Ticari sır açıklama kaydının oluşturma tarihi eksik: $id',
      );
    }

    return IpTradeSecretDisclosureModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.requiredString(data['tradeSecretId']),
      componentIds: _stringList(data['componentIds']),
      accessGrantId: IpModelUtils.nullableString(data['accessGrantId']),
      disclosureCode: IpModelUtils.requiredString(data['disclosureCode']),
      recipientType: IpTradeSecretDisclosureRecipientType.fromValue(
        data['recipientType']?.toString(),
      ),
      recipientId: IpModelUtils.requiredString(data['recipientId']),
      recipientName: IpModelUtils.requiredString(data['recipientName']),
      recipientOrganizationId: IpModelUtils.nullableString(
        data['recipientOrganizationId'],
      ),
      recipientCountryCode: IpModelUtils.nullableString(
        data['recipientCountryCode'],
      ),
      recipientContact: IpModelUtils.nullableString(data['recipientContact']),
      status: IpTradeSecretDisclosureStatus.fromValue(
        data['status']?.toString(),
      ),
      channel: IpTradeSecretDisclosureChannel.fromValue(
        data['channel']?.toString(),
      ),
      purpose: IpTradeSecretDisclosurePurpose.fromValue(
        data['purpose']?.toString(),
      ),
      reason: IpModelUtils.nullableString(data['reason']),
      scopeDescription: IpModelUtils.nullableString(data['scopeDescription']),
      ndaDocumentIds: _stringList(data['ndaDocumentIds']),
      contractDocumentIds: _stringList(data['contractDocumentIds']),
      approvalDocumentIds: _stringList(data['approvalDocumentIds']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      approvedByUserIds: _stringList(data['approvedByUserIds']),
      disclosedAt: disclosedAt,
      disclosedBy: IpModelUtils.requiredString(data['disclosedBy']),
      requiresApproval: data['requiresApproval'] != false,
      approvalCompleted: data['approvalCompleted'] == true,
      returnOrDestructionRequired: data['returnOrDestructionRequired'] == true,
      returnOrDestructionCompleted:
          data['returnOrDestructionCompleted'] == true,
      returnOrDestructionDueAt: IpModelUtils.dateTimeFromValue(
        data['returnOrDestructionDueAt'],
      ),
      returnOrDestructionCompletedAt: IpModelUtils.dateTimeFromValue(
        data['returnOrDestructionCompletedAt'],
      ),
      watermarkApplied: data['watermarkApplied'] == true,
      encryptedTransferUsed: data['encryptedTransferUsed'] == true,
      recipientIdentityVerified: data['recipientIdentityVerified'] == true,
      recipientAcknowledgementReceived:
          data['recipientAcknowledgementReceived'] == true,
      onwardDisclosureAllowed: data['onwardDisclosureAllowed'] == true,
      personalDataIncluded: data['personalDataIncluded'] == true,
      crossBorderTransfer: data['crossBorderTransfer'] == true,
      exportControlReviewRequired: data['exportControlReviewRequired'] == true,
      exportControlReviewCompleted:
          data['exportControlReviewCompleted'] == true,
      disclosureRiskScore: _score(data['disclosureRiskScore']),
      legalProtectionScore: _score(data['legalProtectionScore']),
      reviewDueAt: IpModelUtils.dateTimeFromValue(data['reviewDueAt']),
      cancelledAt: IpModelUtils.dateTimeFromValue(data['cancelledAt']),
      cancelledBy: IpModelUtils.nullableString(data['cancelledBy']),
      cancellationReason: IpModelUtils.nullableString(
        data['cancellationReason'],
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
    _validate();

    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': brandId.trim(),
      'tradeSecretId': tradeSecretId.trim(),
      'componentIds': _cleanList(componentIds),
      'accessGrantId': IpModelUtils.cleanNullable(accessGrantId),
      'disclosureCode': disclosureCode.trim(),
      'recipientType': recipientType.value,
      'recipientId': recipientId.trim(),
      'recipientName': recipientName.trim(),
      'recipientOrganizationId': IpModelUtils.cleanNullable(
        recipientOrganizationId,
      ),
      'recipientCountryCode': IpModelUtils.cleanNullable(recipientCountryCode),
      'recipientContact': IpModelUtils.cleanNullable(recipientContact),
      'status': status.value,
      'channel': channel.value,
      'purpose': purpose.value,
      'reason': IpModelUtils.cleanNullable(reason),
      'scopeDescription': IpModelUtils.cleanNullable(scopeDescription),
      'ndaDocumentIds': _cleanList(ndaDocumentIds),
      'contractDocumentIds': _cleanList(contractDocumentIds),
      'approvalDocumentIds': _cleanList(approvalDocumentIds),
      'evidenceDocumentIds': _cleanList(evidenceDocumentIds),
      'approvedByUserIds': _cleanList(approvedByUserIds),
      'disclosedAt': Timestamp.fromDate(disclosedAt),
      'disclosedBy': disclosedBy.trim(),
      'requiresApproval': requiresApproval,
      'approvalCompleted': approvalCompleted,
      'returnOrDestructionRequired': returnOrDestructionRequired,
      'returnOrDestructionCompleted': returnOrDestructionCompleted,
      'returnOrDestructionDueAt': IpModelUtils.timestampOrNull(
        returnOrDestructionDueAt,
      ),
      'returnOrDestructionCompletedAt': IpModelUtils.timestampOrNull(
        returnOrDestructionCompletedAt,
      ),
      'watermarkApplied': watermarkApplied,
      'encryptedTransferUsed': encryptedTransferUsed,
      'recipientIdentityVerified': recipientIdentityVerified,
      'recipientAcknowledgementReceived': recipientAcknowledgementReceived,
      'onwardDisclosureAllowed': onwardDisclosureAllowed,
      'personalDataIncluded': personalDataIncluded,
      'crossBorderTransfer': crossBorderTransfer,
      'exportControlReviewRequired': exportControlReviewRequired,
      'exportControlReviewCompleted': exportControlReviewCompleted,
      'disclosureRiskScore': _validatedScore(
        disclosureRiskScore,
        'disclosureRiskScore',
      ),
      'legalProtectionScore': _validatedScore(
        legalProtectionScore,
        'legalProtectionScore',
      ),
      'reviewDueAt': IpModelUtils.timestampOrNull(reviewDueAt),
      'cancelledAt': IpModelUtils.timestampOrNull(cancelledAt),
      'cancelledBy': IpModelUtils.cleanNullable(cancelledBy),
      'cancellationReason': IpModelUtils.cleanNullable(cancellationReason),
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
    map.remove('disclosureCode');
    map.remove('recipientType');
    map.remove('recipientId');
    map.remove('disclosedAt');
    map.remove('disclosedBy');
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
        disclosureCode.trim().isNotEmpty &&
        recipientId.trim().isNotEmpty &&
        recipientName.trim().isNotEmpty &&
        disclosedBy.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get isCompleted {
    return status == IpTradeSecretDisclosureStatus.completed;
  }

  bool get isCancelled {
    return status == IpTradeSecretDisclosureStatus.cancelled ||
        cancelledAt != null;
  }

  bool get hasLegalFoundation {
    return ndaDocumentIds.isNotEmpty ||
        contractDocumentIds.isNotEmpty ||
        approvalDocumentIds.isNotEmpty ||
        purpose == IpTradeSecretDisclosurePurpose.legalProceeding ||
        purpose == IpTradeSecretDisclosurePurpose.regulatoryCompliance;
  }

  bool get isExternalDisclosure {
    return recipientType != IpTradeSecretDisclosureRecipientType.employee &&
        recipientType != IpTradeSecretDisclosureRecipientType.department;
  }

  bool get requiresEnhancedProtection {
    return isExternalDisclosure ||
        crossBorderTransfer ||
        disclosureRiskScore >= 70 ||
        onwardDisclosureAllowed ||
        personalDataIncluded;
  }

  bool get requiresImmediateReview {
    return isCancelled ||
        status == IpTradeSecretDisclosureStatus.disputed ||
        disclosureRiskScore >= 80 ||
        reviewDueAt?.isBefore(DateTime.now().toUtc()) == true ||
        (returnOrDestructionRequired &&
            !returnOrDestructionCompleted &&
            returnOrDestructionDueAt?.isBefore(DateTime.now().toUtc()) == true);
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır açıklama kaydının zorunlu kimlik alanları eksik.',
      );
    }

    if (requiresApproval &&
        (status == IpTradeSecretDisclosureStatus.approved ||
            status == IpTradeSecretDisclosureStatus.completed) &&
        !approvalCompleted) {
      throw StateError(
        'Onay gerektiren açıklama, onay tamamlanmadan '
        'onaylanmış veya tamamlanmış olamaz.',
      );
    }

    if (returnOrDestructionRequired && returnOrDestructionDueAt == null) {
      throw StateError('İade veya imha zorunluysa son tarih belirtilmelidir.');
    }

    if (returnOrDestructionCompleted &&
        returnOrDestructionCompletedAt == null) {
      throw StateError(
        'İade veya imha tamamlandıysa tamamlanma tarihi zorunludur.',
      );
    }

    final destructionDueAt = returnOrDestructionDueAt;
    final destructionCompletedAt = returnOrDestructionCompletedAt;

    if (destructionDueAt != null && destructionDueAt.isBefore(disclosedAt)) {
      throw StateError(
        'İade veya imha son tarihi açıklama tarihinden önce olamaz.',
      );
    }

    if (destructionCompletedAt != null &&
        destructionCompletedAt.isBefore(disclosedAt)) {
      throw StateError(
        'İade veya imha tamamlanma tarihi açıklama tarihinden önce olamaz.',
      );
    }

    if (crossBorderTransfer &&
        (recipientCountryCode == null ||
            recipientCountryCode!.trim().isEmpty)) {
      throw StateError('Sınır ötesi aktarımda alıcı ülke kodu zorunludur.');
    }

    if (exportControlReviewRequired &&
        status == IpTradeSecretDisclosureStatus.completed &&
        !exportControlReviewCompleted) {
      throw StateError(
        'İhracat kontrolü incelemesi tamamlanmadan '
        'sınır ötesi açıklama tamamlanamaz.',
      );
    }

    if (channel == IpTradeSecretDisclosureChannel.publicPublication &&
        status == IpTradeSecretDisclosureStatus.completed &&
        approvalDocumentIds.isEmpty) {
      throw StateError('Kamuya açık yayın için onay belgesi zorunludur.');
    }

    final cancelledByValue = cancelledBy;

    if (status == IpTradeSecretDisclosureStatus.cancelled &&
        (cancelledAt == null ||
            cancelledByValue == null ||
            cancelledByValue.trim().isEmpty)) {
      throw StateError(
        'İptal edilen açıklamada iptal tarihi ve iptal eden kişi zorunludur.',
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
      'documentContent',
      'attachmentContent',
      'decryptionKey',
      'encryptionKey',
      'password',
      'credential',
      'accessToken',
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
