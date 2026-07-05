import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretLifecycleTransitionModel {
  const IpTradeSecretLifecycleTransitionModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.transitionCode,
    required this.title,
    required this.fromStatus,
    required this.toStatus,
    required this.transitionType,
    required this.handoverStatus,
    required this.ownerUserId,
    required this.transitionOwnerUserId,
    required this.effectiveAt,
    required this.createdAt,
    required this.createdBy,
    this.componentIds = const <String>[],
    this.accessGrantIds = const <String>[],
    this.disclosureIds = const <String>[],
    this.incidentIds = const <String>[],
    this.protectionControlIds = const <String>[],
    this.riskAssessmentIds = const <String>[],
    this.resilienceProfileIds = const <String>[],
    this.defensibilityRecordIds = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.exitPartyType,
    this.exitPartyId,
    this.exitPartyDisplayName,
    this.previousOwnerUserId,
    this.newOwnerUserId,
    this.approverUserId,
    this.reason,
    this.handoverSummary,
    this.returnedAssetSummary,
    this.outstandingObligationSummary,
    this.exitInterviewReference,
    this.confidentialityReminderReference,
    this.accessRevocationReference,
    this.deviceReturnReference,
    this.documentReturnReference,
    this.keyReturnReference,
    this.highRiskExit = false,
    this.accessRevoked = false,
    this.devicesReturned = false,
    this.documentsReturned = false,
    this.keysReturned = false,
    this.confidentialityReminderDelivered = false,
    this.confidentialityAcknowledged = false,
    this.exitInterviewCompleted = false,
    this.legalReviewRequired = false,
    this.managementEscalationRequired = false,
    this.thirdPartyInvolved = false,
    this.crossBorderTransfer = false,
    this.approvedAt,
    this.handoverDueAt,
    this.handoverCompletedAt,
    this.accessRevokedAt,
    this.assetsReturnedAt,
    this.confidentialityAcknowledgedAt,
    this.exitInterviewCompletedAt,
    this.escalatedAt,
    this.closedAt,
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
  final List<String> accessGrantIds;
  final List<String> disclosureIds;
  final List<String> incidentIds;
  final List<String> protectionControlIds;
  final List<String> riskAssessmentIds;
  final List<String> resilienceProfileIds;
  final List<String> defensibilityRecordIds;
  final List<String> evidenceDocumentIds;

  final String transitionCode;
  final String title;

  final IpTradeSecretLifecycleStatus fromStatus;
  final IpTradeSecretLifecycleStatus toStatus;
  final IpTradeSecretTransitionType transitionType;
  final IpTradeSecretHandoverStatus handoverStatus;
  final IpTradeSecretExitPartyType? exitPartyType;

  final String ownerUserId;
  final String transitionOwnerUserId;
  final String? exitPartyId;
  final String? exitPartyDisplayName;
  final String? previousOwnerUserId;
  final String? newOwnerUserId;
  final String? approverUserId;

  final String? reason;
  final String? handoverSummary;
  final String? returnedAssetSummary;
  final String? outstandingObligationSummary;
  final String? exitInterviewReference;
  final String? confidentialityReminderReference;
  final String? accessRevocationReference;
  final String? deviceReturnReference;
  final String? documentReturnReference;
  final String? keyReturnReference;

  final bool highRiskExit;
  final bool accessRevoked;
  final bool devicesReturned;
  final bool documentsReturned;
  final bool keysReturned;
  final bool confidentialityReminderDelivered;
  final bool confidentialityAcknowledged;
  final bool exitInterviewCompleted;
  final bool legalReviewRequired;
  final bool managementEscalationRequired;
  final bool thirdPartyInvolved;
  final bool crossBorderTransfer;

  final DateTime effectiveAt;
  final DateTime? approvedAt;
  final DateTime? handoverDueAt;
  final DateTime? handoverCompletedAt;
  final DateTime? accessRevokedAt;
  final DateTime? assetsReturnedAt;
  final DateTime? confidentialityAcknowledgedAt;
  final DateTime? exitInterviewCompletedAt;
  final DateTime? escalatedAt;
  final DateTime? closedAt;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretLifecycleTransitionModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır yaşam döngüsü kaydı veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretLifecycleTransitionModel.fromMap(
      id: document.id,
      data: data,
    );
  }

  factory IpTradeSecretLifecycleTransitionModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final effectiveAt = IpModelUtils.dateTimeFromValue(data['effectiveAt']);
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (effectiveAt == null) {
      throw StateError('Yaşam döngüsü geçiş tarihi eksik: $id');
    }

    if (createdAt == null) {
      throw StateError('Yaşam döngüsü oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretLifecycleTransitionModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.requiredString(data['tradeSecretId']),
      componentIds: _stringList(data['componentIds']),
      accessGrantIds: _stringList(data['accessGrantIds']),
      disclosureIds: _stringList(data['disclosureIds']),
      incidentIds: _stringList(data['incidentIds']),
      protectionControlIds: _stringList(data['protectionControlIds']),
      riskAssessmentIds: _stringList(data['riskAssessmentIds']),
      resilienceProfileIds: _stringList(data['resilienceProfileIds']),
      defensibilityRecordIds: _stringList(data['defensibilityRecordIds']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      transitionCode: IpModelUtils.requiredString(data['transitionCode']),
      title: IpModelUtils.requiredString(data['title']),
      fromStatus: IpTradeSecretLifecycleStatus.fromValue(
        data['fromStatus']?.toString(),
      ),
      toStatus: IpTradeSecretLifecycleStatus.fromValue(
        data['toStatus']?.toString(),
      ),
      transitionType: IpTradeSecretTransitionType.fromValue(
        data['transitionType']?.toString(),
      ),
      handoverStatus: IpTradeSecretHandoverStatus.fromValue(
        data['handoverStatus']?.toString(),
      ),
      exitPartyType: data['exitPartyType'] == null
          ? null
          : IpTradeSecretExitPartyType.fromValue(
              data['exitPartyType']?.toString(),
            ),
      ownerUserId: IpModelUtils.requiredString(data['ownerUserId']),
      transitionOwnerUserId: IpModelUtils.requiredString(
        data['transitionOwnerUserId'],
      ),
      exitPartyId: IpModelUtils.nullableString(data['exitPartyId']),
      exitPartyDisplayName: IpModelUtils.nullableString(
        data['exitPartyDisplayName'],
      ),
      previousOwnerUserId: IpModelUtils.nullableString(
        data['previousOwnerUserId'],
      ),
      newOwnerUserId: IpModelUtils.nullableString(data['newOwnerUserId']),
      approverUserId: IpModelUtils.nullableString(data['approverUserId']),
      reason: IpModelUtils.nullableString(data['reason']),
      handoverSummary: IpModelUtils.nullableString(data['handoverSummary']),
      returnedAssetSummary: IpModelUtils.nullableString(
        data['returnedAssetSummary'],
      ),
      outstandingObligationSummary: IpModelUtils.nullableString(
        data['outstandingObligationSummary'],
      ),
      exitInterviewReference: IpModelUtils.nullableString(
        data['exitInterviewReference'],
      ),
      confidentialityReminderReference: IpModelUtils.nullableString(
        data['confidentialityReminderReference'],
      ),
      accessRevocationReference: IpModelUtils.nullableString(
        data['accessRevocationReference'],
      ),
      deviceReturnReference: IpModelUtils.nullableString(
        data['deviceReturnReference'],
      ),
      documentReturnReference: IpModelUtils.nullableString(
        data['documentReturnReference'],
      ),
      keyReturnReference: IpModelUtils.nullableString(
        data['keyReturnReference'],
      ),
      highRiskExit: data['highRiskExit'] == true,
      accessRevoked: data['accessRevoked'] == true,
      devicesReturned: data['devicesReturned'] == true,
      documentsReturned: data['documentsReturned'] == true,
      keysReturned: data['keysReturned'] == true,
      confidentialityReminderDelivered:
          data['confidentialityReminderDelivered'] == true,
      confidentialityAcknowledged: data['confidentialityAcknowledged'] == true,
      exitInterviewCompleted: data['exitInterviewCompleted'] == true,
      legalReviewRequired: data['legalReviewRequired'] == true,
      managementEscalationRequired:
          data['managementEscalationRequired'] == true,
      thirdPartyInvolved: data['thirdPartyInvolved'] == true,
      crossBorderTransfer: data['crossBorderTransfer'] == true,
      effectiveAt: effectiveAt,
      approvedAt: IpModelUtils.dateTimeFromValue(data['approvedAt']),
      handoverDueAt: IpModelUtils.dateTimeFromValue(data['handoverDueAt']),
      handoverCompletedAt: IpModelUtils.dateTimeFromValue(
        data['handoverCompletedAt'],
      ),
      accessRevokedAt: IpModelUtils.dateTimeFromValue(data['accessRevokedAt']),
      assetsReturnedAt: IpModelUtils.dateTimeFromValue(
        data['assetsReturnedAt'],
      ),
      confidentialityAcknowledgedAt: IpModelUtils.dateTimeFromValue(
        data['confidentialityAcknowledgedAt'],
      ),
      exitInterviewCompletedAt: IpModelUtils.dateTimeFromValue(
        data['exitInterviewCompletedAt'],
      ),
      escalatedAt: IpModelUtils.dateTimeFromValue(data['escalatedAt']),
      closedAt: IpModelUtils.dateTimeFromValue(data['closedAt']),
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
      'accessGrantIds': _cleanList(accessGrantIds),
      'disclosureIds': _cleanList(disclosureIds),
      'incidentIds': _cleanList(incidentIds),
      'protectionControlIds': _cleanList(protectionControlIds),
      'riskAssessmentIds': _cleanList(riskAssessmentIds),
      'resilienceProfileIds': _cleanList(resilienceProfileIds),
      'defensibilityRecordIds': _cleanList(defensibilityRecordIds),
      'evidenceDocumentIds': _cleanList(evidenceDocumentIds),
      'transitionCode': transitionCode.trim(),
      'title': title.trim(),
      'fromStatus': fromStatus.value,
      'toStatus': toStatus.value,
      'transitionType': transitionType.value,
      'handoverStatus': handoverStatus.value,
      'exitPartyType': exitPartyType?.value,
      'ownerUserId': ownerUserId.trim(),
      'transitionOwnerUserId': transitionOwnerUserId.trim(),
      'exitPartyId': IpModelUtils.cleanNullable(exitPartyId),
      'exitPartyDisplayName': IpModelUtils.cleanNullable(exitPartyDisplayName),
      'previousOwnerUserId': IpModelUtils.cleanNullable(previousOwnerUserId),
      'newOwnerUserId': IpModelUtils.cleanNullable(newOwnerUserId),
      'approverUserId': IpModelUtils.cleanNullable(approverUserId),
      'reason': IpModelUtils.cleanNullable(reason),
      'handoverSummary': IpModelUtils.cleanNullable(handoverSummary),
      'returnedAssetSummary': IpModelUtils.cleanNullable(returnedAssetSummary),
      'outstandingObligationSummary': IpModelUtils.cleanNullable(
        outstandingObligationSummary,
      ),
      'exitInterviewReference': IpModelUtils.cleanNullable(
        exitInterviewReference,
      ),
      'confidentialityReminderReference': IpModelUtils.cleanNullable(
        confidentialityReminderReference,
      ),
      'accessRevocationReference': IpModelUtils.cleanNullable(
        accessRevocationReference,
      ),
      'deviceReturnReference': IpModelUtils.cleanNullable(
        deviceReturnReference,
      ),
      'documentReturnReference': IpModelUtils.cleanNullable(
        documentReturnReference,
      ),
      'keyReturnReference': IpModelUtils.cleanNullable(keyReturnReference),
      'highRiskExit': highRiskExit,
      'accessRevoked': accessRevoked,
      'devicesReturned': devicesReturned,
      'documentsReturned': documentsReturned,
      'keysReturned': keysReturned,
      'confidentialityReminderDelivered': confidentialityReminderDelivered,
      'confidentialityAcknowledged': confidentialityAcknowledged,
      'exitInterviewCompleted': exitInterviewCompleted,
      'legalReviewRequired': legalReviewRequired,
      'managementEscalationRequired': managementEscalationRequired,
      'thirdPartyInvolved': thirdPartyInvolved,
      'crossBorderTransfer': crossBorderTransfer,
      'effectiveAt': Timestamp.fromDate(effectiveAt),
      'approvedAt': IpModelUtils.timestampOrNull(approvedAt),
      'handoverDueAt': IpModelUtils.timestampOrNull(handoverDueAt),
      'handoverCompletedAt': IpModelUtils.timestampOrNull(handoverCompletedAt),
      'accessRevokedAt': IpModelUtils.timestampOrNull(accessRevokedAt),
      'assetsReturnedAt': IpModelUtils.timestampOrNull(assetsReturnedAt),
      'confidentialityAcknowledgedAt': IpModelUtils.timestampOrNull(
        confidentialityAcknowledgedAt,
      ),
      'exitInterviewCompletedAt': IpModelUtils.timestampOrNull(
        exitInterviewCompletedAt,
      ),
      'escalatedAt': IpModelUtils.timestampOrNull(escalatedAt),
      'closedAt': IpModelUtils.timestampOrNull(closedAt),
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
    map.remove('transitionCode');
    map.remove('effectiveAt');
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
        transitionCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        ownerUserId.trim().isNotEmpty &&
        transitionOwnerUserId.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get isExitTransition {
    return transitionType == IpTradeSecretTransitionType.employeeExit ||
        transitionType == IpTradeSecretTransitionType.consultantExit ||
        transitionType == IpTradeSecretTransitionType.partnerExit ||
        transitionType == IpTradeSecretTransitionType.supplierExit;
  }

  bool get isOwnershipTransfer {
    return transitionType == IpTradeSecretTransitionType.ownershipTransfer ||
        transitionType == IpTradeSecretTransitionType.responsibilityTransfer;
  }

  bool get isHandoverOverdue {
    final dueAt = handoverDueAt;
    return handoverStatus != IpTradeSecretHandoverStatus.completed &&
        handoverStatus != IpTradeSecretHandoverStatus.notRequired &&
        dueAt != null &&
        dueAt.isBefore(DateTime.now().toUtc());
  }

  bool get hasOutstandingExitObligations {
    if (!isExitTransition) {
      return false;
    }

    return !accessRevoked ||
        !devicesReturned ||
        !documentsReturned ||
        !keysReturned ||
        !confidentialityReminderDelivered ||
        !confidentialityAcknowledged ||
        !exitInterviewCompleted;
  }

  bool get requiresImmediateEscalation {
    return managementEscalationRequired ||
        highRiskExit ||
        legalReviewRequired ||
        isHandoverOverdue ||
        hasOutstandingExitObligations;
  }

  bool get shouldAppearOnLifecycleDashboard {
    return toStatus == IpTradeSecretLifecycleStatus.transferPlanned ||
        toStatus == IpTradeSecretLifecycleStatus.transferring ||
        toStatus == IpTradeSecretLifecycleStatus.suspended ||
        toStatus == IpTradeSecretLifecycleStatus.restricted ||
        handoverStatus == IpTradeSecretHandoverStatus.pending ||
        handoverStatus == IpTradeSecretHandoverStatus.inProgress ||
        handoverStatus == IpTradeSecretHandoverStatus.failed ||
        requiresImmediateEscalation;
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır yaşam döngüsü kaydının zorunlu kimlik alanları eksik.',
      );
    }

    if (fromStatus == toStatus &&
        transitionType != IpTradeSecretTransitionType.roleChange &&
        transitionType != IpTradeSecretTransitionType.accessReduction &&
        transitionType != IpTradeSecretTransitionType.accessRevocation) {
      throw StateError(
        'Yaşam döngüsü geçişinde başlangıç ve hedef durum aynı olamaz.',
      );
    }

    if (isExitTransition &&
        (exitPartyType == null ||
            exitPartyId == null ||
            exitPartyId!.trim().isEmpty ||
            exitPartyDisplayName == null ||
            exitPartyDisplayName!.trim().isEmpty)) {
      throw StateError(
        'Çıkış geçişinde taraf türü, taraf kimliği ve görünen ad zorunludur.',
      );
    }

    if (isOwnershipTransfer &&
        (previousOwnerUserId == null ||
            previousOwnerUserId!.trim().isEmpty ||
            newOwnerUserId == null ||
            newOwnerUserId!.trim().isEmpty ||
            previousOwnerUserId!.trim() == newOwnerUserId!.trim())) {
      throw StateError(
        'Sahiplik veya sorumluluk devrinde eski ve yeni sorumlu zorunludur.',
      );
    }

    if (handoverStatus == IpTradeSecretHandoverStatus.completed &&
        (handoverCompletedAt == null ||
            handoverSummary == null ||
            handoverSummary!.trim().isEmpty)) {
      throw StateError('Tamamlanan devir teslimde tarih ve özet zorunludur.');
    }

    if (accessRevoked &&
        (accessRevokedAt == null ||
            accessRevocationReference == null ||
            accessRevocationReference!.trim().isEmpty)) {
      throw StateError(
        'Erişim kapatıldıysa tarih ve doğrulama referansı zorunludur.',
      );
    }

    if ((devicesReturned || documentsReturned || keysReturned) &&
        assetsReturnedAt == null) {
      throw StateError('Varlık iadesi doğrulandıysa iade tarihi zorunludur.');
    }

    if (devicesReturned &&
        (deviceReturnReference == null ||
            deviceReturnReference!.trim().isEmpty)) {
      throw StateError(
        'Cihaz iadesi doğrulandıysa cihaz iade referansı zorunludur.',
      );
    }

    if (documentsReturned &&
        (documentReturnReference == null ||
            documentReturnReference!.trim().isEmpty)) {
      throw StateError(
        'Belge iadesi doğrulandıysa belge iade referansı zorunludur.',
      );
    }

    if (keysReturned &&
        (keyReturnReference == null || keyReturnReference!.trim().isEmpty)) {
      throw StateError(
        'Anahtar iadesi doğrulandıysa anahtar iade referansı zorunludur.',
      );
    }

    if (confidentialityReminderDelivered &&
        (confidentialityReminderReference == null ||
            confidentialityReminderReference!.trim().isEmpty)) {
      throw StateError('Gizlilik hatırlatması yapıldıysa referans zorunludur.');
    }

    if (confidentialityAcknowledged && confidentialityAcknowledgedAt == null) {
      throw StateError(
        'Gizlilik yükümlülüğü kabul edildiyse kabul tarihi zorunludur.',
      );
    }

    if (exitInterviewCompleted &&
        (exitInterviewCompletedAt == null ||
            exitInterviewReference == null ||
            exitInterviewReference!.trim().isEmpty)) {
      throw StateError(
        'Çıkış görüşmesi tamamlandıysa tarih ve referans zorunludur.',
      );
    }

    if (managementEscalationRequired && escalatedAt == null) {
      throw StateError(
        'Yönetim yükseltmesi gereken geçişte yükseltme tarihi zorunludur.',
      );
    }

    if ((toStatus == IpTradeSecretLifecycleStatus.retired ||
            toStatus == IpTradeSecretLifecycleStatus.closed) &&
        closedAt == null) {
      throw StateError(
        'Emekliye ayrılan veya kapatılan ticari sırda kapanış tarihi zorunludur.',
      );
    }

    if (approvedAt != null && approvedAt!.isBefore(effectiveAt)) {
      throw StateError('Onay tarihi geçiş tarihinden önce olamaz.');
    }

    if (handoverCompletedAt != null &&
        handoverCompletedAt!.isBefore(effectiveAt)) {
      throw StateError(
        'Devir teslim tamamlanma tarihi geçiş tarihinden önce olamaz.',
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
      'privateKey',
    };

    final leakedKeys = metadata.keys
        .where(prohibitedKeys.contains)
        .toList(growable: false);

    if (leakedKeys.isNotEmpty) {
      throw StateError(
        'Ticari sır içeriği veya güvenlik anahtarı metadata alanında '
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
}
