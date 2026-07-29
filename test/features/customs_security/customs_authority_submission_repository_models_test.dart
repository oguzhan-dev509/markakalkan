import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';
import 'package:markakalkan/features/customs_security/presentation/customs_authority_submission_labels.dart';

String _hash(String value) => List<String>.filled(64, value).join();

Map<String, dynamic> _submissionMap() => {
  'submissionId': 'submission-1',
  'submissionNumber': 'KRI-2026-ABCDEF12',
  'submissionType': 'fsmh_protection_application',
  'targetAuthority': 'fsmh_program',
  'targetUnit': 'FSMH Başvuru Birimi',
  'channelType': 'fsmh_portal',
  'protectionProfileId': 'profile-1',
  'interventionId': null,
  'caseId': null,
  'legalMatterId': null,
  'incidentReference': 'GKP-2026-ABCDEF12',
  'title': 'Bosch FSMH koruma başvurusu',
  'authoritySummary':
      'Aktif gümrük koruma profili temelinde resmî başvuru taslağıdır.',
  'status': 'draft',
  'humanReviewReference': null,
  'rightsHolderApprovalReference': null,
  'dataMinimizationConfirmed': false,
  'nonAccusatoryLanguageConfirmed': false,
  'duplicateCheckKey': _hash('a'),
  'currentPackageId': null,
  'currentPackageVersion': 0,
  'currentPackageHash': null,
  'preparedByUid': 'user-1',
  'reviewedByUid': null,
  'approvedByUid': null,
  'submittedByUid': null,
  'submittedAt': null,
  'externalSubmissionStatement': null,
  'externalReferenceType': null,
  'externalReferenceValue': null,
  'officialReferenceNumber': null,
  'receiptRecordedAt': null,
  'outcomeResponseId': null,
  'outcomeCode': null,
  'outcomeFinalityLevel': null,
  'authorityReferenceNumber': null,
  'officialDocumentDate': null,
  'outcomeReceivedAt': null,
  'outcomeRecordedAt': null,
  'authorityNameSnapshot': null,
  'authorityUnitSnapshot': null,
  'outcomeSummary': null,
  'packageCount': 0,
  'responseCount': 0,
  'eventCount': 1,
  'lastEventType': 'authority_submission_created',
  'lastEventAt': '2026-07-25T16:00:00.000Z',
  'createdAt': '2026-07-25T16:00:00.000Z',
  'updatedAt': '2026-07-25T16:00:00.000Z',
};

Map<String, dynamic> _packageMap() => {
  'packageId': 'package-1',
  'submissionId': 'submission-1',
  'version': 1,
  'packageType': 'fsmh_application_package',
  'sourceSnapshot': <String, dynamic>{},
  'documentManifest': [
    {
      'referenceId': 'doc-1',
      'title': 'Marka tescil belgesi',
      'sha256': _hash('b'),
      'mimeType': 'application/pdf',
      'sizeBytes': 1200,
    },
  ],
  'evidenceManifest': <Object>[],
  'redactionManifest': <Object>[],
  'coverLetterText': 'Resmî paket için hazırlanan üst yazı metnidir.',
  'authoritySummary': 'Kurum için hazırlanan resmî başvuru özetidir.',
  'legalNeutralityStatement':
      'Bu paket kesin suç isnadı içermez ve insan incelemesine dayanır.',
  'aggregateHashAlgorithm': 'SHA-256',
  'aggregateHash': _hash('c'),
  'generatedAt': '2026-07-25T16:10:00.000Z',
  'generatedByUid': 'user-1',
  'immutable': true,
};

Map<String, dynamic> _responseMap({String type = 'acknowledgement'}) => {
  'responseId': 'response-1',
  'submissionId': 'submission-1',
  'responseType': type,
  'authorityReference': 'FSMH-2026-0001',
  'receivedAt': '2026-07-25T16:20:00.000Z',
  'receivedByUid': 'user-1',
  'summary': 'Kurum cevabı insan incelemesiyle kaydedildi.',
  'attachmentReferences': <String>[],
  'attachmentHashes': <String>[],
  'requestedDueAt': null,
  'outcomeCode': type == 'decision' ? 'action_taken' : 'accepted_for_review',
  'outcomeFinalityLevel': type == 'decision' ? 'administrative_final' : null,
  'officialDocumentDate': type == 'decision'
      ? '2026-07-25T16:00:00.000Z'
      : null,
  'authorityNameSnapshot': type == 'decision' ? 'Ticaret Bakanlığı' : null,
  'authorityUnitSnapshot': type == 'decision' ? 'FSMH Başvuru Birimi' : null,
  'previousResponseId': type == 'decision' ? 'response-previous' : null,
  'additionalNotes': type == 'decision'
      ? 'Kullanıcı tarafından eklenen açıklama.'
      : null,
  'attachmentIntegrityStatus': type == 'decision'
      ? 'metadata_only_unverified'
      : null,
  'immutable': true,
};

