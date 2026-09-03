import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_workspace_repository.dart';

void main() {
  test(
    'repository calls the exact workspace callable and parses projection',
    () async {
      String? callableName;
      Map<String, Object?>? callableRequest;

      final repository = CallableInterventionLegalWorkspaceRepository(
        callable: (name, request) async {
          callableName = name;
          callableRequest = request;
          return _workspacePayload();
        },
      );

      final snapshot = await repository.loadWorkspace(limit: 10);

      expect(callableName, interventionLegalWorkspaceCallableName);
      expect(callableRequest, {
        'contractVersion': interventionLegalWorkspaceContractVersion,
        'limit': 10,
      });
      expect(snapshot.counts.legalMatterCount, 1);
      expect(snapshot.matters, hasLength(1));
      expect(snapshot.matters.single.legalMatterId, 'lm-1');
      expect(
        snapshot.matters.single.capabilityAccess
            .legalAction('transition_legal_matter')
            ?.operationAuthorityGranted,
        isTrue,
      );
      expect(
        snapshot.matters.single.capabilityAccess
            .legalAction('create_approval_request')
            ?.operationAuthorityGranted,
        isFalse,
      );
      expect(
        snapshot.matters.single.approvalRequests.single.status,
        'approved',
      );
      expect(
        snapshot.matters.single.approvalDecisions.single.decisionReasonCode,
        'client_action_authorized',
      );
      expect(
        snapshot.matters.single.approvalDecisions.single.immutable,
        isTrue,
      );
    },
  );

  test('repository rejects unsupported workspace contract', () async {
    final repository = CallableInterventionLegalWorkspaceRepository(
      callable: (_, _) async => {
        ..._workspacePayload(),
        'contractVersion': 'unsupported-v9',
      },
    );

    await expectLater(
      repository.loadWorkspace(),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'repository rejects client limits outside the server contract',
    () async {
      final repository = CallableInterventionLegalWorkspaceRepository(
        callable: (_, _) async => _workspacePayload(),
      );

      await expectLater(
        repository.loadWorkspace(limit: 0),
        throwsA(isA<RangeError>()),
      );
      await expectLater(
        repository.loadWorkspace(limit: 51),
        throwsA(isA<RangeError>()),
      );
    },
  );

  test('missing capability projection fails closed as no authority', () async {
    final payload = _workspacePayload();
    final matters = payload['matters']! as List<Object?>;
    final matter = Map<String, Object?>.from(
      matters.single! as Map<String, Object?>,
    )..remove('capabilityAccess');
    payload['matters'] = <Object?>[matter];
    final repository = CallableInterventionLegalWorkspaceRepository(
      callable: (_, _) async => payload,
    );
    final snapshot = await repository.loadWorkspace();
    expect(
      snapshot.matters.single.capabilityAccess.legalAction(
        'transition_legal_matter',
      ),
      isNull,
    );
  });

  test('capability projection rejects brand scope mismatch', () async {
    final payload = _workspacePayload();
    final matters = payload['matters']! as List<Object?>;
    final matter = Map<String, Object?>.from(
      matters.single! as Map<String, Object?>,
    );
    final capability = Map<String, Object?>.from(
      matter['capabilityAccess']! as Map<String, Object?>,
    );
    final legalAction = Map<String, Object?>.from(
      capability['LEGAL_ACTION']! as Map<String, Object?>,
    );
    final transition = Map<String, Object?>.from(
      legalAction['transition_legal_matter']! as Map<String, Object?>,
    );
    transition['canonicalBrandId'] = 'brand-other';
    legalAction['transition_legal_matter'] = transition;
    capability['LEGAL_ACTION'] = legalAction;
    matter['capabilityAccess'] = capability;
    payload['matters'] = <Object?>[matter];
    final repository = CallableInterventionLegalWorkspaceRepository(
      callable: (_, _) async => payload,
    );
    await expectLater(
      repository.loadWorkspace(),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, Object?> _workspacePayload() {
  return {
    'contractVersion': interventionLegalWorkspaceContractVersion,
    'generatedAt': '2026-08-01T18:48:17.930Z',
    'limit': 20,
    'authorityScopeCount': 1,
    'counts': {
      'legalMatterCount': 1,
      'activeLegalMatterCount': 1,
      'pendingApprovalCount': 0,
      'approvedApprovalCount': 1,
      'rejectedApprovalCount': 0,
    },
    'matters': [
      {
        'legalMatterId': 'lm-1',
        'caseId': 'case-1',
        'tenantId': 'tenant-1',
        'canonicalBrandId': 'brand-1',
        'jurisdictionCode': 'tr.istanbul',
        'countryCode': 'TR',
        'matterScopeCode': 'platform_takedown',
        'priorityCode': 'high',
        'title': 'Canlı hukuki dosya',
        'status': 'legal_review',
        'version': 2,
        'sourceSystemCode': 'case_evidence_center',
        'sourceRecordId': 'case-1',
        'createdAt': '2026-08-01T17:40:00.000Z',
        'updatedAt': '2026-08-01T18:48:17.930Z',
        'createdByUid': 'user-1',
        'updatedByUid': 'user-1',
        'statusChangedByUid': 'user-1',
        'capabilityAccess': {
          'LEGAL_ACTION': {
            'transition_legal_matter': {
              'operationCode': 'transition_legal_matter',
              'canonicalBrandId': 'brand-1',
              'operationAuthorityGranted': true,
              'authoritySource': 'tenant_owner',
            },
            'create_approval_request': {
              'operationCode': 'create_approval_request',
              'canonicalBrandId': 'brand-1',
              'operationAuthorityGranted': false,
              'authoritySource': 'none',
            },
          },
        },
        'approvalRequests': [
          {
            'approvalRequestId': 'lar-1',
            'legalMatterId': 'lm-1',
            'approvalType': 'client_action_authorization',
            'status': 'approved',
            'version': 2,
            'requestSequence': 2,
            'requestReasonCode': 'legal_action_authorization_required',
            'requestNote': 'Hukuki işlem yetkilendirme talebi.',
            'preparedByUid': 'user-1',
            'decisionId': 'lad-1',
            'decidedByUid': 'user-1',
            'createdAt': '2026-08-01T17:45:51.049Z',
            'updatedAt': '2026-08-01T18:48:17.930Z',
            'decidedAt': '2026-08-01T18:48:17.930Z',
          },
        ],
        'approvalDecisions': [
          {
            'decisionId': 'lad-1',
            'approvalRequestId': 'lar-1',
            'legalMatterId': 'lm-1',
            'approvalType': 'client_action_authorization',
            'decision': 'approved',
            'decisionReasonCode': 'client_action_authorized',
            'decisionNote': null,
            'decidedByUid': 'user-1',
            'decidedAt': '2026-08-01T18:48:17.930Z',
            'immutable': true,
          },
        ],
      },
    ],
  };
}
