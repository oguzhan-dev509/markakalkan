import '../constants/ip_trade_secret_detail_enums.dart';
import '../models/ip_trade_secret_portfolio_summary_model.dart';

class IpTradeSecretPortfolioAggregationFacts {
  const IpTradeSecretPortfolioAggregationFacts({
    this.tradeSecretIds = const <String>[],
    this.activeTradeSecretIds = const <String>[],
    this.retiredTradeSecretIds = const <String>[],
    this.criticalTradeSecretIds = const <String>[],
    this.highRiskTradeSecretIds = const <String>[],
    this.openIncidentIds = const <String>[],
    this.highImpactIncidentIds = const <String>[],
    this.overdueRemediationActionIds = const <String>[],
    this.blockedRemediationActionIds = const <String>[],
    this.criticalAlertRuleIds = const <String>[],
    this.unresolvedAlertRuleIds = const <String>[],
    this.pendingDecisionIds = const <String>[],
    this.riskAcceptanceDecisionIds = const <String>[],
    this.weakControlIds = const <String>[],
    this.missingEvidenceRecordIds = const <String>[],
    this.highRiskExitTransitionIds = const <String>[],
    this.expiringAccessGrantIds = const <String>[],
    this.overdueReviewRecordIds = const <String>[],
    this.riskScores = const <int>[],
    this.resilienceScores = const <int>[],
    this.defensibilityScores = const <int>[],
    this.controlEffectivenessScores = const <int>[],
    this.financialExposureByCurrency = const <String, num>{},
    this.departmentRiskCounts = const <String, int>{},
    this.countryRiskCounts = const <String, int>{},
    this.categoryRiskCounts = const <String, int>{},
    this.managementAttentionRequired = false,
    this.legalAttentionRequired = false,
    this.securityAttentionRequired = false,
    this.dataCompletenessWarning = false,
  });

  final List<String> tradeSecretIds;
  final List<String> activeTradeSecretIds;
  final List<String> retiredTradeSecretIds;
  final List<String> criticalTradeSecretIds;
  final List<String> highRiskTradeSecretIds;
  final List<String> openIncidentIds;
  final List<String> highImpactIncidentIds;
  final List<String> overdueRemediationActionIds;
  final List<String> blockedRemediationActionIds;
  final List<String> criticalAlertRuleIds;
  final List<String> unresolvedAlertRuleIds;
  final List<String> pendingDecisionIds;
  final List<String> riskAcceptanceDecisionIds;
  final List<String> weakControlIds;
  final List<String> missingEvidenceRecordIds;
  final List<String> highRiskExitTransitionIds;
  final List<String> expiringAccessGrantIds;
  final List<String> overdueReviewRecordIds;
  final List<int> riskScores;
  final List<int> resilienceScores;
  final List<int> defensibilityScores;
  final List<int> controlEffectivenessScores;
  final Map<String, num> financialExposureByCurrency;
  final Map<String, int> departmentRiskCounts;
  final Map<String, int> countryRiskCounts;
  final Map<String, int> categoryRiskCounts;
  final bool managementAttentionRequired;
  final bool legalAttentionRequired;
  final bool securityAttentionRequired;
  final bool dataCompletenessWarning;
}

class IpTradeSecretPortfolioAggregationService {
  const IpTradeSecretPortfolioAggregationService();

  IpTradeSecretPortfolioSummaryModel aggregateFacts({
    required String tenantId,
    required IpTradeSecretPortfolioScope scope,
    required String scopeId,
    required String generatedBy,
    required DateTime generatedAt,
    required IpTradeSecretPortfolioAggregationFacts facts,
    String? brandId,
    String? businessUnitId,
    String? departmentId,
    String? countryCode,
    String? categoryCode,
    DateTime? snapshotStartAt,
    DateTime? snapshotEndAt,
    IpTradeSecretPortfolioSummaryModel? previousSummary,
  }) {
    final tradeSecretIds = _cleanSet(facts.tradeSecretIds);
    final activeIds = _cleanSet(facts.activeTradeSecretIds);
    final retiredIds = _cleanSet(facts.retiredTradeSecretIds);
    final criticalIds = _cleanSet(facts.criticalTradeSecretIds);
    final highRiskIds = _cleanSet(facts.highRiskTradeSecretIds);

    final averageRiskScore = _average(facts.riskScores);
    final averageResilienceScore = _average(facts.resilienceScores);
    final averageDefensibilityScore = _average(facts.defensibilityScores);
    final averageControlEffectivenessScore = _average(
      facts.controlEffectivenessScores,
    );

    final exposureEntries = facts.financialExposureByCurrency.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value > 0)
        .toList(growable: false);
    final singleCurrency = exposureEntries.length <= 1;
    final totalFinancialExposure = singleCurrency
        ? exposureEntries.fold<num>(0, (sum, entry) => sum + entry.value)
        : 0;
    final currencyCode = exposureEntries.length == 1
        ? exposureEntries.single.key.trim().toUpperCase()
        : null;

