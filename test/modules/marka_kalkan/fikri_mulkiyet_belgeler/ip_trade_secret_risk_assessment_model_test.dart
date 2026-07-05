import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_risk_assessment_model.dart';

void main() {
  group('IpTradeSecretRiskAssessmentModel', () {
    IpTradeSecretRiskAssessmentModel buildModel({
      IpTradeSecretRiskAssessmentStatus status =
          IpTradeSecretRiskAssessmentStatus.active,
      IpTradeSecretRiskLevel riskLevel = IpTradeSecretRiskLevel.high,
      IpTradeSecretGapStatus gapStatus = IpTradeSecretGapStatus.identified,
      String? gapDescription = 'Erişim kontrolü kapsamı eksik.',
      String? approverUserId,
      DateTime? approvedAt,
      int controlEffectivenessScore = 60,
      int inherentRiskScore = 85,
      int residualRiskScore = 70,
      int gapScore = 65,
      int priorityScore = 75,
      bool actionRequired = true,
      String? treatmentPlan = 'Erişim kontrollerini genişlet.',
      String? treatmentOwnerUserId = 'owner-2',
      DateTime? treatmentDueAt,
      DateTime? treatmentCompletedAt,
      bool riskAccepted = false,
      String? riskAcceptanceReason,
      String? riskAcceptedBy,
      DateTime? riskAcceptedAt,
      bool radarEligible = true,
      bool escalated = false,
      DateTime? escalatedAt,
      DateTime? closedAt,
      double? financialExposureAmount,
      String? financialExposureCurrency,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretRiskAssessmentModel(
        id: 'risk-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        componentIds: const <String>['component-1'],
        protectionControlIds: const <String>['control-1'],
        relatedIncidentIds: const <String>['incident-1'],
        assessmentCode: 'RISK-001',
        title: 'Yetkisiz erişim riski',
        status: status,
        riskLevel: riskLevel,
        threatCategory: IpTradeSecretThreatCategory.unauthorizedAccess,
        gapStatus: gapStatus,
        ownerUserId: 'risk-owner-1',
        assessorUserId: 'assessor-1',
        approverUserId: approverUserId,
        threatDescription: 'Yetkisiz kullanıcı erişimi.',
        vulnerabilityDescription: 'Rol tabanlı erişim kapsamı eksik.',
        existingControlDescription: 'Temel kullanıcı doğrulaması uygulanıyor.',
        impactDescription: 'Formül gizliliği zarar görebilir.',
        gapDescription: gapDescription,
        treatmentPlan: treatmentPlan,
        treatmentOwnerUserId: treatmentOwnerUserId,
        riskAcceptanceReason: riskAcceptanceReason,
        riskAcceptedBy: riskAcceptedBy,
        assetValueScore: 90,
        threatLikelihoodScore: 70,
        vulnerabilityScore: 75,
        controlEffectivenessScore: controlEffectivenessScore,
        inherentRiskScore: inherentRiskScore,
        residualRiskScore: residualRiskScore,
        gapScore: gapScore,
        priorityScore: priorityScore,
        actionRequired: actionRequired,
        riskAccepted: riskAccepted,
        radarEligible: radarEligible,
        escalated: escalated,
        legalImpact: true,
        assessedAt: DateTime.utc(2026, 7, 5),
        approvedAt: approvedAt,
        nextReviewAt: DateTime.utc(2030, 1, 1),
        treatmentDueAt: treatmentDueAt ?? DateTime.utc(2026, 8, 1),
        treatmentCompletedAt: treatmentCompletedAt,
        riskAcceptedAt: riskAcceptedAt,
        closedAt: closedAt,
        escalatedAt: escalatedAt,
        financialExposureAmount: financialExposureAmount,
        financialExposureCurrency: financialExposureCurrency,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel risk kimliğini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.hasProtectionGap, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final map = buildModel().toMap();

      expect(map['status'], 'active');
      expect(map['riskLevel'], 'high');
      expect(map['threatCategory'], 'unauthorized_access');
      expect(map['gapStatus'], 'identified');
    });

    test('koruma açığını radara aktarılabilir kabul eder', () {
      final model = buildModel();

      expect(model.shouldAppearOnGapRadar, isTrue);
    });

    test('yüksek riski acil yükseltme olarak işaretler', () {
      final model = buildModel();

      expect(model.requiresImmediateEscalation, isTrue);
      expect(model.requiresImmediateReview, isTrue);
    });

    test('0–100 dışındaki risk skorunu reddeder', () {
      final model = buildModel(residualRiskScore: 101);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('artık risk doğal riskten yüksek olamaz', () {
      final model = buildModel(
        inherentRiskScore: 60,
        residualRiskScore: 70,
        controlEffectivenessScore: 50,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('onaylanan değerlendirmede onay bilgilerini ister', () {
      final model = buildModel(
        status: IpTradeSecretRiskAssessmentStatus.approved,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli onaylanmış değerlendirme serileşir', () {
      final model = buildModel(
        status: IpTradeSecretRiskAssessmentStatus.approved,
        approverUserId: 'director-1',
        approvedAt: DateTime.utc(2026, 7, 6),
      );

      expect(model.toMap()['status'], 'approved');
    });

    test('açık yoksa açık skoru bulunamaz', () {
      final model = buildModel(
        gapStatus: IpTradeSecretGapStatus.none,
        gapDescription: null,
        gapScore: 1,
        actionRequired: false,
        treatmentPlan: null,
        treatmentOwnerUserId: null,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('koruma açığında açıklama zorunludur', () {
      final model = buildModel(gapDescription: null);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('aksiyon gerekiyorsa plan ve sorumlu ister', () {
      final model = buildModel(treatmentPlan: null, treatmentOwnerUserId: null);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('tamamlanan iyileştirmede aksiyon açık kalamaz', () {
      final model = buildModel(treatmentCompletedAt: DateTime.utc(2026, 7, 20));

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('risk kabulünde gerekçe ve kabul bilgilerini ister', () {
      final model = buildModel(riskAccepted: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli risk kabul kaydı serileşir', () {
      final model = buildModel(
        status: IpTradeSecretRiskAssessmentStatus.accepted,
        gapStatus: IpTradeSecretGapStatus.accepted,
        actionRequired: false,
        treatmentPlan: null,
        treatmentOwnerUserId: null,
        riskAccepted: true,
        riskAcceptanceReason: 'Yönetim tarafından kabul edildi.',
        riskAcceptedBy: 'director-1',
        riskAcceptedAt: DateTime.utc(2026, 7, 7),
      );

      expect(model.toMap()['riskAccepted'], isTrue);
    });

    test('yükseltilen riskte tarih zorunludur', () {
      final model = buildModel(escalated: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('negatif finansal maruziyeti reddeder', () {
      final model = buildModel(
        financialExposureAmount: -1,
        financialExposureCurrency: 'TRY',
      );

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('finansal maruziyette para birimini zorunlu tutar', () {
      final model = buildModel(financialExposureAmount: 100000);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli kapatılmış değerlendirmeyi serileştirir', () {
      final model = buildModel(
        status: IpTradeSecretRiskAssessmentStatus.closed,
        gapStatus: IpTradeSecretGapStatus.mitigated,
        gapDescription: null,
        gapScore: 0,
        actionRequired: false,
        treatmentPlan: null,
        treatmentOwnerUserId: null,
        treatmentCompletedAt: DateTime.utc(2026, 7, 20),
        closedAt: DateTime.utc(2026, 7, 21),
      );

      expect(model.toMap()['status'], 'closed');
    });

    test('metadata içinde ticari sır içeriğini reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'secretContent': 'gizli formül'},
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });
  });
}
