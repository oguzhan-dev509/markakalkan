import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_portfolio_summary_model.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/services/ip_trade_secret_portfolio_aggregation_service.dart';

void main() {
  const service = IpTradeSecretPortfolioAggregationService();

  IpTradeSecretPortfolioAggregationFacts facts({
    List<String> tradeSecretIds = const <String>['s1', 's2', 's3'],
    List<String> activeTradeSecretIds = const <String>['s1', 's2'],
    List<String> retiredTradeSecretIds = const <String>['s3'],
    List<String> criticalTradeSecretIds = const <String>[],
    List<String> highRiskTradeSecretIds = const <String>[],
    List<String> highImpactIncidentIds = const <String>[],
    List<String> overdueRemediationActionIds = const <String>[],
    List<String> criticalAlertRuleIds = const <String>[],
    List<String> weakControlIds = const <String>[],
    List<String> missingEvidenceRecordIds = const <String>[],
    List<String> highRiskExitTransitionIds = const <String>[],
    List<int> riskScores = const <int>[20, 40],
    List<int> resilienceScores = const <int>[70, 80],
    List<int> defensibilityScores = const <int>[65, 75],
    List<int> controlEffectivenessScores = const <int>[70, 90],
    Map<String, num> financialExposureByCurrency = const <String, num>{},
  }) {
    return IpTradeSecretPortfolioAggregationFacts(
      tradeSecretIds: tradeSecretIds,
      activeTradeSecretIds: activeTradeSecretIds,
      retiredTradeSecretIds: retiredTradeSecretIds,
      criticalTradeSecretIds: criticalTradeSecretIds,
      highRiskTradeSecretIds: highRiskTradeSecretIds,
      highImpactIncidentIds: highImpactIncidentIds,
      overdueRemediationActionIds: overdueRemediationActionIds,
      criticalAlertRuleIds: criticalAlertRuleIds,
      weakControlIds: weakControlIds,
      missingEvidenceRecordIds: missingEvidenceRecordIds,
      highRiskExitTransitionIds: highRiskExitTransitionIds,
      riskScores: riskScores,
      resilienceScores: resilienceScores,
      defensibilityScores: defensibilityScores,
      controlEffectivenessScores: controlEffectivenessScores,
      financialExposureByCurrency: financialExposureByCurrency,
      departmentRiskCounts: const <String, int>{'R&D': 2},
      countryRiskCounts: const <String, int>{'TR': 3},
      categoryRiskCounts: const <String, int>{'formula': 3},
    );
  }

  IpTradeSecretPortfolioSummaryModel aggregate({
    IpTradeSecretPortfolioAggregationFacts? customFacts,
    IpTradeSecretPortfolioSummaryModel? previousSummary,
  }) {
    return service.aggregateFacts(
      tenantId: 'tenant-1',
      scope: IpTradeSecretPortfolioScope.brand,
      scopeId: 'brand-1',
      brandId: 'brand-1',
      generatedBy: 'system-1',
      generatedAt: DateTime.utc(2026, 7, 5, 12),
      snapshotStartAt: DateTime.utc(2026, 7, 1),
      snapshotEndAt: DateTime.utc(2026, 7, 5),
      previousSummary: previousSummary,
      facts: customFacts ?? facts(),
    );
  }

  test('temel toplama doğru sayaçları üretir', () {
    final summary = aggregate();
    expect(summary.totalTradeSecretCount, 3);
    expect(summary.activeTradeSecretCount, 2);
    expect(summary.retiredTradeSecretCount, 1);
  });

  test('tekrarlı kimlikleri tekilleştirir', () {
    final summary = aggregate(
      customFacts: facts(
        tradeSecretIds: const <String>['s1', 's1', 's2'],
        activeTradeSecretIds: const <String>['s1', 's1'],
        retiredTradeSecretIds: const <String>['s2'],
      ),
    );
    expect(summary.totalTradeSecretCount, 2);
    expect(summary.activeTradeSecretCount, 1);
  });

  test('ortalama skorları hesaplar', () {
    final summary = aggregate(
      customFacts: facts(riskScores: const <int>[10, 20, 31]),
    );
    expect(summary.averageRiskScore, 20);
  });

  test('geçersiz skorları dışlar', () {
    final summary = aggregate(
      customFacts: facts(riskScores: const <int>[-1, 50, 101]),
    );
    expect(summary.averageRiskScore, 50);
  });

  test('tek para biriminde maruziyeti toplar', () {
    final summary = aggregate(
      customFacts: facts(
        financialExposureByCurrency: const <String, num>{'TRY': 250000},
      ),
    );
    expect(summary.totalFinancialExposure, 250000);
    expect(summary.currencyCode, 'TRY');
  });

  test('çoklu para biriminde uyarı üretir', () {
    final summary = aggregate(
      customFacts: facts(
        financialExposureByCurrency: const <String, num>{
          'TRY': 250000,
          'USD': 10000,
        },
      ),
    );
    expect(summary.totalFinancialExposure, 0);
    expect(summary.dataCompletenessWarning, isTrue);
  });

  test('kritik sinyaller kritik sağlık üretir', () {
    final summary = aggregate(
      customFacts: facts(
        criticalTradeSecretIds: const <String>['s1'],
        highImpactIncidentIds: const <String>['i1'],
        criticalAlertRuleIds: const <String>['a1'],
      ),
    );
    expect(summary.health, IpTradeSecretPortfolioHealth.critical);
  });

  test('temiz düşük riskli portföy sağlıklıdır', () {
    final summary = aggregate(customFacts: facts(riskScores: const <int>[15]));
    expect(summary.health, IpTradeSecretPortfolioHealth.healthy);
  });

  test('orta risk izlenmeli sınıfı üretir', () {
    expect(
      aggregate(customFacts: facts(riskScores: const <int>[40])).health,
      IpTradeSecretPortfolioHealth.watch,
    );
  });

  test('yüksek risk yüksek risk sınıfı üretir', () {
    expect(
      aggregate(customFacts: facts(riskScores: const <int>[75])).health,
      IpTradeSecretPortfolioHealth.highRisk,
    );
  });

  test('önceki özet yoksa eğilim bilinmiyor olur', () {
    expect(aggregate().trend, IpTradeSecretPortfolioTrend.unknown);
  });

  test('risk düşerse eğilim iyileşir', () {
    final previous = aggregate(customFacts: facts(riskScores: const <int>[70]));
    final current = aggregate(
      customFacts: facts(riskScores: const <int>[50]),
      previousSummary: previous,
    );
    expect(current.trend, IpTradeSecretPortfolioTrend.improving);
  });

  test('risk yükselirse eğilim kötüleşir', () {
    final previous = aggregate(customFacts: facts(riskScores: const <int>[40]));
    final current = aggregate(
      customFacts: facts(riskScores: const <int>[60]),
      previousSummary: previous,
    );
    expect(current.trend, IpTradeSecretPortfolioTrend.deteriorating);
  });

  test('küçük değişimde eğilim sabittir', () {
    final previous = aggregate(customFacts: facts(riskScores: const <int>[50]));
    final current = aggregate(
      customFacts: facts(riskScores: const <int>[54]),
      previousSummary: previous,
    );
    expect(current.trend, IpTradeSecretPortfolioTrend.stable);
  });

  test('kritik olay yönetim dikkatini açar', () {
    final summary = aggregate(
      customFacts: facts(highImpactIncidentIds: const <String>['i1']),
    );
    expect(summary.managementAttentionRequired, isTrue);
  });

  test('düşük savunulabilirlik hukuk dikkatini açar', () {
    final summary = aggregate(
      customFacts: facts(defensibilityScores: const <int>[50]),
    );
    expect(summary.legalAttentionRequired, isTrue);
  });

  test('zayıf kontrol güvenlik dikkatini açar', () {
    final summary = aggregate(
      customFacts: facts(weakControlIds: const <String>['c1']),
    );
    expect(summary.securityAttentionRequired, isTrue);
  });

  test('snapshot kimliği deterministiktir', () {
    final id = service.buildSnapshotId(
      tenantId: 'Tenant 1',
      scope: IpTradeSecretPortfolioScope.brand,
      scopeId: 'Marka / A',
      snapshotEndAt: DateTime.utc(2026, 7, 5),
    );
    expect(id, 'tenant_1_brand_marka_a_2026-07-05');
  });

  test('boş kapsam kimliği reddedilir', () {
    expect(
      () => service.buildSnapshotId(
        tenantId: 'tenant-1',
        scope: IpTradeSecretPortfolioScope.brand,
        scopeId: ' ',
        snapshotEndAt: DateTime.utc(2026, 7, 5),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('özet açık ticari sır içeriği taşımaz', () {
    final summary = aggregate();
    expect(summary.storesPlaintextSecretContent, isFalse);
    expect(summary.metadata.containsKey('secretContent'), isFalse);
    expect(summary.toMap(), isA<Map<String, dynamic>>());
  });
}
