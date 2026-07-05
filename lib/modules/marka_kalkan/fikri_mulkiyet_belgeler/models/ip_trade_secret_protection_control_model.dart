import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretProtectionControlModel {
  const IpTradeSecretProtectionControlModel({
    required this.id,
    required this.tenantId,
    required this.brandId,
    required this.tradeSecretId,
    required this.controlCode,
    required this.name,
    required this.type,
    required this.category,
    required this.status,
    required this.frequency,
    required this.ownerUserId,
    required this.implementedAt,
    required this.createdAt,
    required this.createdBy,
    this.componentIds = const <String>[],
    this.relatedAccessGrantIds = const <String>[],
    this.relatedDisclosureIds = const <String>[],
    this.relatedIncidentIds = const <String>[],
    this.ownerDepartmentId,
    this.implementationDescription,
    this.controlObjective,
    this.scopeDescription,
    this.procedureDocumentIds = const <String>[],
    this.policyDocumentIds = const <String>[],
    this.evidenceDocumentIds = const <String>[],
    this.testDocumentIds = const <String>[],
    this.systemIds = const <String>[],
    this.locationCodes = const <String>[],
    this.supplierOrganizationIds = const <String>[],
    this.automated = false,
    this.preventiveCoverage = false,
    this.detectiveCoverage = false,
    this.correctiveCoverage = false,
    this.lastTestedAt,
    this.nextTestAt,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.lastFailureAt,
    this.suspendedAt,
    this.retiredAt,
    this.testPassed,
    this.designEffectivenessScore = 0,
    this.operatingEffectivenessScore = 0,
    this.coverageScore = 0,
    this.residualRiskScore = 0,
    this.findingCount = 0,
    this.openFindingCount = 0,
    this.remediationRequired = false,
    this.remediationDueAt,
    this.remediationCompletedAt,
    this.remediationOwnerUserId,
    this.remediationPlan,
    this.exceptionApproved = false,
    this.exceptionReason,
    this.exceptionApprovedBy,
    this.exceptionExpiresAt,
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
  final List<String> relatedAccessGrantIds;
  final List<String> relatedDisclosureIds;
  final List<String> relatedIncidentIds;

  final String controlCode;
  final String name;

  final IpTradeSecretProtectionControlType type;
  final IpTradeSecretProtectionControlCategory category;
  final IpTradeSecretProtectionControlStatus status;
  final IpTradeSecretProtectionControlFrequency frequency;

  final String ownerUserId;
  final String? ownerDepartmentId;

  final String? implementationDescription;
  final String? controlObjective;
  final String? scopeDescription;

  final List<String> procedureDocumentIds;
  final List<String> policyDocumentIds;
  final List<String> evidenceDocumentIds;
  final List<String> testDocumentIds;

  final List<String> systemIds;
  final List<String> locationCodes;
  final List<String> supplierOrganizationIds;

  final bool automated;
  final bool preventiveCoverage;
  final bool detectiveCoverage;
  final bool correctiveCoverage;

  final DateTime implementedAt;
  final DateTime? lastTestedAt;
  final DateTime? nextTestAt;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final DateTime? lastFailureAt;
  final DateTime? suspendedAt;
  final DateTime? retiredAt;

  final bool? testPassed;

  final int designEffectivenessScore;
  final int operatingEffectivenessScore;
  final int coverageScore;
  final int residualRiskScore;

  final int findingCount;
  final int openFindingCount;

  final bool remediationRequired;
  final DateTime? remediationDueAt;
  final DateTime? remediationCompletedAt;
  final String? remediationOwnerUserId;
  final String? remediationPlan;

  final bool exceptionApproved;
  final String? exceptionReason;
  final String? exceptionApprovedBy;
  final DateTime? exceptionExpiresAt;

  final String? notes;
  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretProtectionControlModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır koruma kontrolü veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretProtectionControlModel.fromMap(
      id: document.id,
      data: data,
    );
  }

  factory IpTradeSecretProtectionControlModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final implementedAt = IpModelUtils.dateTimeFromValue(data['implementedAt']);

    final createdAt = IpModelUtils.dateTimeFromValue(data['createdAt']);

    if (implementedAt == null) {
      throw StateError('Koruma kontrolünün uygulama tarihi eksik: $id');
    }

    if (createdAt == null) {
      throw StateError('Koruma kontrolünün oluşturma tarihi eksik: $id');
    }

    return IpTradeSecretProtectionControlModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.requiredString(data['brandId']),
      tradeSecretId: IpModelUtils.requiredString(data['tradeSecretId']),
      componentIds: _stringList(data['componentIds']),
      relatedAccessGrantIds: _stringList(data['relatedAccessGrantIds']),
      relatedDisclosureIds: _stringList(data['relatedDisclosureIds']),
      relatedIncidentIds: _stringList(data['relatedIncidentIds']),
      controlCode: IpModelUtils.requiredString(data['controlCode']),
      name: IpModelUtils.requiredString(data['name']),
      type: IpTradeSecretProtectionControlType.fromValue(
        data['type']?.toString(),
      ),
      category: IpTradeSecretProtectionControlCategory.fromValue(
        data['category']?.toString(),
      ),
      status: IpTradeSecretProtectionControlStatus.fromValue(
        data['status']?.toString(),
      ),
      frequency: IpTradeSecretProtectionControlFrequency.fromValue(
        data['frequency']?.toString(),
      ),
      ownerUserId: IpModelUtils.requiredString(data['ownerUserId']),
      ownerDepartmentId: IpModelUtils.nullableString(data['ownerDepartmentId']),
      implementationDescription: IpModelUtils.nullableString(
        data['implementationDescription'],
      ),
      controlObjective: IpModelUtils.nullableString(data['controlObjective']),
      scopeDescription: IpModelUtils.nullableString(data['scopeDescription']),
      procedureDocumentIds: _stringList(data['procedureDocumentIds']),
      policyDocumentIds: _stringList(data['policyDocumentIds']),
      evidenceDocumentIds: _stringList(data['evidenceDocumentIds']),
      testDocumentIds: _stringList(data['testDocumentIds']),
      systemIds: _stringList(data['systemIds']),
      locationCodes: _stringList(data['locationCodes']),
      supplierOrganizationIds: _stringList(data['supplierOrganizationIds']),
      automated: data['automated'] == true,
      preventiveCoverage: data['preventiveCoverage'] == true,
      detectiveCoverage: data['detectiveCoverage'] == true,
      correctiveCoverage: data['correctiveCoverage'] == true,
      implementedAt: implementedAt,
      lastTestedAt: IpModelUtils.dateTimeFromValue(data['lastTestedAt']),
      nextTestAt: IpModelUtils.dateTimeFromValue(data['nextTestAt']),
      lastReviewedAt: IpModelUtils.dateTimeFromValue(data['lastReviewedAt']),
      nextReviewAt: IpModelUtils.dateTimeFromValue(data['nextReviewAt']),
      lastFailureAt: IpModelUtils.dateTimeFromValue(data['lastFailureAt']),
      suspendedAt: IpModelUtils.dateTimeFromValue(data['suspendedAt']),
      retiredAt: IpModelUtils.dateTimeFromValue(data['retiredAt']),
      testPassed: _nullableBool(data['testPassed']),
      designEffectivenessScore: _score(data['designEffectivenessScore']),
      operatingEffectivenessScore: _score(data['operatingEffectivenessScore']),
      coverageScore: _score(data['coverageScore']),
      residualRiskScore: _score(data['residualRiskScore']),
      findingCount: _nonNegativeInt(data['findingCount']),
      openFindingCount: _nonNegativeInt(data['openFindingCount']),
      remediationRequired: data['remediationRequired'] == true,
      remediationDueAt: IpModelUtils.dateTimeFromValue(
        data['remediationDueAt'],
      ),
      remediationCompletedAt: IpModelUtils.dateTimeFromValue(
        data['remediationCompletedAt'],
      ),
      remediationOwnerUserId: IpModelUtils.nullableString(
        data['remediationOwnerUserId'],
      ),
      remediationPlan: IpModelUtils.nullableString(data['remediationPlan']),
      exceptionApproved: data['exceptionApproved'] == true,
      exceptionReason: IpModelUtils.nullableString(data['exceptionReason']),
      exceptionApprovedBy: IpModelUtils.nullableString(
        data['exceptionApprovedBy'],
      ),
      exceptionExpiresAt: IpModelUtils.dateTimeFromValue(
        data['exceptionExpiresAt'],
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
      'relatedAccessGrantIds': _cleanList(relatedAccessGrantIds),
      'relatedDisclosureIds': _cleanList(relatedDisclosureIds),
      'relatedIncidentIds': _cleanList(relatedIncidentIds),
      'controlCode': controlCode.trim(),
      'name': name.trim(),
      'type': type.value,
      'category': category.value,
      'status': status.value,
      'frequency': frequency.value,
      'ownerUserId': ownerUserId.trim(),
      'ownerDepartmentId': IpModelUtils.cleanNullable(ownerDepartmentId),
      'implementationDescription': IpModelUtils.cleanNullable(
        implementationDescription,
      ),
      'controlObjective': IpModelUtils.cleanNullable(controlObjective),
      'scopeDescription': IpModelUtils.cleanNullable(scopeDescription),
      'procedureDocumentIds': _cleanList(procedureDocumentIds),
      'policyDocumentIds': _cleanList(policyDocumentIds),
      'evidenceDocumentIds': _cleanList(evidenceDocumentIds),
      'testDocumentIds': _cleanList(testDocumentIds),
      'systemIds': _cleanList(systemIds),
      'locationCodes': _cleanList(locationCodes),
      'supplierOrganizationIds': _cleanList(supplierOrganizationIds),
      'automated': automated,
      'preventiveCoverage': preventiveCoverage,
      'detectiveCoverage': detectiveCoverage,
      'correctiveCoverage': correctiveCoverage,
      'implementedAt': Timestamp.fromDate(implementedAt),
      'lastTestedAt': IpModelUtils.timestampOrNull(lastTestedAt),
      'nextTestAt': IpModelUtils.timestampOrNull(nextTestAt),
      'lastReviewedAt': IpModelUtils.timestampOrNull(lastReviewedAt),
      'nextReviewAt': IpModelUtils.timestampOrNull(nextReviewAt),
      'lastFailureAt': IpModelUtils.timestampOrNull(lastFailureAt),
      'suspendedAt': IpModelUtils.timestampOrNull(suspendedAt),
      'retiredAt': IpModelUtils.timestampOrNull(retiredAt),
      'testPassed': testPassed,
      'designEffectivenessScore': _validatedScore(
        designEffectivenessScore,
        'designEffectivenessScore',
      ),
      'operatingEffectivenessScore': _validatedScore(
        operatingEffectivenessScore,
        'operatingEffectivenessScore',
      ),
      'coverageScore': _validatedScore(coverageScore, 'coverageScore'),
      'residualRiskScore': _validatedScore(
        residualRiskScore,
        'residualRiskScore',
      ),
      'findingCount': _validatedNonNegativeInt(findingCount, 'findingCount'),
      'openFindingCount': _validatedNonNegativeInt(
        openFindingCount,
        'openFindingCount',
      ),
      'remediationRequired': remediationRequired,
      'remediationDueAt': IpModelUtils.timestampOrNull(remediationDueAt),
      'remediationCompletedAt': IpModelUtils.timestampOrNull(
        remediationCompletedAt,
      ),
      'remediationOwnerUserId': IpModelUtils.cleanNullable(
        remediationOwnerUserId,
      ),
      'remediationPlan': IpModelUtils.cleanNullable(remediationPlan),
      'exceptionApproved': exceptionApproved,
      'exceptionReason': IpModelUtils.cleanNullable(exceptionReason),
      'exceptionApprovedBy': IpModelUtils.cleanNullable(exceptionApprovedBy),
      'exceptionExpiresAt': IpModelUtils.timestampOrNull(exceptionExpiresAt),
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
    map.remove('controlCode');
    map.remove('implementedAt');
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
        controlCode.trim().isNotEmpty &&
        name.trim().isNotEmpty &&
        ownerUserId.trim().isNotEmpty &&
        createdBy.trim().isNotEmpty;
  }

  bool get isActive {
    return status == IpTradeSecretProtectionControlStatus.active ||
        status == IpTradeSecretProtectionControlStatus.partiallyEffective;
  }

  bool get isOverdueForTest {
    final nextDate = nextTestAt;

    return nextDate != null && nextDate.isBefore(DateTime.now().toUtc());
  }

  bool get isOverdueForReview {
    final nextDate = nextReviewAt;

    return nextDate != null && nextDate.isBefore(DateTime.now().toUtc());
  }

  bool get hasOpenFindings => openFindingCount > 0;

  bool get isEffective {
    return isActive &&
        testPassed == true &&
        designEffectivenessScore >= 70 &&
        operatingEffectivenessScore >= 70 &&
        coverageScore >= 70 &&
        !remediationRequired;
  }

  bool get requiresImmediateReview {
    return status == IpTradeSecretProtectionControlStatus.ineffective ||
        status == IpTradeSecretProtectionControlStatus.remediationRequired ||
        testPassed == false ||
        remediationRequired ||
        residualRiskScore >= 80 ||
        isOverdueForTest ||
        isOverdueForReview ||
        openFindingCount > 0;
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır koruma kontrolünün zorunlu kimlik alanları eksik.',
      );
    }

    final testedAt = lastTestedAt;
    final nextTest = nextTestAt;
    final reviewedAt = lastReviewedAt;
    final nextReview = nextReviewAt;

    if (testedAt != null && testedAt.isBefore(implementedAt)) {
      throw StateError('Son test tarihi uygulama tarihinden önce olamaz.');
    }

    if (nextTest != null && nextTest.isBefore(implementedAt)) {
      throw StateError('Sonraki test tarihi uygulama tarihinden önce olamaz.');
    }

    if (reviewedAt != null && reviewedAt.isBefore(implementedAt)) {
      throw StateError('Son inceleme tarihi uygulama tarihinden önce olamaz.');
    }

    if (nextReview != null && nextReview.isBefore(implementedAt)) {
      throw StateError(
        'Sonraki inceleme tarihi uygulama tarihinden önce olamaz.',
      );
    }

    if (testPassed != null && lastTestedAt == null) {
      throw StateError('Test sonucu varsa son test tarihi zorunludur.');
    }

    if (status == IpTradeSecretProtectionControlStatus.ineffective &&
        testPassed != false) {
      throw StateError('Etkisiz kontrolün test sonucu başarısız olmalıdır.');
    }

    if (status == IpTradeSecretProtectionControlStatus.suspended &&
        suspendedAt == null) {
      throw StateError(
        'Askıya alınan kontrolün askıya alınma tarihi zorunludur.',
      );
    }

    if (status == IpTradeSecretProtectionControlStatus.retired &&
        retiredAt == null) {
      throw StateError(
        'Kullanımdan kaldırılan kontrolün kaldırılma tarihi zorunludur.',
      );
    }

    _validatedNonNegativeInt(findingCount, 'findingCount');

    _validatedNonNegativeInt(openFindingCount, 'openFindingCount');

    if (openFindingCount > findingCount) {
      throw StateError(
        'Açık bulgu sayısı toplam bulgu sayısından fazla olamaz.',
      );
    }

    if (remediationRequired &&
        (remediationDueAt == null ||
            remediationOwnerUserId == null ||
            remediationOwnerUserId!.trim().isEmpty ||
            remediationPlan == null ||
            remediationPlan!.trim().isEmpty)) {
      throw StateError(
        'İyileştirme gerekiyorsa son tarih, sorumlu ve plan zorunludur.',
      );
    }

    if (remediationCompletedAt != null && remediationRequired) {
      throw StateError(
        'İyileştirme tamamlandıysa remediationRequired false olmalıdır.',
      );
    }

    if (exceptionApproved &&
        (exceptionReason == null ||
            exceptionReason!.trim().isEmpty ||
            exceptionApprovedBy == null ||
            exceptionApprovedBy!.trim().isEmpty ||
            exceptionExpiresAt == null)) {
      throw StateError(
        'Onaylı istisnada gerekçe, onaylayan ve bitiş tarihi zorunludur.',
      );
    }

    if (!preventiveCoverage && !detectiveCoverage && !correctiveCoverage) {
      throw StateError('Kontrol en az bir koruma kapsamına sahip olmalıdır.');
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

  static bool? _nullableBool(Object? value) {
    if (value is bool) {
      return value;
    }

    return null;
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

  static int _validatedNonNegativeInt(int value, String fieldName) {
    if (value < 0) {
      throw RangeError.value(value, fieldName, '$fieldName negatif olamaz.');
    }

    return value;
  }
}
