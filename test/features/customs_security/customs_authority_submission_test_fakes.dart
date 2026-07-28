import 'dart:async';

import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';

Map<String, dynamic> _submissionMap({
  String submissionId = 'submission-1',
  String status = 'draft',
  String submissionType = 'fsmh_protection_application',
  String targetAuthority = 'fsmh_program',
  String? protectionProfileId = 'profile-1',
  String? interventionId,
  String title = 'Bosch FSMH koruma başvurusu',
}) => <String, dynamic>{
  'submissionId': submissionId,
  'submissionNumber': 'KRI-2026-ABC12345',
  'submissionType': submissionType,
  'targetAuthority': targetAuthority,
  'targetUnit': null,
  'channelType': submissionType == 'fsmh_protection_application'
      ? 'fsmh_portal'
      : 'official_online_form',
  'protectionProfileId': protectionProfileId,
  'interventionId': interventionId,
  'caseId': null,
  'legalMatterId': null,
  'incidentReference': interventionId == null
      ? 'GKP-2026-ABC12345'
      : 'SGM-2026-ABC12345',
  'title': title,
  'authoritySummary':
      'İnsan incelemesine sunulan, şüphe ile kesinleşmiş sonucu ayrı tutan hukuken nötr resmî iletim taslağıdır.',
  'status': status,
  'humanReviewReference': null,
  'rightsHolderApprovalReference': null,
  'dataMinimizationConfirmed': false,
  'nonAccusatoryLanguageConfirmed': false,
  'duplicateCheckKey': 'duplicate-key-1',
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
  'lastEventAt': '2026-07-25T10:00:00.000Z',
  'createdAt': '2026-07-25T10:00:00.000Z',
  'updatedAt': '2026-07-25T10:00:00.000Z',
};

CustomsAuthoritySubmission sampleAuthoritySubmission({
  String submissionId = 'submission-1',
  String status = 'draft',
  String submissionType = 'fsmh_protection_application',
  String targetAuthority = 'fsmh_program',
  String? protectionProfileId = 'profile-1',
  String? interventionId,
  String title = 'Bosch FSMH koruma başvurusu',
}) => CustomsAuthoritySubmission.fromMap(
  _submissionMap(
    submissionId: submissionId,
    status: status,
    submissionType: submissionType,
    targetAuthority: targetAuthority,
    protectionProfileId: protectionProfileId,
    interventionId: interventionId,
    title: title,
  ),
);

CustomsAuthoritySubmissionDetail sampleAuthoritySubmissionDetail({
  String submissionId = 'submission-1',
  bool includePackage = false,
  bool includeScope = false,
  String artifactStatus = 'legacy_not_materialized',
  bool pdfReady = false,
  bool manifestReady = false,
}) => CustomsAuthoritySubmissionDetail.fromMap(<String, dynamic>{
  'contractVersion': 'customs-authority-submission-detail-v1',
  'submission': _submissionMap(submissionId: submissionId),
  'packages': includePackage
      ? <Map<String, dynamic>>[
          <String, dynamic>{
            'packageId': 'package-1',
            'submissionId': submissionId,
            'version': 1,
            'packageType': 'fsmh_application_package',
            'sourceSnapshot': const <String, dynamic>{},
            'documentManifest': const <Object>[],
            'evidenceManifest': const <Object>[],
            'redactionManifest': const <Object>[],
            'coverLetterText': 'Resmî üst yazı',
            'authoritySummary': 'Resmî paket özeti',
            'legalNeutralityStatement': 'Hukuken nötr ifade',
            'aggregateHashAlgorithm': 'SHA-256',
            'aggregateHash': List<String>.filled(64, 'a').join(),
            'generatedAt': '2026-07-25T10:00:00.000Z',
            'generatedByUid': 'user-1',
            'immutable': true,
            'artifactStatus': artifactStatus,
            'artifactFormatVersion': 'customs-submission-package-artifact-v1',
            'sourcePackageHash': List<String>.filled(64, 'b').join(),
            if (pdfReady)
              'pdfArtifact': <String, dynamic>{
                'ready': true,
                'contentType': 'application/pdf',
                'sizeBytes': 2048,
                'sha256': List<String>.filled(64, 'c').join(),
                'safeFileName': 'resmi-paket.pdf',
              },
            if (manifestReady)
              'jsonManifestArtifact': <String, dynamic>{
                'ready': true,
                'contentType': 'application/json',
                'sizeBytes': 1024,
                'sha256': List<String>.filled(64, 'd').join(),
                'safeFileName': 'resmi-paket.json',
              },
          },
        ]
      : const <Map<String, dynamic>>[],
  'responses': const <Map<String, dynamic>>[],
  'events': <Map<String, dynamic>>[
    <String, dynamic>{
      'submissionId': submissionId,
      'sequence': 1,
      'eventType': 'authority_submission_created',
      'previousStatus': null,
      'nextStatus': 'draft',
      'summary': 'Resmî iletim taslağı oluşturuldu.',
      'reason': 'Kaynak kayıt üzerinden insan incelemesi için hazırlandı.',
      'actorLabel': 'Yetkili kullanıcı',
      'recordedAt': '2026-07-25T10:00:00.000Z',
    },
  ],
  'integrityStatus': 'verified',
  'readOnly': true,
  'writesPerformed': 0,
  'scope': includeScope
      ? const <String, dynamic>{
          'contractVersion': 'customs-authority-submission-artifact-scope-v1',
          'tenantId': 'tenant-1',
          'canonicalBrandId': 'brand-1',
        }
      : null,
});

