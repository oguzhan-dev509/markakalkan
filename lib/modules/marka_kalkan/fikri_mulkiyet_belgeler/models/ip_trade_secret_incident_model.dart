import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretIncidentModel {
  const IpTradeSecretIncidentModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.incidentCode,
    required this.title,
    required this.type,
    required this.status,
    required this.severity,
    required this.source,
    required this.detectedAt,
    required this.reportedAt,
    required this.reportedBy,
    required this.createdAt,
    required this.createdBy,
    this.componentIds = const <String>[],
    this.accessGrantIds = const <String>[],
    this.disclosureIds = const <String>[],
    this.affectedUserIds = const <String>[],
    this.affectedOrganizationIds = const <String>[],
    this.suspectedActorIds = const <String>[],
    this.ownerUserId,
    this.assignedTeamId,
    this.summary,
    this.detectionDetails,
    this.impactDescription,
    this.rootCause,
    this.containmentActions = const <String>[],
    this.remediationActions = const <String>[],
    this.preventiveActions = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.relatedDocumentIds = const <String>[],
    this.relatedCaseIds = const <String>[],
    this.externalReferenceIds = const <String>[],
    this.containedAt,
    this.resolvedAt,
    this.closedAt,
    this.escalatedAt,
    this.legalNotifiedAt,
    this.regulatorNotifiedAt,
    this.dataProtectionAuthorityNotifiedAt,
    this.lawEnforcementNotifiedAt,
    this.publicDisclosureAt,
    this.personalDataAffected = false,
    this.crossBorderImpact = false,
    this.externalPartyInvolved = false,
    this.lawEnforcementInvolved = false,
    this.regulatorNotificationRequired = false,
    this.regulatorNotificationCompleted = false,
    this.legalReviewRequired = false,
    this.legalReviewCompleted = false,
    this.evidencePreservationRequired = true,
    this.evidencePreservationCompleted = false,
    this.accessRevocationRequired = false,
    this.accessRevocationCompleted = false,
    this.containmentCompleted = false,
    this.remediationCompleted = false,
    this.businessContinuityAffected = false,
    this.financialLossAmount,
    this.financialLossCurrency,
    this.affectedRecordCount = 0,
    this.incidentRiskScore = 0,
    this.businessImpactScore = 0,
    this.legalImpactScore = 0,
    this.reputationImpactScore = 0,
    this.nextReviewAt,
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

  final String incidentCode;
  final String title;

  final IpTradeSecretIncidentType type;
  final IpTradeSecretIncidentStatus status;
  final IpTradeSecretIncidentSeverity severity;
  final IpTradeSecretIncidentSource source;

  final String? ownerUserId;
  final String? assignedTeamId;

  final List<String> affectedUserIds;
  final List<String> affectedOrganizationIds;
  final List<String> suspectedActorIds;

  final String? summary;
  final String? detectionDetails;
  final String? impactDescription;
  final String? rootCause;

  final List<String> containmentActions;
  final List<String> remediationActions;
  final List<String> preventiveActions;

  final List<String> evidenceDocumentIds;
  final List<String> relatedDocumentIds;
  final List<String> relatedCaseIds;
  final List<String> externalReferenceIds;

  final DateTime detectedAt;
  final DateTime reportedAt;
  final String reportedBy;

  final DateTime? containedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final DateTime? escalatedAt;

  final DateTime? legalNotifiedAt;
  final DateTime? regulatorNotifiedAt;
  final DateTime? dataProtectionAuthorityNotifiedAt;
  final DateTime? lawEnforcementNotifiedAt;
  final DateTime? publicDisclosureAt;

  final bool personalDataAffected;
  final bool crossBorderImpact;
  final bool externalPartyInvolved;
  final bool lawEnforcementInvolved;

  final bool regulatorNotificationRequired;
  final bool regulatorNotificationCompleted;

  final bool legalReviewRequired;
  final bool legalReviewCompleted;

  final bool evidencePreservationRequired;
  final bool evidencePreservationCompleted;

  final bool accessRevocationRequired;
  final bool accessRevocationCompleted;

  final bool containmentCompleted;
  final bool remediationCompleted;

  final bool businessContinuityAffected;

  final double? financialLossAmount;
  final String? financialLossCurrency;
  final int affectedRecordCount;

  final int incidentRiskScore;
  final int businessImpactScore;
  final int legalImpactScore;
  final int reputationImpactScore;

  final DateTime? nextReviewAt;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretIncidentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Ticari sır olay kaydı veri içermiyor: ${document.id}');
    }

    return IpTradeSecretIncidentModel.fromMap(id: document.id, data: data);
  }

  factory IpTradeSecretIncidentModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final detectedAt = IpModelUtils.dateTimeFromValue(data['detectedAt']);

    final reportedAt = IpModelUtils.dateTimeFromValue(data['reportedAt']);

    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (detectedAt == null) {
      throw StateError('Ticari sır olayının tespit tarihi eksik: $id');
    }

    if (reportedAt == null) {
      throw StateError('Ticari sır olayının bildirim tarihi eksik: $id');
    }

    if (createdAt == null) {
      throw StateError('Ticari sır olay kaydının oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretIncidentModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.requiredString(data['tradeSecretId']),
      componentIds: _stringList(data['componentIds']),
      accessGrantIds: _stringList(data['accessGrantIds']),
      disclosureIds: _stringList(data['disclosureIds']),
      incidentCode: IpModelUtils.requiredString(data['incidentCode']),
      title: IpModelUtils.requiredString(data['title']),
      type: IpTradeSecretIncidentType.fromValue(data['type']?.toString()),
      status: IpTradeSecretIncidentStatus.fromValue(data['status']?.toString()),
      severity: IpTradeSecretIncidentSeverity.fromValue(
        data['severity']?.toString(),
      ),
      source: IpTradeSecretIncidentSource.fromValue(data['source']?.toString()),
      ownerUserId: IpModelUtils.nullableString(data['ownerUserId']),
      assignedTeamId: IpModelUtils.nullableString(data['assignedTeamId']),
      affectedUserIds: _stringList(data['affectedUserIds']),
      affectedOrganizationIds: _stringList(data['affectedOrganizationIds']),
      suspectedActorIds: _stringList(data['suspectedActorIds']),
      summary: IpModelUtils.nullableString(data['summary']),
      detectionDetails: IpModelUtils.nullableString(data['detectionDetails']),
      impactDescription: IpModelUtils.nullableString(data['impactDescription']),
      rootCause: IpModelUtils.nullableString(data['rootCause']),
      containmentActions: _stringList(data['containmentActions']),
      remediationActions: _stringList(data['remediationActions']),
      preventiveActions: _stringList(data['preventiveActions']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      relatedDocumentIds: _stringList(data['relatedDocumentIds']),
      relatedCaseIds: _stringList(data['relatedCaseIds']),
      externalReferenceIds: _stringList(data['externalReferenceIds']),
      detectedAt: detectedAt,
      reportedAt: reportedAt,
      reportedBy: IpModelUtils.requiredString(data['reportedBy']),
      containedAt: IpModelUtils.dateTimeFromValue(data['containedAt']),
      resolvedAt: IpModelUtils.dateTimeFromValue(data['resolvedAt']),
      closedAt: IpModelUtils.dateTimeFromValue(data['closedAt']),
      escalatedAt: IpModelUtils.dateTimeFromValue(data['escalatedAt']),
      legalNotifiedAt: IpModelUtils.dateTimeFromValue(data['legalNotifiedAt']),
      regulatorNotifiedAt: IpModelUtils.dateTimeFromValue(
        data['regulatorNotifiedAt'],
      ),
      dataProtectionAuthorityNotifiedAt: IpModelUtils.dateTimeFromValue(
        data['dataProtectionAuthorityNotifiedAt'],
      ),
      lawEnforcementNotifiedAt: IpModelUtils.dateTimeFromValue(
        data['lawEnforcementNotifiedAt'],
      ),
      publicDisclosureAt: IpModelUtils.dateTimeFromValue(
        data['publicDisclosureAt'],
      ),
      personalDataAffected: data['personalDataAffected'] == true,
      crossBorderImpact: data['crossBorderImpact'] == true,
      externalPartyInvolved: data['externalPartyInvolved'] == true,
      lawEnforcementInvolved: data['lawEnforcementInvolved'] == true,
      regulatorNotificationRequired:
          data['regulatorNotificationRequired'] == true,
      regulatorNotificationCompleted:
          data['regulatorNotificationCompleted'] == true,
      legalReviewRequired: data['legalReviewRequired'] == true,
      legalReviewCompleted: data['legalReviewCompleted'] == true,
      evidencePreservationRequired:
          data['evidencePreservationRequired'] != false,
      evidencePreservationCompleted:
          data['evidencePreservationCompleted'] == true,
      accessRevocationRequired: data['accessRevocationRequired'] == true,
      accessRevocationCompleted: data['accessRevocationCompleted'] == true,
      containmentCompleted: data['containmentCompleted'] == true,
      remediationCompleted: data['remediationCompleted'] == true,
      businessContinuityAffected: data['businessContinuityAffected'] == true,
      financialLossAmount: _nullableDouble(data['financialLossAmount']),
      financialLossCurrency: IpModelUtils.nullableString(
        data['financialLossCurrency'],
      ),
      affectedRecordCount: _nonNegativeInt(data['affectedRecordCount']),
      incidentRiskScore: _score(data['incidentRiskScore']),
      businessImpactScore: _score(data['businessImpactScore']),
      legalImpactScore: _score(data['legalImpactScore']),
      reputationImpactScore: _score(data['reputationImpactScore']),
      nextReviewAt: IpModelUtils.dateTimeFromValue(data['nextReviewAt']),
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
      'incidentCode': incidentCode.trim(),
      'title': title.trim(),
      'type': type.value,
      'status': status.value,
      'severity': severity.value,
      'source': source.value,
      'ownerUserId': IpModelUtils.cleanNullable(ownerUserId),
      'assignedTeamId': IpModelUtils.cleanNullable(assignedTeamId),
      'affectedUserIds': _cleanList(affectedUserIds),
      'affectedOrganizationIds': _cleanList(affectedOrganizationIds),
      'suspectedActorIds': _cleanList(suspectedActorIds),
      'summary': IpModelUtils.cleanNullable(summary),
      'detectionDetails': IpModelUtils.cleanNullable(detectionDetails),
      'impactDescription': IpModelUtils.cleanNullable(impactDescription),
      'rootCause': IpModelUtils.cleanNullable(rootCause),
      'containmentActions': _cleanList(containmentActions),
      'remediationActions': _cleanList(remediationActions),
      'preventiveActions': _cleanList(preventiveActions),
      'evidenceDocumentIds': _cleanList(evidenceDocumentIds),
      'relatedDocumentIds': _cleanList(relatedDocumentIds),
      'relatedCaseIds': _cleanList(relatedCaseIds),
      'externalReferenceIds': _cleanList(externalReferenceIds),
      'detectedAt': Timestamp.fromDate(detectedAt),
      'reportedAt': Timestamp.fromDate(reportedAt),
      'reportedBy': reportedBy.trim(),
      'containedAt': IpModelUtils.timestampOrNull(containedAt),
      'resolvedAt': IpModelUtils.timestampOrNull(resolvedAt),
      'closedAt': IpModelUtils.timestampOrNull(closedAt),
      'escalatedAt': IpModelUtils.timestampOrNull(escalatedAt),
      'legalNotifiedAt': IpModelUtils.timestampOrNull(legalNotifiedAt),
      'regulatorNotifiedAt': IpModelUtils.timestampOrNull(regulatorNotifiedAt),
      'dataProtectionAuthorityNotifiedAt': IpModelUtils.timestampOrNull(
        dataProtectionAuthorityNotifiedAt,
      ),
      'lawEnforcementNotifiedAt': IpModelUtils.timestampOrNull(
        lawEnforcementNotifiedAt,
      ),
      'publicDisclosureAt': IpModelUtils.timestampOrNull(publicDisclosureAt),
      'personalDataAffected': personalDataAffected,
      'crossBorderImpact': crossBorderImpact,
      'externalPartyInvolved': externalPartyInvolved,
      'lawEnforcementInvolved': lawEnforcementInvolved,
      'regulatorNotificationRequired': regulatorNotificationRequired,
      'regulatorNotificationCompleted': regulatorNotificationCompleted,
      'legalReviewRequired': legalReviewRequired,
      'legalReviewCompleted': legalReviewCompleted,
      'evidencePreservationRequired': evidencePreservationRequired,
      'evidencePreservationCompleted': evidencePreservationCompleted,
      'accessRevocationRequired': accessRevocationRequired,
      'accessRevocationCompleted': accessRevocationCompleted,
      'containmentCompleted': containmentCompleted,
      'remediationCompleted': remediationCompleted,
      'businessContinuityAffected': businessContinuityAffected,
      'financialLossAmount': financialLossAmount,
      'financialLossCurrency': IpModelUtils.cleanNullable(
        financialLossCurrency,
      ),
      'affectedRecordCount': _validatedNonNegativeInt(
        affectedRecordCount,
        'affectedRecordCount',
      ),
      'incidentRiskScore': _validatedScore(
        incidentRiskScore,
        'incidentRiskScore',
      ),
      'businessImpactScore': _validatedScore(
        businessImpactScore,
        'businessImpactScore',
      ),
      'legalImpactScore': _validatedScore(legalImpactScore, 'legalImpactScore'),
      'reputationImpactScore': _validatedScore(
        reputationImpactScore,
        'reputationImpactScore',
      ),
      'nextReviewAt': IpModelUtils.timestampOrNull(nextReviewAt),
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
    map.remove('incidentCode');
    map.remove('detectedAt');
    map.remove('reportedAt');
    map.remove('reportedBy');
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
        incidentCode.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        reportedBy.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get isOpen {
    return status != IpTradeSecretIncidentStatus.resolved &&
        status != IpTradeSecretIncidentStatus.closed &&
        status != IpTradeSecretIncidentStatus.falsePositive;
  }

  bool get isCritical {
    return severity == IpTradeSecretIncidentSeverity.critical ||
        incidentRiskScore >= 90;
  }

  bool get hasExternalImpact {
    return externalPartyInvolved ||
        crossBorderImpact ||
        publicDisclosureAt != null ||
        regulatorNotificationRequired ||
        lawEnforcementInvolved;
  }

  bool get requiresImmediateEscalation {
    return isCritical ||
        severity == IpTradeSecretIncidentSeverity.high ||
        personalDataAffected ||
        publicDisclosureAt != null ||
        incidentRiskScore >= 80 ||
        businessContinuityAffected;
  }

  bool get requiresImmediateReview {
    return isOpen &&
        (requiresImmediateEscalation ||
            nextReviewAt?.isBefore(DateTime.now().toUtc()) == true ||
            (evidencePreservationRequired && !evidencePreservationCompleted) ||
            (accessRevocationRequired && !accessRevocationCompleted));
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır olay kaydının zorunlu kimlik alanları eksik.',
      );
    }

    if (reportedAt.isBefore(detectedAt)) {
      throw StateError('Olay bildirim tarihi tespit tarihinden önce olamaz.');
    }

    final contained = containedAt;
    final resolved = resolvedAt;
    final closed = closedAt;

    if (contained != null && contained.isBefore(detectedAt)) {
      throw StateError(
        'Kontrol altına alma tarihi tespit tarihinden önce olamaz.',
      );
    }

    if (resolved != null && resolved.isBefore(detectedAt)) {
      throw StateError('Çözüm tarihi tespit tarihinden önce olamaz.');
    }

    if (closed != null && closed.isBefore(detectedAt)) {
      throw StateError('Kapanış tarihi tespit tarihinden önce olamaz.');
    }

    if (status == IpTradeSecretIncidentStatus.contained &&
        (!containmentCompleted || containedAt == null)) {
      throw StateError(
        'Kontrol altındaki olayda containment tamamlanmalı '
        've tarih belirtilmelidir.',
      );
    }

    if (status == IpTradeSecretIncidentStatus.resolved &&
        (!remediationCompleted || resolvedAt == null)) {
      throw StateError(
        'Çözülen olayda giderme tamamlanmalı ve çözüm tarihi belirtilmelidir.',
      );
    }

    if (status == IpTradeSecretIncidentStatus.closed &&
        (resolvedAt == null || closedAt == null || !remediationCompleted)) {
      throw StateError(
        'Kapatılan olayda çözüm, kapanış tarihi ve giderme tamamlanmış olmalıdır.',
      );
    }

    if (regulatorNotificationRequired &&
        status == IpTradeSecretIncidentStatus.closed &&
        !regulatorNotificationCompleted) {
      throw StateError(
        'Zorunlu düzenleyici kurum bildirimi tamamlanmadan olay kapatılamaz.',
      );
    }

    if (legalReviewRequired &&
        status == IpTradeSecretIncidentStatus.closed &&
        !legalReviewCompleted) {
      throw StateError(
        'Zorunlu hukuki inceleme tamamlanmadan olay kapatılamaz.',
      );
    }

    if (evidencePreservationRequired &&
        status == IpTradeSecretIncidentStatus.closed &&
        !evidencePreservationCompleted) {
      throw StateError('Kanıt koruma işlemi tamamlanmadan olay kapatılamaz.');
    }

    if (accessRevocationRequired &&
        status == IpTradeSecretIncidentStatus.closed &&
        !accessRevocationCompleted) {
      throw StateError('Zorunlu erişim iptali tamamlanmadan olay kapatılamaz.');
    }

    final lossAmount = financialLossAmount;

    if (lossAmount != null && lossAmount < 0) {
      throw RangeError.value(
        lossAmount,
        'financialLossAmount',
        'Finansal kayıp tutarı negatif olamaz.',
      );
    }

    if (lossAmount != null &&
        (financialLossCurrency == null ||
            financialLossCurrency!.trim().isEmpty)) {
      throw StateError('Finansal kayıp tutarı varsa para birimi zorunludur.');
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

  static int _validatedNonNegativeInt(int value, String fieldName) {
    if (value < 0) {
      throw RangeError.value(value, fieldName, '$fieldName negatif olamaz.');
    }

    return value;
  }
}
