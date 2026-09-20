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

  test(
    'ODLA operational repository routes seven write callables exactly',
    () async {
      final names = <String>[];
      final payloads = <Map<String, Object?>>[];
      final repository = CallableOdlaWorkspaceRepository(
        callable: (name, request) async {
          names.add(name);
          payloads.add(Map<String, Object?>.from(request));
          return <String, Object?>{'ok': true};
        },
      );
      const payload = <String, Object?>{'operationId': 'op-1'};

      await repository.createVerificationCase(payload);
      await repository.appendCustodyEvent(payload);
      await repository.createTestRequest(payload);
      await repository.recordTestResult(payload);
      await repository.adjudicateFinding(payload);
      await repository.openAppeal(payload);
      await repository.resolveAppeal(payload);

      expect(names, <String>[
        odlaCreateVerificationCaseCallableName,
        odlaAppendCustodyCallableName,
        odlaCreateTestRequestCallableName,
        odlaRecordTestResultCallableName,
        odlaAdjudicateFindingCallableName,
        odlaOpenAppealCallableName,
        odlaResolveAppealCallableName,
      ]);
      expect(payloads, hasLength(7));
      expect(payloads.every((item) => item['operationId'] == 'op-1'), isTrue);
    },
  );

  test(
    'ODLA detail sends exact case scope and parses five typed domains',
    () async {
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
                'reportIntegrityContractVersion':
                    odlaReportIntegrityContractVersion,
                'reportArtifactRef': 'artifact:report-1',
                'reportArtifactVersion': 2,
                'reportSha256':
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
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

            'custodyIntegrityContext': <String, Object?>{
              'contractVersion': odlaCustodyIntegrityContextContractVersion,
              'samples': <Object?>[
                <String, Object?>{
                  'sampleId': 's1',
                  'eventCount': 1,
                  'latestEventId': 'e1',
                  'latestEventSequence': 1,
                  'currentSealId': 'seal-1',
                  'sealIds': <Object?>['seal-1'],
                  'sealChangeCount': 0,
                  'openingEventCount': 0,
                  'hasSealChange': false,
                  'appendOnlyStatus': 'VERIFIED',
                  'integrityStatus': 'VERIFIED',
                  'integrityCode': 'OK',
                  'hashIntegrityStatus': 'VERIFIED',
                  'sequenceIntegrityStatus': 'VERIFIED',
                  'predecessorIntegrityStatus': 'VERIFIED',
                  'evidenceReferenceCount': 1,
                  'testRequestIds': <Object?>['q1'],
                  'testResultIds': <Object?>['r1'],
                  'appealIds': <Object?>[],
                  'testResultIntegritySummary': <String, Object?>{
                    'status': 'VERIFIED',
                    'reportedCount': 1,
                    'verifiedCount': 1,
                    'failedCount': 0,
                    'unknownCount': 0,
                  },
                },
                <String, Object?>{
                  'sampleId': 's2',
                  'eventCount': 0,
                  'latestEventId': null,
                  'latestEventSequence': null,
                  'currentSealId': null,
                  'sealIds': <Object?>[],
                  'sealChangeCount': 0,
                  'openingEventCount': 0,
                  'hasSealChange': false,
                  'appendOnlyStatus': 'NOT_ESTABLISHED',
                  'integrityStatus': 'NOT_ESTABLISHED',
                  'integrityCode': 'NO_CUSTODY_EVENTS',
                  'hashIntegrityStatus': 'NOT_ESTABLISHED',
                  'sequenceIntegrityStatus': 'NOT_ESTABLISHED',
                  'predecessorIntegrityStatus': 'NOT_ESTABLISHED',
                  'evidenceReferenceCount': 0,
                  'testRequestIds': <Object?>[],
                  'testResultIds': <Object?>[],
                  'appealIds': <Object?>['a1'],
                  'testResultIntegritySummary': <String, Object?>{
                    'status': 'NOT_REPORTED',
                    'reportedCount': 0,
                    'verifiedCount': 0,
                    'failedCount': 0,
                    'unknownCount': 0,
                  },
                },
              ],
              'referencedSampleCount': 2,
              'establishedSampleCount': 1,
              'notEstablishedSampleCount': 1,
              'truncated': false,
            },
            'laboratoryRegistryContext': <String, Object?>{
              'contractVersion': odlaLaboratoryRegistryContextContractVersion,
              'laboratories': <Object?>[
                <String, Object?>{
                  'laboratoryId': 'lab-1',
                  'laboratory': <String, Object?>{
                    'laboratoryId': 'lab-1',
                    'legalName': 'Anadolu Doğrulama Laboratuvarı A.Ş.',
                    'displayName': 'Anadolu Doğrulama Lab',
                    'countryCode': 'TR',
                    'registrationAuthorityId': 'TR-LAB-AUTH',
                    'registrationNumber': 'LAB-0001',
                    'status': 'ACTIVE',
                  },
                  'registryStatus': 'ACTIVE',
                  'verificationStatus': 'VERIFIED',
                  'accreditations': <Object?>[
                    <String, Object?>{
                      'accreditationId': 'acc-1',
                      'laboratoryId': 'lab-1',
                      'standardCode': 'ISO_IEC_17025',
                      'certificateNumber': 'CERT-0001',
                      'accreditationBodyTypeCode': 'NATIONAL',
                      'accreditationBodyId': 'TURKAK',
                      'validFrom': '2026-01-01T00:00:00Z',
                      'validUntil': '2027-01-01T00:00:00Z',
                      'status': 'ACTIVE',
                      'verificationStatus': 'VERIFIED',
                    },
                  ],
                  'scopes': <Object?>[
                    <String, Object?>{
                      'scopeId': 'scope-1',
                      'laboratoryId': 'lab-1',
                      'accreditationId': 'acc-1',
                      'testTypeCode': 'AUTHENTICITY',
                      'methodCode': 'M-1',
                      'status': 'ACTIVE',
                    },
                  ],
                  'coverageContexts': <Object?>[
                    <String, Object?>{
                      'referenceType': 'TEST_REQUEST',
                      'referenceId': 'q1',
                      'accreditationId': 'acc-1',
                      'scopeId': 'scope-1',
                      'persistedCoverageStatus': 'COVERED',
                      'persistedCoverageReasonCode': 'SCOPE_MATCH',
                      'verificationStatus': 'VERIFIED',
                      'registryMatchStatus': 'RESOLVED',
                    },
                  ],
                  'registryResolutionStatus': 'RESOLVED',
                },
              ],
              'referencedLaboratoryCount': 1,
              'resolvedLaboratoryCount': 1,
              'legacyUnknownCount': 0,
              'truncated': false,
            },
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
      expect(
        detail.testResults.single.reportIntegrityContractVersion,
        odlaReportIntegrityContractVersion,
      );
      expect(detail.testResults.single.reportArtifactRef, 'artifact:report-1');
      expect(detail.testResults.single.reportArtifactVersion, 2);
      expect(
        detail.testResults.single.reportIntegrityStatus,
        'ARTIFACT_VERSION_BOUND',
      );

      const validHash =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      expect(
        OdlaTestResult.fromMap(<String, Object?>{
          'reportSha256': validHash,
        }).reportIntegrityStatus,
        'LEGACY_HASH_ONLY',
      );
      expect(
        OdlaTestResult.fromMap(<String, Object?>{
          'reportIntegrityContractVersion': odlaReportIntegrityContractVersion,
          'reportSha256': validHash,
        }).reportIntegrityStatus,
        'HASH_RECORDED',
      );
      expect(
        OdlaTestResult.fromMap(<String, Object?>{
          'reportIntegrityContractVersion': odlaReportIntegrityContractVersion,
          'reportArtifactRef': 'artifact:partial',
          'reportSha256': validHash,
        }).reportIntegrityStatus,
        'ARTIFACT_BINDING_INCOMPLETE',
      );
      expect(
        OdlaTestResult.fromMap(<String, Object?>{
          'reportIntegrityContractVersion': 'future-contract-v2',
          'reportSha256': validHash,
        }).reportIntegrityStatus,
        'UNKNOWN_CONTRACT',
      );
      expect(
        OdlaTestResult.fromMap(<String, Object?>{
          'reportIntegrityContractVersion': odlaReportIntegrityContractVersion,
          'reportSha256': 'not-a-sha',
        }).reportIntegrityStatus,
        'HASH_FORMAT_INVALID',
      );

      expect(detail.findings, hasLength(1));
      expect(detail.findings.single.findingId, 'f1');
      expect(detail.findings.single.findingVersion, 1);
      expect(detail.findings.single.reasonCodes, <String>['LAB_MATCH']);

      expect(detail.appeals, hasLength(1));
      expect(detail.appeals.single.appealId, 'a1');
      expect(detail.appeals.single.secondLaboratoryId, 'lab-2');

      final custody = detail.custodyIntegrityContext;
      expect(
        custody.contractVersion,
        odlaCustodyIntegrityContextContractVersion,
      );
      expect(custody.referencedSampleCount, 2);
      expect(custody.establishedSampleCount, 1);
      expect(custody.notEstablishedSampleCount, 1);
      expect(custody.samples, hasLength(2));
      expect(custody.samples.first.sampleId, 's1');
      expect(custody.samples.first.integrityStatus, 'VERIFIED');
      expect(custody.samples.first.currentSealId, 'seal-1');
      expect(custody.samples.last.sampleId, 's2');
      expect(custody.samples.last.integrityStatus, 'NOT_ESTABLISHED');

      final registry = detail.laboratoryRegistryContext;
      expect(
        registry.contractVersion,
        odlaLaboratoryRegistryContextContractVersion,
      );
      expect(registry.referencedLaboratoryCount, 1);
      expect(registry.resolvedLaboratoryCount, 1);
      expect(registry.legacyUnknownCount, 0);
      expect(registry.truncated, isFalse);
      expect(registry.laboratories, hasLength(1));
      final laboratory = registry.laboratories.single;
      expect(laboratory.laboratoryId, 'lab-1');
      expect(laboratory.displayName, 'Anadolu Doğrulama Lab');
      expect(laboratory.legalName, 'Anadolu Doğrulama Laboratuvarı A.Ş.');
      expect(laboratory.registryStatus, 'ACTIVE');
      expect(laboratory.verificationStatus, 'VERIFIED');
      expect(laboratory.accreditations.single.standardCode, 'ISO_IEC_17025');
      expect(laboratory.scopes.single.methodCode, 'M-1');
      expect(
        laboratory.coverageContexts.single.registryMatchStatus,
        'RESOLVED',
      );
    },
  );

  test('ODLA laboratory registry preserves legacy unknown fallback', () {
    final registry = OdlaLaboratoryRegistryContext.fromMap(<String, Object?>{
      'contractVersion': odlaLaboratoryRegistryContextContractVersion,
      'laboratories': <Object?>[
        <String, Object?>{
          'laboratoryId': 'legacy-lab',
          'laboratory': null,
          'registryStatus': 'UNKNOWN',
          'verificationStatus': 'UNVERIFIED',
          'accreditations': <Object?>[],
          'scopes': <Object?>[],
          'coverageContexts': <Object?>[],
          'registryResolutionStatus': 'UNKNOWN',
        },
      ],
      'referencedLaboratoryCount': 1,
      'resolvedLaboratoryCount': 0,
      'legacyUnknownCount': 1,
      'truncated': false,
    });

    final laboratory = registry.laboratories.single;
    expect(laboratory.laboratory, isNull);
    expect(laboratory.displayName, isNull);
    expect(laboratory.legalName, isNull);
    expect(laboratory.registryStatus, 'UNKNOWN');
    expect(laboratory.verificationStatus, 'UNVERIFIED');
    expect(laboratory.registryResolutionStatus, 'UNKNOWN');
    expect(registry.legacyUnknownCount, 1);
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

  test(
    'ODLA detail parser fails closed when an operational list is malformed',
    () {
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
    },
  );
}
