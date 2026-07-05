import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretDefensibilityRecordModel {
  const IpTradeSecretDefensibilityRecordModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.recordCode,
    required this.title,
    required this.status,
    required this.legalReadinessLevel,
    required this.primaryEvidenceCategory,
    required this.evidenceStrength,
    required this.ownerUserId,
    required this.reviewerUserId,
    required this.assessedAt,
    required this.createdAt,
    required this.createdBy,
    this.componentIds = const <String>[],
    this.accessGrantIds = const <String>[],
    this.disclosureIds = const <String>[],
    this.incidentIds = const <String>[],
    this.protectionControlIds = const <String>[],
    this.riskAssessmentIds = const <String>[],
    this.resilienceProfileIds = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.evidenceCategories = const <IpTradeSecretEvidenceCategory>[],
    this.ownerDepartmentId,
    this.approverUserId,
    this.evidenceSource,
    this.evidenceHash,
    this.hashAlgorithm,
    this.chainOfCustodyReference,
    this.storageLocationReference,
    this.retentionPolicyReference,
    this.jurisdictionCode,
    this.summary,
    this.gapDescription,
    this.remediationPlan,
    this.remediationOwnerUserId,
    this.evidenceCompletenessScore = 0,
    this.evidenceFreshnessScore = 0,
    this.controlTraceabilityScore = 0,
    this.ownershipProofScore = 0,
    this.confidentialityProofScore = 0,
    this.accessProofScore = 0,
    this.contractualProofScore = 0,
    this.incidentResponseProofScore = 0,
    this.overallDefensibilityScore = 0,
    this.criticalEvidenceGapCount = 0,
    this.expiredEvidenceCount = 0,
    this.unverifiedEvidenceCount = 0,
    this.remediationRequired = false,
    this.managementEscalationRequired = false,
    this.litigationHold = false,
    this.chainOfCustodyVerified = false,
    this.evidenceIntegrityVerified = false,
    this.crossBorderEvidence = false,
    this.thirdPartyEvidence = false,
    this.approvedAt,
    this.nextReviewAt,
    this.evidenceValidUntil,
    this.remediationDueAt,
    this.remediationCompletedAt,
    this.escalatedAt,
    this.litigationHoldAt,
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
  final List<String> evidenceDocumentIds;
  final List<IpTradeSecretEvidenceCategory> evidenceCategories;

  final String recordCode;
  final String title;

  final IpTradeSecretDefensibilityStatus status;
  final IpTradeSecretLegalReadinessLevel legalReadinessLevel;
  final IpTradeSecretEvidenceCategory primaryEvidenceCategory;
  final IpTradeSecretEvidenceStrength evidenceStrength;

  final String ownerUserId;
  final String reviewerUserId;
  final String? ownerDepartmentId;
  final String? approverUserId;

  final String? evidenceSource;
  final String? evidenceHash;
  final String? hashAlgorithm;
  final String? chainOfCustodyReference;
  final String? storageLocationReference;
  final String? retentionPolicyReference;
  final String? jurisdictionCode;

  final String? summary;
  final String? gapDescription;
  final String? remediationPlan;
  final String? remediationOwnerUserId;

  final int evidenceCompletenessScore;
  final int evidenceFreshnessScore;
  final int controlTraceabilityScore;
  final int ownershipProofScore;
  final int confidentialityProofScore;
  final int accessProofScore;
  final int contractualProofScore;
  final int incidentResponseProofScore;
  final int overallDefensibilityScore;

  final int criticalEvidenceGapCount;
  final int expiredEvidenceCount;
  final int unverifiedEvidenceCount;

  final bool remediationRequired;
  final bool managementEscalationRequired;
  final bool litigationHold;
  final bool chainOfCustodyVerified;
  final bool evidenceIntegrityVerified;
  final bool crossBorderEvidence;
  final bool thirdPartyEvidence;

  final DateTime assessedAt;
  final DateTime? approvedAt;
  final DateTime? nextReviewAt;
  final DateTime? evidenceValidUntil;
  final DateTime? remediationDueAt;
  final DateTime? remediationCompletedAt;
  final DateTime? escalatedAt;
  final DateTime? litigationHoldAt;
  final DateTime? closedAt;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretDefensibilityRecordModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır savunulabilirlik kaydı veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretDefensibilityRecordModel.fromMap(
      id: document.id,
      data: data,
    );
  }

  factory IpTradeSecretDefensibilityRecordModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final assessedAt = IpModelUtils.dateTimeFromValue(data['assessedAt']);
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (assessedAt == null) {
      throw StateError('Savunulabilirlik değerlendirme tarihi eksik: $id');
    }

    if (createdAt == null) {
      throw StateError('Savunulabilirlik oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretDefensibilityRecordModel(
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
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      evidenceCategories: _evidenceCategoryList(data['evidenceCategories']),
      recordCode: IpModelUtils.requiredString(data['recordCode']),
      title: IpModelUtils.requiredString(data['title']),
      status: IpTradeSecretDefensibilityStatus.fromValue(
        data['status']?.toString(),
      ),
      legalReadinessLevel: IpTradeSecretLegalReadinessLevel.fromValue(
        data['legalReadinessLevel']?.toString(),
      ),
      primaryEvidenceCategory: IpTradeSecretEvidenceCategory.fromValue(
        data['primaryEvidenceCategory']?.toString(),
      ),
      evidenceStrength: IpTradeSecretEvidenceStrength.fromValue(
        data['evidenceStrength']?.toString(),
      ),
      ownerUserId: IpModelUtils.requiredString(data['ownerUserId']),
      reviewerUserId: IpModelUtils.requiredString(data['reviewerUserId']),
      ownerDepartmentId: IpModelUtils.nullableString(data['ownerDepartmentId']),
      approverUserId: IpModelUtils.nullableString(data['approverUserId']),
      evidenceSource: IpModelUtils.nullableString(data['evidenceSource']),
      evidenceHash: IpModelUtils.nullableString(data['evidenceHash']),
      hashAlgorithm: IpModelUtils.nullableString(data['hashAlgorithm']),
      chainOfCustodyReference: IpModelUtils.nullableString(
        data['chainOfCustodyReference'],
      ),
      storageLocationReference: IpModelUtils.nullableString(
        data['storageLocationReference'],
      ),
      retentionPolicyReference: IpModelUtils.nullableString(
        data['retentionPolicyReference'],
      ),
      jurisdictionCode: IpModelUtils.nullableString(data['jurisdictionCode']),
      summary: IpModelUtils.nullableString(data['summary']),
      gapDescription: IpModelUtils.nullableString(data['gapDescription']),
      remediationPlan: IpModelUtils.nullableString(data['remediationPlan']),
      remediationOwnerUserId: IpModelUtils.nullableString(
        data['remediationOwnerUserId'],
      ),
      evidenceCompletenessScore: _score(data['evidenceCompletenessScore']),
      evidenceFreshnessScore: _score(data['evidenceFreshnessScore']),
      controlTraceabilityScore: _score(data['controlTraceabilityScore']),
      ownershipProofScore: _score(data['ownershipProofScore']),
      confidentialityProofScore: _score(data['confidentialityProofScore']),
      accessProofScore: _score(data['accessProofScore']),
      contractualProofScore: _score(data['contractualProofScore']),
      incidentResponseProofScore: _score(data['incidentResponseProofScore']),
      overallDefensibilityScore: _score(data['overallDefensibilityScore']),
      criticalEvidenceGapCount: _nonNegativeInt(
        data['criticalEvidenceGapCount'],
      ),
      expiredEvidenceCount: _nonNegativeInt(data['expiredEvidenceCount']),
      unverifiedEvidenceCount: _nonNegativeInt(data['unverifiedEvidenceCount']),
      remediationRequired: data['remediationRequired'] == true,
      managementEscalationRequired:
          data['managementEscalationRequired'] == true,
      litigationHold: data['litigationHold'] == true,
      chainOfCustodyVerified: data['chainOfCustodyVerified'] == true,
      evidenceIntegrityVerified: data['evidenceIntegrityVerified'] == true,
      crossBorderEvidence: data['crossBorderEvidence'] == true,
      thirdPartyEvidence: data['thirdPartyEvidence'] == true,
      assessedAt: assessedAt,
      approvedAt: IpModelUtils.dateTimeFromValue(data['approvedAt']),
      nextReviewAt: IpModelUtils.dateTimeFromValue(data['nextReviewAt']),
      evidenceValidUntil: IpModelUtils.dateTimeFromValue(
        data['evidenceValidUntil'],
      ),
      remediationDueAt: IpModelUtils.dateTimeFromValue(
        data['remediationDueAt'],
      ),
      remediationCompletedAt: IpModelUtils.dateTimeFromValue(
        data['remediationCompletedAt'],
      ),
      escalatedAt: IpModelUtils.dateTimeFromValue(data['escalatedAt']),
      litigationHoldAt: IpModelUtils.dateTimeFromValue(
        data['litigationHoldAt'],
      ),
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
      'evidenceDocumentIds': _cleanList(evidenceDocumentIds),
      'evidenceCategories': evidenceCategories
          .map((item) => item.value)
          .toSet()
          .toList(),
      'recordCode': recordCode.trim(),
      'title': title.trim(),
      'status': status.value,
      'legalReadinessLevel': legalReadinessLevel.value,
      'primaryEvidenceCategory': primaryEvidenceCategory.value,
      'evidenceStrength': evidenceStrength.value,
      'ownerUserId': ownerUserId.trim(),
      'reviewerUserId': reviewerUserId.trim(),
      'ownerDepartmentId': IpModelUtils.cleanNullable(ownerDepartmentId),
      'approverUserId': IpModelUtils.cleanNullable(approverUserId),
      'evidenceSource': IpModelUtils.cleanNullable(evidenceSource),
      'evidenceHash': IpModelUtils.cleanNullable(evidenceHash),
      'hashAlgorithm': IpModelUtils.cleanNullable(hashAlgorithm),
      'chainOfCustodyReference': IpModelUtils.cleanNullable(
        chainOfCustodyReference,
      ),
      'storageLocationReference': IpModelUtils.cleanNullable(
        storageLocationReference,
      ),
      'retentionPolicyReference': IpModelUtils.cleanNullable(
        retentionPolicyReference,
      ),
      'jurisdictionCode': IpModelUtils.cleanNullable(jurisdictionCode),
      'summary': IpModelUtils.cleanNullable(summary),
      'gapDescription': IpModelUtils.cleanNullable(gapDescription),
      'remediationPlan': IpModelUtils.cleanNullable(remediationPlan),
      'remediationOwnerUserId': IpModelUtils.cleanNullable(
        remediationOwnerUserId,
      ),
      'evidenceCompletenessScore': _validatedScore(
        evidenceCompletenessScore,
        'evidenceCompletenessScore',
      ),
      'evidenceFreshnessScore': _validatedScore(
        evidenceFreshnessScore,
        'evidenceFreshnessScore',
      ),
      'controlTraceabilityScore': _validatedScore(
        controlTraceabilityScore,
        'controlTraceabilityScore',
      ),
      'ownershipProofScore': _validatedScore(
        ownershipProofScore,
        'ownershipProofScore',
      ),
      'confidentialityProofScore': _validatedScore(
        confidentialityProofScore,
        'confidentialityProofScore',
      ),
      'accessProofScore': _validatedScore(accessProofScore, 'accessProofScore'),
      'contractualProofScore': _validatedScore(
        contractualProofScore,
        'contractualProofScore',
      ),
      'incidentResponseProofScore': _validatedScore(
        incidentResponseProofScore,
        'incidentResponseProofScore',
      ),
      'overallDefensibilityScore': _validatedScore(
        overallDefensibilityScore,
        'overallDefensibilityScore',
      ),
      'criticalEvidenceGapCount': _validatedCount(
        criticalEvidenceGapCount,
        'criticalEvidenceGapCount',
      ),
      'expiredEvidenceCount': _validatedCount(
        expiredEvidenceCount,
        'expiredEvidenceCount',
      ),
      'unverifiedEvidenceCount': _validatedCount(
        unverifiedEvidenceCount,
        'unverifiedEvidenceCount',
      ),
      'remediationRequired': remediationRequired,
      'managementEscalationRequired': managementEscalationRequired,
      'litigationHold': litigationHold,
      'chainOfCustodyVerified': chainOfCustodyVerified,
      'evidenceIntegrityVerified': evidenceIntegrityVerified,
      'crossBorderEvidence': crossBorderEvidence,
      'thirdPartyEvidence': thirdPartyEvidence,
      'assessedAt': Timestamp.fromDate(assessedAt),
      'approvedAt': IpModelUtils.timestampOrNull(approvedAt),
      'nextReviewAt': IpModelUtils.timestampOrNull(nextReviewAt),
      'evidenceValidUntil': IpModelUtils.timestampOrNull(evidenceValidUntil),
      'remediationDueAt': IpModelUtils.timestampOrNull(remediationDueAt),
      'remediationCompletedAt': IpModelUtils.timestampOrNull(
        remediationCompletedAt,
      ),
      'escalatedAt': IpModelUtils.timestampOrNull(escalatedAt),
      'litigationHoldAt': IpModelUtils.timestampOrNull(litigationHoldAt),
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
    map.remove('recordCode');
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
        recordCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        ownerUserId.trim().isNotEmpty &&
        reviewerUserId.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get isEvidenceExpired {
    final validUntil = evidenceValidUntil;
    return validUntil != null && validUntil.isBefore(DateTime.now().toUtc());
  }

  bool get hasCriticalEvidenceGap {
    return criticalEvidenceGapCount > 0 ||
        evidenceCompletenessScore < 50 ||
        overallDefensibilityScore < 50 ||
        evidenceStrength == IpTradeSecretEvidenceStrength.none;
  }

  bool get isLitigationReady {
    return legalReadinessLevel ==
            IpTradeSecretLegalReadinessLevel.litigationReady &&
        overallDefensibilityScore >= 80 &&
        criticalEvidenceGapCount == 0 &&
        expiredEvidenceCount == 0 &&
        unverifiedEvidenceCount == 0 &&
        chainOfCustodyVerified &&
        evidenceIntegrityVerified;
  }

  bool get requiresImmediateEscalation {
    return managementEscalationRequired ||
        hasCriticalEvidenceGap ||
        litigationHold ||
        expiredEvidenceCount > 0 ||
        isRemediationOverdue;
  }

  bool get isRemediationOverdue {
    final dueAt = remediationDueAt;
    return remediationRequired &&
        dueAt != null &&
        dueAt.isBefore(DateTime.now().toUtc()) &&
        remediationCompletedAt == null;
  }

  bool get shouldAppearOnLegalDefenseDashboard {
    return status == IpTradeSecretDefensibilityStatus.active ||
        status == IpTradeSecretDefensibilityStatus.remediationRequired ||
        litigationHold ||
        remediationRequired ||
        hasCriticalEvidenceGap ||
        isEvidenceExpired;
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır savunulabilirlik kaydının zorunlu kimlik alanları eksik.',
      );
    }

    for (final entry in <String, int>{
      'evidenceCompletenessScore': evidenceCompletenessScore,
      'evidenceFreshnessScore': evidenceFreshnessScore,
      'controlTraceabilityScore': controlTraceabilityScore,
      'ownershipProofScore': ownershipProofScore,
      'confidentialityProofScore': confidentialityProofScore,
      'accessProofScore': accessProofScore,
      'contractualProofScore': contractualProofScore,
      'incidentResponseProofScore': incidentResponseProofScore,
      'overallDefensibilityScore': overallDefensibilityScore,
    }.entries) {
      _validatedScore(entry.value, entry.key);
    }

    for (final entry in <String, int>{
      'criticalEvidenceGapCount': criticalEvidenceGapCount,
      'expiredEvidenceCount': expiredEvidenceCount,
      'unverifiedEvidenceCount': unverifiedEvidenceCount,
    }.entries) {
      _validatedCount(entry.value, entry.key);
    }

    if (status == IpTradeSecretDefensibilityStatus.approved &&
        (approverUserId == null ||
            approverUserId!.trim().isEmpty ||
            approvedAt == null)) {
      throw StateError(
        'Onaylanan savunulabilirlik kaydında onaylayan ve onay tarihi zorunludur.',
      );
    }

    if (evidenceIntegrityVerified &&
        (evidenceHash == null ||
            evidenceHash!.trim().isEmpty ||
            hashAlgorithm == null ||
            hashAlgorithm!.trim().isEmpty)) {
      throw StateError(
        'Kanıt bütünlüğü doğrulanmışsa hash ve algoritma zorunludur.',
      );
    }

    if (chainOfCustodyVerified &&
        (chainOfCustodyReference == null ||
            chainOfCustodyReference!.trim().isEmpty)) {
      throw StateError(
        'Muhafaza zinciri doğrulanmışsa zincir referansı zorunludur.',
      );
    }

    if (remediationRequired &&
        (gapDescription == null ||
            gapDescription!.trim().isEmpty ||
            remediationPlan == null ||
            remediationPlan!.trim().isEmpty ||
            remediationOwnerUserId == null ||
            remediationOwnerUserId!.trim().isEmpty ||
            remediationDueAt == null)) {
      throw StateError(
        'Eksik giderme gerekiyorsa açık, plan, sorumlu ve hedef tarih zorunludur.',
      );
    }

    if (remediationCompletedAt != null && remediationRequired) {
      throw StateError(
        'Eksik giderme tamamlandıysa remediationRequired false olmalıdır.',
      );
    }

    if (managementEscalationRequired && escalatedAt == null) {
      throw StateError(
        'Yönetim yükseltmesi gereken kayıtta yükseltme tarihi zorunludur.',
      );
    }

    if (litigationHold && litigationHoldAt == null) {
      throw StateError('Hukuki muhafaza etkinse litigationHoldAt zorunludur.');
    }

    if (status == IpTradeSecretDefensibilityStatus.closed && closedAt == null) {
      throw StateError(
        'Kapatılan savunulabilirlik kaydında kapanış tarihi zorunludur.',
      );
    }

    if (approvedAt != null && approvedAt!.isBefore(assessedAt)) {
      throw StateError('Onay tarihi değerlendirme tarihinden önce olamaz.');
    }

    if (remediationCompletedAt != null &&
        remediationCompletedAt!.isBefore(assessedAt)) {
      throw StateError(
        'Eksik giderme tamamlanma tarihi değerlendirme tarihinden önce olamaz.',
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

  static List<IpTradeSecretEvidenceCategory> _evidenceCategoryList(
    Object? value,
  ) {
    if (value is! Iterable) {
      return const <IpTradeSecretEvidenceCategory>[];
    }

    return value
        .map((item) => IpTradeSecretEvidenceCategory.fromValue(item.toString()))
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

  static int _validatedCount(int value, String fieldName) {
    if (value < 0) {
      throw RangeError.value(value, fieldName, '$fieldName negatif olamaz.');
    }

    return value;
  }
}