    final criticalIncidentIds = _cleanSet(facts.highImpactIncidentIds);
    final overdueActionIds = _cleanSet(facts.overdueRemediationActionIds);
    final criticalAlertIds = _cleanSet(facts.criticalAlertRuleIds);
    final pendingDecisionIds = _cleanSet(facts.pendingDecisionIds);

    final health = classifyHealth(
      averageRiskScore: averageRiskScore,
      criticalTradeSecretCount: criticalIds.length,
      highRiskTradeSecretCount: highRiskIds.length,
      highImpactIncidentCount: criticalIncidentIds.length,
      overdueRemediationCount: overdueActionIds.length,
      criticalAlertCount: criticalAlertIds.length,
      missingEvidenceCount: _cleanSet(facts.missingEvidenceRecordIds).length,
      highRiskExitCount: _cleanSet(facts.highRiskExitTransitionIds).length,
    );

    final trend = classifyTrend(
      currentAverageRiskScore: averageRiskScore,
      currentCriticalCount:
          criticalIds.length +
          criticalIncidentIds.length +
          criticalAlertIds.length,
      previousSummary: previousSummary,
    );

    final managementAttention =
        facts.managementAttentionRequired ||
        health == IpTradeSecretPortfolioHealth.critical ||
        criticalIncidentIds.isNotEmpty ||
        criticalAlertIds.isNotEmpty ||
        _cleanSet(facts.highRiskExitTransitionIds).isNotEmpty;
    final legalAttention =
        facts.legalAttentionRequired ||
        _cleanSet(facts.missingEvidenceRecordIds).isNotEmpty ||
        averageDefensibilityScore < 60;
    final securityAttention =
        facts.securityAttentionRequired ||
        criticalAlertIds.isNotEmpty ||
        criticalIncidentIds.isNotEmpty ||
        _cleanSet(facts.weakControlIds).isNotEmpty;

    final model = IpTradeSecretPortfolioSummaryModel(
      id: buildSnapshotId(
        tenantId: tenantId,
        scope: scope,
        scopeId: scopeId,
        snapshotEndAt: snapshotEndAt ?? generatedAt,
      ),
      tenantId: tenantId.trim(),
      brandId: _cleanNullable(brandId),
      businessUnitId: _cleanNullable(businessUnitId),
      departmentId: _cleanNullable(departmentId),
      countryCode: _cleanNullable(countryCode)?.toUpperCase(),
      categoryCode: _cleanNullable(categoryCode),
      scope: scope,
      scopeId: scopeId.trim(),
      health: health,
      trend: trend,
      totalTradeSecretCount: tradeSecretIds.length,
      activeTradeSecretCount: activeIds.length,
      retiredTradeSecretCount: retiredIds.length,
      criticalTradeSecretCount: criticalIds.length,
      highRiskTradeSecretCount: highRiskIds.length,
      openIncidentCount: _cleanSet(facts.openIncidentIds).length,
      highImpactIncidentCount: criticalIncidentIds.length,
      overdueRemediationCount: overdueActionIds.length,
      blockedRemediationCount: _cleanSet(
        facts.blockedRemediationActionIds,
      ).length,
      criticalAlertCount: criticalAlertIds.length,
      unresolvedAlertCount: _cleanSet(facts.unresolvedAlertRuleIds).length,
      pendingDecisionCount: pendingDecisionIds.length,
      riskAcceptanceDecisionCount: _cleanSet(
        facts.riskAcceptanceDecisionIds,
      ).length,
      weakControlCount: _cleanSet(facts.weakControlIds).length,
      missingEvidenceCount: _cleanSet(facts.missingEvidenceRecordIds).length,
      highRiskExitCount: _cleanSet(facts.highRiskExitTransitionIds).length,
      expiringAccessGrantCount: _cleanSet(facts.expiringAccessGrantIds).length,
      overdueReviewCount: _cleanSet(facts.overdueReviewRecordIds).length,
      averageRiskScore: averageRiskScore,
      averageResilienceScore: averageResilienceScore,
      averageDefensibilityScore: averageDefensibilityScore,
      averageControlEffectivenessScore: averageControlEffectivenessScore,
      totalFinancialExposure: totalFinancialExposure,
      currencyCode: currencyCode,
      departmentRiskCounts: _cleanCountMap(facts.departmentRiskCounts),
      countryRiskCounts: _cleanCountMap(facts.countryRiskCounts),
      categoryRiskCounts: _cleanCountMap(facts.categoryRiskCounts),
      topRiskTradeSecretIds: <String>[
        ...criticalIds,
        ...highRiskIds.where((id) => !criticalIds.contains(id)),
      ].take(20).toList(growable: false),
      criticalIncidentIds: criticalIncidentIds.take(20).toList(growable: false),
      overdueRemediationActionIds: overdueActionIds
          .take(20)
          .toList(growable: false),
      criticalAlertRuleIds: criticalAlertIds.take(20).toList(growable: false),
      pendingDecisionIds: pendingDecisionIds.take(20).toList(growable: false),
      managementAttentionRequired: managementAttention,
      legalAttentionRequired: legalAttention,
      securityAttentionRequired: securityAttention,
      dataCompletenessWarning: facts.dataCompletenessWarning || !singleCurrency,
      snapshotStartAt: snapshotStartAt?.toUtc(),
      snapshotEndAt: snapshotEndAt?.toUtc(),
      metadata: <String, dynamic>{
        'aggregationVersion': 1,
        'currencyConflictDetected': !singleCurrency,
      },
      generatedAt: generatedAt.toUtc(),
      generatedBy: generatedBy.trim(),
    );