class FakeCustomsAuthoritySubmissionRepository
    implements CustomsAuthoritySubmissionRepository {
  List<CustomsAuthoritySubmission> submissions = [sampleAuthoritySubmission()];

  int createCalls = 0;
  int detailCalls = 0;
  int materializeCalls = 0;
  int pdfAuthorizationCalls = 0;
  int manifestAuthorizationCalls = 0;
  CustomsAuthoritySubmissionDraft? lastDraft;
  CustomsAuthoritySubmissionDetail? detail;
  Object? materializationError;
  Object? authorizationError;
  Completer<void>? materializationGate;
  Completer<void>? pdfAuthorizationGate;
  Completer<void>? manifestAuthorizationGate;
  final List<String> materializationRequestIds = [];
  final List<String> authorizationRequestIds = [];

  @override
  Future<CustomsAuthoritySubmissionList> listSubmissions({
    String? status,
    String? targetAuthority,
    String? pageToken,
    int pageSize = 25,
  }) async {
    final filtered = submissions.where((submission) {
      if (status != null && submission.status != status) return false;
      if (targetAuthority != null &&
          submission.targetAuthority != targetAuthority) {
        return false;
      }
      return true;
    }).toList();
    return CustomsAuthoritySubmissionList(items: filtered, nextPageToken: null);
  }

  @override
  Future<CustomsAuthoritySubmission> createSubmission(
    CustomsAuthoritySubmissionDraft draft,
  ) async {
    createCalls++;
    lastDraft = draft;
    final created = sampleAuthoritySubmission(
      submissionId: 'submission-created',
      submissionType: draft.submissionType,
      targetAuthority: draft.targetAuthority,
      protectionProfileId: draft.protectionProfileId,
      interventionId: draft.interventionId,
      title: draft.title,
    );
    submissions = [...submissions, created];
    return created;
  }

  @override
  Future<CustomsAuthoritySubmissionDetail> getSubmissionDetail(
    String submissionId,
  ) async {
    detailCalls++;
    return detail ??
        sampleAuthoritySubmissionDetail(submissionId: submissionId);
  }

  @override
  Future<CustomsPackageGenerationResult> generatePackage({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsSubmissionPackageDraft draft,
    required String requestId,
  }) async => throw UnsupportedError(
    'FakeCustomsAuthoritySubmissionRepository.generatePackage is not configured.',
  );

  @override
  Future<CustomsExternalSubmissionResult> recordExternalSubmission({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required String packageId,
    required int packageVersion,
    required String packageHash,
    required CustomsExternalSubmissionDraft draft,
    required String requestId,
  }) async => throw UnsupportedError(
    'FakeCustomsAuthoritySubmissionRepository.recordExternalSubmission is not configured.',
  );

  @override
  Future<CustomsSubmissionReceiptResult> recordReceipt({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsSubmissionReceiptDraft draft,
    required String requestId,
  }) async => throw UnsupportedError(
    'FakeCustomsAuthoritySubmissionRepository.recordReceipt is not configured.',
  );

  @override
  Future<CustomsAuthorityResponseAppendResult> appendAuthorityResponse({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityResponseDraft draft,
    required String requestId,
  }) async => throw UnsupportedError(
    'FakeCustomsAuthoritySubmissionRepository.appendAuthorityResponse is not configured.',
  );

  @override
  Future<CustomsAuthorityOutcomeResult> recordAuthorityOutcome({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityOutcomeDraft draft,
    required String requestId,
  }) async => throw UnsupportedError(
    'FakeCustomsAuthoritySubmissionRepository.recordAuthorityOutcome is not configured.',
  );

  @override
  Future<CustomsPackageMaterializationResult> materializePackageArtifact({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required String packageId,
    required String requestId,
  }) async {
    materializeCalls++;
    materializationRequestIds.add(requestId);
    await materializationGate?.future;
    final error = materializationError;
    if (error != null) throw error;
    return CustomsPackageMaterializationResult.fromMap(<String, dynamic>{
      'contractVersion':
          'customs-submission-package-artifact-materialize-result-v1',
      'ok': true,
      'duplicate': false,
      'transactionApplied': true,
      'recovered': false,
      'artifactStatus': 'ready',
      'submissionId': submissionId,
      'packageId': packageId,
      'packageVersion': 1,
      'sourcePackageHash': List<String>.filled(64, 'b').join(),
    });
  }

  @override
  Future<CustomsPackageDownloadAuthorization> authorizePackageDownload({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required String packageId,
    required CustomsArtifactType artifactType,
    required String requestId,
  }) async {
    if (artifactType == CustomsArtifactType.pdf) {
      pdfAuthorizationCalls++;
      await pdfAuthorizationGate?.future;
    } else {
      manifestAuthorizationCalls++;
      await manifestAuthorizationGate?.future;
    }
    authorizationRequestIds.add(requestId);
    final error = authorizationError;
    if (error != null) throw error;
    return CustomsPackageDownloadAuthorization.fromMap(<String, dynamic>{
      'contractVersion':
          'customs-submission-package-download-authorize-result-v1',
      'ok': true,
      'artifactType': artifactType.wireValue,
      'downloadUrl': 'https://storage.example.invalid/short-lived',
      'expiresAt': '2026-07-25T10:05:00.000Z',
      'safeFileName': artifactType == CustomsArtifactType.pdf
          ? 'resmi-paket.pdf'
          : 'resmi-paket.json',
      'contentType': artifactType == CustomsArtifactType.pdf
          ? 'application/pdf'
          : 'application/json',
      'sizeBytes': 1024,
      'sha256': List<String>.filled(64, 'c').join(),
      'generation': '1',
      'sourcePackageHash': List<String>.filled(64, 'b').join(),
    });
  }

  @override
  Future<CustomsAuthoritySubmission> transitionSubmission({
    required String submissionId,
    required String nextStatus,
    required String reason,
    String? submittedAt,
    String? externalSubmissionStatement,
  }) async {
    final current = submissions.firstWhere(
      (item) => item.submissionId == submissionId,
    );
    final updated = CustomsAuthoritySubmission.fromMap(<String, dynamic>{
      ..._submissionMap(
        submissionId: current.submissionId,
        status: nextStatus,
        submissionType: current.submissionType,
        targetAuthority: current.targetAuthority,
        protectionProfileId: current.protectionProfileId,
        interventionId: current.interventionId,
        title: current.title,
      ),
    });
    submissions = [
      for (final item in submissions)
        if (item.submissionId == submissionId) updated else item,
    ];
    return updated;
  }

  @override
  Future<CustomsAuthoritySubmission> updateSubmission({
    required String submissionId,
    required CustomsAuthoritySubmissionUpdateDraft draft,
  }) async {
    return submissions.firstWhere((item) => item.submissionId == submissionId);
  }
}
