import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretResilienceProfileModel {
  const IpTradeSecretResilienceProfileModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.profileCode,
    required this.title,
    required this.status,
    required this.resilienceLevel,
    required this.maturityLevel,
    required this.reviewType,
    required this.ownerUserId,
    required this.reviewerUserId,
    required this.reviewedAt,
    required this.createdAt,
    required this.createdBy,
    this.version = 1,
    this.componentIds = const <String>[],
    this.accessGrantIds = const <String>[],
    this.disclosureIds = const <String>[],
    this.incidentIds = const <String>[],
    this.protectionControlIds = const <String>[],
    this.riskAssessmentIds = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.ownerDepartmentId,
    this.approverUserId,
    this.previousProfileId,
    this.summary,
    this.strengthsSummary,
    this.weaknessesSummary,
    this.improvementPlan,
    this.improvementOwnerUserId,
    this.confidentialityScore = 0,
    this.accessGovernanceScore = 0,
    this.contractualProtectionScore = 0,
    this.technicalProtectionScore = 0,
    this.physicalProtectionScore = 0,
    this.incidentReadinessScore = 0,
    this.businessContinuityScore = 0,
    this.monitoringScore = 0,
    this.overallResilienceScore = 0,
    this.openRiskScore = 0,
    this.improvementPriorityScore = 0,
    this.openGapCount = 0,
    this.criticalGapCount = 0,
    this.openIncidentCount = 0,
    this.highRiskCount = 0,
    this.overdueActionCount = 0,
    this.reviewRequired = false,
    this.improvementRequired = false,
    this.managementEscalationRequired = false,
    this.businessContinuityCritical = false,
    this.crossBorderExposure = false,
    this.thirdPartyExposure = false,
    this.approvedAt,
    this.nextReviewAt,
    this.improvementDueAt,
    this.improvementCompletedAt,
    this.escalatedAt,
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

  final int version;

  final List<String> componentIds;
  final List<String> accessGrantIds;
  final List<String> disclosureIds;
  final List<String> incidentIds;
  final List<String> protectionControlIds;
  final List<String> riskAssessmentIds;
  final List<String> evidenceDocumentIds;

  final String profileCode;
  final String title;

  final IpTradeSecretResilienceProfileStatus status;
  final IpTradeSecretResilienceLevel resilienceLevel;
  final IpTradeSecretMaturityLevel maturityLevel;
  final IpTradeSecretReviewType reviewType;

  final String ownerUserId;
  final String reviewerUserId;
  final String? ownerDepartmentId;
  final String? approverUserId;
  final String? previousProfileId;

  final String? summary;
  final String? strengthsSummary;
  final String? weaknessesSummary;
  final String? improvementPlan;
  final String? improvementOwnerUserId;

  final int confidentialityScore;
  final int accessGovernanceScore;
  final int contractualProtectionScore;
  final int technicalProtectionScore;
  final int physicalProtectionScore;
  final int incidentReadinessScore;
  final int businessContinuityScore;
  final int monitoringScore;

  final int overallResilienceScore;
  final int openRiskScore;
  final int improvementPriorityScore;

  final int openGapCount;
  final int criticalGapCount;
  final int openIncidentCount;
  final int highRiskCount;
  final int overdueActionCount;

  final bool reviewRequired;
  final bool improvementRequired;
  final bool managementEscalationRequired;
  final bool businessContinuityCritical;
  final bool crossBorderExposure;
  final bool thirdPartyExposure;

  final DateTime reviewedAt;
  final DateTime? approvedAt;
  final DateTime? nextReviewAt;
  final DateTime? improvementDueAt;
  final DateTime? improvementCompletedAt;
  final DateTime? escalatedAt;
  final DateTime? supersededAt;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretResilienceProfileModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır dayanıklılık profili veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretResilienceProfileModel.fromMap(
      id: document.id,
      data: data,
    );
  }

  factory IpTradeSecretResilienceProfileModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final reviewedAt = IpModelUtils.dateTimeFromValue(data['reviewedAt']);
    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (reviewedAt == null) {
      throw StateError('Dayanıklılık profili inceleme tarihi eksik: $id');
    }

    if (createdAt == null) {
      throw StateError('Dayanıklılık profili oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretResilienceProfileModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.requiredString(data['tradeSecretId']),
      version: _nonNegativeInt(data['version'], fallback: 1),
      componentIds: _stringList(data['componentIds']),
      accessGrantIds: _stringList(data['accessGrantIds']),
      disclosureIds: _stringList(data['disclosureIds']),
      incidentIds: _stringList(data['incidentIds']),
      protectionControlIds: _stringList(data['protectionControlIds']),
      riskAssessmentIds: _stringList(data['riskAssessmentIds']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      profileCode: IpModelUtils.requiredString(data['profileCode']),
      title: IpModelUtils.requiredString(data['title']),
      status: IpTradeSecretResilienceProfileStatus.fromValue(
        data['status']?.toString(),
      ),
      resilienceLevel: IpTradeSecretResilienceLevel.fromValue(
        data['resilienceLevel']?.toString(),
      ),
      maturityLevel: IpTradeSecretMaturityLevel.fromValue(
        data['maturityLevel']?.toString(),
      ),
      reviewType: IpTradeSecretReviewType.fromValue(
        data['reviewType']?.toString(),
      ),
      ownerUserId: IpModelUtils.requiredString(data['ownerUserId']),
      reviewerUserId: IpModelUtils.requiredString(data['reviewerUserId']),
      ownerDepartmentId: IpModelUtils.nullableString(data['ownerDepartmentId']),
      approverUserId: IpModelUtils.nullableString(data['approverUserId']),
      previousProfileId: IpModelUtils.nullableString(data['previousProfileId']),
      summary: IpModelUtils.nullableString(data['summary']),
      strengthsSummary: IpModelUtils.nullableString(data['strengthsSummary']),
      weaknessesSummary: IpModelUtils.nullableString(data['weaknessesSummary']),
      improvementPlan: IpModelUtils.nullableString(data['improvementPlan']),
      improvementOwnerUserId: IpModelUtils.nullableString(
        data['improvementOwnerUserId'],
      ),
      confidentialityScore: _score(data['confidentialityScore']),
      accessGovernanceScore: _score(data['accessGovernanceScore']),
      contractualProtectionScore: _score(data['contractualProtectionScore']),
      technicalProtectionScore: _score(data['technicalProtectionScore']),
      physicalProtectionScore: _score(data['physicalProtectionScore']),
      incidentReadinessScore: _score(data['incidentReadinessScore']),
      businessContinuityScore: _score(data['businessContinuityScore']),
      monitoringScore: _score(data['monitoringScore']),
      overallResilienceScore: _score(data['overallResilienceScore']),
      openRiskScore: _score(data['openRiskScore']),
      improvementPriorityScore: _score(data['improvementPriorityScore']),
      openGapCount: _nonNegativeInt(data['openGapCount']),
      criticalGapCount: _nonNegativeInt(data['criticalGapCount']),
      openIncidentCount: _nonNegativeInt(data['openIncidentCount']),
      highRiskCount: _nonNegativeInt(data['highRiskCount']),
      overdueActionCount: _nonNegativeInt(data['overdueActionCount']),
      reviewRequired: data['reviewRequired'] == true,
      improvementRequired: data['improvementRequired'] == true,
      managementEscalationRequired:
          data['managementEscalationRequired'] == true,
      businessContinuityCritical: data['businessContinuityCritical'] == true,
      crossBorderExposure: data['crossBorderExposure'] == true,
      thirdPartyExposure: data['thirdPartyExposure'] == true,
      reviewedAt: reviewedAt,
      approvedAt: IpModelUtils.dateTimeFromValue(data['approvedAt']),
      nextReviewAt: IpModelUtils.dateTimeFromValue(data['nextReviewAt']),
      improvementDueAt: IpModelUtils.dateTimeFromValue(
        data['improvementDueAt'],
      ),
      improvementCompletedAt: IpModelUtils.dateTimeFromValue(
        data['improvementCompletedAt'],
      ),
      escalatedAt: IpModelUtils.dateTimeFromValue(data['escalatedAt']),
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
      'version': version,
      'componentIds': _cleanList(componentIds),
      'accessGrantIds': _cleanList(accessGrantIds),
      'disclosureIds': _cleanList(disclosureIds),
      'incidentIds': _cleanList(incidentIds),
      'protectionControlIds': _cleanList(protectionControlIds),
      'riskAssessmentIds': _cleanList(riskAssessmentIds),
      'evidenceDocumentIds': _cleanList(evidenceDocumentIds),
      'profileCode': profileCode.trim(),
      'title': title.trim(),
      'status': status.value,
      'resilienceLevel': resilienceLevel.value,
      'maturityLevel': maturityLevel.value,
      'reviewType': reviewType.value,
      'ownerUserId': ownerUserId.trim(),
      'reviewerUserId': reviewerUserId.trim(),
      'ownerDepartmentId': IpModelUtils.cleanNullable(ownerDepartmentId),
      'approverUserId': IpModelUtils.cleanNullable(approverUserId),
      'previousProfileId': IpModelUtils.cleanNullable(previousProfileId),
      'summary': IpModelUtils.cleanNullable(summary),
      'strengthsSummary': IpModelUtils.cleanNullable(strengthsSummary),
      'weaknessesSummary': IpModelUtils.cleanNullable(weaknessesSummary),
      'improvementPlan': IpModelUtils.cleanNullable(improvementPlan),
      'improvementOwnerUserId': IpModelUtils.cleanNullable(
        improvementOwnerUserId,
      ),
      'confidentialityScore': _validatedScore(
        confidentialityScore,
        'confidentialityScore',
      ),
      'accessGovernanceScore': _validatedScore(
        accessGovernanceScore,
        'accessGovernanceScore',
      ),
      'contractualProtectionScore': _validatedScore(
        contractualProtectionScore,
        'contractualProtectionScore',
      ),
      'technicalProtectionScore': _validatedScore(
        technicalProtectionScore,
        'technicalProtectionScore',
      ),
      'physicalProtectionScore': _validatedScore(
        physicalProtectionScore,
        'physicalProtectionScore',
      ),
      'incidentReadinessScore': _validatedScore(
        incidentReadinessScore,
        'incidentReadinessScore',
      ),
      'businessContinuityScore': _validatedScore(
        businessContinuityScore,
        'businessContinuityScore',
      ),
      'monitoringScore': _validatedScore(monitoringScore, 'monitoringScore'),
      'overallResilienceScore': _validatedScore(
        overallResilienceScore,
        'overallResilienceScore',
      ),
      'openRiskScore': _validatedScore(openRiskScore, 'openRiskScore'),
      'improvementPriorityScore': _validatedScore(
        improvementPriorityScore,
        'improvementPriorityScore',
      ),
      'openGapCount': _validatedCount(openGapCount, 'openGapCount'),
      'criticalGapCount': _validatedCount(criticalGapCount, 'criticalGapCount'),
      'openIncidentCount': _validatedCount(
        openIncidentCount,
        'openIncidentCount',
      ),
      'highRiskCount': _validatedCount(highRiskCount, 'highRiskCount'),
      'overdueActionCount': _validatedCount(
        overdueActionCount,
        'overdueActionCount',
      ),
      'reviewRequired': reviewRequired,
      'improvementRequired': improvementRequired,
      'managementEscalationRequired': managementEscalationRequired,
      'businessContinuityCritical': businessContinuityCritical,
      'crossBorderExposure': crossBorderExposure,
      'thirdPartyExposure': thirdPartyExposure,
      'reviewedAt': Timestamp.fromDate(reviewedAt),
      'approvedAt': IpModelUtils.timestampOrNull(approvedAt),
      'nextReviewAt': IpModelUtils.timestampOrNull(nextReviewAt),
      'improvementDueAt': IpModelUtils.timestampOrNull(improvementDueAt),
      'improvementCompletedAt': IpModelUtils.timestampOrNull(
        improvementCompletedAt,
      ),
      'escalatedAt': IpModelUtils.timestampOrNull(escalatedAt),
      'supersededAt': IpModelUtils.timestampOrNull(supersededAt),
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
    map.remove('profileCode');
    map.remove('version');
    map.remove('reviewedAt');
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
        profileCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        ownerUserId.trim().isNotEmpty &&
        reviewerUserId.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty &&
        version > 0;
  }

  bool get isReviewOverdue {
    final dueAt = nextReviewAt;
    return reviewRequired &&
        dueAt != null &&
        dueAt.isBefore(DateTime.now().toUtc());
  }

  bool get isImprovementOverdue {
    final dueAt = improvementDueAt;
    return improvementRequired &&
        dueAt != null &&
        dueAt.isBefore(DateTime.now().toUtc()) &&
        improvementCompletedAt == null;
  }

  bool get hasCriticalExposure {
    return criticalGapCount > 0 ||
        highRiskCount > 0 ||
        openRiskScore >= 80 ||
        improvementPriorityScore >= 85 ||
        businessContinuityCritical;
  }

  bool get requiresImmediateEscalation {
    return managementEscalationRequired ||
        hasCriticalExposure ||
        overdueActionCount > 0 ||
        isImprovementOverdue;
  }

  bool get shouldAppearOnResilienceDashboard {
    return status == IpTradeSecretResilienceProfileStatus.active ||
        status == IpTradeSecretResilienceProfileStatus.improvementRequired ||
        reviewRequired ||
        improvementRequired ||
        hasCriticalExposure;
  }

  bool get isDefenseReady {
    return overallResilienceScore >= 70 &&
        openRiskScore < 60 &&
        criticalGapCount == 0 &&
        highRiskCount == 0 &&
        overdueActionCount == 0 &&
        !businessContinuityCritical;
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır dayanıklılık profilinin zorunlu kimlik alanları eksik.',
      );
    }

    for (final entry in <String, int>{
      'confidentialityScore': confidentialityScore,
      'accessGovernanceScore': accessGovernanceScore,
      'contractualProtectionScore': contractualProtectionScore,
      'technicalProtectionScore': technicalProtectionScore,
      'physicalProtectionScore': physicalProtectionScore,
      'incidentReadinessScore': incidentReadinessScore,
      'businessContinuityScore': businessContinuityScore,
      'monitoringScore': monitoringScore,
      'overallResilienceScore': overallResilienceScore,
      'openRiskScore': openRiskScore,
      'improvementPriorityScore': improvementPriorityScore,
    }.entries) {
      _validatedScore(entry.value, entry.key);
    }

    for (final entry in <String, int>{
      'openGapCount': openGapCount,
      'criticalGapCount': criticalGapCount,
      'openIncidentCount': openIncidentCount,
      'highRiskCount': highRiskCount,
      'overdueActionCount': overdueActionCount,
    }.entries) {
      _validatedCount(entry.value, entry.key);
    }

    if (criticalGapCount > openGapCount) {
      throw StateError(
        'Kritik açık sayısı toplam açık sayısından büyük olamaz.',
      );
    }

    if (status == IpTradeSecretResilienceProfileStatus.approved &&
        (approverUserId == null ||
            approverUserId!.trim().isEmpty ||
            approvedAt == null)) {
      throw StateError(
        'Onaylanan dayanıklılık profilinde onaylayan ve onay tarihi zorunludur.',
      );
    }

    if (reviewRequired && nextReviewAt == null) {
      throw StateError(
        'İnceleme gereken profilde sonraki inceleme tarihi zorunludur.',
      );
    }

    if (improvementRequired &&
        (improvementPlan == null ||
            improvementPlan!.trim().isEmpty ||
            improvementOwnerUserId == null ||
            improvementOwnerUserId!.trim().isEmpty ||
            improvementDueAt == null)) {
      throw StateError(
        'İyileştirme gereken profilde plan, sorumlu ve hedef tarih zorunludur.',
      );
    }

    if (improvementCompletedAt != null && improvementRequired) {
      throw StateError(
        'İyileştirme tamamlandıysa improvementRequired false olmalıdır.',
      );
    }

    if (managementEscalationRequired && escalatedAt == null) {
      throw StateError(
        'Yönetim yükseltmesi gereken profilde yükseltme tarihi zorunludur.',
      );
    }

    if (status == IpTradeSecretResilienceProfileStatus.superseded &&
        supersededAt == null) {
      throw StateError(
        'Yeni sürümle değiştirilen profilde supersededAt zorunludur.',
      );
    }

    if (version > 1 &&
        (previousProfileId == null || previousProfileId!.trim().isEmpty)) {
      throw StateError(
        'İkinci ve sonraki profil sürümlerinde önceki profil bağlantısı zorunludur.',
      );
    }

    if (approvedAt != null && approvedAt!.isBefore(reviewedAt)) {
      throw StateError('Onay tarihi inceleme tarihinden önce olamaz.');
    }

    if (improvementCompletedAt != null &&
        improvementCompletedAt!.isBefore(reviewedAt)) {
      throw StateError(
        'İyileştirme tamamlanma tarihi inceleme tarihinden önce olamaz.',
      );
    }

    if (supersededAt != null && supersededAt!.isBefore(reviewedAt)) {
      throw StateError(
        'Yeni sürümle değiştirme tarihi inceleme tarihinden önce olamaz.',
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

  static int _score(Object? value) {
    if (value is int) {
      return value.clamp(0, 100);
    }

    if (value is num) {
      return value.round().clamp(0, 100);
    }

    return 0;
  }

  static int _nonNegativeInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
    }

    return fallback;
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
