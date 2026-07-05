import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretRemediationActionModel {
  const IpTradeSecretRemediationActionModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.actionCode,
    required this.title,
    required this.status,
    required this.priority,
    required this.sourceType,
    required this.verificationOutcome,
    required this.ownerUserId,
    required this.assigneeUserId,
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
    this.lifecycleTransitionIds = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.dependencyActionIds = const <String>[],
    this.sourceRecordId,
    this.reviewerUserId,
    this.approverUserId,
    this.verifierUserId,
    this.description,
    this.expectedOutcome,
    this.blockerReason,
    this.closureSummary,
    this.reopenReason,
    this.verificationNotes,
    this.progressPercent = 0,
    this.preActionRiskScore = 0,
    this.postActionRiskScore = 0,
    this.effectivenessScore = 0,
    this.estimatedCostAmount,
    this.actualCostAmount,
    this.currencyCode,
    this.criticalAction = false,
    this.blocked = false,
    this.verificationRequired = true,
    this.managementEscalationRequired = false,
    this.legalReviewRequired = false,
    this.reopened = false,
    this.dueAt,
    this.startedAt,
    this.completedAt,
    this.verificationDueAt,
    this.verifiedAt,
    this.approvedAt,
    this.closedAt,
    this.reopenedAt,
    this.escalatedAt,
    this.cancelledAt,
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
  final List<String> lifecycleTransitionIds;
  final List<String> evidenceDocumentIds;
  final List<String> dependencyActionIds;

  final String actionCode;
  final String title;

  final IpTradeSecretRemediationStatus status;
  final IpTradeSecretRemediationPriority priority;
  final IpTradeSecretRemediationSourceType sourceType;
  final IpTradeSecretVerificationOutcome verificationOutcome;

  final String ownerUserId;
  final String assigneeUserId;
  final String? sourceRecordId;
  final String? reviewerUserId;
  final String? approverUserId;
  final String? verifierUserId;

  final String? description;
  final String? expectedOutcome;
  final String? blockerReason;
  final String? closureSummary;
  final String? reopenReason;
  final String? verificationNotes;

  final int progressPercent;
  final int preActionRiskScore;
  final int postActionRiskScore;
  final int effectivenessScore;

  final num? estimatedCostAmount;
  final num? actualCostAmount;
  final String? currencyCode;

  final bool criticalAction;
  final bool blocked;
  final bool verificationRequired;
  final bool managementEscalationRequired;
  final bool legalReviewRequired;
  final bool reopened;

  final DateTime? dueAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? verificationDueAt;
  final DateTime? verifiedAt;
  final DateTime? approvedAt;
  final DateTime? closedAt;
  final DateTime? reopenedAt;
  final DateTime? escalatedAt;
  final DateTime? cancelledAt;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretRemediationActionModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır iyileştirme eylemi veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretRemediationActionModel.fromMap(
      id: document.id,
      data: data,
    );
  }

  factory IpTradeSecretRemediationActionModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('İyileştirme eylemi oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretRemediationActionModel(
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
      lifecycleTransitionIds: _stringList(data['lifecycleTransitionIds']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      dependencyActionIds: _stringList(data['dependencyActionIds']),
      actionCode: IpModelUtils.requiredString(data['actionCode']),
      title: IpModelUtils.requiredString(data['title']),
      status: IpTradeSecretRemediationStatus.fromValue(
        data['status']?.toString(),
      ),
      priority: IpTradeSecretRemediationPriority.fromValue(
        data['priority']?.toString(),
      ),
      sourceType: IpTradeSecretRemediationSourceType.fromValue(
        data['sourceType']?.toString(),
      ),
      verificationOutcome: IpTradeSecretVerificationOutcome.fromValue(
        data['verificationOutcome']?.toString(),
      ),
      ownerUserId: IpModelUtils.requiredString(data['ownerUserId']),
      assigneeUserId: IpModelUtils.requiredString(data['assigneeUserId']),
      sourceRecordId: IpModelUtils.nullableString(data['sourceRecordId']),
      reviewerUserId: IpModelUtils.nullableString(data['reviewerUserId']),
      approverUserId: IpModelUtils.nullableString(data['approverUserId']),
      verifierUserId: IpModelUtils.nullableString(data['verifierUserId']),
      description: IpModelUtils.nullableString(data['description']),
      expectedOutcome: IpModelUtils.nullableString(data['expectedOutcome']),
      blockerReason: IpModelUtils.nullableString(data['blockerReason']),
      closureSummary: IpModelUtils.nullableString(data['closureSummary']),
      reopenReason: IpModelUtils.nullableString(data['reopenReason']),
      verificationNotes: IpModelUtils.nullableString(data['verificationNotes']),
      progressPercent: _boundedInt(data['progressPercent'], 0, 100),
      preActionRiskScore: _boundedInt(data['preActionRiskScore'], 0, 100),
      postActionRiskScore: _boundedInt(data['postActionRiskScore'], 0, 100),
      effectivenessScore: _boundedInt(data['effectivenessScore'], 0, 100),
      estimatedCostAmount: data['estimatedCostAmount'] is num
          ? data['estimatedCostAmount'] as num
          : null,
      actualCostAmount: data['actualCostAmount'] is num
          ? data['actualCostAmount'] as num
          : null,
      currencyCode: IpModelUtils.nullableString(data['currencyCode']),
      criticalAction: data['criticalAction'] == true,
      blocked: data['blocked'] == true,
      verificationRequired: data['verificationRequired'] != false,
      managementEscalationRequired:
          data['managementEscalationRequired'] == true,
      legalReviewRequired: data['legalReviewRequired'] == true,
      reopened: data['reopened'] == true,
      dueAt: IpModelUtils.dateTimeFromValue(data['dueAt']),
      startedAt: IpModelUtils.dateTimeFromValue(data['startedAt']),
      completedAt: IpModelUtils.dateTimeFromValue(data['completedAt']),
      verificationDueAt: IpModelUtils.dateTimeFromValue(
        data['verificationDueAt'],
      ),
      verifiedAt: IpModelUtils.dateTimeFromValue(data['verifiedAt']),
      approvedAt: IpModelUtils.dateTimeFromValue(data['approvedAt']),
      closedAt: IpModelUtils.dateTimeFromValue(data['closedAt']),
      reopenedAt: IpModelUtils.dateTimeFromValue(data['reopenedAt']),
      escalatedAt: IpModelUtils.dateTimeFromValue(data['escalatedAt']),
      cancelledAt: IpModelUtils.dateTimeFromValue(data['cancelledAt']),
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
      'lifecycleTransitionIds': _cleanList(lifecycleTransitionIds),
      'evidenceDocumentIds': _cleanList(evidenceDocumentIds),
      'dependencyActionIds': _cleanList(dependencyActionIds),
      'actionCode': actionCode.trim(),
      'title': title.trim(),
      'status': status.value,
      'priority': priority.value,
      'sourceType': sourceType.value,
      'verificationOutcome': verificationOutcome.value,
      'ownerUserId': ownerUserId.trim(),
      'assigneeUserId': assigneeUserId.trim(),
      'sourceRecordId': IpModelUtils.cleanNullable(sourceRecordId),
      'reviewerUserId': IpModelUtils.cleanNullable(reviewerUserId),
      'approverUserId': IpModelUtils.cleanNullable(approverUserId),
      'verifierUserId': IpModelUtils.cleanNullable(verifierUserId),
      'description': IpModelUtils.cleanNullable(description),
      'expectedOutcome': IpModelUtils.cleanNullable(expectedOutcome),
      'blockerReason': IpModelUtils.cleanNullable(blockerReason),
      'closureSummary': IpModelUtils.cleanNullable(closureSummary),
      'reopenReason': IpModelUtils.cleanNullable(reopenReason),
      'verificationNotes': IpModelUtils.cleanNullable(verificationNotes),
      'progressPercent': _validatedScore(progressPercent, 'progressPercent'),
      'preActionRiskScore': _validatedScore(
        preActionRiskScore,
        'preActionRiskScore',
      ),
      'postActionRiskScore': _validatedScore(
        postActionRiskScore,
        'postActionRiskScore',
      ),
      'effectivenessScore': _validatedScore(
        effectivenessScore,
        'effectivenessScore',
      ),
      'estimatedCostAmount': _validatedAmount(
        estimatedCostAmount,
        'estimatedCostAmount',
      ),
      'actualCostAmount': _validatedAmount(
        actualCostAmount,
        'actualCostAmount',
      ),
      'currencyCode': IpModelUtils.cleanNullable(currencyCode),
      'criticalAction': criticalAction,
      'blocked': blocked,
      'verificationRequired': verificationRequired,
      'managementEscalationRequired': managementEscalationRequired,
      'legalReviewRequired': legalReviewRequired,
      'reopened': reopened,
      'dueAt': IpModelUtils.timestampOrNull(dueAt),
      'startedAt': IpModelUtils.timestampOrNull(startedAt),
      'completedAt': IpModelUtils.timestampOrNull(completedAt),
      'verificationDueAt': IpModelUtils.timestampOrNull(verificationDueAt),
      'verifiedAt': IpModelUtils.timestampOrNull(verifiedAt),
      'approvedAt': IpModelUtils.timestampOrNull(approvedAt),
      'closedAt': IpModelUtils.timestampOrNull(closedAt),
      'reopenedAt': IpModelUtils.timestampOrNull(reopenedAt),
      'escalatedAt': IpModelUtils.timestampOrNull(escalatedAt),
      'cancelledAt': IpModelUtils.timestampOrNull(cancelledAt),
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
    map.remove('actionCode');
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
        actionCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        ownerUserId.trim().isNotEmpty &&
        assigneeUserId.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get isOverdue {
    final targetDate = dueAt;
    return targetDate != null &&
        targetDate.isBefore(DateTime.now().toUtc()) &&
        status != IpTradeSecretRemediationStatus.closed &&
        status != IpTradeSecretRemediationStatus.cancelled;
  }

  bool get isVerificationOverdue {
    final targetDate = verificationDueAt;
    return verificationRequired &&
        targetDate != null &&
        targetDate.isBefore(DateTime.now().toUtc()) &&
        verifiedAt == null;
  }

  bool get isIneffective {
    return verificationOutcome ==
            IpTradeSecretVerificationOutcome.ineffective ||
        verificationOutcome == IpTradeSecretVerificationOutcome.rejected ||
        (verifiedAt != null && effectivenessScore < 50);
  }

  bool get requiresImmediateEscalation {
    return managementEscalationRequired ||
        criticalAction ||
        blocked ||
        isOverdue ||
        isVerificationOverdue ||
        isIneffective;
  }

  bool get shouldAppearOnRemediationDashboard {
    return status == IpTradeSecretRemediationStatus.assigned ||
        status == IpTradeSecretRemediationStatus.inProgress ||
        status == IpTradeSecretRemediationStatus.blocked ||
        status == IpTradeSecretRemediationStatus.pendingVerification ||
        status == IpTradeSecretRemediationStatus.reopened ||
        requiresImmediateEscalation;
  }

  bool get isClosureReady {
    return progressPercent == 100 &&
        completedAt != null &&
        (!verificationRequired ||
            (verifiedAt != null &&
                verificationOutcome ==
                    IpTradeSecretVerificationOutcome.effective)) &&
        !blocked &&
        evidenceDocumentIds.isNotEmpty;
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır iyileştirme eyleminin zorunlu kimlik alanları eksik.',
      );
    }

    for (final entry in <String, int>{
      'progressPercent': progressPercent,
      'preActionRiskScore': preActionRiskScore,
      'postActionRiskScore': postActionRiskScore,
      'effectivenessScore': effectivenessScore,
    }.entries) {
      _validatedScore(entry.value, entry.key);
    }

    _validatedAmount(estimatedCostAmount, 'estimatedCostAmount');
    _validatedAmount(actualCostAmount, 'actualCostAmount');

    final hasAnyCost = estimatedCostAmount != null || actualCostAmount != null;

    if (hasAnyCost &&
        (currencyCode == null || currencyCode!.trim().length != 3)) {
      throw StateError(
        'Maliyet bilgisi varsa üç harfli para birimi kodu zorunludur.',
      );
    }

    if (sourceType != IpTradeSecretRemediationSourceType.other &&
        (sourceRecordId == null || sourceRecordId!.trim().isEmpty)) {
      throw StateError(
        'Kaynak türü diğer değilse kaynak kayıt kimliği zorunludur.',
      );
    }

    if ((status == IpTradeSecretRemediationStatus.assigned ||
            status == IpTradeSecretRemediationStatus.inProgress) &&
        dueAt == null) {
      throw StateError('Atanmış veya yürütülen eylemde son tarih zorunludur.');
    }

    if (blocked &&
        (status != IpTradeSecretRemediationStatus.blocked ||
            blockerReason == null ||
            blockerReason!.trim().isEmpty)) {
      throw StateError('Engellenmiş eylemde durum ve engel nedeni zorunludur.');
    }

    if (status == IpTradeSecretRemediationStatus.blocked && !blocked) {
      throw StateError(
        'Durumu engellendi olan eylemde blocked true olmalıdır.',
      );
    }

    if (progressPercent == 100 && completedAt == null) {
      throw StateError(
        'Yüzde 100 tamamlanan eylemde tamamlanma tarihi zorunludur.',
      );
    }

    if (completedAt != null && progressPercent != 100) {
      throw StateError('Tamamlanma tarihi bulunan eylem yüzde 100 olmalıdır.');
    }

    if (status == IpTradeSecretRemediationStatus.pendingVerification &&
        (!verificationRequired ||
            completedAt == null ||
            verificationDueAt == null)) {
      throw StateError(
        'Doğrulama bekleyen eylem tamamlanmış ve doğrulama tarihli olmalıdır.',
      );
    }

    if (status == IpTradeSecretRemediationStatus.verified &&
        (verifiedAt == null ||
            verifierUserId == null ||
            verifierUserId!.trim().isEmpty ||
            verificationOutcome ==
                IpTradeSecretVerificationOutcome.notReviewed)) {
      throw StateError(
        'Doğrulanan eylemde doğrulayan, tarih ve sonuç zorunludur.',
      );
    }

    if (status == IpTradeSecretRemediationStatus.closed &&
        (closedAt == null ||
            approverUserId == null ||
            approverUserId!.trim().isEmpty ||
            approvedAt == null ||
            closureSummary == null ||
            closureSummary!.trim().isEmpty ||
            !isClosureReady)) {
      throw StateError(
        'Kapatılan eylemde onay, kapanış özeti ve doğrulanmış kanıt zorunludur.',
      );
    }

    if (reopened &&
        (status != IpTradeSecretRemediationStatus.reopened ||
            reopenedAt == null ||
            reopenReason == null ||
            reopenReason!.trim().isEmpty)) {
      throw StateError(
        'Yeniden açılan eylemde durum, tarih ve gerekçe zorunludur.',
      );
    }

    if (status == IpTradeSecretRemediationStatus.reopened && !reopened) {
      throw StateError(
        'Durumu yeniden açıldı olan eylemde reopened true olmalıdır.',
      );
    }

    if (managementEscalationRequired && escalatedAt == null) {
      throw StateError(
        'Yönetim yükseltmesi gereken eylemde yükseltme tarihi zorunludur.',
      );
    }

    if (status == IpTradeSecretRemediationStatus.cancelled &&
        cancelledAt == null) {
      throw StateError('İptal edilen eylemde iptal tarihi zorunludur.');
    }

    if (completedAt != null &&
        startedAt != null &&
        completedAt!.isBefore(startedAt!)) {
      throw StateError('Tamamlanma tarihi başlangıç tarihinden önce olamaz.');
    }

    if (verifiedAt != null &&
        completedAt != null &&
        verifiedAt!.isBefore(completedAt!)) {
      throw StateError('Doğrulama tarihi tamamlanma tarihinden önce olamaz.');
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

  static int _boundedInt(Object? value, int minimum, int maximum) {
    if (value is int) {
      return value.clamp(minimum, maximum);
    }

    if (value is num) {
      return value.round().clamp(minimum, maximum);
    }

    return minimum;
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

  static num? _validatedAmount(num? value, String fieldName) {
    if (value != null && value < 0) {
      throw RangeError.value(value, fieldName, '$fieldName negatif olamaz.');
    }

    return value;
  }
}
