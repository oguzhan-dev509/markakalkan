import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_capability_access_adapter_v1.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_workspace_repository.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

void main() {
  const adapter = InterventionLegalCapabilityAccessAdapterV1();

  test('granted scoped authority grants LEGAL_ACTION UX capability', () {
    final decision = adapter.evaluate(
      matter: _matter(transitionGranted: true),
      operationCode: interventionLegalTransitionOperationCode,
    );
    expect(decision.granted, isTrue);
    expect(decision.missingRequirements, isEmpty);
  });

  test('denied scoped authority fails closed', () {
    final decision = adapter.evaluate(
      matter: _matter(transitionGranted: false),
      operationCode: interventionLegalTransitionOperationCode,
    );
    expect(decision.granted, isFalse);
    expect(
      decision.missingRequirements,
      contains(AccessRequirementCodeV1.operationAuthorityRequired),
    );
  });

  test('missing operation projection fails closed', () {
    expect(
      adapter.isGranted(
        matter: _matter(transitionGranted: true),
        operationCode: 'unknown_legal_operation',
      ),
      isFalse,
    );
  });

  test(
    'approval request authority is independent from transition authority',
    () {
      final matter = _matter(
        transitionGranted: false,
        approvalRequestGranted: true,
      );
      expect(
        adapter.isGranted(
          matter: matter,
          operationCode: interventionLegalTransitionOperationCode,
        ),
        isFalse,
      );
      expect(
        adapter.isGranted(
          matter: matter,
          operationCode: interventionLegalCreateApprovalRequestOperationCode,
        ),
        isTrue,
      );
    },
  );
}

InterventionLegalMatterSummary _matter({
  required bool transitionGranted,
  bool approvalRequestGranted = false,
}) {
  return InterventionLegalMatterSummary(
    legalMatterId: 'lm-1',
    caseId: 'case-1',
    tenantId: 'tenant-1',
    canonicalBrandId: 'brand-1',
    jurisdictionCode: 'tr.istanbul',
    countryCode: 'TR',
    matterScopeCode: 'platform_takedown',
    priorityCode: 'high',
    title: 'Canlı hukuki dosya',
    status: 'legal_review',
    version: 2,
    sourceSystemCode: 'case_evidence_center',
    sourceRecordId: 'case-1',
    createdAt: DateTime.utc(2026, 8, 1, 17, 40),
    updatedAt: DateTime.utc(2026, 8, 1, 18, 48),
    createdByUid: 'user-1',
    updatedByUid: 'user-1',
    statusChangedByUid: 'user-1',
    capabilityAccess: InterventionLegalMatterCapabilityAccess(
      legalActionByOperationCode: {
        interventionLegalTransitionOperationCode:
            InterventionLegalOperationAuthorityProjection(
              operationCode: interventionLegalTransitionOperationCode,
              canonicalBrandId: 'brand-1',
              operationAuthorityGranted: transitionGranted,
              authoritySource: transitionGranted ? 'tenant_owner' : 'none',
            ),
        interventionLegalCreateApprovalRequestOperationCode:
            InterventionLegalOperationAuthorityProjection(
              operationCode:
                  interventionLegalCreateApprovalRequestOperationCode,
              canonicalBrandId: 'brand-1',
              operationAuthorityGranted: approvalRequestGranted,
              authoritySource: approvalRequestGranted
                  ? 'explicit_delegation'
                  : 'none',
            ),
      },
    ),
    approvalRequests: const [],
    approvalDecisions: const [],
  );
}
