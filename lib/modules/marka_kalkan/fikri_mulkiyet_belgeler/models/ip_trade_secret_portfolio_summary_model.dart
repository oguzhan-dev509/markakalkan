import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ip_trade_secret_detail_enums.dart';
import '../utils/ip_model_utils.dart';

class IpTradeSecretPortfolioSummaryModel {
  const IpTradeSecretPortfolioSummaryModel({
    required this.id,
    required this.tenantId,
    required this.scope,
    required this.scopeId,
    required this.health,
    required this.trend,
    required this.generatedAt,
    required this.generatedBy,
    this.brandId,
    this.businessUnitId,
    this.departmentId,
    this.countryCode,
    this.categoryCode,
    this.totalTradeSecretCount = 0,
    this.activeTradeSecretCount = 0,
    this.retiredTradeSecretCount = 0,
    this.criticalTradeSecretCount = 0,
    this.highRiskTradeSecretCount = 0,
    this.openIncidentCount = 0,
    this.highImpactIncidentCount = 0,
    this.overdueRemediationCount = 0,
    this.blockedRemediationCount = 0,
    this.criticalAlertCount = 0,
    this.unresolvedAlertCount = 0,
    this.pendingDecisionCount = 0,
    this.riskAcceptanceDecisionCount = 0,
    this.weakControlCount = 0,
    this.missingEvidenceCount = 0,
    this.highRiskExitCount = 0,
    this.expiringAccessGrantCount = 0,
    this.overdueReviewCount = 0,
    this.averageRiskScore = 0,
    this.averageResilienceScore = 0,
    this.averageDefensibilityScore = 0,
    this.averageControlEffectivenessScore = 0,
    this.totalFinancialExposure = 0,
    this.currencyCode,
    this.departmentRiskCounts = const <String, int>{},
    this.countryRiskCounts = const <String, int>{},
    this.categoryRiskCounts = const <String, int>{},
    this.topRiskTradeSecretIds = const <String>[],
    this.criticalIncidentIds = const <String>[],
    this.overdueRemediationActionIds = const <String>[],
    this.criticalAlertRuleIds = const <String>[],
    this.pendingDecisionIds = const <String>[],
    this.managementAttentionRequired = false,
    this.legalAttentionRequired = false,
    this.securityAttentionRequired = false,
    this.dataCompletenessWarning = false,
    this.snapshotStartAt,
    this.snapshotEndAt,
    this.notes,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String tenantId;
  final String? brandId;
  final String? businessUnitId;
  final String? departmentId;
  final String? countryCode;
  final String? categoryCode;
  final IpTradeSecretPortfolioScope scope;
  final String scopeId;
  final IpTradeSecretPortfolioHealth health;
  final IpTradeSecretPortfolioTrend trend;

  final int totalTradeSecretCount;
  final int activeTradeSecretCount;
  final int retiredTradeSecretCount;
  final int criticalTradeSecretCount;
  final int highRiskTradeSecretCount;
  final int openIncidentCount;
  final int highImpactIncidentCount;
  final int overdueRemediationCount;
  final int blockedRemediationCount;
  final int criticalAlertCount;
  final int unresolvedAlertCount;
  final int pendingDecisionCount;
  final int riskAcceptanceDecisionCount;
  final int weakControlCount;
  final int missingEvidenceCount;
  final int highRiskExitCount;
  final int expiringAccessGrantCount;
  final int overdueReviewCount;

  final int averageRiskScore;
  final int averageResilienceScore;
  final int averageDefensibilityScore;
  final int averageControlEffectivenessScore;

  final num totalFinancialExposure;
  final String? currencyCode;

  final Map<String, int> departmentRiskCounts;
  final Map<String, int> countryRiskCounts;
  final Map<String, int> categoryRiskCounts;

  final List<String> topRiskTradeSecretIds;
  final List<String> criticalIncidentIds;
  final List<String> overdueRemediationActionIds;
  final List<String> criticalAlertRuleIds;
  final List<String> pendingDecisionIds;

  final bool managementAttentionRequired;
  final bool legalAttentionRequired;
  final bool securityAttentionRequired;
  final bool dataCompletenessWarning;

  final DateTime? snapshotStartAt;
  final DateTime? snapshotEndAt;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime generatedAt;
  final String generatedBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory IpTradeSecretPortfolioSummaryModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Ticari sır portföy özeti veri içermiyor: ${document.id}',
      );
    }

