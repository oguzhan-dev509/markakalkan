import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretRiskAssessmentModel {
  const IpTradeSecretRiskAssessmentModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.assessmentCode,
    required this.title,
    required this.status,
    required this.riskLevel,
    required this.threatCategory,
    required this.gapStatus,
    required this.ownerUserId,
    required this.assessorUserId,
    required this.assessedAt,
    required this.createdAt,
    required this.createdBy,
    this.componentIds = const <String>[],
    this.protectionControlIds = const <String>[],
    this.relatedIncidentIds = const <String>[],
    this.relatedDisclosureIds = const <String>[],
    this.relatedAccessGrantIds = const <String>[],
    this.relatedDocumentIds = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.ownerDepartmentId,
    this.approverUserId,
    this.threatDescription,
    this.vulnerabilityDescription,
    this.existingControlDescription,
    this.impactDescription,
    this.gapDescription,
    this.assumptions,
    this.treatmentPlan,
    this.riskAcceptanceReason,
    this.treatmentOwnerUserId,
    this.riskAcceptedBy,
    this.assetValueScore = 0,
    this.threatLikelihoodScore = 0,
    this.vulnerabilityScore = 0,
    this.controlEffectivenessScore = 0,
    this.inherentRiskScore = 0,
    this.residualRiskScore = 0,
    this.gapScore = 0,
    this.priorityScore = 0,
    this.financialExposureAmount,
    this.financialExposureCurrency,
    this.actionRequired = false,
    this.riskAccepted = false,
    this.radarEligible = false,
    this.escalated = false,
    this.externalPartyInvolved = false,
    this.crossBorderImpact = false,
    this.businessContinuityImpact = false,
    this.legalImpact = false,
    this.reputationImpact = false,
    this.approvedAt,
    this.nextReviewAt,
    this.treatmentDueAt,
    this.treatmentCompletedAt,
    this.riskAcceptedAt,
    this.closedAt,
    this.escalatedAt,
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
  final List<String> protectionControlIds;
  final List<String> relatedIncidentIds;
  final List<String> relatedDisclosureIds;
  final List<String> relatedAccessGrantIds;
  final List<String> relatedDocumentIds;
  final List<String> evidenceDocumentIds;

  final String assessmentCode;
  final String title;

  final IpTradeSecretRiskAssessmentStatus status;
  final IpTradeSecretRiskLevel riskLevel;
  final IpTradeSecretThreatCategory threatCategory;
  final IpTradeSecretGapStatus gapStatus;

  final String ownerUserId;
  final String assessorUserId;
  final String? ownerDepartmentId;
  final String? approverUserId;

  final String? threatDescription;
  final String? vulnerabilityDescription;
  final String? existingControlDescription;
  final String? impactDescription;
  final String? gapDescription;
  final String? assumptions;

  final String? treatmentPlan;
  final String? treatmentOwnerUserId;

  final String? riskAcceptanceReason;
  final String? riskAcceptedBy;

  final int assetValueScore;
  final int threatLikelihoodScore;
  final int vulnerabilityScore;
  final int controlEffectivenessScore;
  final int inherentRiskScore;
  final int residualRiskScore;
  final int gapScore;
  final int priorityScore;

  final double? financialExposureAmount;
  final String? financialExposureCurrency;

  final bool actionRequired;
  final bool riskAccepted;
  final bool radarEligible;
  final bool escalated;

  final bool externalPartyInvolved;
  final bool crossBorderImpact;
  final bool businessContinuityImpact;
  final bool legalImpact;
  final bool reputationImpact;

  final DateTime assessedAt;
  final DateTime? approvedAt;
  final DateTime? nextReviewAt;
  final DateTime? treatmentDueAt;
  final DateTime? treatmentCompletedAt;
  final DateTime? riskAcceptedAt;
  final DateTime? closedAt;
  final DateTime? escalatedAt;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretRiskAssessmentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır risk değerlendirmesi veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretRiskAssessmentModel.fromMap(
      id: document.id,
      data: data,
    );
  }

  factory IpTradeSecretRiskAssessmentModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final assessedAt = IpModelUtils.dateTimeFromValue(data['assessedAt']);

    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (assessedAt == null) {
      throw StateError('Risk değerlendirme tarihi eksik: $id');
    }

    if (createdAt == null) {
      throw StateError('Risk değerlendirme oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretRiskAssessmentModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.requiredString(data['tradeSecretId']),
      componentIds: _stringList(data['componentIds']),
      protectionControlIds: _stringList(data['protectionControlIds']),
      relatedIncidentIds: _stringList(data['relatedIncidentIds']),
      relatedDisclosureIds: _stringList(data['relatedDisclosureIds']),
      relatedAccessGrantIds: _stringList(data['relatedAccessGrantIds']),
      relatedDocumentIds: _stringList(data['relatedDocumentIds']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      assessmentCode: IpModelUtils.requiredString(data['assessmentCode']),
      title: IpModelUtils.requiredString(data['title']),
      status: IpTradeSecretRiskAssessmentStatus.fromValue(
        data['status']?.toString(),
      ),
      riskLevel: IpTradeSecretRiskLevel.fromValue(
        data['riskLevel']?.toString(),
      ),
      threatCategory: IpTradeSecretThreatCategory.fromValue(
        data['threatCategory']?.toString(),
      ),
      gapStatus: IpTradeSecretGapStatus.fromValue(
        data['gapStatus']?.toString(),
      ),
      ownerUserId: IpModelUtils.requiredString(data['ownerUserId']),
      assessorUserId: IpModelUtils.requiredString(data['assessorUserId']),
      ownerDepartmentId: IpModelUtils.nullableString(data['ownerDepartmentId']),
      approverUserId: IpModelUtils.nullableString(data['approverUserId']),
      threatDescription: IpModelUtils.nullableString(data['threatDescription']),
      vulnerabilityDescription: IpModelUtils.nullableString(
        data['vulnerabilityDescription'],
      ),
      existingControlDescription: IpModelUtils.nullableString(
        data['existingControlDescription'],
      ),
      impactDescription: IpModelUtils.nullableString(data['impactDescription']),
      gapDescription: IpModelUtils.nullableString(data['gapDescription']),
      assumptions: IpModelUtils.nullableString(data['assumptions']),
      treatmentPlan: IpModelUtils.nullableString(data['treatmentPlan']),
      treatmentOwnerUserId: IpModelUtils.nullableString(
        data['treatmentOwnerUserId'],
      ),
      riskAcceptanceReason: IpModelUtils.nullableString(
        data['riskAcceptanceReason'],
      ),
      riskAcceptedBy: IpModelUtils.nullableString(data['riskAcceptedBy']),
      assetValueScore: _score(data['assetValueScore']),
      threatLikelihoodScore: _score(data['threatLikelihoodScore']),
      vulnerabilityScore: _score(data['vulnerabilityScore']),
      controlEffectivenessScore: _score(data['controlEffectivenessScore']),
      inherentRiskScore: _score(data['inherentRiskScore']),
      residualRiskScore: _score(data['residualRiskScore']),
      gapScore: _score(data['gapScore']),
      priorityScore: _score(data['priorityScore']),
      financialExposureAmount: _nullableDouble(data['financialExposureAmount']),
      financialExposureCurrency: IpModelUtils.nullableString(
        data['financialExposureCurrency'],
      ),
      actionRequired: data['actionRequired'] == true,
      riskAccepted: data['riskAccepted'] == true,
      radarEligible: data['radarEligible'] == true,
      escalated: data['escalated'] == true,
      externalPartyInvolved: data['externalPartyInvolved'] == true,
      crossBorderImpact: data['crossBorderImpact'] == true,
      businessContinuityImpact: data['businessContinuityImpact'] == true,
      legalImpact: data['legalImpact'] == true,
      reputationImpact: data['reputationImpact'] == true,
      assessedAt: assessedAt,
      approvedAt: IpModelUtils.dateTimeFromValue(data['approvedAt']),
      nextReviewAt: IpModelUtils.dateTimeFromValue(data['nextReviewAt']),
      treatmentDueAt: IpModelUtils.dateTimeFromValue(data['treatmentDueAt']),
      treatmentCompletedAt: IpModelUtils.dateTimeFromValue(
        data['treatmentCompletedAt'],
      ),
      riskAcceptedAt: IpModelUtils.dateTimeFromValue(data['riskAcceptedAt']),
      closedAt: IpModelUtils.dateTimeFromValue(data['closedAt']),
      escalatedAt: IpModelUtils.dateTimeFromValue(data['escalatedAt']),
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
      'protectionControlIds': _cleanList(protectionControlIds),
      'relatedIncidentIds': _cleanList(relatedIncidentIds),
      'relatedDisclosureIds': _cleanList(relatedDisclosureIds),
      'relatedAccessGrantIds': _cleanList(relatedAccessGrantIds),
      'relatedDocumentIds': _cleanList(relatedDocumentIds),
      'evidenceDocumentIds': _cleanList(evidenceDocumentIds),
      'assessmentCode': assessmentCode.trim(),
      'title': title.trim(),
      'status': status.value,
      'riskLevel': riskLevel.value,
      'threatCategory': threatCategory.value,
      'gapStatus': gapStatus.value,
      'ownerUserId': ownerUserId.trim(),
      'assessorUserId': assessorUserId.trim(),
      'ownerDepartmentId': IpModelUtils.cleanNullable(ownerDepartmentId),
      'approverUserId': IpModelUtils.cleanNullable(approverUserId),
      'threatDescription': IpModelUtils.cleanNullable(threatDescription),
      'vulnerabilityDescription': IpModelUtils.cleanNullable(
        vulnerabilityDescription,
      ),
      'existingControlDescription': IpModelUtils.cleanNullable(
        existingControlDescription,
      ),
      'impactDescription': IpModelUtils.cleanNullable(impactDescription),
      'gapDescription': IpModelUtils.cleanNullable(gapDescription),
      'assumptions': IpModelUtils.cleanNullable(assumptions),
      'treatmentPlan': IpModelUtils.cleanNullable(treatmentPlan),
      'treatmentOwnerUserId': IpModelUtils.cleanNullable(treatmentOwnerUserId),
      'riskAcceptanceReason': IpModelUtils.cleanNullable(riskAcceptanceReason),
      'riskAcceptedBy': IpModelUtils.cleanNullable(riskAcceptedBy),
      'assetValueScore': _validatedScore(assetValueScore, 'assetValueScore'),
      'threatLikelihoodScore': _validatedScore(
        threatLikelihoodScore,
        'threatLikelihoodScore',
      ),
      'vulnerabilityScore': _validatedScore(
        vulnerabilityScore,
        'vulnerabilityScore',
      ),
      'controlEffectivenessScore': _validatedScore(
        controlEffectivenessScore,
        'controlEffectivenessScore',
      ),
      'inherentRiskScore': _validatedScore(
        inherentRiskScore,
        'inherentRiskScore',
      ),
      'residualRiskScore': _validatedScore(
        residualRiskScore,
        'residualRiskScore',
      ),
      'gapScore': _validatedScore(gapScore, 'gapScore'),
      'priorityScore': _validatedScore(priorityScore, 'priorityScore'),
      'financialExposureAmount': financialExposureAmount,
      'financialExposureCurrency': IpModelUtils.cleanNullable(
        financialExposureCurrency,
      ),
      'actionRequired': actionRequired,
      'riskAccepted': riskAccepted,
      'radarEligible': radarEligible,
      'escalated': escalated,
      'externalPartyInvolved': externalPartyInvolved,
      'crossBorderImpact': crossBorderImpact,
      'businessContinuityImpact': businessContinuityImpact,
      'legalImpact': legalImpact,
      'reputationImpact': reputationImpact,
      'assessedAt': Timestamp.fromDate(assessedAt),
      'approvedAt': IpModelUtils.timestampOrNull(approvedAt),
      'nextReviewAt': IpModelUtils.timestampOrNull(nextReviewAt),
      'treatmentDueAt': IpModelUtils.timestampOrNull(treatmentDueAt),
      'treatmentCompletedAt': IpModelUtils.timestampOrNull(
        treatmentCompletedAt,
      ),
      'riskAcceptedAt': IpModelUtils.timestampOrNull(riskAcceptedAt),
      'closedAt': IpModelUtils.timestampOrNull(closedAt),
      'escalatedAt': IpModelUtils.timestampOrNull(escalatedAt),
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
    map.remove('assessmentCode');
    map.remove('assessedAt');
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
        assessmentCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        ownerUserId.trim().isNotEmpty &&
        assessorUserId.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get hasProtectionGap {
    return gapStatus != IpTradeSecretGapStatus.none &&
        gapStatus != IpTradeSecretGapStatus.mitigated &&
        gapStatus != IpTradeSecretGapStatus.closed;
  }

  bool get isCritical {
    return riskLevel == IpTradeSecretRiskLevel.critical ||
        residualRiskScore >= 90 ||
        priorityScore >= 90;
  }

  bool get requiresImmediateEscalation {
    return isCritical ||
        riskLevel == IpTradeSecretRiskLevel.high ||
        residualRiskScore >= 80 ||
        gapScore >= 80 ||
        businessContinuityImpact ||
        legalImpact ||
        reputationImpact;
  }

  bool get shouldAppearOnGapRadar {
    return radarEligible &&
        hasProtectionGap &&
        (gapScore >= 50 || residualRiskScore >= 60 || priorityScore >= 60);
  }

  bool get isTreatmentOverdue {
    final dueAt = treatmentDueAt;

    return actionRequired &&
        dueAt != null &&
        dueAt.isBefore(DateTime.now().toUtc()) &&
        treatmentCompletedAt == null;
  }

  bool get requiresImmediateReview {
    return requiresImmediateEscalation ||
        isTreatmentOverdue ||
        gapStatus == IpTradeSecretGapStatus.overdue ||
        (nextReviewAt?.isBefore(DateTime.now().toUtc()) == true);
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır risk değerlendirmesinin zorunlu kimlik alanları eksik.',
      );
    }

    _validatedScore(assetValueScore, 'assetValueScore');
    _validatedScore(threatLikelihoodScore, 'threatLikelihoodScore');
    _validatedScore(vulnerabilityScore, 'vulnerabilityScore');
    _validatedScore(controlEffectivenessScore, 'controlEffectivenessScore');
    _validatedScore(inherentRiskScore, 'inherentRiskScore');
    _validatedScore(residualRiskScore, 'residualRiskScore');
    _validatedScore(gapScore, 'gapScore');
    _validatedScore(priorityScore, 'priorityScore');

    if (residualRiskScore > inherentRiskScore &&
        controlEffectivenessScore > 0) {
      throw StateError(
        'Kontrol etkinliği bulunan değerlendirmede artık risk '
        'doğal riskten yüksek olamaz.',
      );
    }

    if (status == IpTradeSecretRiskAssessmentStatus.approved &&
        (approverUserId == null ||
            approverUserId!.trim().isEmpty ||
            approvedAt == null)) {
      throw StateError(
        'Onaylanan değerlendirmede onaylayan ve onay tarihi zorunludur.',
      );
    }

    if (gapStatus == IpTradeSecretGapStatus.none &&
        (gapScore > 0 || actionRequired)) {
      throw StateError(
        'Koruma açığı yoksa açık skoru ve aksiyon gereksinimi olamaz.',
      );
    }

    if (hasProtectionGap &&
        (gapDescription == null || gapDescription!.trim().isEmpty)) {
      throw StateError(
        'Koruma açığı bulunan değerlendirmede açık açıklaması zorunludur.',
      );
    }

    if (actionRequired &&
        (treatmentPlan == null ||
            treatmentPlan!.trim().isEmpty ||
            treatmentOwnerUserId == null ||
            treatmentOwnerUserId!.trim().isEmpty ||
            treatmentDueAt == null)) {
      throw StateError(
        'Aksiyon gerekiyorsa plan, sorumlu ve hedef tarih zorunludur.',
      );
    }

    if (treatmentCompletedAt != null && actionRequired) {
      throw StateError(
        'İyileştirme tamamlandıysa actionRequired false olmalıdır.',
      );
    }

    if (riskAccepted &&
        (riskAcceptanceReason == null ||
            riskAcceptanceReason!.trim().isEmpty ||
            riskAcceptedBy == null ||
            riskAcceptedBy!.trim().isEmpty ||
            riskAcceptedAt == null)) {
      throw StateError(
        'Risk kabulünde gerekçe, kabul eden ve kabul tarihi zorunludur.',
      );
    }

    if (status == IpTradeSecretRiskAssessmentStatus.accepted && !riskAccepted) {
      throw StateError(
        'Kabul edilmiş durumdaki değerlendirmede riskAccepted true olmalıdır.',
      );
    }

    if (gapStatus == IpTradeSecretGapStatus.accepted && !riskAccepted) {
      throw StateError(
        'Kabul edilen koruma açığında risk kabul bilgileri zorunludur.',
      );
    }

    if (status == IpTradeSecretRiskAssessmentStatus.closed &&
        (closedAt == null ||
            actionRequired ||
            !{
              IpTradeSecretGapStatus.none,
              IpTradeSecretGapStatus.mitigated,
              IpTradeSecretGapStatus.closed,
              IpTradeSecretGapStatus.accepted,
            }.contains(gapStatus))) {
      throw StateError(
        'Kapatılan değerlendirmede kapanış tarihi bulunmalı ve açık '
        'sonuçlandırılmış olmalıdır.',
      );
    }

    if (escalated && escalatedAt == null) {
      throw StateError('Yükseltilen riskte yükseltme tarihi zorunludur.');
    }

    final exposureAmount = financialExposureAmount;

    if (exposureAmount != null && exposureAmount < 0) {
      throw RangeError.value(
        exposureAmount,
        'financialExposureAmount',
        'Finansal maruziyet negatif olamaz.',
      );
    }

    if (exposureAmount != null &&
        (financialExposureCurrency == null ||
            financialExposureCurrency!.trim().isEmpty)) {
      throw StateError('Finansal maruziyet varsa para birimi zorunludur.');
    }

    if (approvedAt != null && approvedAt!.isBefore(assessedAt)) {
      throw StateError('Onay tarihi değerlendirme tarihinden önce olamaz.');
    }

    if (treatmentCompletedAt != null &&
        treatmentCompletedAt!.isBefore(assessedAt)) {
      throw StateError(
        'İyileştirme tamamlanma tarihi değerlendirme tarihinden önce olamaz.',
      );
    }

    if (closedAt != null && closedAt!.isBefore(assessedAt)) {
      throw StateError('Kapanış tarihi değerlendirme tarihinden önce olamaz.');
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

  static int _score(Object? value) {
    if (value is int) {
      return value.clamp(0, 100);
    }

    if (value is num) {
      return value.round().clamp(0, 100);
    }

    return 0;
  }

  static double? _nullableDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
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
