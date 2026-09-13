import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/odla/data/odla_workspace_repository.dart';

void main() {
  test('ODLA discovery uses only the existing read callable', () async {
    final calls = <Map<String, Object?>>[];
    final repository = CallableOdlaWorkspaceRepository(
      callable: (name, request) async {
        expect(name, odlaWorkspaceCallableName);
        expect(name, 'getOdlaVerificationWorkspace');
        calls.add(request);
        return <String, Object?>{
          'contractVersion': odlaDiscoveryContractVersion,
          'mode': 'discovery',
          'tenantId': 't1',
          'brandUids': <Object?>['b1'],
          'roles': <Object?>['authorized_reviewer'],
          'count': 1,
          'cases': <Object?>[
            <String, Object?>{
              'caseId': 'c1',
              'tenantId': 't1',
              'brandUid': 'b1',
              'state': 'verification_in_progress',
              'profileCode': 'electronics',
              'profileVersion': 3,
              'productClassCode': 'ELEC',
              'countryCode': 'TR',
            },
          ],
        };
      },
    );

    final result = await repository.loadDiscovery();

    expect(calls.single, isEmpty);
    expect(result.cases.single.caseId, 'c1');
    expect(result.cases.single.profileVersion, 3);
    expect(result.roles, <String>['authorized_reviewer']);
  });

  test('ODLA detail sends exact case scope and parses five typed domains', () async {
    Map<String, Object?>? captured;
    final repository = CallableOdlaWorkspaceRepository(
      callable: (name, request) async {
        expect(name, odlaWorkspaceCallableName);
        captured = request;
        return <String, Object?>{
          'contractVersion': odlaDetailContractVersion,
          'case': <String, Object?>{
            'caseId': 'c1',
            'tenantId': 't1',
            'brandUid': 'b1',
            'state': 'verification_in_progress',
            'countryCode': 'TR',
            'profileCode': 'electronics',
            'profileVersion': 3,
            'productClassCode': 'ELEC',
          },
          'custodyEvents': <Object?>[
            <String, Object?>{
              'eventId': 'e1',
              'eventSequence': 1,
              'sampleId': 's1',
              'eventType': 'sample_received',
              'actorType': 'laboratory',
              'locationCode': 'TR-34',
              'sealId': 'seal-1',
              'evidenceRefs': <Object?>['ev-1'],
              'appendOnly': true,
            },
          ],
          'testRequests': <Object?>[
            <String, Object?>{
              'testRequestId': 'q1',
              'requestSequence': 1,
              'sampleId': 's1',
              'laboratoryId': 'lab-1',
              'testQuestionCode': 'AUTHENTICITY',
              'methodCode': 'M-1',
              'state': 'testing',
            },
          ],
          'testResults': <Object?>[
            <String, Object?>{
              'testResultId': 'r1',
              'testRequestId': 'q1',
              'sampleId': 's1',
              'laboratoryId': 'lab-1',
              'laboratoryReportId': 'report-1',
              'methodCode': 'M-1',
              'resultCode': 'MATCH',
              'resultSummaryCode': 'AUTHENTIC',
              'custodyIntegrityVerified': true,
              'referenceIntegrityVerified': true,
              'reportSha256': 'abc',
            },
          ],
          'findings': <Object?>[
            <String, Object?>{
              'findingId': 'f1',
              'findingVersion': 1,
              'findingCode': 'AUTHENTIC',
              'confidenceBand': 'HIGH',
              'reasonCodes': <Object?>['LAB_MATCH'],
            },
          ],
          'appeals': <Object?>[
            <String, Object?>{
              'appealId': 'a1',
              'appealSequence': 1,
              'appellantType': 'brand',
              'challengedFindingId': 'f1',
              'requestedRemedyCode': 'SECOND_LAB',
              'reserveSampleId': 's2',
              'secondLaboratoryId': 'lab-2',
              'state': 'second_lab_in_progress',
            },
          ],
        };
      },
    );

    final detail = await repository.loadWorkspace(
      const OdlaCaseSummary(
        caseId: 'c1',
        tenantId: 't1',
        brandUid: 'b1',
        state: 'verification_in_progress',
      ),
    );

    expect(captured, <String, Object?>{
      'caseId': 'c1',
      'tenantId': 't1',
      'brandUid': 'b1',
    });
    expect(detail.caseId, 'c1');
    expect(detail.profileVersion, 3);

    expect(detail.custodyEvents, hasLength(1));
    expect(detail.custodyEvents.single.eventId, 'e1');
    expect(detail.custodyEvents.single.eventSequence, 1);
    expect(detail.custodyEvents.single.evidenceRefs, <String>['ev-1']);

    expect(detail.testRequests, hasLength(1));
    expect(detail.testRequests.single.testRequestId, 'q1');
    expect(detail.testRequests.single.state, 'testing');

    expect(detail.testResults, hasLength(1));
    expect(detail.testResults.single.testResultId, 'r1');
    expect(detail.testResults.single.resultSummaryCode, 'AUTHENTIC');
    expect(detail.testResults.single.custodyIntegrityVerified, isTrue);

    expect(detail.findings, hasLength(1));
    expect(detail.findings.single.findingId, 'f1');
    expect(detail.findings.single.findingVersion, 1);
    expect(detail.findings.single.reasonCodes, <String>['LAB_MATCH']);

    expect(detail.appeals, hasLength(1));
    expect(detail.appeals.single.appealId, 'a1');
    expect(detail.appeals.single.secondLaboratoryId, 'lab-2');
  });

  test('ODLA detail parser fails closed on unsupported contract', () {
    expect(
      () => OdlaWorkspaceDetail.fromMap(<String, Object?>{
        'contractVersion': 'odla-workspace-detail-v0',
        'case': <String, Object?>{},
        'custodyEvents': <Object?>[],
        'testRequests': <Object?>[],
        'testResults': <Object?>[],
        'findings': <Object?>[],
        'appeals': <Object?>[],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('ODLA detail parser fails closed when an operational list is malformed', () {
    expect(
      () => OdlaWorkspaceDetail.fromMap(<String, Object?>{
        'contractVersion': odlaDetailContractVersion,
        'case': <String, Object?>{'caseId': 'c1'},
        'custodyEvents': 'not-a-list',
        'testRequests': <Object?>[],
        'testResults': <Object?>[],
        'findings': <Object?>[],
        'appeals': <Object?>[],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
