import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_lifecycle_transition_model.dart';

void main() {
  group('IpTradeSecretLifecycleTransitionModel', () {
    IpTradeSecretLifecycleTransitionModel buildModel({
      IpTradeSecretLifecycleStatus fromStatus =
          IpTradeSecretLifecycleStatus.active,
      IpTradeSecretLifecycleStatus toStatus =
          IpTradeSecretLifecycleStatus.restricted,
      IpTradeSecretTransitionType transitionType =
          IpTradeSecretTransitionType.accessReduction,
      IpTradeSecretHandoverStatus handoverStatus =
          IpTradeSecretHandoverStatus.notRequired,
      IpTradeSecretExitPartyType? exitPartyType,
      String? exitPartyId,
      String? exitPartyDisplayName,
      String? previousOwnerUserId,
      String? newOwnerUserId,
      String? approverUserId,
      DateTime? approvedAt,
      String? handoverSummary,
      DateTime? handoverDueAt,
      DateTime? handoverCompletedAt,
      bool highRiskExit = false,
      bool accessRevoked = false,
      DateTime? accessRevokedAt,
      String? accessRevocationReference,
      bool devicesReturned = false,
      String? deviceReturnReference,
      bool documentsReturned = false,
      String? documentReturnReference,
      bool keysReturned = false,
      String? keyReturnReference,
      DateTime? assetsReturnedAt,
      bool confidentialityReminderDelivered = false,
      String? confidentialityReminderReference,
      bool confidentialityAcknowledged = false,
      DateTime? confidentialityAcknowledgedAt,
      bool exitInterviewCompleted = false,
      DateTime? exitInterviewCompletedAt,
      String? exitInterviewReference,
      bool legalReviewRequired = false,
      bool managementEscalationRequired = false,
      DateTime? escalatedAt,
      DateTime? closedAt,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretLifecycleTransitionModel(
        id: 'life-1',
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
        defensibilityRecordIds: const <String>['def-1'],
        transitionCode: 'LIFE-001',
        title: 'Erişim daraltma geçişi',
        fromStatus: fromStatus,
        toStatus: toStatus,
        transitionType: transitionType,
        handoverStatus: handoverStatus,
        exitPartyType: exitPartyType,
        ownerUserId: 'owner-1',
        transitionOwnerUserId: 'transition-owner-1',
        exitPartyId: exitPartyId,
        exitPartyDisplayName: exitPartyDisplayName,
        previousOwnerUserId: previousOwnerUserId,
        newOwnerUserId: newOwnerUserId,
        approverUserId: approverUserId,
        reason: 'Görev değişikliği',
        handoverSummary: handoverSummary,
        accessRevocationReference: accessRevocationReference,
        deviceReturnReference: deviceReturnReference,
        documentReturnReference: documentReturnReference,
        keyReturnReference: keyReturnReference,
        confidentialityReminderReference: confidentialityReminderReference,
        exitInterviewReference: exitInterviewReference,
        highRiskExit: highRiskExit,
        accessRevoked: accessRevoked,
        devicesReturned: devicesReturned,
        documentsReturned: documentsReturned,
        keysReturned: keysReturned,
        confidentialityReminderDelivered: confidentialityReminderDelivered,
        confidentialityAcknowledged: confidentialityAcknowledged,
        exitInterviewCompleted: exitInterviewCompleted,
        legalReviewRequired: legalReviewRequired,
        managementEscalationRequired: managementEscalationRequired,
        effectiveAt: DateTime.utc(2026, 7, 5),
        approvedAt: approvedAt,
        handoverDueAt: handoverDueAt,
        handoverCompletedAt: handoverCompletedAt,
        accessRevokedAt: accessRevokedAt,
        assetsReturnedAt: assetsReturnedAt,
        confidentialityAcknowledgedAt: confidentialityAcknowledgedAt,
        exitInterviewCompletedAt: exitInterviewCompletedAt,
        escalatedAt: escalatedAt,
        closedAt: closedAt,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel yaşam döngüsü kimliğini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final map = buildModel().toMap();

      expect(map['fromStatus'], 'active');
      expect(map['toStatus'], 'restricted');
      expect(map['transitionType'], 'access_reduction');
      expect(map['handoverStatus'], 'not_required');
    });

    test('erişim daraltmayı yaşam döngüsü paneline taşır', () {
      expect(buildModel().shouldAppearOnLifecycleDashboard, isTrue);
    });

    test('aynı durum geçişini uygunsuz tipte reddeder', () {
      final model = buildModel(
        fromStatus: IpTradeSecretLifecycleStatus.active,
        toStatus: IpTradeSecretLifecycleStatus.active,
        transitionType: IpTradeSecretTransitionType.closure,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('çıkış geçişinde taraf bilgilerini ister', () {
      final model = buildModel(
        transitionType: IpTradeSecretTransitionType.employeeExit,
        toStatus: IpTradeSecretLifecycleStatus.restricted,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli çalışan çıkışını serileştirir', () {
      final model = buildModel(
        transitionType: IpTradeSecretTransitionType.employeeExit,
        exitPartyType: IpTradeSecretExitPartyType.employee,
        exitPartyId: 'employee-1',
        exitPartyDisplayName: 'Çalışan 1',
        highRiskExit: true,
      );

      expect(model.toMap()['exitPartyType'], 'employee');
      expect(model.isExitTransition, isTrue);
    });

    test('sahiplik devrinde eski ve yeni sorumluyu ister', () {
      final model = buildModel(
        transitionType: IpTradeSecretTransitionType.ownershipTransfer,
        toStatus: IpTradeSecretLifecycleStatus.transferring,
        handoverStatus: IpTradeSecretHandoverStatus.inProgress,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli sahiplik devrini serileştirir', () {
      final model = buildModel(
        transitionType: IpTradeSecretTransitionType.ownershipTransfer,
        toStatus: IpTradeSecretLifecycleStatus.transferring,
        handoverStatus: IpTradeSecretHandoverStatus.inProgress,
        previousOwnerUserId: 'owner-old',
        newOwnerUserId: 'owner-new',
      );

      expect(model.isOwnershipTransfer, isTrue);
    });

    test('tamamlanan devir teslimde tarih ve özet ister', () {
      final model = buildModel(
        handoverStatus: IpTradeSecretHandoverStatus.completed,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli tamamlanan devir teslim serileşir', () {
      final model = buildModel(
        handoverStatus: IpTradeSecretHandoverStatus.completed,
        handoverSummary: 'Sorumluluk ve belgeler devredildi.',
        handoverCompletedAt: DateTime.utc(2026, 7, 6),
      );

      expect(model.toMap()['handoverStatus'], 'completed');
    });

    test('erişim kapatmada tarih ve referans ister', () {
      final model = buildModel(accessRevoked: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('varlık iadesinde tarih ister', () {
      final model = buildModel(
        devicesReturned: true,
        deviceReturnReference: 'DEV-001',
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('cihaz iadesinde referans ister', () {
      final model = buildModel(
        devicesReturned: true,
        assetsReturnedAt: DateTime.utc(2026, 7, 6),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('gizlilik hatırlatmasında referans ister', () {
      final model = buildModel(confidentialityReminderDelivered: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('gizlilik kabulünde tarih ister', () {
      final model = buildModel(confidentialityAcknowledged: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('çıkış görüşmesinde tarih ve referans ister', () {
      final model = buildModel(exitInterviewCompleted: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('çıkış yükümlülüklerini açık olarak belirler', () {
      final model = buildModel(
        transitionType: IpTradeSecretTransitionType.employeeExit,
        exitPartyType: IpTradeSecretExitPartyType.employee,
        exitPartyId: 'employee-1',
        exitPartyDisplayName: 'Çalışan 1',
      );

      expect(model.hasOutstandingExitObligations, isTrue);
      expect(model.requiresImmediateEscalation, isTrue);
    });

    test('tamamlanan çıkışta açık yükümlülük bırakmaz', () {
      final model = buildModel(
        transitionType: IpTradeSecretTransitionType.employeeExit,
        exitPartyType: IpTradeSecretExitPartyType.employee,
        exitPartyId: 'employee-1',
        exitPartyDisplayName: 'Çalışan 1',
        accessRevoked: true,
        accessRevokedAt: DateTime.utc(2026, 7, 6),
        accessRevocationReference: 'ACC-001',
        devicesReturned: true,
        deviceReturnReference: 'DEV-001',
        documentsReturned: true,
        documentReturnReference: 'DOC-001',
        keysReturned: true,
        keyReturnReference: 'KEY-001',
        assetsReturnedAt: DateTime.utc(2026, 7, 6),
        confidentialityReminderDelivered: true,
        confidentialityReminderReference: 'REM-001',
        confidentialityAcknowledged: true,
        confidentialityAcknowledgedAt: DateTime.utc(2026, 7, 6),
        exitInterviewCompleted: true,
        exitInterviewCompletedAt: DateTime.utc(2026, 7, 6),
        exitInterviewReference: 'EXIT-001',
      );

      expect(model.hasOutstandingExitObligations, isFalse);
    });

    test('yönetim yükseltmesinde tarih zorunludur', () {
      final model = buildModel(managementEscalationRequired: true);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('kapatılan kayıtta kapanış tarihi ister', () {
      final model = buildModel(
        toStatus: IpTradeSecretLifecycleStatus.closed,
        transitionType: IpTradeSecretTransitionType.closure,
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
