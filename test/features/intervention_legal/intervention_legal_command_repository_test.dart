import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/intervention_legal/data/intervention_legal_command_repository.dart';

void main() {
  group('CallableInterventionLegalCommandRepository', () {
    late List<String> sequence;
    late List<_CapturedCall> calls;
    late int requestCounter;
    late int idempotencyCounter;
    late CallableInterventionLegalCommandRepository repository;

    setUp(() {
      sequence = <String>[];
      calls = <_CapturedCall>[];
      requestCounter = 0;
      idempotencyCounter = 0;

      repository = CallableInterventionLegalCommandRepository(
        ensureAppCheckReady: () async {
          sequence.add('app-check');
        },
        requestIdFactory: () => 'req-${++requestCounter}',
        idempotencyKeyFactory: () => 'idem-${++idempotencyCounter}',
        callable: (String name, Map<String, dynamic> request) async {
          sequence.add('call:$name');
          calls.add(_CapturedCall(name, request));
          return <String, dynamic>{
            'resultType': _resultType(name),
            'idempotentReplay': false,
          };
        },
      );
    });

    test(
      'create matter sends trusted context without client actor fields',
      () async {
        final result = await repository.createLegalMatter(
          context: const InterventionLegalCreateMatterContext(
            tenantId: ' tenant-1 ',
            canonicalBrandId: ' brand-1 ',
            caseId: ' case-1 ',
          ),
          input: const InterventionLegalCreateMatterInput(
            jurisdictionCode: ' tr.istanbul ',
            matterScopeCode: ' counterfeit_enforcement ',
            countryCode: ' TR ',
            priorityCode: ' high ',
            title: ' Test matter ',
            sourceSystemCode: ' case_evidence_center ',
            sourceRecordId: ' case-1 ',
          ),
        );

        expect(result.resultType, 'legal_matter');
        expect(sequence, <String>[
          'app-check',
          'call:createInterventionLegalMatter',
        ]);
        expect(calls, hasLength(1));
        expect(calls.single.name, 'createInterventionLegalMatter');
        expect(calls.single.request, <String, dynamic>{
          'contractVersion': 'intervention-legal-core-v1',
          'requestId': 'req-1',
          'idempotencyKey': 'idem-1',
          'tenantId': 'tenant-1',
          'canonicalBrandId': 'brand-1',
          'caseId': 'case-1',
          'jurisdictionCode': 'tr.istanbul',
          'matterScopeCode': 'counterfeit_enforcement',
          'countryCode': 'TR',
          'priorityCode': 'high',
          'title': 'Test matter',
          'sourceSystemCode': 'case_evidence_center',
          'sourceRecordId': 'case-1',
        });
        _expectNoActorFields(calls.single.request);
      },
    );

    test(
      'transition sends expectedVersion and explicit business input',
      () async {
        await repository.transitionLegalMatter(
          context: const InterventionLegalMatterVersionContext(
            legalMatterId: 'lm-1',
            expectedVersion: 2,
          ),
          input: const InterventionLegalTransitionInput(
            nextStatus: 'legal_review',
            reasonCode: 'evidence_received',
            note: 'ready',
          ),
        );

        expect(sequence, <String>[
          'app-check',
          'call:transitionInterventionLegalMatter',
        ]);
        expect(calls.single.request, <String, dynamic>{
          'contractVersion': 'intervention-legal-core-v1',
          'requestId': 'req-1',
          'idempotencyKey': 'idem-1',
          'expectedVersion': 2,
          'legalMatterId': 'lm-1',
          'nextStatus': 'legal_review',
          'reasonCode': 'evidence_received',
          'note': 'ready',
        });
        _expectNoActorFields(calls.single.request);
      },
    );

    test('approval request keeps preparedByUid server-only', () async {
      await repository.createApprovalRequest(
        context: const InterventionLegalApprovalRequestContext(
          legalMatterId: 'lm-1',
          expectedLegalMatterVersion: 3,
        ),
        input: const InterventionLegalApprovalRequestInput(
          approvalType: 'client_action_authorization',
          requestReasonCode: 'external_action_required',
          requestNote: 'Client authorization required.',
        ),
      );

      expect(sequence, <String>[
        'app-check',
        'call:createInterventionLegalApprovalRequest',
      ]);
      expect(calls.single.request, <String, dynamic>{
        'contractVersion': 'intervention-legal-core-v1',
        'requestId': 'req-1',
        'idempotencyKey': 'idem-1',
        'expectedLegalMatterVersion': 3,
        'legalMatterId': 'lm-1',
        'approvalType': 'client_action_authorization',
        'requestReasonCode': 'external_action_required',
        'requestNote': 'Client authorization required.',
      });
      _expectNoActorFields(calls.single.request);
    });

    test('approval decision keeps decidedByUid server-only', () async {
      final result = await repository.recordApprovalDecision(
        context: const InterventionLegalApprovalDecisionContext(
          approvalRequestId: 'lar-1',
          legalMatterId: 'lm-1',
          approvalType: 'lawyer_legal_approval',
          expectedApprovalRequestVersion: 1,
        ),
        input: const InterventionLegalApprovalDecisionInput(
          decision: 'approved',
          decisionReasonCode: 'review_completed',
          decisionNote: 'Approved after review.',
        ),
      );

      expect(result.resultType, 'legal_approval_decision');
      expect(sequence, <String>[
        'app-check',
        'call:recordInterventionLegalApprovalDecision',
      ]);
      expect(calls.single.request, <String, dynamic>{
        'contractVersion': 'intervention-legal-core-v1',
        'requestId': 'req-1',
        'idempotencyKey': 'idem-1',
        'expectedApprovalRequestVersion': 1,
        'approvalRequestId': 'lar-1',
        'legalMatterId': 'lm-1',
        'approvalType': 'lawyer_legal_approval',
        'decision': 'approved',
        'decisionReasonCode': 'review_completed',
        'decisionNote': 'Approved after review.',
      });
      _expectNoActorFields(calls.single.request);
    });

    test('invalid optimistic version fails before App Check and callable', () {
      expect(
        () => repository.transitionLegalMatter(
          context: const InterventionLegalMatterVersionContext(
            legalMatterId: 'lm-1',
            expectedVersion: 0,
          ),
          input: const InterventionLegalTransitionInput(
            nextStatus: 'legal_review',
            reasonCode: 'manual_review',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(sequence, isEmpty);
      expect(calls, isEmpty);
    });

    test('optional blank strings are omitted from wire payload', () async {
      await repository.createApprovalRequest(
        context: const InterventionLegalApprovalRequestContext(
          legalMatterId: 'lm-1',
          expectedLegalMatterVersion: 1,
        ),
        input: const InterventionLegalApprovalRequestInput(
          approvalType: 'client_budget_authorization',
          requestReasonCode: 'budget_required',
          requestNote: '   ',
        ),
      );

      expect(calls.single.request.containsKey('requestNote'), isFalse);
    });

    test('source boundary contains no direct Firestore dependency', () {
      final source = File(
        'lib/features/intervention_legal/data/'
        'intervention_legal_command_repository.dart',
      ).readAsStringSync();

      expect(source.contains('cloud_firestore'), isFalse);
      expect(source.contains('FirebaseFirestore'), isFalse);
      expect(
        source.contains(
          "FirebaseFunctions.instanceFor(region: 'europe-west3')",
        ),
        isTrue,
      );
      expect(source.contains('AppCheckBootstrap.instance.ensureReady'), isTrue);
    });
  });
}

void _expectNoActorFields(Map<String, dynamic> request) {
  expect(request.containsKey('actorUid'), isFalse);
  expect(request.containsKey('preparedByUid'), isFalse);
  expect(request.containsKey('decidedByUid'), isFalse);
}

String _resultType(String callable) {
  switch (callable) {
    case 'createInterventionLegalMatter':
      return 'legal_matter';
    case 'createInterventionLegalApprovalRequest':
      return 'legal_approval_request';
    case 'recordInterventionLegalApprovalDecision':
      return 'legal_approval_decision';
    default:
      return 'legal_matter';
  }
}

final class _CapturedCall {
  const _CapturedCall(this.name, this.request);

  final String name;
  final Map<String, dynamic> request;
}