Map<String, dynamic> _eventMap(int sequence, String type) => {
  'submissionId': 'submission-1',
  'sequence': sequence,
  'eventType': type,
  'previousStatus': 'package_generated',
  'nextStatus': sequence == 3 ? 'submitted_externally' : 'concluded',
  'summary': 'Resmî iletim olayı kaydedildi.',
  'reason': 'İnsan tarafından doğrulanan işlem.',
  'actorLabel': 'Yetkili kullanıcı',
  'recordedAt': '2026-07-25T16:30:00.000Z',
};

void main() {
  test('artifact scope and package fields parse backward compatibly', () {
    Map<String, dynamic> detailMap(Object? scope, Object? status) => {
      'contractVersion': 'customs-authority-submission-detail-v1',
      'submission': _submissionMap(),
      'packages': [
        {
          'packageId': 'package-1',
          'submissionId': 'submission-1',
          'version': 1,
          'packageType': 'fsmh_application_package',
          'sourceSnapshot': <String, dynamic>{},
          'documentManifest': <Object>[],
          'evidenceManifest': <Object>[],
          'redactionManifest': <Object>[],
          'coverLetterText': 'Üst yazı',
          'authoritySummary': 'Özet',
          'legalNeutralityStatement': 'Nötr',
          'aggregateHashAlgorithm': 'SHA-256',
          'aggregateHash': _hash('b'),
          'generatedAt': '2026-07-25T16:10:00.000Z',
          'generatedByUid': 'user-1',
          'immutable': true,
          'artifactStatus': ?status,
          'pdfArtifact': {
            'ready': true,
            'contentType': 'application/pdf',
            'sizeBytes': 1200,
            'sha256': _hash('c'),
            'safeFileName': 'paket.pdf',
            'bucket': 'ignored',
            'objectName': 'ignored',
            'generation': 'ignored',
          },
        },
      ],
      'responses': <Object>[],
      'events': <Object>[],
      'integrityStatus': 'verified',
      'scope': scope,
      'readOnly': true,
      'writesPerformed': 0,
    };

    final valid = CustomsAuthoritySubmissionDetail.fromMap(
      detailMap({
        'contractVersion': 'customs-authority-submission-artifact-scope-v1',
        'tenantId': 'tenant-1',
        'canonicalBrandId': 'brand-1',
      }, 'ready'),
    );
    expect(valid.artifactScope?.tenantId, 'tenant-1');
    expect(
      valid.packages.single.artifactStatus,
      CustomsSubmissionArtifactStatus.ready,
    );
    expect(valid.packages.single.pdfArtifact?.safeFileName, 'paket.pdf');

    final legacy = CustomsAuthoritySubmissionDetail.fromMap(
      detailMap(null, null),
    );
    expect(legacy.artifactScope, isNull);
    expect(
      legacy.packages.single.artifactStatus,
      CustomsSubmissionArtifactStatus.legacyNotMaterialized,
    );
    final invalid = CustomsAuthoritySubmissionDetail.fromMap(
      detailMap({
        'contractVersion': 'wrong',
        'tenantId': '',
        'canonicalBrandId': 'brand-1',
      }, 'future_status'),
    );
    expect(invalid.artifactScope, isNull);
    expect(
      invalid.packages.single.artifactStatus,
      CustomsSubmissionArtifactStatus.unknown,
    );
  });

  test('artifact callable contracts preserve caller request ids', () async {
    final calls = <MapEntry<String, Map<String, dynamic>>>[];
    final repository = CallableCustomsAuthoritySubmissionRepository(
      ensureAppCheckReady: () async {},
      callable: (name, request) async {
        calls.add(MapEntry(name, request));
        if (name == 'materializeCustomsSubmissionPackageArtifact') {
          return {
            'contractVersion':
                'customs-submission-package-artifact-materialize-result-v1',
            'ok': true,
            'duplicate': true,
            'transactionApplied': false,
            'recovered': true,
            'artifactStatus': 'ready',
            'submissionId': 'submission-1',
            'packageId': 'package-1',
            'packageVersion': 1,
            'sourcePackageHash': _hash('b'),
          };
        }
        return {
          'contractVersion':
              'customs-submission-package-download-authorize-result-v1',
          'ok': true,
          'artifactType': request['artifactType'],
          'downloadUrl': 'https://storage.example.invalid/token',
          'expiresAt': '2026-07-25T16:15:00.000Z',
          'safeFileName': 'paket',
          'contentType': 'application/octet-stream',
          'sizeBytes': 1200,
          'sha256': _hash('c'),
          'generation': '1',
          'sourcePackageHash': _hash('b'),
        };
      },
    );

    final result = await repository.materializePackageArtifact(
      tenantId: 'tenant-1',
      canonicalBrandId: 'brand-1',
      submissionId: 'submission-1',
      packageId: 'package-1',
      requestId: 'stable-materialize',
    );
    expect(result.duplicate, isTrue);
    for (final type in CustomsArtifactType.values) {
      await repository.authorizePackageDownload(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        packageId: 'package-1',
        artifactType: type,
        requestId: 'stable-${type.wireValue}',
      );
    }
    expect(calls[0].value['requestId'], 'stable-materialize');
    expect(calls[1].value['artifactType'], 'pdf');
    expect(calls[2].value['artifactType'], 'json_manifest');
    expect(
      calls[0].value['contractVersion'],
      'customs-submission-package-artifact-materialize-request-v1',
    );
  });

  test(
    'review and approval writes preserve explicit scope and request ids',
    () async {
      final calls = <MapEntry<String, Map<String, dynamic>>>[];
      final repository = CallableCustomsAuthoritySubmissionRepository(
        ensureAppCheckReady: () async {},
        requestIdFactory: () => 'generated-request-id',
        callable: (name, request) async {
          calls.add(MapEntry(name, request));
          return <String, dynamic>{
            'contractVersion': name == 'updateCustomsAuthoritySubmission'
                ? 'customs-authority-submission-update-result-v1'
                : 'customs-authority-submission-transition-result-v1',
            'ok': true,
            'duplicate': false,
            'transactionCommitted': true,
            'submission': <String, dynamic>{
              ..._submissionMap(),
              'status': request['nextStatus'] ?? 'awaiting_human_review',
              'humanReviewReference': request['humanReviewReference'],
              'dataMinimizationConfirmed':
                  request['dataMinimizationConfirmed'] ?? false,
              'nonAccusatoryLanguageConfirmed':
                  request['nonAccusatoryLanguageConfirmed'] ?? false,
            },
          };
        },
      );

      await repository.updateSubmission(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        requestId: 'stable-update-id',
        draft: const CustomsAuthoritySubmissionUpdateDraft(
          title: 'Bosch FSMH koruma başvurusu',
          authoritySummary:
              'Aktif gümrük koruma profili temelinde resmî başvuru taslağıdır.',
          humanReviewReference: 'review-reference-1',
          dataMinimizationConfirmed: false,
          nonAccusatoryLanguageConfirmed: false,
        ),
      );
      await repository.transitionSubmission(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        nextStatus: 'awaiting_rights_holder_approval',
        reason: 'İnsan incelemesi tamamlandı ve onay aşamasına geçildi.',
        requestId: 'stable-transition-id',
      );

      expect(calls, hasLength(2));
      expect(calls[0].key, 'updateCustomsAuthoritySubmission');
      expect(calls[0].value['tenantId'], 'tenant-1');
      expect(calls[0].value['canonicalBrandId'], 'brand-1');
      expect(calls[0].value['requestId'], 'stable-update-id');
      expect(calls[0].value['humanReviewReference'], 'review-reference-1');
      expect(calls[1].key, 'transitionCustomsAuthoritySubmission');
      expect(calls[1].value['tenantId'], 'tenant-1');
      expect(calls[1].value['canonicalBrandId'], 'brand-1');
      expect(calls[1].value['requestId'], 'stable-transition-id');
      expect(calls[1].value['nextStatus'], 'awaiting_rights_holder_approval');
    },
  );

  test('download authorization rejects unsafe or mismatched responses', () {
    Map<String, dynamic> response(String url) => {
      'contractVersion':
          'customs-submission-package-download-authorize-result-v1',
      'ok': true,
      'artifactType': 'pdf',
      'downloadUrl': url,
      'expiresAt': '2026-07-25T16:15:00.000Z',
      'safeFileName': 'paket.pdf',
      'contentType': 'application/pdf',
      'sizeBytes': 1200,
      'sha256': _hash('c'),
      'generation': '1',
      'sourcePackageHash': _hash('b'),
    };
    expect(
      () => CustomsPackageDownloadAuthorization.fromMap(
        response('http://unsafe.invalid/file'),
      ),
      throwsFormatException,
    );
    expect(
      () => CustomsPackageDownloadAuthorization.fromMap({
        ...response('https://safe.invalid/file'),
        'contractVersion': 'wrong',
      }),
      throwsFormatException,
    );
  });

  test('list accepts only the read-only authority submission contract', () {
    final result = CustomsAuthoritySubmissionList.fromMap({
      'contractVersion': 'customs-authority-submission-list-v1',
      'items': [_submissionMap()],
      'nextPageToken': null,
      'readOnly': true,
      'writesPerformed': 0,
    });

    expect(result.items, hasLength(1));
    expect(result.items.single.submissionNumber, 'KRI-2026-ABCDEF12');
    expect(result.items.single.targetAuthority, 'fsmh_program');
    expect(result.items.single.packageCount, 0);
  });

  test('read contract rejects a response that claims a write', () {
    expect(
      () => CustomsAuthoritySubmissionList.fromMap({
        'contractVersion': 'customs-authority-submission-list-v1',
        'items': const [],
        'nextPageToken': null,
        'readOnly': true,
        'writesPerformed': 1,
      }),
      throwsFormatException,
    );
  });

  test(
    'read model preserves external delivery and authority outcome metadata',
    () {
      final submission = CustomsAuthoritySubmission.fromMap({
        ..._submissionMap(),
        'status': 'concluded',
        'externalReferenceType': 'portal_transaction_id',
        'externalReferenceValue': 'PORTAL-2026-0001',
        'outcomeResponseId': 'response-outcome-1',
        'outcomeCode': 'action_taken',
        'outcomeFinalityLevel': 'administrative_final',
        'authorityReferenceNumber': 'FSMH-2026-SONUC-1',
        'officialDocumentDate': '2026-07-25T16:00:00.000Z',
        'outcomeReceivedAt': '2026-07-25T16:30:00.000Z',
        'outcomeRecordedAt': '2026-07-25T16:35:00.000Z',
        'authorityNameSnapshot': 'Ticaret Bakanlığı',
        'authorityUnitSnapshot': 'FSMH Başvuru Birimi',
        'outcomeSummary': 'Kurum tarafından bildirilen nihai sonuç.',
      });
      final response = CustomsAuthorityResponse.fromMap(
        _responseMap(type: 'decision'),
      );

      expect(submission.externalReferenceType, 'portal_transaction_id');
      expect(submission.externalReferenceValue, 'PORTAL-2026-0001');
      expect(submission.outcomeResponseId, 'response-outcome-1');
      expect(submission.outcomeCode, 'action_taken');
      expect(submission.outcomeFinalityLevel, 'administrative_final');
      expect(submission.authorityReferenceNumber, 'FSMH-2026-SONUC-1');
      expect(submission.officialDocumentDate, '2026-07-25T16:00:00.000Z');
      expect(submission.outcomeReceivedAt, '2026-07-25T16:30:00.000Z');
      expect(submission.outcomeRecordedAt, '2026-07-25T16:35:00.000Z');
      expect(submission.authorityNameSnapshot, 'Ticaret Bakanlığı');
      expect(submission.authorityUnitSnapshot, 'FSMH Başvuru Birimi');
      expect(
        submission.outcomeSummary,
        'Kurum tarafından bildirilen nihai sonuç.',
      );
      expect(response.outcomeFinalityLevel, 'administrative_final');
      expect(response.officialDocumentDate, '2026-07-25T16:00:00.000Z');
      expect(response.authorityNameSnapshot, 'Ticaret Bakanlığı');
      expect(response.authorityUnitSnapshot, 'FSMH Başvuru Birimi');
      expect(response.previousResponseId, 'response-previous');
      expect(
        response.additionalNotes,
        'Kullanıcı tarafından eklenen açıklama.',
      );
      expect(response.attachmentIntegrityStatus, 'metadata_only_unverified');
    },
  );

  test('detail parses package response and verified event chain', () {
    final detail = CustomsAuthoritySubmissionDetail.fromMap({
      'contractVersion': 'customs-authority-submission-detail-v1',
      'submission': {
        ..._submissionMap(),
        'status': 'package_generated',
        'currentPackageId': 'package-1',
        'currentPackageVersion': 1,
        'currentPackageHash': _hash('b'),
        'packageCount': 1,
        'responseCount': 1,
        'eventCount': 3,
      },
      'packages': [
        {
          'packageId': 'package-1',
          'submissionId': 'submission-1',
          'version': 1,
          'packageType': 'fsmh_application_package',
          'sourceSnapshot': {
            'profile': {'profileId': 'profile-1'},
          },
          'documentManifest': [
            {
              'referenceId': 'doc-1',
              'title': 'Marka tescil belgesi',
              'sha256': _hash('c'),
              'mimeType': 'application/pdf',
              'sizeBytes': 1200,
            },
          ],
          'evidenceManifest': const [],
          'redactionManifest': [
            {
              'fieldPath': 'profile.emergencyContactIds',
              'action': 'mask',
              'reason': 'Kişisel veri minimizasyonu',
            },
          ],
          'coverLetterText':
              'Başvuru paketi için hazırlanmış resmî üst yazı metnidir.',
          'authoritySummary':
              'Hak, ürün ve doğrulama bilgilerini içeren başvuru özetidir.',
          'legalNeutralityStatement':
              'Bu paket kesin suç isnadı içermez ve insan incelemesine dayanır.',
          'aggregateHashAlgorithm': 'SHA-256',
          'aggregateHash': _hash('b'),
          'generatedAt': '2026-07-25T16:10:00.000Z',
          'generatedByUid': 'user-1',
          'immutable': true,
        },
      ],
      'responses': [
        {
          'responseId': 'response-1',
          'submissionId': 'submission-1',
          'responseType': 'acknowledgement',
          'authorityReference': 'FSMH-2026-0001',
          'receivedAt': '2026-07-25T16:20:00.000Z',
          'receivedByUid': 'user-1',
          'summary': 'Başvurunun teslim alındığı doğrulandı.',
          'attachmentReferences': const [],
          'attachmentHashes': const [],
          'requestedDueAt': null,
          'outcomeCode': 'accepted_for_review',
          'immutable': true,
        },
      ],
      'events': [
        {
          'submissionId': 'submission-1',
          'sequence': 1,
          'eventType': 'authority_submission_created',
          'previousStatus': null,
          'nextStatus': 'draft',
          'summary': 'Resmî iletim taslağı oluşturuldu.',
          'reason': 'Kullanıcı tarafından başlatıldı.',
          'actorLabel': 'Yetkili kullanıcı',
          'recordedAt': '2026-07-25T16:00:00.000Z',
        },
      ],
      'integrityStatus': 'verified',
      'readOnly': true,
      'writesPerformed': 0,
    });

    expect(detail.integrityStatus, 'verified');
    expect(detail.packages.single.immutable, isTrue);
    expect(detail.packages.single.documentManifest.single.sizeBytes, 1200);
    expect(detail.responses.single.outcomeCode, 'accepted_for_review');
    expect(detail.events.single.sequence, 1);
  });

  test('draft maps preserve server field names and omit empty optionals', () {
    const draft = CustomsAuthoritySubmissionDraft(
      submissionType: 'fsmh_protection_application',
      targetAuthority: 'fsmh_program',
      channelType: 'fsmh_portal',
      protectionProfileId: 'profile-1',
      incidentReference: ' GKP-2026-001 ',
      title: ' FSMH koruma başvurusu ',
      authoritySummary:
          ' Aktif koruma profiline dayanan resmî başvuru özeti hazırlanmıştır. ',
    );

    final map = draft.toRequestMap();

    expect(map['submissionType'], 'fsmh_protection_application');
    expect(map['targetAuthority'], 'fsmh_program');
    expect(map['protectionProfileId'], 'profile-1');
    expect(map['incidentReference'], 'GKP-2026-001');
    expect(map['title'], 'FSMH koruma başvurusu');
    expect(map['dataMinimizationConfirmed'], isFalse);
    expect(map['nonAccusatoryLanguageConfirmed'], isFalse);
    expect(map.containsKey('interventionId'), isFalse);
    expect(map.containsKey('targetUnit'), isFalse);
  });

  test('draft requires a profile or intervention source', () {
    const draft = CustomsAuthoritySubmissionDraft(
      submissionType: 'other_official_submission',
      targetAuthority: 'other_authorized_body',
      incidentReference: 'OLAY-2026-001',
      title: 'Diğer resmî iletim',
      authoritySummary:
          'Yetkili kurum için hazırlanan resmî iletim özeti ve dayanakları.',
    );

    expect(draft.toRequestMap, throwsArgumentError);
  });

  test(
    'labels keep package and receipt operations out of generic transitions',
    () {
      expect(
        customsAuthoritySubmissionTransitions['approved_for_package'],
        isNot(contains('package_generated')),
      );
      expect(
        customsAuthoritySubmissionTransitions['submitted_externally'],
        isNot(contains('receipt_recorded')),
      );
      expect(
        customsAuthoritySubmissionStatusLabel('awaiting_human_review'),
        'İnsan incelemesi bekleniyor',
      );
      expect(
        customsAuthorityTargetLabel('police_anti_smuggling'),
        'Emniyet KOM',
      );
    },
  );

  test('request id generator returns UUID v4 compatible identifiers', () {
    final value = generateCustomsAuthoritySubmissionRequestId();
    expect(
      value,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
  test(
    'five protected operations preserve exact contracts and request ids',
    () async {
      final calls = <MapEntry<String, Map<String, dynamic>>>[];
      var appCheckCalls = 0;
      final repository = CallableCustomsAuthoritySubmissionRepository(
        ensureAppCheckReady: () async {
          appCheckCalls++;
        },
        callable: (name, request) async {
          calls.add(MapEntry(name, request));
          return switch (name) {
            'generateCustomsSubmissionPackage' => {
              'contractVersion':
                  'customs-submission-package-generate-result-v1',
              'ok': true,
              'duplicate': false,
              'transactionCommitted': true,
              'submission': {
                ..._submissionMap(),
                'status': 'package_generated',
                'currentPackageId': 'package-1',
                'currentPackageVersion': 1,
                'currentPackageHash': _hash('c'),
                'packageCount': 1,
              },
              'package': _packageMap(),
            },
            'recordCustomsExternalSubmission' => {
              'contractVersion': 'customs-external-submission-record-result-v1',
              'ok': true,
              'duplicate': false,
              'transactionApplied': true,
              'submission': {
                ..._submissionMap(),
                'status': 'submitted_externally',
              },
              'event': _eventMap(
                3,
                'customs_submission_recorded_as_submitted_externally',
              ),
            },
            'recordCustomsSubmissionReceipt' => {
              'contractVersion': 'customs-submission-receipt-record-result-v1',
              'ok': true,
              'duplicate': true,
              'transactionCommitted': false,
              'submission': {..._submissionMap(), 'status': 'receipt_recorded'},
              'response': _responseMap(type: 'receipt'),
            },
            'appendCustomsAuthorityResponse' => {
              'contractVersion': 'customs-authority-response-append-result-v1',
              'ok': true,
              'duplicate': false,
              'transactionCommitted': true,
              'submission': _submissionMap(),
              'response': _responseMap(),
            },
            'recordCustomsAuthorityOutcome' => {
              'contractVersion': 'customs-authority-outcome-record-result-v1',
              'ok': true,
              'duplicate': false,
              'transactionApplied': true,
              'submission': {..._submissionMap(), 'status': 'concluded'},
              'response': _responseMap(type: 'decision'),
              'events': [
                _eventMap(4, 'customs_authority_outcome_recorded'),
                _eventMap(5, 'customs_authority_submission_concluded'),
              ],
            },
            _ => throw StateError('Beklenmeyen callable: $name'),
          };
        },
      );

      const manifest = CustomsSubmissionManifestItem(
        referenceId: 'doc-1',
        title: 'Marka tescil belgesi',
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        mimeType: 'application/pdf',
        sizeBytes: 1200,
      );
      const packageDraft = CustomsSubmissionPackageDraft(
        packageType: CustomsSubmissionPackageType.fsmhApplicationPackage,
        coverLetterText: 'Kurum için hazırlanan resmî üst yazı metnidir.',
        authoritySummary: 'Kurum için hazırlanan resmî başvuru özetidir.',
        legalNeutralityStatement:
            'Bu paket kesin suç isnadı içermez ve insan incelemesine dayanır.',
        documentManifest: [manifest],
      );
      final packageResult = await repository.generatePackage(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        draft: packageDraft,
        requestId: 'request-package',
      );
      final externalResult = await repository.recordExternalSubmission(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        packageId: 'package-1',
        packageVersion: 1,
        packageHash: _hash('c'),
        draft: const CustomsExternalSubmissionDraft(
          submissionChannel: CustomsSubmissionChannel.fsmhPortal,
          submittedAt: '2026-07-25T16:15:00.000Z',
          externalSubmissionStatement:
              'Paket kurum portalına insan tarafından teslim edildi.',
          externalReferenceType: CustomsExternalReferenceType.none,
          externalSubmissionConfirmed: true,
        ),
        requestId: 'request-external',
      );
      final receiptResult = await repository.recordReceipt(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        draft: const CustomsSubmissionReceiptDraft(
          officialReferenceNumber: 'FSMH-2026-0001',
          receivedAt: '2026-07-25T16:20:00.000Z',
          channelType: CustomsSubmissionChannel.fsmhPortal,
          summary: 'Başvurunun kurum tarafından alındığı teyit edildi.',
        ),
        requestId: 'request-receipt',
      );
      final responseResult = await repository.appendAuthorityResponse(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        draft: const CustomsAuthorityResponseDraft(
          responseType: CustomsInterimAuthorityResponseType.acknowledgement,
          receivedAt: '2026-07-25T16:25:00.000Z',
          summary: 'Kurum incelemenin başladığını bildirdi.',
        ),
        requestId: 'request-response',
      );
      final outcomeResult = await repository.recordAuthorityOutcome(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        draft: const CustomsAuthorityOutcomeDraft(
          responseType: CustomsFinalAuthorityResponseType.decision,
          outcomeCode: CustomsAuthorityOutcomeCode.actionTaken,
          outcomeFinalityLevel:
              CustomsAuthorityOutcomeFinalityLevel.administrativeFinal,
          authorityReferenceNumber: 'FSMH-2026-SONUC-1',
          officialDocumentDate: '2026-07-25T16:00:00.000Z',
          receivedAt: '2026-07-25T16:30:00.000Z',
          authorityNameSnapshot: 'Ticaret Bakanlığı',
          summary: 'Kurum tarafından bildirilen nihai sonuç kaydedildi.',
          humanEntryConfirmed: true,
        ),
        requestId: 'request-outcome',
      );

      expect(appCheckCalls, 5);
      expect(calls.map((call) => call.key), [
        'generateCustomsSubmissionPackage',
        'recordCustomsExternalSubmission',
        'recordCustomsSubmissionReceipt',
        'appendCustomsAuthorityResponse',
        'recordCustomsAuthorityOutcome',
      ]);
      expect(calls.map((call) => call.value['requestId']), [
        'request-package',
        'request-external',
        'request-receipt',
        'request-response',
        'request-outcome',
      ]);
      expect(calls.map((call) => call.value['contractVersion']), [
        'customs-submission-package-generate-request-v1',
        'customs-external-submission-record-request-v1',
        'customs-submission-receipt-record-request-v1',
        'customs-authority-response-append-request-v1',
        'customs-authority-outcome-record-request-v1',
      ]);
      expect(
        calls[1].value['externalSubmissionConfirmationVersion'],
        CustomsExternalSubmissionDraft.confirmationVersion,
      );
      expect(calls[1].value.containsKey('externalReferenceValue'), isFalse);
      expect(
        calls[4].value['humanEntryConfirmationVersion'],
        CustomsAuthorityOutcomeDraft.humanEntryConfirmationVersion,
      );
      expect(calls[4].value.containsKey('authorityUnitSnapshot'), isFalse);
      expect(packageResult.transactionCommitted, isTrue);
      expect(externalResult.transactionApplied, isTrue);
      expect(receiptResult.duplicate, isTrue);
      expect(responseResult.response.responseType, 'acknowledgement');
      expect(outcomeResult.events, hasLength(2));
    },
  );

  test(
    'new drafts enforce confirmations, manifests and paired attachments',
    () {
      const noManifest = CustomsSubmissionPackageDraft(
        packageType: CustomsSubmissionPackageType.authorityReferralPackage,
        coverLetterText: 'Kurum için hazırlanan resmî üst yazı metnidir.',
        authoritySummary: 'Kurum için hazırlanan resmî başvuru özetidir.',
        legalNeutralityStatement:
            'Bu paket kesin suç isnadı içermez ve insan incelemesine dayanır.',
      );
      expect(noManifest.toRequestMap, throwsArgumentError);

      const unconfirmed = CustomsExternalSubmissionDraft(
        submissionChannel: CustomsSubmissionChannel.registeredEmail,
        submittedAt: '2026-07-25T16:15:00.000Z',
        externalSubmissionStatement:
            'Paket kayıtlı elektronik posta ile kuruma teslim edildi.',
        externalReferenceType: CustomsExternalReferenceType.kepMessageId,
        externalReferenceValue: 'KEP-1',
      );
      expect(unconfirmed.toRequestMap, throwsArgumentError);

      const mismatchedResponse = CustomsAuthorityResponseDraft(
        responseType: CustomsInterimAuthorityResponseType.statusUpdate,
        receivedAt: '2026-07-25T16:25:00.000Z',
        summary: 'Kurum dosyanın incelemede olduğunu bildirdi.',
        attachmentReferences: ['doc-1'],
      );
      expect(mismatchedResponse.toRequestMap, throwsArgumentError);

      const unconfirmedOutcome = CustomsAuthorityOutcomeDraft(
        responseType: CustomsFinalAuthorityResponseType.closureNotice,
        outcomeCode: CustomsAuthorityOutcomeCode.closed,
        outcomeFinalityLevel: CustomsAuthorityOutcomeFinalityLevel.notStated,
        authorityReferenceNumber: 'FSMH-2026-SONUC-2',
        officialDocumentDate: '2026-07-25T16:00:00.000Z',
        receivedAt: '2026-07-25T16:30:00.000Z',
        authorityNameSnapshot: 'Ticaret Bakanlığı',
        summary: 'Kurum dosyanın kapatıldığını bildirdi.',
      );
      expect(unconfirmedOutcome.toRequestMap, throwsArgumentError);
    },
  );

  test('empty repository rejects all five new write operations', () async {
    const repository = EmptyCustomsAuthoritySubmissionRepository();
    const packageDraft = CustomsSubmissionPackageDraft(
      packageType: CustomsSubmissionPackageType.fsmhApplicationPackage,
      coverLetterText: 'Kurum için hazırlanan resmî üst yazı metnidir.',
      authoritySummary: 'Kurum için hazırlanan resmî başvuru özetidir.',
      legalNeutralityStatement:
          'Bu paket kesin suç isnadı içermez ve insan incelemesine dayanır.',
      documentManifest: [
        CustomsSubmissionManifestItem(
          referenceId: 'doc-1',
          title: 'Marka tescil belgesi',
          sha256:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
      ],
    );
    const externalDraft = CustomsExternalSubmissionDraft(
      submissionChannel: CustomsSubmissionChannel.fsmhPortal,
      submittedAt: '2026-07-25T16:15:00.000Z',
      externalSubmissionStatement:
          'Paket kurum portalına insan tarafından teslim edildi.',
      externalReferenceType: CustomsExternalReferenceType.none,
      externalSubmissionConfirmed: true,
    );
    const receiptDraft = CustomsSubmissionReceiptDraft(
      officialReferenceNumber: 'FSMH-2026-0001',
      receivedAt: '2026-07-25T16:20:00.000Z',
      channelType: CustomsSubmissionChannel.fsmhPortal,
      summary: 'Başvurunun kurum tarafından alındığı teyit edildi.',
    );
    const responseDraft = CustomsAuthorityResponseDraft(
      responseType: CustomsInterimAuthorityResponseType.acknowledgement,
      receivedAt: '2026-07-25T16:25:00.000Z',
      summary: 'Kurum incelemenin başladığını bildirdi.',
    );
    const outcomeDraft = CustomsAuthorityOutcomeDraft(
      responseType: CustomsFinalAuthorityResponseType.decision,
      outcomeCode: CustomsAuthorityOutcomeCode.actionTaken,
      outcomeFinalityLevel:
          CustomsAuthorityOutcomeFinalityLevel.administrativeFinal,
      authorityReferenceNumber: 'FSMH-2026-SONUC-1',
      officialDocumentDate: '2026-07-25T16:00:00.000Z',
      receivedAt: '2026-07-25T16:30:00.000Z',
      authorityNameSnapshot: 'Ticaret Bakanlığı',
      summary: 'Kurum tarafından bildirilen nihai sonuç kaydedildi.',
      humanEntryConfirmed: true,
    );

    await expectLater(
      repository.generatePackage(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        draft: packageDraft,
        requestId: 'request-package',
      ),
      throwsUnsupportedError,
    );
    await expectLater(
      repository.recordExternalSubmission(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        packageId: 'package-1',
        packageVersion: 1,
        packageHash: _hash('c'),
        draft: externalDraft,
        requestId: 'request-external',
      ),
      throwsUnsupportedError,
    );
    await expectLater(
      repository.recordReceipt(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        draft: receiptDraft,
        requestId: 'request-receipt',
      ),
      throwsUnsupportedError,
    );
    await expectLater(
      repository.appendAuthorityResponse(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        draft: responseDraft,
        requestId: 'request-response',
      ),
      throwsUnsupportedError,
    );
    await expectLater(
      repository.recordAuthorityOutcome(
        tenantId: 'tenant-1',
        canonicalBrandId: 'brand-1',
        submissionId: 'submission-1',
        draft: outcomeDraft,
        requestId: 'request-outcome',
      ),
      throwsUnsupportedError,
    );
  });

  test('new mutation results reject wrong contracts and event counts', () {
    expect(
      () => CustomsPackageGenerationResult.fromMap({
        'contractVersion': 'wrong',
        'ok': true,
        'duplicate': false,
        'transactionCommitted': true,
      }),
      throwsFormatException,
    );
    expect(
      () => CustomsAuthorityOutcomeResult.fromMap({
        'contractVersion': 'customs-authority-outcome-record-result-v1',
        'ok': true,
        'duplicate': false,
        'transactionApplied': true,
        'submission': _submissionMap(),
        'response': _responseMap(type: 'decision'),
        'events': [_eventMap(4, 'customs_authority_outcome_recorded')],
      }),
      throwsFormatException,
    );
  });
}
