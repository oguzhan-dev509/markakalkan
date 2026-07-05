import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_remediation_action_model.dart';

void main() {
  group('IpTradeSecretRemediationActionModel', () {
    IpTradeSecretRemediationActionModel buildModel({
      IpTradeSecretRemediationStatus status =
          IpTradeSecretRemediationStatus.planned,
      IpTradeSecretRemediationPriority priority =
          IpTradeSecretRemediationPriority.high,
      IpTradeSecretRemediationSourceType sourceType =
          IpTradeSecretRemediationSourceType.riskAssessment,
      IpTradeSecretVerificationOutcome verificationOutcome =
          IpTradeSecretVerificationOutcome.notReviewed,
      String? sourceRecordId = 'risk-1',
      String? approverUserId,
      String? verifierUserId,
      String? blockerReason,
      String? closureSummary,
      String? reopenReason,
      String? verificationNotes,
      int progressPercent = 0,
      int preActionRiskScore = 80,
      int postActionRiskScore = 0,
      int effectivenessScore = 0,
      num? estimatedCostAmount,
      num? actualCostAmount,
      String? currencyCode,
      bool criticalAction = false,
      bool blocked = false,
      bool verificationRequired = true,
      bool managementEscalationRequired = false,
      bool reopened = false,
      DateTime? dueAt,
      DateTime? startedAt,
      DateTime? completedAt,
      DateTime? verificationDueAt,
      DateTime? verifiedAt,
      DateTime? approvedAt,
      DateTime? closedAt,
      DateTime? reopenedAt,
      DateTime? escalatedAt,
      DateTime? cancelledAt,
      List<String> evidenceDocumentIds = const <String>[],
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretRemediationActionModel(
        id: 'action-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        componentIds: const <String>['component-1'],
        incidentIds: const <String>['incident-1'],
        protectionControlIds: const <String>['control-1'],
        riskAssessmentIds: const <String>['risk-1'],
        resilienceProfileIds: const <String>['profile-1'],
        defensibilityRecordIds: const <String>['def-1'],
        lifecycleTransitionIds: const <String>['life-1'],
        evidenceDocumentIds: evidenceDocumentIds,
        dependencyActionIds: const <String>['action-0'],
        actionCode: 'ACT-001',
        title: 'NDA kanıtlarını tamamla',
        status: status,
        priority: priority,
        sourceType: sourceType,
        verificationOutcome: verificationOutcome,
        ownerUserId: 'owner-1',
        assigneeUserId: 'assignee-1',
        sourceRecordId: sourceRecordId,
        reviewerUserId: 'reviewer-1',
        approverUserId: approverUserId,
        verifierUserId: verifierUserId,
        description: 'Eksik NDA kayıtlarını tamamla.',
        expectedOutcome: 'Hukuki savunma dosyası eksiksiz hale gelir.',
        blockerReason: blockerReason,
        closureSummary: closureSummary,
        reopenReason: reopenReason,
        verificationNotes: verificationNotes,
        progressPercent: progressPercent,
        preActionRiskScore: preActionRiskScore,
        postActionRiskScore: postActionRiskScore,
        effectivenessScore: effectivenessScore,
        estimatedCostAmount: estimatedCostAmount,
        actualCostAmount: actualCostAmount,
        currencyCode: currencyCode,
        criticalAction: criticalAction,
        blocked: blocked,
        verificationRequired: verificationRequired,
        managementEscalationRequired: managementEscalationRequired,
        reopened: reopened,
        dueAt: dueAt,
        startedAt: startedAt,
        completedAt: completedAt,
        verificationDueAt: verificationDueAt,
        verifiedAt: verifiedAt,
        approvedAt: approvedAt,
        closedAt: closedAt,
        reopenedAt: reopenedAt,
        escalatedAt: escalatedAt,
        cancelledAt: cancelledAt,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel iyileştirme eylemi kimliğini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final map = buildModel().toMap();

      expect(map['status'], 'planned');
      expect(map['priority'], 'high');
      expect(map['sourceType'], 'risk_assessment');
      expect(map['verificationOutcome'], 'not_reviewed');
    });

    test('kaynak türünde kaynak kayıt kimliği ister', () {
      final model = buildModel(sourceRecordId: null);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('diğer kaynak türünde kaynak kimliği zorunlu değildir', () {
      final model = buildModel(
        sourceType: IpTradeSecretRemediationSourceType.other,
        sourceRecordId: null,
      );

      expect(model.toMap()['sourceType'], 'other');
    });

    test('atanmış eylemde son tarih ister', () {
      final model = buildModel(status: IpTradeSecretRemediationStatus.assigned);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('engellenmiş eylemde durum ve neden ister', () {
      final model = buildModel(blocked: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli engellenmiş eylemi serileştirir', () {
      final model = buildModel(
        status: IpTradeSecretRemediationStatus.blocked,
        blocked: true,
        blockerReason: 'Tedarikçi belgesi bekleniyor.',
      );

      expect(model.toMap()['blocked'], isTrue);
    });

    test('yüzde yüz ilerlemede tamamlanma tarihi ister', () {
      final model = buildModel(progressPercent: 100);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('tamamlanma tarihi bulunan eylem yüzde yüz olmalıdır', () {
      final model = buildModel(
        progressPercent: 90,
        completedAt: DateTime.utc(2026, 7, 10),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('doğrulama bekleyen eylemde tamamlanma ve tarih ister', () {
      final model = buildModel(
        status: IpTradeSecretRemediationStatus.pendingVerification,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('doğrulanan eylemde doğrulayan ve sonuç ister', () {
      final model = buildModel(status: IpTradeSecretRemediationStatus.verified);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli doğrulanmış eylemi serileştirir', () {
      final model = buildModel(
        status: IpTradeSecretRemediationStatus.verified,
        verificationOutcome: IpTradeSecretVerificationOutcome.effective,
        verifierUserId: 'verifier-1',
        progressPercent: 100,
        completedAt: DateTime.utc(2026, 7, 10),
        verifiedAt: DateTime.utc(2026, 7, 11),
        effectivenessScore: 90,
      );

      expect(model.toMap()['status'], 'verified');
    });

    test('kapanışta onay ve kanıt ister', () {
      final model = buildModel(
        status: IpTradeSecretRemediationStatus.closed,
        progressPercent: 100,
        completedAt: DateTime.utc(2026, 7, 10),
        verificationOutcome: IpTradeSecretVerificationOutcome.effective,
        verifierUserId: 'verifier-1',
        verifiedAt: DateTime.utc(2026, 7, 11),
        effectivenessScore: 90,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli kapanış kaydını serileştirir', () {
      final model = buildModel(
        status: IpTradeSecretRemediationStatus.closed,
        progressPercent: 100,
        completedAt: DateTime.utc(2026, 7, 10),
        verificationOutcome: IpTradeSecretVerificationOutcome.effective,
        verifierUserId: 'verifier-1',
        verifiedAt: DateTime.utc(2026, 7, 11),
        effectivenessScore: 90,
        approverUserId: 'director-1',
        approvedAt: DateTime.utc(2026, 7, 12),
        closedAt: DateTime.utc(2026, 7, 12),
        closureSummary: 'Açık doğrulandı ve kapatıldı.',
        evidenceDocumentIds: const <String>['evidence-1'],
      );

      expect(model.isClosureReady, isTrue);
      expect(model.toMap()['status'], 'closed');
    });

    test('yeniden açmada tarih ve gerekçe ister', () {
      final model = buildModel(reopened: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli yeniden açılan eylemi serileştirir', () {
      final model = buildModel(
        status: IpTradeSecretRemediationStatus.reopened,
        reopened: true,
        reopenedAt: DateTime.utc(2026, 7, 15),
        reopenReason: 'Kontrol yeniden başarısız oldu.',
      );

      expect(model.toMap()['reopened'], isTrue);
    });

    test('yönetim yükseltmesinde tarih ister', () {
      final model = buildModel(managementEscalationRequired: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('maliyet varsa para birimi ister', () {
      final model = buildModel(estimatedCostAmount: 1000);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('negatif maliyeti reddeder', () {
      final model = buildModel(estimatedCostAmount: -1, currencyCode: 'TRY');

      expect(model.toMap, throwsA(isA<RangeError>()));
    });

    test('etkisiz sonucu acil yükseltir', () {
      final model = buildModel(
        verificationOutcome: IpTradeSecretVerificationOutcome.ineffective,
      );

      expect(model.isIneffective, isTrue);
      expect(model.requiresImmediateEscalation, isTrue);
    });

    test('yürütülen eylemi panele taşır', () {
      final model = buildModel(
        status: IpTradeSecretRemediationStatus.inProgress,
        dueAt: DateTime.utc(2030, 1, 1),
      );

      expect(model.shouldAppearOnRemediationDashboard, isTrue);
    });

    test('iptal edilen eylemde tarih ister', () {
      final model = buildModel(
        status: IpTradeSecretRemediationStatus.cancelled,
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
