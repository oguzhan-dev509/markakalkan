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
  'officialReferenceNumber': null,
  'receiptRecordedAt': null,
  'packageCount': 0,
  'responseCount': 0,
  'eventCount': 1,
  'lastEventType': 'authority_submission_created',
  'lastEventAt': '2026-07-25T16:00:00.000Z',
  'createdAt': '2026-07-25T16:00:00.000Z',
  'updatedAt': '2026-07-25T16:00:00.000Z',
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
}
