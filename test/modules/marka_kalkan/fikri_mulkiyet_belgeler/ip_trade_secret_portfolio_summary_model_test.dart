import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_portfolio_summary_model.dart';

void main() {
  group('IpTradeSecretPortfolioSummaryModel', () {
    IpTradeSecretPortfolioSummaryModel buildModel({
      IpTradeSecretPortfolioScope scope = IpTradeSecretPortfolioScope.brand,
      String scopeId = 'brand-1',
      String? brandId = 'brand-1',
      String? businessUnitId,
      String? departmentId,
      String? countryCode,
      String? categoryCode,
      IpTradeSecretPortfolioHealth health = IpTradeSecretPortfolioHealth.watch,
      IpTradeSecretPortfolioTrend trend = IpTradeSecretPortfolioTrend.stable,
      int totalTradeSecretCount = 10,
      int activeTradeSecretCount = 8,
      int retiredTradeSecretCount = 2,
      int criticalTradeSecretCount = 1,
      int highRiskTradeSecretCount = 2,
      int openIncidentCount = 1,
      int highImpactIncidentCount = 0,
      int overdueRemediationCount = 1,
      int blockedRemediationCount = 0,
      int criticalAlertCount = 0,
      int unresolvedAlertCount = 1,
      int pendingDecisionCount = 1,
      int riskAcceptanceDecisionCount = 0,
      int weakControlCount = 1,
      int missingEvidenceCount = 1,
      int highRiskExitCount = 0,
      int expiringAccessGrantCount = 1,
      int overdueReviewCount = 0,
      int averageRiskScore = 55,
      int averageResilienceScore = 70,
      int averageDefensibilityScore = 65,
      int averageControlEffectivenessScore = 72,
      num totalFinancialExposure = 0,
      String? currencyCode,
      Map<String, int> departmentRiskCounts = const <String, int>{'R&D': 2},
      Map<String, int> countryRiskCounts = const <String, int>{'TR': 2},
      Map<String, int> categoryRiskCounts = const <String, int>{'formula': 2},
      bool managementAttentionRequired = false,
      bool legalAttentionRequired = false,
      bool securityAttentionRequired = false,
      bool dataCompletenessWarning = false,
      DateTime? snapshotStartAt,
      DateTime? snapshotEndAt,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretPortfolioSummaryModel(
        id: 'portfolio-1',
        tenantId: 'tenant-1',
        brandId: brandId,
        businessUnitId: businessUnitId,
        departmentId: departmentId,
        countryCode: countryCode,
        categoryCode: categoryCode,
        scope: scope,
        scopeId: scopeId,
        health: health,
        trend: trend,
        totalTradeSecretCount: totalTradeSecretCount,
        activeTradeSecretCount: activeTradeSecretCount,
        retiredTradeSecretCount: retiredTradeSecretCount,
        criticalTradeSecretCount: criticalTradeSecretCount,
        highRiskTradeSecretCount: highRiskTradeSecretCount,
        openIncidentCount: openIncidentCount,
        highImpactIncidentCount: highImpactIncidentCount,
        overdueRemediationCount: overdueRemediationCount,
        blockedRemediationCount: blockedRemediationCount,
        criticalAlertCount: criticalAlertCount,
        unresolvedAlertCount: unresolvedAlertCount,
        pendingDecisionCount: pendingDecisionCount,
        riskAcceptanceDecisionCount: riskAcceptanceDecisionCount,
        weakControlCount: weakControlCount,
        missingEvidenceCount: missingEvidenceCount,
        highRiskExitCount: highRiskExitCount,
        expiringAccessGrantCount: expiringAccessGrantCount,
        overdueReviewCount: overdueReviewCount,
        averageRiskScore: averageRiskScore,
        averageResilienceScore: averageResilienceScore,
        averageDefensibilityScore: averageDefensibilityScore,
        averageControlEffectivenessScore: averageControlEffectivenessScore,
        totalFinancialExposure: totalFinancialExposure,
        currencyCode: currencyCode,
        departmentRiskCounts: departmentRiskCounts,
        countryRiskCounts: countryRiskCounts,
        categoryRiskCounts: categoryRiskCounts,
        topRiskTradeSecretIds: const <String>['secret-1'],
        criticalIncidentIds: const <String>['incident-1'],
        overdueRemediationActionIds: const <String>['action-1'],
        criticalAlertRuleIds: const <String>['alert-1'],
        pendingDecisionIds: const <String>['decision-1'],
        managementAttentionRequired: managementAttentionRequired,
        legalAttentionRequired: legalAttentionRequired,
        securityAttentionRequired: securityAttentionRequired,
        dataCompletenessWarning: dataCompletenessWarning,
        snapshotStartAt: snapshotStartAt,
        snapshotEndAt: snapshotEndAt,
        metadata: metadata,
        generatedAt: DateTime.utc(2026, 7, 5),
        generatedBy: 'system-1',
      );
    }

    test('temel portföy özeti kimliğini üretir', () {
      final model = buildModel();
      expect(model.hasCompleteIdentity, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final map = buildModel().toMap();
      expect(map['scope'], 'brand');
      expect(map['health'], 'watch');
      expect(map['trend'], 'stable');
    });

    test('marka kapsamında brandId ister', () {
      expect(buildModel(brandId: null).toMap, throwsA(isA<StateError>()));
    });

    test('iş birimi kapsamında businessUnitId ister', () {
      final model = buildModel(
        scope: IpTradeSecretPortfolioScope.businessUnit,
        scopeId: 'unit-1',
        brandId: null,
      );
      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('departman kapsamında departmentId ister', () {
      final model = buildModel(
        scope: IpTradeSecretPortfolioScope.department,
        scopeId: 'department-1',
        brandId: null,
      );
      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('ülke kapsamında iki harfli countryCode ister', () {
      final model = buildModel(
        scope: IpTradeSecretPortfolioScope.country,
        scopeId: 'TR',
        brandId: null,
        countryCode: 'TUR',
      );
      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kategori kapsamında categoryCode ister', () {
      final model = buildModel(
        scope: IpTradeSecretPortfolioScope.category,
        scopeId: 'formula',
        brandId: null,
      );
      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('negatif sayaçları reddeder', () {
      expect(
        buildModel(openIncidentCount: -1).toMap,
        throwsA(isA<RangeError>()),
      );
    });

    test('aktif ve emekli toplamı genel toplamı aşamaz', () {
      final model = buildModel(
        totalTradeSecretCount: 10,
        activeTradeSecretCount: 9,
        retiredTradeSecretCount: 2,
      );
      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kritik ve yüksek riskli toplam genel toplamı aşamaz', () {
      final model = buildModel(
        totalTradeSecretCount: 2,
        activeTradeSecretCount: 2,
        retiredTradeSecretCount: 0,
        criticalTradeSecretCount: 2,
        highRiskTradeSecretCount: 1,
      );
      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('skorlar 0 ile 100 arasında olmalıdır', () {
      expect(
        buildModel(averageRiskScore: 101).toMap,
        throwsA(isA<RangeError>()),
      );
    });

    test('parasal maruziyet varsa para birimi ister', () {
      expect(
        buildModel(totalFinancialExposure: 100000).toMap,
        throwsA(isA<StateError>()),
      );
    });

    test('negatif parasal maruziyeti reddeder', () {
      expect(
        buildModel(totalFinancialExposure: -1, currencyCode: 'TRY').toMap,
        throwsA(isA<RangeError>()),
      );
    });

    test('yoğunluk haritasında negatif değerleri reddeder', () {
      final model = buildModel(
        departmentRiskCounts: const <String, int>{'R&D': -1},
      );
      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kritik maruziyeti algılar', () {
      expect(buildModel(criticalAlertCount: 1).hasCriticalExposure, isTrue);
    });

    test('operasyonel iş yükünü algılar', () {
      expect(
        buildModel(overdueRemediationCount: 2).hasOperationalBacklog,
        isTrue,
      );
    });

    test('hukuki savunma açığını algılar', () {
      final model = buildModel(
        missingEvidenceCount: 0,
        averageDefensibilityScore: 50,
      );
      expect(model.hasLegalDefensibilityGap, isTrue);
    });

    test('kritik portföyü acil yönetime taşır', () {
      final model = buildModel(health: IpTradeSecretPortfolioHealth.critical);
      expect(model.requiresImmediateManagementAttention, isTrue);
      expect(model.shouldAppearOnExecutiveDashboard, isTrue);
    });

    test('aktif portföy oranını hesaplar', () {
      final model = buildModel(
        totalTradeSecretCount: 10,
        activeTradeSecretCount: 8,
      );
      expect(model.activePortfolioRatio, 0.8);
    });

    test('sıfır toplamda oranı sıfır döndürür', () {
      final model = buildModel(
        totalTradeSecretCount: 0,
        activeTradeSecretCount: 0,
        retiredTradeSecretCount: 0,
        criticalTradeSecretCount: 0,
        highRiskTradeSecretCount: 0,
      );
      expect(model.activePortfolioRatio, 0);
    });

    test('özet bitiş tarihi başlangıçtan önce olamaz', () {
      final model = buildModel(
        snapshotStartAt: DateTime.utc(2026, 7, 10),
        snapshotEndAt: DateTime.utc(2026, 7, 1),
      );
      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('metadata içinde ticari sır içeriğini reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'secretContent': 'gizli formül'},
      );
      expect(model.toMap, throwsA(isA<StateError>()));
    });
  });
}
