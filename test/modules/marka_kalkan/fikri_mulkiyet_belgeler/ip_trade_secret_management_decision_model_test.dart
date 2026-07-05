import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/constants/ip_trade_secret_detail_enums.dart';
import 'package:markakalkan/modules/marka_kalkan/fikri_mulkiyet_belgeler/models/ip_trade_secret_management_decision_model.dart';

void main() {
  group('IpTradeSecretManagementDecisionModel', () {
    IpTradeSecretManagementDecisionModel buildModel({
      IpTradeSecretDecisionStatus status =
          IpTradeSecretDecisionStatus.underReview,
      IpTradeSecretDecisionType decisionType = IpTradeSecretDecisionType.other,
      IpTradeSecretDecisionVotingMethod votingMethod =
          IpTradeSecretDecisionVotingMethod.singleApprover,
      IpTradeSecretApprovalOutcome approvalOutcome =
          IpTradeSecretApprovalOutcome.pending,
      List<String> riskAssessmentIds = const <String>[],
      List<String> approverUserIds = const <String>['approver-1'],
      List<String> approvedUserIds = const <String>[],
      List<String> rejectedUserIds = const <String>[],
      List<String> abstainedUserIds = const <String>[],
      List<String> recusedUserIds = const <String>[],
      List<String> evidenceDocumentIds = const <String>[],
      String? rationale,
      String? conditions,
      String? dissentingOpinion,
      String? rejectionReason,
      String? suspensionReason,
      String? revocationReason,
      String? supersededByDecisionId,
      String? previousOwnerUserId,
      String? newOwnerUserId,
      String? previousProtectionLevel,
      String? newProtectionLevel,
      num? requestedBudgetAmount,
      num? approvedBudgetAmount,
      String? currencyCode,
      int requiredApprovalCount = 1,
      bool riskAcceptance = false,
      bool conditionalDecision = false,
      bool conditionsSatisfied = false,
      bool reassessmentRequired = false,
      DateTime? decisionAt,
      DateTime? effectiveAt,
      DateTime? expiresAt,
      DateTime? reassessmentAt,
      DateTime? conditionsSatisfiedAt,
      DateTime? suspendedAt,
      DateTime? revokedAt,
      DateTime? expiredAt,
      DateTime? supersededAt,
      Map<String, dynamic> metadata = const <String, dynamic>{},
    }) {
      return IpTradeSecretManagementDecisionModel(
        id: 'decision-1',
        tenantId: 'tenant-1',
        brandId: 'brand-1',
        tradeSecretId: 'secret-1',
        componentIds: const <String>['component-1'],
        riskAssessmentIds: riskAssessmentIds,
        remediationActionIds: const <String>['action-1'],
        alertRuleIds: const <String>['alert-1'],
        evidenceDocumentIds: evidenceDocumentIds,
        reviewerUserIds: const <String>['reviewer-1'],
        approverUserIds: approverUserIds,
        approvedUserIds: approvedUserIds,
        rejectedUserIds: rejectedUserIds,
        abstainedUserIds: abstainedUserIds,
        recusedUserIds: recusedUserIds,
        decisionCode: 'DEC-001',
        title: 'Ticari sır yönetim kararı',
        status: status,
        decisionType: decisionType,
        votingMethod: votingMethod,
        approvalOutcome: approvalOutcome,
        ownerUserId: 'owner-1',
        decisionSummary: 'Yönetim kurulu değerlendirmesi.',
        rationale: rationale,
        conditions: conditions,
        dissentingOpinion: dissentingOpinion,
        rejectionReason: rejectionReason,
        suspensionReason: suspensionReason,
        revocationReason: revocationReason,
        supersededByDecisionId: supersededByDecisionId,
        previousOwnerUserId: previousOwnerUserId,
        newOwnerUserId: newOwnerUserId,
        previousProtectionLevel: previousProtectionLevel,
        newProtectionLevel: newProtectionLevel,
        requestedBudgetAmount: requestedBudgetAmount,
        approvedBudgetAmount: approvedBudgetAmount,
        currencyCode: currencyCode,
        requiredApprovalCount: requiredApprovalCount,
        riskAcceptance: riskAcceptance,
        conditionalDecision: conditionalDecision,
        conditionsSatisfied: conditionsSatisfied,
        reassessmentRequired: reassessmentRequired,
        decisionAt: decisionAt,
        effectiveAt: effectiveAt,
        expiresAt: expiresAt,
        reassessmentAt: reassessmentAt,
        conditionsSatisfiedAt: conditionsSatisfiedAt,
        suspendedAt: suspendedAt,
        revokedAt: revokedAt,
        expiredAt: expiredAt,
        supersededAt: supersededAt,
        metadata: metadata,
        createdAt: DateTime.utc(2026, 7, 5),
        createdBy: 'admin-1',
      );
    }

    test('temel yönetim kararı kimliğini üretir', () {
      final model = buildModel();

      expect(model.hasCompleteIdentity, isTrue);
      expect(model.storesPlaintextSecretContent, isFalse);
    });

    test('enum değerlerini doğru serileştirir', () {
      final map = buildModel().toMap();

      expect(map['status'], 'under_review');
      expect(map['decisionType'], 'other');
      expect(map['votingMethod'], 'single_approver');
      expect(map['approvalOutcome'], 'pending');
    });

    test('gerekli onay sayısı pozitif olmalıdır', () {
      final model = buildModel(requiredApprovalCount: 0);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('onaylayan sayısı gerekli onay sayısından az olamaz', () {
      final model = buildModel(
        requiredApprovalCount: 2,
        approverUserIds: const <String>['approver-1'],
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('bir kullanıcı birden fazla oy listesinde bulunamaz', () {
      final model = buildModel(
        approvedUserIds: const <String>['user-1'],
        rejectedUserIds: const <String>['user-1'],
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('onaylanan kararda yeterli onay ve tarih ister', () {
      final model = buildModel(status: IpTradeSecretDecisionStatus.approved);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli onaylanan kararı serileştirir', () {
      final model = buildModel(
        status: IpTradeSecretDecisionStatus.approved,
        approvalOutcome: IpTradeSecretApprovalOutcome.approved,
        approvedUserIds: const <String>['approver-1'],
        decisionAt: DateTime.utc(2026, 7, 6),
      );

      expect(model.hasQuorum, isTrue);
      expect(model.toMap()['status'], 'approved');
    });

    test('koşullu onayda koşullar ister', () {
      final model = buildModel(
        status: IpTradeSecretDecisionStatus.conditionallyApproved,
        approvalOutcome: IpTradeSecretApprovalOutcome.approved,
        approvedUserIds: const <String>['approver-1'],
        conditionalDecision: true,
        decisionAt: DateTime.utc(2026, 7, 6),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('koşullar karşılandıysa tarih ister', () {
      final model = buildModel(
        conditionalDecision: true,
        conditions: 'Ek kontrol uygulanacak.',
        conditionsSatisfied: true,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('reddedilen kararda ret sonucu ve gerekçe ister', () {
      final model = buildModel(status: IpTradeSecretDecisionStatus.rejected);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('yürürlükteki koşullu karar koşulları tamamlamalıdır', () {
      final model = buildModel(
        status: IpTradeSecretDecisionStatus.effective,
        approvalOutcome: IpTradeSecretApprovalOutcome.approved,
        approvedUserIds: const <String>['approver-1'],
        conditionalDecision: true,
        conditions: 'Kontrol uygulanacak.',
        decisionAt: DateTime.utc(2026, 7, 6),
        effectiveAt: DateTime.utc(2026, 7, 7),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('askıya alınan kararda tarih ve gerekçe ister', () {
      final model = buildModel(status: IpTradeSecretDecisionStatus.suspended);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('iptal edilen kararda tarih ve gerekçe ister', () {
      final model = buildModel(status: IpTradeSecretDecisionStatus.revoked);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('yerine yeni karar geçen kayıtta yeni karar kimliği ister', () {
      final model = buildModel(
        status: IpTradeSecretDecisionStatus.superseded,
        supersededAt: DateTime.utc(2026, 8, 1),
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('risk kabulünde gerekçe risk kaydı ve tarih ister', () {
      final model = buildModel(
        decisionType: IpTradeSecretDecisionType.riskAcceptance,
        riskAcceptance: true,
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('geçerli risk kabul kararını serileştirir', () {
      final model = buildModel(
        decisionType: IpTradeSecretDecisionType.riskAcceptance,
        riskAcceptance: true,
        rationale: 'Risk iştahı içinde.',
        riskAssessmentIds: const <String>['risk-1'],
        reassessmentRequired: true,
        reassessmentAt: DateTime.utc(2026, 12, 31),
      );

      expect(model.isRiskAcceptanceDecision, isTrue);
      expect(model.toMap()['riskAcceptance'], isTrue);
    });

    test('devir kararında farklı eski ve yeni sorumlu ister', () {
      final model = buildModel(
        decisionType: IpTradeSecretDecisionType.ownershipTransfer,
        previousOwnerUserId: 'owner-1',
        newOwnerUserId: 'owner-1',
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('koruma seviyesi kararında farklı seviyeler ister', () {
      final model = buildModel(
        decisionType: IpTradeSecretDecisionType.protectionLevelIncrease,
        previousProtectionLevel: 'high',
        newProtectionLevel: 'high',
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('bütçe varsa para birimi ister', () {
      final model = buildModel(requestedBudgetAmount: 1000);

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('bütçe onayı kararında onaylanan tutar ister', () {
      final model = buildModel(
        decisionType: IpTradeSecretDecisionType.budgetApproval,
        requestedBudgetAmount: 1000,
        currencyCode: 'TRY',
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });

    test('karşı oy bilgisini algılar', () {
      final model = buildModel(
        rejectedUserIds: const <String>['approver-2'],
        dissentingOpinion: 'Risk seviyesi kabul edilemez.',
        approverUserIds: const <String>['approver-1', 'approver-2'],
      );

      expect(model.hasDissent, isTrue);
    });

    test('bekleyen kararı karar paneline taşır', () {
      final model = buildModel(
        status: IpTradeSecretDecisionStatus.pendingApproval,
      );

      expect(model.shouldAppearOnDecisionDashboard, isTrue);
    });

    test('metadata içinde ticari sır içeriğini reddeder', () {
      final model = buildModel(
        metadata: const <String, dynamic>{'secretContent': 'gizli formül'},
      );

      expect(model.toMap, throwsA(isA<StateError>()));
    });
  });
}