    return IpTradeSecretPortfolioSummaryModel.fromMap(
      id: document.id,
      data: data,
    );
  }

  factory IpTradeSecretPortfolioSummaryModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final generatedAt = IpModelUtils.dateTimeFromValue(data['generatedAt']);

    if (generatedAt == null) {
      throw StateError('Portföy özeti üretim tarihi eksik: $id');
    }

    return IpTradeSecretPortfolioSummaryModel(
      id: id.trim(),
      tenantId: IpModelUtils.requiredString(data['tenantId']),
      brandId: IpModelUtils.nullableString(data['brandId']),
      businessUnitId: IpModelUtils.nullableString(data['businessUnitId']),
      departmentId: IpModelUtils.nullableString(data['departmentId']),
      countryCode: IpModelUtils.nullableString(data['countryCode']),
      categoryCode: IpModelUtils.nullableString(data['categoryCode']),
      scope: IpTradeSecretPortfolioScope.fromValue(data['scope']?.toString()),
      scopeId: IpModelUtils.requiredString(data['scopeId']),
      health: IpTradeSecretPortfolioHealth.fromValue(
        data['health']?.toString(),
      ),
      trend: IpTradeSecretPortfolioTrend.fromValue(data['trend']?.toString()),
      totalTradeSecretCount: _nonNegativeInt(data['totalTradeSecretCount']),
      activeTradeSecretCount: _nonNegativeInt(data['activeTradeSecretCount']),
      retiredTradeSecretCount: _nonNegativeInt(data['retiredTradeSecretCount']),
      criticalTradeSecretCount: _nonNegativeInt(
        data['criticalTradeSecretCount'],
      ),
      highRiskTradeSecretCount: _nonNegativeInt(
        data['highRiskTradeSecretCount'],
      ),
      openIncidentCount: _nonNegativeInt(data['openIncidentCount']),
      highImpactIncidentCount: _nonNegativeInt(data['highImpactIncidentCount']),
      overdueRemediationCount: _nonNegativeInt(data['overdueRemediationCount']),
      blockedRemediationCount: _nonNegativeInt(data['blockedRemediationCount']),
      criticalAlertCount: _nonNegativeInt(data['criticalAlertCount']),
      unresolvedAlertCount: _nonNegativeInt(data['unresolvedAlertCount']),
      pendingDecisionCount: _nonNegativeInt(data['pendingDecisionCount']),
      riskAcceptanceDecisionCount: _nonNegativeInt(
        data['riskAcceptanceDecisionCount'],
      ),
      weakControlCount: _nonNegativeInt(data['weakControlCount']),
      missingEvidenceCount: _nonNegativeInt(data['missingEvidenceCount']),
      highRiskExitCount: _nonNegativeInt(data['highRiskExitCount']),
      expiringAccessGrantCount: _nonNegativeInt(
        data['expiringAccessGrantCount'],
      ),
      overdueReviewCount: _nonNegativeInt(data['overdueReviewCount']),
      averageRiskScore: _boundedScore(data['averageRiskScore']),
      averageResilienceScore: _boundedScore(data['averageResilienceScore']),
      averageDefensibilityScore: _boundedScore(
        data['averageDefensibilityScore'],
      ),
      averageControlEffectivenessScore: _boundedScore(
        data['averageControlEffectivenessScore'],
      ),
      totalFinancialExposure: data['totalFinancialExposure'] is num
          ? data['totalFinancialExposure'] as num
          : 0,
      currencyCode: IpModelUtils.nullableString(data['currencyCode']),
      departmentRiskCounts: _intMap(data['departmentRiskCounts']),
      countryRiskCounts: _intMap(data['countryRiskCounts']),
      categoryRiskCounts: _intMap(data['categoryRiskCounts']),
      topRiskTradeSecretIds: _stringList(data['topRiskTradeSecretIds']),
      criticalIncidentIds: _stringList(data['criticalIncidentIds']),
      overdueRemediationActionIds: _stringList(
        data['overdueRemediationActionIds'],
      ),
      criticalAlertRuleIds: _stringList(data['criticalAlertRuleIds']),
      pendingDecisionIds: _stringList(data['pendingDecisionIds']),
      managementAttentionRequired: data['managementAttentionRequired'] == true,
      legalAttentionRequired: data['legalAttentionRequired'] == true,
      securityAttentionRequired: data['securityAttentionRequired'] == true,
      dataCompletenessWarning: data['dataCompletenessWarning'] == true,
      snapshotStartAt: IpModelUtils.dateTimeFromValue(data['snapshotStartAt']),
      snapshotEndAt: IpModelUtils.dateTimeFromValue(data['snapshotEndAt']),
      notes: IpModelUtils.nullableString(data['notes']),
      metadata: IpModelUtils.mapFromValue(data['metadata']),
      generatedAt: generatedAt,
      generatedBy: IpModelUtils.requiredString(data['generatedBy']),
      updatedAt: IpModelUtils.dateTimeFromValue(data['updatedAt']),
      updatedBy: IpModelUtils.nullableString(data['updatedBy']),
    );
  }

  Map<String, dynamic> toMap() {
    _validate();

    return <String, dynamic>{
      'tenantId': tenantId.trim(),
      'brandId': IpModelUtils.cleanNullable(brandId),
      'businessUnitId': IpModelUtils.cleanNullable(businessUnitId),
      'departmentId': IpModelUtils.cleanNullable(departmentId),
      'countryCode': IpModelUtils.cleanNullable(countryCode),
      'categoryCode': IpModelUtils.cleanNullable(categoryCode),
      'scope': scope.value,
      'scopeId': scopeId.trim(),
      'health': health.value,
      'trend': trend.value,
      'totalTradeSecretCount': totalTradeSecretCount,
      'activeTradeSecretCount': activeTradeSecretCount,
      'retiredTradeSecretCount': retiredTradeSecretCount,
      'criticalTradeSecretCount': criticalTradeSecretCount,
      'highRiskTradeSecretCount': highRiskTradeSecretCount,
      'openIncidentCount': openIncidentCount,
      'highImpactIncidentCount': highImpactIncidentCount,
      'overdueRemediationCount': overdueRemediationCount,
      'blockedRemediationCount': blockedRemediationCount,
      'criticalAlertCount': criticalAlertCount,
      'unresolvedAlertCount': unresolvedAlertCount,
      'pendingDecisionCount': pendingDecisionCount,
      'riskAcceptanceDecisionCount': riskAcceptanceDecisionCount,
      'weakControlCount': weakControlCount,
      'missingEvidenceCount': missingEvidenceCount,
      'highRiskExitCount': highRiskExitCount,
      'expiringAccessGrantCount': expiringAccessGrantCount,
      'overdueReviewCount': overdueReviewCount,
      'averageRiskScore': _validatedScore(averageRiskScore, 'averageRiskScore'),
      'averageResilienceScore': _validatedScore(
        averageResilienceScore,
        'averageResilienceScore',
      ),
      'averageDefensibilityScore': _validatedScore(
        averageDefensibilityScore,
        'averageDefensibilityScore',
      ),
      'averageControlEffectivenessScore': _validatedScore(
        averageControlEffectivenessScore,
        'averageControlEffectivenessScore',
      ),
      'totalFinancialExposure': _validatedAmount(
        totalFinancialExposure,
        'totalFinancialExposure',
      ),
      'currencyCode': IpModelUtils.cleanNullable(currencyCode),
      'departmentRiskCounts': _cleanIntMap(departmentRiskCounts),
      'countryRiskCounts': _cleanIntMap(countryRiskCounts),
      'categoryRiskCounts': _cleanIntMap(categoryRiskCounts),
      'topRiskTradeSecretIds': _cleanList(topRiskTradeSecretIds),
      'criticalIncidentIds': _cleanList(criticalIncidentIds),
      'overdueRemediationActionIds': _cleanList(overdueRemediationActionIds),
      'criticalAlertRuleIds': _cleanList(criticalAlertRuleIds),
      'pendingDecisionIds': _cleanList(pendingDecisionIds),
      'managementAttentionRequired': managementAttentionRequired,
      'legalAttentionRequired': legalAttentionRequired,
      'securityAttentionRequired': securityAttentionRequired,
      'dataCompletenessWarning': dataCompletenessWarning,
      'snapshotStartAt': IpModelUtils.timestampOrNull(snapshotStartAt),
      'snapshotEndAt': IpModelUtils.timestampOrNull(snapshotEndAt),
      'notes': IpModelUtils.cleanNullable(notes),
      'metadata': Map<String, dynamic>.from(metadata),
      'generatedAt': Timestamp.fromDate(generatedAt),
      'generatedBy': generatedBy.trim(),
      'updatedAt': IpModelUtils.timestampOrNull(updatedAt),
      'updatedBy': IpModelUtils.cleanNullable(updatedBy),
    };
  }

  bool get hasCompleteIdentity {
    return tenantId.trim().isNotEmpty &&
        scopeId.trim().isNotEmpty &&
        generatedBy.trim().isNotEmpty;
  }

  bool get hasCriticalExposure {
    return criticalTradeSecretCount > 0 ||
        highImpactIncidentCount > 0 ||
        criticalAlertCount > 0 ||
        highRiskExitCount > 0;
  }

  bool get hasOperationalBacklog {
    return overdueRemediationCount > 0 ||
        blockedRemediationCount > 0 ||
        overdueReviewCount > 0 ||
        pendingDecisionCount > 0;
  }

  bool get hasLegalDefensibilityGap {
    return missingEvidenceCount > 0 ||
        averageDefensibilityScore < 60 ||
        legalAttentionRequired;
  }

  bool get requiresImmediateManagementAttention {
    return managementAttentionRequired ||
        health == IpTradeSecretPortfolioHealth.critical ||
        hasCriticalExposure ||
        (averageRiskScore >= 80 && hasOperationalBacklog);
  }

  bool get shouldAppearOnExecutiveDashboard {
    return requiresImmediateManagementAttention ||
        hasOperationalBacklog ||
        hasLegalDefensibilityGap ||
        securityAttentionRequired ||
        dataCompletenessWarning;
  }

  double get activePortfolioRatio {
    if (totalTradeSecretCount == 0) {
      return 0;
    }

    return activeTradeSecretCount / totalTradeSecretCount;
  }

  bool get storesPlaintextSecretContent => false;

  void _validate() {
    if (!hasCompleteIdentity) {
      throw StateError(
        'Ticari sır portföy özetinin zorunlu kimlik alanları eksik.',
      );
    }

    if (scope == IpTradeSecretPortfolioScope.brand &&
        (brandId == null || brandId!.trim().isEmpty)) {
      throw StateError('Marka kapsamlı portföy özetinde brandId zorunludur.');
    }

    if (scope == IpTradeSecretPortfolioScope.businessUnit &&
        (businessUnitId == null || businessUnitId!.trim().isEmpty)) {
      throw StateError(
        'İş birimi kapsamlı portföy özetinde businessUnitId zorunludur.',
      );
    }

    if (scope == IpTradeSecretPortfolioScope.department &&
        (departmentId == null || departmentId!.trim().isEmpty)) {
      throw StateError(
        'Departman kapsamlı portföy özetinde departmentId zorunludur.',
      );
    }

    if (scope == IpTradeSecretPortfolioScope.country &&
        (countryCode == null || countryCode!.trim().length != 2)) {
      throw StateError(
        'Ülke kapsamlı portföy özetinde iki harfli countryCode zorunludur.',
      );
    }

    if (scope == IpTradeSecretPortfolioScope.category &&
        (categoryCode == null || categoryCode!.trim().isEmpty)) {
      throw StateError(
        'Kategori kapsamlı portföy özetinde categoryCode zorunludur.',
      );
    }

    final countFields = <String, int>{
      'totalTradeSecretCount': totalTradeSecretCount,
      'activeTradeSecretCount': activeTradeSecretCount,
      'retiredTradeSecretCount': retiredTradeSecretCount,
      'criticalTradeSecretCount': criticalTradeSecretCount,
      'highRiskTradeSecretCount': highRiskTradeSecretCount,
      'openIncidentCount': openIncidentCount,
      'highImpactIncidentCount': highImpactIncidentCount,
      'overdueRemediationCount': overdueRemediationCount,
      'blockedRemediationCount': blockedRemediationCount,
      'criticalAlertCount': criticalAlertCount,
      'unresolvedAlertCount': unresolvedAlertCount,
      'pendingDecisionCount': pendingDecisionCount,
      'riskAcceptanceDecisionCount': riskAcceptanceDecisionCount,
      'weakControlCount': weakControlCount,
      'missingEvidenceCount': missingEvidenceCount,
      'highRiskExitCount': highRiskExitCount,
      'expiringAccessGrantCount': expiringAccessGrantCount,
      'overdueReviewCount': overdueReviewCount,
    };

    for (final entry in countFields.entries) {
      if (entry.value < 0) {
        throw RangeError.value(
          entry.value,
          entry.key,
          '${entry.key} negatif olamaz.',
        );
      }
    }

    if (activeTradeSecretCount + retiredTradeSecretCount >
        totalTradeSecretCount) {
      throw StateError(
        'Aktif ve emekli ticari sır toplamı genel toplamı aşamaz.',
      );
    }

    if (criticalTradeSecretCount + highRiskTradeSecretCount >
        totalTradeSecretCount) {
      throw StateError(
        'Kritik ve yüksek riskli ticari sır toplamı genel toplamı aşamaz.',
      );
    }

    for (final entry in <String, int>{
      'averageRiskScore': averageRiskScore,
      'averageResilienceScore': averageResilienceScore,
      'averageDefensibilityScore': averageDefensibilityScore,
      'averageControlEffectivenessScore': averageControlEffectivenessScore,
    }.entries) {
      _validatedScore(entry.value, entry.key);
    }

    _validatedAmount(totalFinancialExposure, 'totalFinancialExposure');

    if (totalFinancialExposure > 0 &&
        (currencyCode == null || currencyCode!.trim().length != 3)) {
      throw StateError(
        'Parasal maruziyet varsa üç harfli para birimi kodu zorunludur.',
      );
    }

    for (final entry in <String, Map<String, int>>{
      'departmentRiskCounts': departmentRiskCounts,
      'countryRiskCounts': countryRiskCounts,
      'categoryRiskCounts': categoryRiskCounts,
    }.entries) {
      for (final item in entry.value.entries) {
        if (item.key.trim().isEmpty || item.value < 0) {
          throw StateError(
            '${entry.key} içinde boş anahtar veya negatif değer olamaz.',
          );
        }
      }
    }

    if (snapshotStartAt != null &&
        snapshotEndAt != null &&
        snapshotEndAt!.isBefore(snapshotStartAt!)) {
      throw StateError('Özet bitiş tarihi başlangıç tarihinden önce olamaz.');
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

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) {
      return const <String, int>{};
    }

    final result = <String, int>{};

    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final rawValue = entry.value;

      if (key.isEmpty) {
        continue;
      }

      if (rawValue is int) {
        result[key] = rawValue;
      } else if (rawValue is num) {
        result[key] = rawValue.round();
      }
    }

    return result;
  }

  static Map<String, int> _cleanIntMap(Map<String, int> values) {
    final result = <String, int>{};

    for (final entry in values.entries) {
      final key = entry.key.trim();

      if (key.isNotEmpty) {
        result[key] = entry.value;
      }
    }

    return result;
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

  static int _boundedScore(Object? value) {
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

  static num _validatedAmount(num value, String fieldName) {
    if (value < 0) {
      throw RangeError.value(value, fieldName, '$fieldName negatif olamaz.');
    }

    return value;
  }
}