    model.toMap();
    return model;
  }

  IpTradeSecretPortfolioHealth classifyHealth({
    required int averageRiskScore,
    required int criticalTradeSecretCount,
    required int highRiskTradeSecretCount,
    required int highImpactIncidentCount,
    required int overdueRemediationCount,
    required int criticalAlertCount,
    required int missingEvidenceCount,
    required int highRiskExitCount,
  }) {
    final criticalSignals =
        criticalTradeSecretCount +
        highImpactIncidentCount +
        criticalAlertCount +
        highRiskExitCount;

    if (criticalSignals >= 3 || averageRiskScore >= 85) {
      return IpTradeSecretPortfolioHealth.critical;
    }
    if (criticalSignals > 0 ||
        averageRiskScore >= 70 ||
        overdueRemediationCount >= 5) {
      return IpTradeSecretPortfolioHealth.highRisk;
    }
    if (highRiskTradeSecretCount >= 3 ||
        averageRiskScore >= 55 ||
        missingEvidenceCount >= 3 ||
        overdueRemediationCount >= 2) {
      return IpTradeSecretPortfolioHealth.elevated;
    }
    if (averageRiskScore >= 35 ||
        highRiskTradeSecretCount > 0 ||
        missingEvidenceCount > 0 ||
        overdueRemediationCount > 0) {
      return IpTradeSecretPortfolioHealth.watch;
    }
    return IpTradeSecretPortfolioHealth.healthy;
  }

  IpTradeSecretPortfolioTrend classifyTrend({
    required int currentAverageRiskScore,
    required int currentCriticalCount,
    required IpTradeSecretPortfolioSummaryModel? previousSummary,
  }) {
    if (previousSummary == null) {
      return IpTradeSecretPortfolioTrend.unknown;
    }

    final previousCriticalCount =
        previousSummary.criticalTradeSecretCount +
        previousSummary.highImpactIncidentCount +
        previousSummary.criticalAlertCount;
    final riskDelta =
        currentAverageRiskScore - previousSummary.averageRiskScore;
    final criticalDelta = currentCriticalCount - previousCriticalCount;

    if (riskDelta <= -10 && criticalDelta <= 0) {
      return IpTradeSecretPortfolioTrend.improving;
    }
    if (riskDelta >= 10 && criticalDelta >= 0) {
      return IpTradeSecretPortfolioTrend.deteriorating;
    }
    if (riskDelta.abs() >= 15 || criticalDelta.abs() >= 3) {
      return IpTradeSecretPortfolioTrend.volatile;
    }
    return IpTradeSecretPortfolioTrend.stable;
  }

  String buildSnapshotId({
    required String tenantId,
    required IpTradeSecretPortfolioScope scope,
    required String scopeId,
    required DateTime snapshotEndAt,
  }) {
    final tenant = _slug(tenantId);
    final scopeKey = _slug(scopeId);
    if (tenant.isEmpty || scopeKey.isEmpty) {
      throw StateError('Snapshot kimliği için tenantId ve scopeId zorunludur.');
    }
    final date = snapshotEndAt.toUtc().toIso8601String().substring(0, 10);
    return '${tenant}_${scope.value}_${scopeKey}_$date';
  }

  static List<String> _cleanSet(Iterable<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static Map<String, int> _cleanCountMap(Map<String, int> values) {
    final result = <String, int>{};
    for (final entry in values.entries) {
      final key = entry.key.trim();
      if (key.isNotEmpty && entry.value >= 0) {
        result[key] = entry.value;
      }
    }
    return result;
  }

  static int _average(Iterable<int> values) {
    final valid = values.where((item) => item >= 0 && item <= 100).toList();
    if (valid.isEmpty) return 0;
    return (valid.reduce((a, b) => a + b) / valid.length).round();
  }

  static String? _cleanNullable(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  static String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
