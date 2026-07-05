import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_defensibility_record_model.dart';

void main() {
  group('IpTradeSecretDefensibilityRecordModel', () {
    IpTradeSecretDefensibilityRecordModel buildModel({
      IpTradeSecretDefensibilityStatus status =
          IpTradeSecretDefensibilityStatus.active,
      IpTradeSecretLegalReadinessLevel legalReadinessLevel =
          IpTradeSecretLegalReadinessLevel.strong,
      IpTradeSecretEvidenceStrength evidenceStrength =
          IpTradeSecretEvidenceStrength.strong,
      String? approverUserId,
      DateTime? approvedAt,
      int evidenceCompletenessScore = 85,
      int overallDefensibilityScore = 82,
      int criticalEvidenceGapCount = 0,
      int expiredEvidenceCount = 0,
      int unverifiedEvidenceCount = 0,
      bool evidenceIntegrityVerified = true,
      String? evidenceHash = 'abc123',
      String? hashAlgorithm = 'SHA-256',
      bool chainOfCustodyVerified = true,
      String? chainOfCustodyReference = 'COC-001',
      bool remediationRequired = false,
      String? gapDescription,
      String? remediationPlan,
      String? remediationOwnerUserId,
      DateTime? remediationDueAt,
      DateTime? remediationCompletedAt,
      bool managementEscalationRequired = false,
      DateTime? escalatedAt,
      bool litigationHold = false,
      DateTime? litigationHoldAt,
      DateTime? closedAt,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretDefensibilityRecordModel(
        id: 'def-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        componentIds: const <String>['component-1'],
        accessGrantIds: const <String>['access-1'],
        disclosureIds: const <String>['disclosure-1'],
        incidentIds: const <String>['incident-1'],
        protectionControlIds: const <String>['control-1'],
        riskAssessmentIds: const <String>['risk-1'],
        resilienceProfileIds: const <String>['profile-1'],
        evidenceDocumentIds: const <String>['document-1'],
        evidenceCategories: const <IpTradeSecretEvidenceCategory>[
          IpTradeSecretEvidenceCategory.ownership,
          IpTradeSecretEvidenceCategory.accessControl,
        ],
        recordCode: 'DEF-001',
        title: 'Formül hukuki savunma dosyası',
        status: status,
        legalReadinessLevel: legalReadinessLevel,
        primaryEvidenceCategory: IpTradeSecretEvidenceCategory.ownership,
        evidenceStrength: evidenceStrength,
        ownerUserId: 'owner-1',
        reviewerUserId: 'reviewer-1',
        approverUserId: approverUserId,
        evidenceSource: 'Kanıt Defteri',
        evidenceHash: evidenceHash,
        hashAlgorithm: hashAlgorithm,
        chainOfCustodyReference: chainOfCustodyReference,
        storageLocationReference: 'vault://evidence/document-1',
        retentionPolicyReference: 'RET-10Y',
        jurisdictionCode: 'TR',
        summary: 'Makul koruma tedbirleri kanıtlarla ilişkilendirildi.',
        gapDescription: gapDescription,
        remediationPlan: remediationPlan,
        remediationOwnerUserId: remediationOwnerUserId,
        evidenceCompletenessScore: evidenceCompletenessScore,
        evidenceFreshnessScore: 80,
        controlTraceabilityScore: 84,
        ownershipProofScore: 90,
        confidentialityProofScore: 85,
        accessProofScore: 82,
        contractualProofScore: 78,
        incidentResponseProofScore: 76,
        overallDefensibilityScore: overallDefensibilityScore,
        criticalEvidenceGapCount: criticalEvidenceGapCount,
        expiredEvidenceCount: expiredEvidenceCount,
        unverifiedEvidenceCount: unverifiedEvidenceCount,
        remediationRequired: remediationRequired,
        managementEscalationRequired: managementEscalationRequired,
        litigationHold: litigationHold,
        chainOfCustodyVerified: chainOfCustodyVerified,
        evidenceIntegrityVerified: evidenceIntegrityVerified,
        assessedAt: DateTime.utc(2026, 7, 5),
        approvedAt: approvedAt,
        nextReviewAt: DateTime.utc(2030, 1, 1),
        evidenceValidUntil: DateTime.utc(2030, 1, 1),
        remediationDueAt: remediationDueAt,
        remediationCompletedAt: remediationCompletedAt,
        escalatedAt: escalatedAt,
        litigationHoldAt: litigationHoldAt,
        closedAt: closedAt,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel savunma kimliğini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final map = buildModel().toMap();

      expect(map['status'], 'active');
      expect(map['legalReadinessLevel'], 'strong');
      expect(map['primaryEvidenceCategory'], 'ownership');
      expect(map['evidenceStrength'], 'strong');
    });

    test('aktif kaydı hukuki savunma paneline taşır', () {
      expect(buildModel().shouldAppearOnLegalDefenseDashboard, isTrue);
    });

    test('0–100 dışındaki skoru reddeder', () {
      final model = buildModel(evidenceCompletenessScore: 101);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('negatif kanıt açığı sayısını reddeder', () {
      final model = buildModel(criticalEvidenceGapCount: -1);

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('onaylanan kayıtta onay bilgilerini ister', () {
      final model = buildModel(
        status: IpTradeSecretDefensibilityStatus.approved,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli onaylanan kayıt serileşir', () {
      final model = buildModel(
        status: IpTradeSecretDefensibilityStatus.approved,
        approverUserId: 'director-1',
        approvedAt: DateTime.utc(2026, 7, 6),
      );

      expect(model.toMap()['status'], 'approved');
    });

    test('kanıt bütünlüğünde hash ve algoritma ister', () {
      final model = buildModel(
        evidenceIntegrityVerified: true,
        evidenceHash: null,
        hashAlgorithm: null,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('muhafaza zincirinde referans ister', () {
      final model = buildModel(
        chainOfCustodyVerified: true,
        chainOfCustodyReference: null,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('eksik gidermede plan ve sorumlu ister', () {
      final model = buildModel(remediationRequired: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli eksik giderme planı serileşir', () {
      final model = buildModel(
        remediationRequired: true,
        gapDescription: 'NDA kanıtı eksik.',
        remediationPlan: 'İmzalı NDA belgelerini ekle.',
        remediationOwnerUserId: 'owner-2',
        remediationDueAt: DateTime.utc(2030, 2, 1),
      );

      expect(model.toMap()['remediationRequired'], isTrue);
    });

    test('tamamlanan giderimde gereksinim açık kalamaz', () {
      final model = buildModel(
        remediationRequired: true,
        gapDescription: 'Kanıt eksik.',
        remediationPlan: 'Kanıtı tamamla.',
        remediationOwnerUserId: 'owner-2',
        remediationDueAt: DateTime.utc(2030, 2, 1),
        remediationCompletedAt: DateTime.utc(2026, 7, 20),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('yönetim yükseltmesinde tarih zorunludur', () {
      final model = buildModel(managementEscalationRequired: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('hukuki muhafazada tarih zorunludur', () {
      final model = buildModel(litigationHold: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kritik kanıt açığını acil yükseltir', () {
      final model = buildModel(criticalEvidenceGapCount: 1);

      expect(model.hasCriticalEvidenceGap, isTrue);
      expect(model.requiresImmediateEscalation, isTrue);
    });

    test('uyuşmazlığa hazır kaydı belirler', () {
      final model = buildModel(
        legalReadinessLevel: IpTradeSecretLegalReadinessLevel.litigationReady,
        overallDefensibilityScore: 90,
      );

      expect(model.isLitigationReady, isTrue);
    });

    test('doğrulanmamış kanıt varsa uyuşmazlığa hazır saymaz', () {
      final model = buildModel(
        legalReadinessLevel: IpTradeSecretLegalReadinessLevel.litigationReady,
        overallDefensibilityScore: 90,
        unverifiedEvidenceCount: 1,
      );

      expect(model.isLitigationReady, isFalse);
    });

    test('kapatılan kayıtta kapanış tarihi ister', () {
      final model = buildModel(status: IpTradeSecretDefensibilityStatus.closed);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli kapatılan kayıt serileşir', () {
      final model = buildModel(
        status: IpTradeSecretDefensibilityStatus.closed,
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
