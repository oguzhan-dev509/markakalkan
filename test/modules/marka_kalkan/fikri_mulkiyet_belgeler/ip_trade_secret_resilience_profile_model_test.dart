import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_resilience_profile_model.dart';

void main() {
  group('IpTradeSecretResilienceProfileModel', () {
    IpTradeSecretResilienceProfileModel buildModel({
      int version = 1,
      String? previousProfileId,
      IpTradeSecretResilienceProfileStatus status =
          IpTradeSecretResilienceProfileStatus.active,
      String? approverUserId,
      DateTime? approvedAt,
      int confidentialityScore = 80,
      int overallResilienceScore = 78,
      int openRiskScore = 45,
      int improvementPriorityScore = 55,
      int openGapCount = 2,
      int criticalGapCount = 0,
      int highRiskCount = 0,
      int overdueActionCount = 0,
      bool reviewRequired = true,
      DateTime? nextReviewAt,
      bool improvementRequired = false,
      String? improvementPlan,
      String? improvementOwnerUserId,
      DateTime? improvementDueAt,
      DateTime? improvementCompletedAt,
      bool managementEscalationRequired = false,
      DateTime? escalatedAt,
      bool businessContinuityCritical = false,
      DateTime? supersededAt,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretResilienceProfileModel(
        id: 'profile-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        version: version,
        componentIds: const <String>['component-1'],
        accessGrantIds: const <String>['access-1'],
        disclosureIds: const <String>['disclosure-1'],
        incidentIds: const <String>['incident-1'],
        protectionControlIds: const <String>['control-1'],
        riskAssessmentIds: const <String>['risk-1'],
        profileCode: 'RES-001',
        title: 'Formül dayanıklılık profili',
        status: status,
        resilienceLevel: IpTradeSecretResilienceLevel.resilient,
        maturityLevel: IpTradeSecretMaturityLevel.managed,
        reviewType: IpTradeSecretReviewType.periodic,
        ownerUserId: 'owner-1',
        reviewerUserId: 'reviewer-1',
        approverUserId: approverUserId,
        previousProfileId: previousProfileId,
        summary: 'Koruma altyapısı düzenli olarak inceleniyor.',
        strengthsSummary: 'Teknik ve sözleşmesel kontroller güçlü.',
        weaknessesSummary: 'İki açık iyileştirme bekliyor.',
        improvementPlan: improvementPlan,
        improvementOwnerUserId: improvementOwnerUserId,
        confidentialityScore: confidentialityScore,
        accessGovernanceScore: 82,
        contractualProtectionScore: 79,
        technicalProtectionScore: 84,
        physicalProtectionScore: 76,
        incidentReadinessScore: 73,
        businessContinuityScore: 72,
        monitoringScore: 78,
        overallResilienceScore: overallResilienceScore,
        openRiskScore: openRiskScore,
        improvementPriorityScore: improvementPriorityScore,
        openGapCount: openGapCount,
        criticalGapCount: criticalGapCount,
        openIncidentCount: 1,
        highRiskCount: highRiskCount,
        overdueActionCount: overdueActionCount,
        reviewRequired: reviewRequired,
        improvementRequired: improvementRequired,
        managementEscalationRequired: managementEscalationRequired,
        businessContinuityCritical: businessContinuityCritical,
        reviewedAt: DateTime.utc(2026, 7, 5),
        approvedAt: approvedAt,
        nextReviewAt: nextReviewAt ?? DateTime.utc(2030, 1, 1),
        improvementDueAt: improvementDueAt,
        improvementCompletedAt: improvementCompletedAt,
        escalatedAt: escalatedAt,
        supersededAt: supersededAt,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel profil kimliğini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final map = buildModel().toMap();

      expect(map['status'], 'active');
      expect(map['resilienceLevel'], 'resilient');
      expect(map['maturityLevel'], 'managed');
      expect(map['reviewType'], 'periodic');
    });

    test('aktif profili dayanıklılık paneline taşır', () {
      expect(buildModel().shouldAppearOnResilienceDashboard, isTrue);
    });

    test('savunmaya hazır profili belirler', () {
      expect(buildModel().isDefenseReady, isTrue);
    });

    test('0–100 dışındaki skoru reddeder', () {
      final model = buildModel(confidentialityScore: 101);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('negatif açık sayısını reddeder', () {
      final model = buildModel(openGapCount: -1);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('kritik açık toplam açıktan büyük olamaz', () {
      final model = buildModel(openGapCount: 1, criticalGapCount: 2);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('onaylanan profilde onay bilgilerini ister', () {
      final model = buildModel(
        status: IpTradeSecretResilienceProfileStatus.approved,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli onaylanan profil serileşir', () {
      final model = buildModel(
        status: IpTradeSecretResilienceProfileStatus.approved,
        approverUserId: 'director-1',
        approvedAt: DateTime.utc(2026, 7, 6),
      );

      expect(model.toMap()['status'], 'approved');
    });

    test('inceleme gereken profilde tarih zorunludur', () {
      final model = buildModel(reviewRequired: true, nextReviewAt: null);
      final map = model.toMap();

      expect(map['reviewRequired'], isTrue);
    });

    test('iyileştirme gereken profilde plan ve sorumlu ister', () {
      final model = buildModel(improvementRequired: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli iyileştirme planı serileşir', () {
      final model = buildModel(
        improvementRequired: true,
        improvementPlan: 'Erişim kontrollerini genişlet.',
        improvementOwnerUserId: 'owner-2',
        improvementDueAt: DateTime.utc(2030, 2, 1),
      );

      expect(model.toMap()['improvementRequired'], isTrue);
    });

    test('tamamlanan iyileştirmede gereksinim açık kalamaz', () {
      final model = buildModel(
        improvementRequired: true,
        improvementPlan: 'Kontrolleri tamamla.',
        improvementOwnerUserId: 'owner-2',
        improvementDueAt: DateTime.utc(2030, 2, 1),
        improvementCompletedAt: DateTime.utc(2026, 7, 20),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('yönetim yükseltmesinde tarih zorunludur', () {
      final model = buildModel(managementEscalationRequired: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kritik maruziyeti acil yükseltir', () {
      final model = buildModel(criticalGapCount: 1, openGapCount: 2);

      expect(model.hasCriticalExposure, isTrue);
      expect(model.requiresImmediateEscalation, isTrue);
    });

    test('savunmaya hazır olmayan profili ayırır', () {
      final model = buildModel(overallResilienceScore: 60, openRiskScore: 70);

      expect(model.isDefenseReady, isFalse);
    });

    test('ikinci sürümde önceki profil bağlantısını ister', () {
      final model = buildModel(version: 2);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli ikinci sürüm serileşir', () {
      final model = buildModel(version: 2, previousProfileId: 'profile-0');

      expect(model.toMap()['version'], 2);
    });

    test('superseded profilde tarih zorunludur', () {
      final model = buildModel(
        status: IpTradeSecretResilienceProfileStatus.superseded,
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
