import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_protection_control_model.dart';

void main() {
  group('IpTradeSecretProtectionControlModel', () {
    IpTradeSecretProtectionControlModel buildModel({
      IpTradeSecretProtectionControlStatus status =
          IpTradeSecretProtectionControlStatus.active,
      DateTime? implementedAt,
      DateTime? lastTestedAt,
      DateTime? nextTestAt,
      DateTime? suspendedAt,
      DateTime? retiredAt,
      bool? testPassed = true,
      bool preventiveCoverage = true,
      bool detectiveCoverage = false,
      bool correctiveCoverage = false,
      int designEffectivenessScore = 85,
      int operatingEffectivenessScore = 80,
      int coverageScore = 90,
      int residualRiskScore = 25,
      int findingCount = 0,
      int openFindingCount = 0,
      bool remediationRequired = false,
      DateTime? remediationDueAt,
      DateTime? remediationCompletedAt,
      String? remediationOwnerUserId,
      String? remediationPlan,
      bool exceptionApproved = false,
      String? exceptionReason,
      String? exceptionApprovedBy,
      DateTime? exceptionExpiresAt,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretProtectionControlModel(
        id: 'control-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        componentIds: const <String>['component-1'],
        relatedAccessGrantIds: const <String>['grant-1'],
        relatedIncidentIds: const <String>['incident-1'],
        controlCode: 'CTRL-001',
        name: 'Şifreli erişim kontrolü',
        type: IpTradeSecretProtectionControlType.preventive,
        category: IpTradeSecretProtectionControlCategory.accessControl,
        status: status,
        frequency: IpTradeSecretProtectionControlFrequency.continuous,
        ownerUserId: 'security-owner-1',
        policyDocumentIds: const <String>['policy-1'],
        evidenceDocumentIds: const <String>['evidence-1'],
        automated: true,
        preventiveCoverage: preventiveCoverage,
        detectiveCoverage: detectiveCoverage,
        correctiveCoverage: correctiveCoverage,
        implementedAt: implementedAt ?? DateTime.utc(2026, 7, 5),
        lastTestedAt: lastTestedAt ?? DateTime.utc(2026, 7, 6),
        nextTestAt: nextTestAt ?? DateTime.utc(2030, 1, 1),
        testPassed: testPassed,
        suspendedAt: suspendedAt,
        retiredAt: retiredAt,
        designEffectivenessScore: designEffectivenessScore,
        operatingEffectivenessScore: operatingEffectivenessScore,
        coverageScore: coverageScore,
        residualRiskScore: residualRiskScore,
        findingCount: findingCount,
        openFindingCount: openFindingCount,
        remediationRequired: remediationRequired,
        remediationDueAt: remediationDueAt,
        remediationCompletedAt: remediationCompletedAt,
        remediationOwnerUserId: remediationOwnerUserId,
        remediationPlan: remediationPlan,
        exceptionApproved: exceptionApproved,
        exceptionReason: exceptionReason,
        exceptionApprovedBy: exceptionApprovedBy,
        exceptionExpiresAt: exceptionExpiresAt,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel kontrol kimliğini ve etkinliği üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.isActive, isTrue);
      expect(model.isEffective, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final model = buildModel();

      final map = model.toMap();

      expect(map['type'], 'preventive');
      expect(map['category'], 'access_control');
      expect(map['status'], 'active');
      expect(map['frequency'], 'continuous');
    });

    test('test sonucu varsa test tarihini zorunlu tutar', () {
      final model = buildModel();

      final recreated = IpTradeSecretProtectionControlModel(
        id: model.id,
        tenantId: model.tenantId,
        brandId: model.brandId,
        tradeSecretId: model.tradeSecretId,
        controlCode: model.controlCode,
        name: model.name,
        type: model.type,
        category: model.category,
        status: model.status,
        frequency: model.frequency,
        ownerUserId: model.ownerUserId,
        implementedAt: model.implementedAt,
        createdAt: model.createdAt,
        createdBy: model.createdBy,
        preventiveCoverage: true,
        testPassed: false,
      );

      expect(recreated.toMap, throwsA(isA<StateError>()));
    });

    test('etkisiz kontrolün başarısız test sonucu olmalıdır', () {
      final model = buildModel(
        status: IpTradeSecretProtectionControlStatus.ineffective,
        testPassed: true,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('askıya alınan kontrolde tarih zorunludur', () {
      final model = buildModel(
        status: IpTradeSecretProtectionControlStatus.suspended,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli askıya alma kaydı serileşir', () {
      final model = buildModel(
        status: IpTradeSecretProtectionControlStatus.suspended,
        suspendedAt: DateTime.utc(2026, 7, 7),
      );

      expect(model.toMap()['status'], 'suspended');
    });

    test('kullanımdan kaldırılan kontrolde tarih zorunludur', () {
      final model = buildModel(
        status: IpTradeSecretProtectionControlStatus.retired,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('açık bulgu toplam bulgudan fazla olamaz', () {
      final model = buildModel(findingCount: 1, openFindingCount: 2);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('iyileştirme gerekiyorsa plan ve sorumlu ister', () {
      final model = buildModel(remediationRequired: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli iyileştirme kaydı serileşir', () {
      final model = buildModel(
        remediationRequired: true,
        remediationDueAt: DateTime.utc(2026, 8, 1),
        remediationOwnerUserId: 'owner-2',
        remediationPlan: 'Kontrol yapılandırmasını güçlendir.',
      );

      expect(model.toMap()['remediationRequired'], isTrue);
      expect(model.requiresImmediateReview, isTrue);
    });

    test('onaylı istisnada gerekçe ve onay bilgisi ister', () {
      final model = buildModel(exceptionApproved: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli istisna kaydı serileşir', () {
      final model = buildModel(
        exceptionApproved: true,
        exceptionReason: 'Geçici sistem geçişi',
        exceptionApprovedBy: 'director-1',
        exceptionExpiresAt: DateTime.utc(2026, 9, 1),
      );

      expect(model.toMap()['exceptionApproved'], isTrue);
    });

    test('en az bir koruma kapsamını zorunlu tutar', () {
      final model = buildModel(
        preventiveCoverage: false,
        detectiveCoverage: false,
        correctiveCoverage: false,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('0–100 dışındaki etkinlik skorunu reddeder', () {
      final model = buildModel(designEffectivenessScore: 101);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('negatif bulgu sayısını reddeder', () {
      final model = buildModel(findingCount: -1);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('negatif açık bulgu sayısını reddeder', () {
      final model = buildModel(openFindingCount: -1);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('metadata içinde ticari sır içeriğini reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'privateKey': 'gizli-anahtar'},
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });
  });
}
