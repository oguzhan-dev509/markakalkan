import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretManagementDecisionModel {
  const IpTradeSecretManagementDecisionModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.decisionCode,
    required this.title,
    required this.status,
    required this.decisionType,
    required this.votingMethod,
    required this.ownerUserId,
    required this.createdAt,
    required this.createdBy,
    this.componentIds = const <String>[],
    this.riskAssessmentIds = const <String>[],
    this.disclosureIds = const <String>[],
    this.incidentIds = const <String>[],
    this.protectionControlIds = const <String>[],
    this.resilienceProfileIds = const <String>[],
    this.defensibilityRecordIds = const <String>[],
    this.lifecycleTransitionIds = const <String>[],
    this.remediationActionIds = const <String>[],
    this.alertRuleIds = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.reviewerUserIds = const <String>[],
    this.approverUserIds = const <String>[],
    this.approvedUserIds = const <String>[],
    this.rejectedUserIds = const <String>[],
    this.abstainedUserIds = const <String>[],
    this.recusedUserIds = const <String>[],
    this.decisionSummary,
    this.rationale,
    this.conditions,
    this.dissentingOpinion,
    this.rejectionReason,
    this.suspensionReason,
    this.revocationReason,
    this.supersededByDecisionId,
    this.previousOwnerUserId,
    this.newOwnerUserId,
    this.previousProtectionLevel,
    this.newProtectionLevel,
    this.requestedBudgetAmount,
    this.approvedBudgetAmount,
    this.currencyCode,
    this.requiredApprovalCount = 1,
    this.approvalOutcome = IpTradeSecretApprovalOutcome.pending,
    this.riskAcceptance = false,
    this.conditionalDecision = false,
    this.conditionsSatisfied = false,
    this.legalReviewRequired = false,
    this.securityReviewRequired = false,
    this.financeReviewRequired = false,
    this.boardReviewRequired = false,
    this.reassessmentRequired = false,
    this.decisionAt,
    this.effectiveAt,
    this.expiresAt,
    this.reassessmentAt,
    this.conditionsSatisfiedAt,
    this.suspendedAt,
    this.revokedAt,
    this.expiredAt,
    this.supersededAt,
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
  final List<String> riskAssessmentIds;
  final List<String> disclosureIds;
  final List<String> incidentIds;
  final List<String> protectionControlIds;
  final List<String> resilienceProfileIds;
  final List<String> defensibilityRecordIds;
  final List<String> lifecycleTransitionIds;
  final List<String> remediationActionIds;
  final List<String> alertRuleIds;
  final List<String> evidenceDocumentIds;

  final List<String> reviewerUserIds;
  final List<String> approverUserIds;
  final List<String> approvedUserIds;
  final List<String> rejectedUserIds;
  final List<String> abstainedUserIds;
  final List<String> recusedUserIds;

  final String decisionCode;
  final String title;
  final IpTradeSecretDecisionStatus status;
  final IpTradeSecretDecisionType decisionType;
  final IpTradeSecretDecisionVotingMethod votingMethod;
  final IpTradeSecretApprovalOutcome approvalOutcome;
  final String ownerUserId;

  final String? decisionSummary;
  final String? rationale;
  final String? conditions;
  final String? dissentingOpinion;
  final String? rejectionReason;
  final String? suspensionReason;
  final String? revocationReason;
  final String? supersededByDecisionId;
  final String? previousOwnerUserId;
  final String? newOwnerUserId;
  final String? previousProtectionLevel;
  final String? newProtectionLevel;

  final num? requestedBudgetAmount;
  final num? approvedBudgetAmount;
  final String? currencyCode;
  final int requiredApprovalCount;

  final bool riskAcceptance;
  final bool conditionalDecision;
  final bool conditionsSatisfied;
  final bool legalReviewRequired;
  final bool securityReviewRequired;
  final bool financeReviewRequired;
  final bool boardReviewRequired;
  final bool reassessmentRequired;

  final DateTime? decisionAt;
  final DateTime? effectiveAt;
  final DateTime? expiresAt;
  final DateTime? reassessmentAt;
  final DateTime? conditionsSatisfiedAt;
  final DateTime? suspendedAt;
  final DateTime? revokedAt;
  final DateTime? expiredAt;
  final DateTime? supersededAt;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretManagementDecisionModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır yönetim kararı veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretManagementDecisionModel.fromMap(
      id: document.id,
      data: data,
    );
  }

  factory IpTradeSecretManagementDecisionModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (createdAt == null) {
      throw StateError('Yönetim kararı oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretManagementDecisionModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.requiredString(data['tradeSecretId']),
      componentIds: _stringList(data['componentIds']),
      riskAssessmentIds: _stringList(data['riskAssessmentIds']),
      disclosureIds: _stringList(data['disclosureIds']),
      incidentIds: _stringList(data['incidentIds']),
      protectionControlIds: _stringList(data['protectionControlIds']),
      resilienceProfileIds: _stringList(data['resilienceProfileIds']),
      defensibilityRecordIds: _stringList(data['defensibilityRecordIds']),
      lifecycleTransitionIds: _stringList(data['lifecycleTransitionIds']),
      remediationActionIds: _stringList(data['remediationActionIds']),
      alertRuleIds: _stringList(data['alertRuleIds']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      reviewerUserIds: _stringList(data['reviewerUserIds']),
      approverUserIds: _stringList(data['approverUserIds']),
      approvedUserIds: _stringList(data['approvedUserIds']),
      rejectedUserIds: _stringList(data['rejectedUserIds']),
      abstainedUserIds: _stringList(data['abstainedUserIds']),
      recusedUserIds: _stringList(data['recusedUserIds']),
      decisionCode: IpModelUtils.requiredString(data['decisionCode']),
      title: IpModelUtils.requiredString(data['title']),
      status: IpTradeSecretDecisionStatus.fromValue(data['status']?.toString()),
      decisionType: IpTradeSecretDecisionType.fromValue(
        data['decisionType']?.toString(),
      ),
      votingMethod: IpTradeSecretDecisionVotingMethod.fromValue(
        data['votingMethod']?.toString(),
      ),
      approvalOutcome: IpTradeSecretApprovalOutcome.fromValue(
        data['approvalOutcome']?.toString(),
      ),
      ownerUserId: IpModelUtils.requiredString(data['ownerUserId']),
      decisionSummary: IpModelUtils.nullableString(data['decisionSummary']),
      rationale: IpModelUtils.nullableString(data['rationale']),
      conditions: IpModelUtils.nullableString(data['conditions']),
      dissentingOpinion: IpModelUtils.nullableString(data['dissentingOpinion']),
      rejectionReason: IpModelUtils.nullableString(data['rejectionReason']),
      suspensionReason: IpModelUtils.nullableString(data['suspensionReason']),
      revocationReason: IpModelUtils.nullableString(data['revocationReason']),
      supersededByDecisionId: IpModelUtils.nullableString(
        data['supersededByDecisionId'],
      ),
      previousOwnerUserId: IpModelUtils.nullableString(
        data['previousOwnerUserId'],
      ),
      newOwnerUserId: IpModelUtils.nullableString(data['newOwnerUserId']),
      previousProtectionLevel: IpModelUtils.nullableString(
        data['previousProtectionLevel'],
      ),
      newProtectionLevel: IpModelUtils.nullableString(
        data['newProtectionLevel'],
      ),
      requestedBudgetAmount: data['requestedBudgetAmount'] is num
          ? data['requestedBudgetAmount'] as num
          : null,
      approvedBudgetAmount: data['approvedBudgetAmount'] is num
          ? data['approvedBudgetAmount'] as num
          : null,
      currencyCode: IpModelUtils.nullableString(data['currencyCode']),
      requiredApprovalCount: _nonNegativeInt(
        data['requiredApprovalCount'],
        fallback: 1,
      ),
      riskAcceptance: data['riskAcceptance'] == true,
      conditionalDecision: data['conditionalDecision'] == true,
      conditionsSatisfied: data['conditionsSatisfied'] == true,
      legalReviewRequired: data['legalReviewRequired'] == true,
      securityReviewRequired: data['securityReviewRequired'] == true,
      financeReviewRequired: data['financeReviewRequired'] == true,
      boardReviewRequired: data['boardReviewRequired'] == true,
      reassessmentRequired: data['reassessmentRequired'] == true,
      decisionAt: IpModelUtils.dateTimeFromValue(data['decisionAt']),
      effectiveAt: IpModelUtils.dateTimeFromValue(data['effectiveAt']),
      expiresAt: IpModelUtils.dateTimeFromValue(data['expiresAt']),
      reassessmentAt: IpModelUtils.dateTimeFromValue(data['reassessmentAt']),
      conditionsSatisfiedAt: IpModelUtils.dateTimeFromValue(
        data['conditionsSatisfiedAt'],
      ),
      suspendedAt: IpModelUtils.dateTimeFromValue(data['suspendedAt']),
      revokedAt: IpModelUtils.dateTimeFromValue(data['revokedAt']),
      expiredAt: IpModelUtils.dateTimeFromValue(data['expiredAt']),
      supersededAt: IpModelUtils.dateTimeFromValue(data['supersededAt']),
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
      'riskAssessmentIds': _cleanList(riskAssessmentIds),
      'disclosureIds': _cleanList(disclosureIds),
      'incidentIds': _cleanList(incidentIds),
      'protectionControlIds': _cleanList(protectionControlIds),
      'resilienceProfileIds': _cleanList(resilienceProfileIds),
      'defensibilityRecordIds': _cleanList(defensibilityRecordIds),
      'lifecycleTransitionIds': _cleanList(lifecycleTransitionIds),
      'remediationActionIds': _cleanList(remediationActionIds),
      'alertRuleIds': _cleanList(alertRuleIds),
      'evidenceDocumentIds': _cleanList(evidenceDocumentIds),
      'reviewerUserIds': _cleanList(reviewerUserIds),
      'approverUserIds': _cleanList(approverUserIds),
      'approvedUserIds': _cleanList(approvedUserIds),
      'rejectedUserIds': _cleanList(rejectedUserIds),
      'abstainedUserIds': _cleanList(abstainedUserIds),
      'recusedUserIds': _cleanList(recusedUserIds),
      'decisionCode': decisionCode.trim(),
      'title': title.trim(),
      'status': status.value,
      'decisionType': decisionType.value,
      'votingMethod': votingMethod.value,
      'approvalOutcome': approvalOutcome.value,
      'ownerUserId': ownerUserId.trim(),
      'decisionSummary': IpModelUtils.cleanNullable(decisionSummary),
      'rationale': IpModelUtils.cleanNullable(rationale),
      'conditions': IpModelUtils.cleanNullable(conditions),
      'dissentingOpinion': IpModelUtils.cleanNullable(dissentingOpinion),
      'rejectionReason': IpModelUtils.cleanNullable(rejectionReason),
      'suspensionReason': IpModelUtils.cleanNullable(suspensionReason),
      'revocationReason': IpModelUtils.cleanNullable(revocationReason),
      'supersededByDecisionId': IpModelUtils.cleanNullable(
        supersededByDecisionId,
      ),
      'previousOwnerUserId': IpModelUtils.cleanNullable(previousOwnerUserId),
      'newOwnerUserId': IpModelUtils.cleanNullable(newOwnerUserId),
      'previousProtectionLevel': IpModelUtils.cleanNullable(
        previousProtectionLevel,
      ),
      'newProtectionLevel': IpModelUtils.cleanNullable(newProtectionLevel),
      'requestedBudgetAmount': _validatedAmount(
        requestedBudgetAmount,
        'requestedBudgetAmount',
      ),
      'approvedBudgetAmount': _validatedAmount(
        approvedBudgetAmount,
        'approvedBudgetAmount',
      ),
      'currencyCode': IpModelUtils.cleanNullable(currencyCode),
      'requiredApprovalCount': requiredApprovalCount,
      'riskAcceptance': riskAcceptance,
      'conditionalDecision': conditionalDecision,
      'conditionsSatisfied': conditionsSatisfied,
      'legalReviewRequired': legalReviewRequired,
      'securityReviewRequired': securityReviewRequired,
      'financeReviewRequired': financeReviewRequired,
      'boardReviewRequired': boardReviewRequired,
      'reassessmentRequired': reassessmentRequired,
      'decisionAt': IpModelUtils.timestampOrNull(decisionAt),
      'effectiveAt': IpModelUtils.timestampOrNull(effectiveAt),
      'expiresAt': IpModelUtils.timestampOrNull(expiresAt),
      'reassessmentAt': IpModelUtils.timestampOrNull(reassessmentAt),
      'conditionsSatisfiedAt': IpModelUtils.timestampOrNull(
        conditionsSatisfiedAt,
      ),
      'suspendedAt': IpModelUtils.timestampOrNull(suspendedAt),
      'revokedAt': IpModelUtils.timestampOrNull(revokedAt),
      'expiredAt': IpModelUtils.timestampOrNull(expiredAt),
      'supersededAt': IpModelUtils.timestampOrNull(supersededAt),
      'notes': IpModelUtils.cleanNullable(notes),
      'metadata': Map<String, dynamic>.from(metadata),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy.trim(),
      'updatedAt': IpModelUtils.timestampOrNull(updatedAt),
      'updatedBy': IpModelUtils.cleanNullable(updatedBy),
    };
  }

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        brandId.trim().isNotEmpty &&
        tradeSecretId.trim().isNotEmpty &&
        decisionCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        ownerUserId.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get hasQuorum {
    return approvedUserIds.length >= requiredApprovalCount;
  }

  bool get hasDissent {
    return rejectedUserIds.isNotEmpty ||
        (dissentingOpinion != null && dissentingOpinion!.trim().isNotEmpty);
  }

  bool get isRiskAcceptanceDecision {
    return decisionType == IpTradeSecretDecisionType.riskAcceptance ||
        riskAcceptance;
  }

  bool get requiresReassessment {
    final reviewDate = reassessmentAt;
    return reassessmentRequired &&
        reviewDate != null &&
        reviewDate.isBefore(DateTime.now().toUtc());
  }

  bool get shouldAppearOnDecisionDashboard {
    return status == IpTradeSecretDecisionStatus.underReview ||
        status == IpTradeSecretDecisionStatus.pendingApproval ||
        status == IpTradeSecretDecisionStatus.conditionallyApproved ||
        status == IpTradeSecretDecisionStatus.suspended ||
        requiresReassessment;
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır yönetim kararının zorunlu kimlik alanları eksik.',
      );
    }

    if (requiredApprovalCount <= 0) {
      throw StateError('Gerekli onay sayısı sıfırdan büyük olmalıdır.');
    }

    if (approverUserIds.length < requiredApprovalCount) {
      throw StateError('Onaylayan sayısı gerekli onay sayısından az olamaz.');
    }

    final allVoteIds = <String>[
      ...approvedUserIds,
      ...rejectedUserIds,
      ...abstainedUserIds,
      ...recusedUserIds,
    ];

    if (allVoteIds.toSet().length != allVoteIds.length) {
      throw StateError(
        'Bir kullanıcı birden fazla oy sonucu listesinde bulunamaz.',
      );
    }

    if (status == IpTradeSecretDecisionStatus.approved &&
        (!hasQuorum ||
            approvalOutcome != IpTradeSecretApprovalOutcome.approved ||
            decisionAt == null)) {
      throw StateError(
        'Onaylanan kararda yeterli onay, onay sonucu ve karar tarihi zorunludur.',
      );
    }

    if (status == IpTradeSecretDecisionStatus.conditionallyApproved &&
        (!hasQuorum ||
            !conditionalDecision ||
            conditions == null ||
            conditions!.trim().isEmpty ||
            decisionAt == null)) {
      throw StateError(
        'Koşullu onayda yeterli onay, koşullar ve karar tarihi zorunludur.',
      );
    }

    if (conditionsSatisfied &&
        (!conditionalDecision || conditionsSatisfiedAt == null)) {
      throw StateError(
        'Koşullar karşılandıysa koşullu karar ve karşılama tarihi zorunludur.',
      );
    }

    if (status == IpTradeSecretDecisionStatus.rejected &&
        (approvalOutcome != IpTradeSecretApprovalOutcome.rejected ||
            rejectionReason == null ||
            rejectionReason!.trim().isEmpty ||
            decisionAt == null)) {
      throw StateError(
        'Reddedilen kararda ret sonucu, gerekçe ve karar tarihi zorunludur.',
      );
    }

    if (status == IpTradeSecretDecisionStatus.effective &&
        (effectiveAt == null ||
            decisionAt == null ||
            (conditionalDecision && !conditionsSatisfied))) {
      throw StateError(
        'Yürürlükteki kararda karar ve yürürlük tarihi ile koşul tamamlanması zorunludur.',
      );
    }

    if (status == IpTradeSecretDecisionStatus.suspended &&
        (suspendedAt == null ||
            suspensionReason == null ||
            suspensionReason!.trim().isEmpty)) {
      throw StateError('Askıya alınan kararda tarih ve gerekçe zorunludur.');
    }

    if (status == IpTradeSecretDecisionStatus.revoked &&
        (revokedAt == null ||
            revocationReason == null ||
            revocationReason!.trim().isEmpty)) {
      throw StateError('İptal edilen kararda tarih ve gerekçe zorunludur.');
    }

    if (status == IpTradeSecretDecisionStatus.expired && expiredAt == null) {
      throw StateError('Süresi dolan kararda sona erme tarihi zorunludur.');
    }

    if (status == IpTradeSecretDecisionStatus.superseded &&
        (supersededAt == null ||
            supersededByDecisionId == null ||
            supersededByDecisionId!.trim().isEmpty)) {
      throw StateError(
        'Yerine yeni karar geçen kayıtta tarih ve yeni karar kimliği zorunludur.',
      );
    }

    if (decisionType == IpTradeSecretDecisionType.riskAcceptance &&
        (!riskAcceptance ||
            rationale == null ||
            rationale!.trim().isEmpty ||
            riskAssessmentIds.isEmpty ||
            reassessmentAt == null)) {
      throw StateError(
        'Risk kabulünde gerekçe, risk kaydı ve yeniden değerlendirme tarihi zorunludur.',
      );
    }

    if ((decisionType == IpTradeSecretDecisionType.ownershipTransfer ||
            decisionType == IpTradeSecretDecisionType.responsibilityTransfer) &&
        (previousOwnerUserId == null ||
            previousOwnerUserId!.trim().isEmpty ||
            newOwnerUserId == null ||
            newOwnerUserId!.trim().isEmpty ||
            previousOwnerUserId!.trim() == newOwnerUserId!.trim())) {
      throw StateError(
        'Devir kararında farklı eski ve yeni sorumlu zorunludur.',
      );
    }

    if ((decisionType == IpTradeSecretDecisionType.protectionLevelIncrease ||
            decisionType ==
                IpTradeSecretDecisionType.protectionLevelReduction) &&
        (previousProtectionLevel == null ||
            previousProtectionLevel!.trim().isEmpty ||
            newProtectionLevel == null ||
            newProtectionLevel!.trim().isEmpty ||
            previousProtectionLevel!.trim() == newProtectionLevel!.trim())) {
      throw StateError(
        'Koruma seviyesi kararında farklı eski ve yeni seviye zorunludur.',
      );
    }

    final hasBudget =
        requestedBudgetAmount != null || approvedBudgetAmount != null;

    if (hasBudget &&
        (currencyCode == null || currencyCode!.trim().length != 3)) {
      throw StateError(
        'Bütçe bilgisi varsa üç harfli para birimi kodu zorunludur.',
      );
    }

    _validatedAmount(requestedBudgetAmount, 'requestedBudgetAmount');
    _validatedAmount(approvedBudgetAmount, 'approvedBudgetAmount');

    if (decisionType == IpTradeSecretDecisionType.budgetApproval &&
        approvedBudgetAmount == null) {
      throw StateError(
        'Bütçe onayı kararında onaylanan bütçe tutarı zorunludur.',
      );
    }

    if (reassessmentRequired && reassessmentAt == null) {
      throw StateError(
        'Yeniden değerlendirme gereken kararda tarih zorunludur.',
      );
    }

    if (expiresAt != null &&
        effectiveAt != null &&
        expiresAt!.isBefore(effectiveAt!)) {
      throw StateError('Sona erme tarihi yürürlük tarihinden önce olamaz.');
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

  static int _nonNegativeInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value < 0 ? fallback : value;
    }

    if (value is num) {
      final rounded = value.round();
      return rounded < 0 ? fallback : rounded;
    }

    return fallback;
  }

  static num? _validatedAmount(num? value, String fieldName) {
    if (value != null && value < 0) {
      throw RangeError.value(value, fieldName, '$fieldName negatif olamaz.');
    }

    return value;
  }
}
