import 'dart:async';

import 'package:markakalkan/features/customs_security/data/customs_authority_submission_repository.dart';

Map<String, dynamic> _submissionMap({
  String submissionId = 'submission-1',
  String status = 'draft',
  String submissionType = 'fsmh_protection_application',
  String targetAuthority = 'fsmh_program',
  String? targetUnit,
  String? protectionProfileId = 'profile-1',
  String? interventionId,
  String title = 'Bosch FSMH koruma başvurusu',
  String? humanReviewReference,
  String? rightsHolderApprovalReference,
  bool dataMinimizationConfirmed = false,
  bool nonAccusatoryLanguageConfirmed = false,
  String? currentPackageId,
  int currentPackageVersion = 0,
  String? currentPackageHash,
  int packageCount = 0,
  int responseCount = 0,
  int? eventCount,
  String? channelType,
  String? submittedAt,
  String? externalSubmissionStatement,
  String? externalReferenceType,
  String? externalReferenceValue,
  String? officialReferenceNumber,
  String? receiptRecordedAt,
  String? outcomeResponseId,
  String? outcomeCode,
  String? outcomeFinalityLevel,
  String? authorityReferenceNumber,
  String? officialDocumentDate,
  String? outcomeReceivedAt,
  String? outcomeRecordedAt,
  String? authorityNameSnapshot,
  String? authorityUnitSnapshot,
  String? outcomeSummary,
  String? lastEventType,
  String lastEventAt = '2026-07-25T10:00:00.000Z',
}) => <String, dynamic>{
  'submissionId': submissionId,
  'submissionNumber': 'KRI-2026-ABC12345',
  'submissionType': submissionType,
  'targetAuthority': targetAuthority,
  'targetUnit': targetUnit,
  'channelType':
      channelType ??
      (submissionType == 'fsmh_protection_application'
          ? 'fsmh_portal'
          : 'official_online_form'),
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
  'humanReviewReference': humanReviewReference,
  'rightsHolderApprovalReference': rightsHolderApprovalReference,
  'dataMinimizationConfirmed': dataMinimizationConfirmed,
  'nonAccusatoryLanguageConfirmed': nonAccusatoryLanguageConfirmed,
  'duplicateCheckKey': 'duplicate-key-1',
  'currentPackageId': currentPackageId,
  'currentPackageVersion': currentPackageVersion,
  'currentPackageHash': currentPackageHash,
  'preparedByUid': 'user-1',
  'reviewedByUid': humanReviewReference == null ? null : 'reviewer-1',
  'approvedByUid': rightsHolderApprovalReference == null ? null : 'approver-1',
  'submittedByUid': submittedAt == null ? null : 'user-1',
  'submittedAt': submittedAt,
  'externalSubmissionStatement': externalSubmissionStatement,
  'externalReferenceType': externalReferenceType,
  'externalReferenceValue': externalReferenceValue,
  'officialReferenceNumber': officialReferenceNumber,
  'receiptRecordedAt': receiptRecordedAt,
  'outcomeResponseId': outcomeResponseId,
  'outcomeCode': outcomeCode,
  'outcomeFinalityLevel': outcomeFinalityLevel,
  'authorityReferenceNumber': authorityReferenceNumber,
  'officialDocumentDate': officialDocumentDate,
  'outcomeReceivedAt': outcomeReceivedAt,
  'outcomeRecordedAt': outcomeRecordedAt,
  'authorityNameSnapshot': authorityNameSnapshot,
  'authorityUnitSnapshot': authorityUnitSnapshot,
  'outcomeSummary': outcomeSummary,
  'packageCount': packageCount,
  'responseCount': responseCount,
  'eventCount': eventCount ?? (packageCount == 0 ? 1 : 2),
  'lastEventType':
      lastEventType ??
      (packageCount == 0
          ? 'authority_submission_created'
          : 'customs_submission_package_generated'),
  'lastEventAt': lastEventAt,
  'createdAt': '2026-07-25T10:00:00.000Z',
  'updatedAt': lastEventAt,
};

Map<String, dynamic> _packageMap({
  String submissionId = 'submission-1',
  String artifactStatus = 'legacy_not_materialized',
  bool pdfReady = false,
  bool manifestReady = false,
}) => <String, dynamic>{
  'packageId': 'package-1',
  'submissionId': submissionId,
  'version': 1,
  'packageType': 'fsmh_application_package',
  'sourceSnapshot': const <String, dynamic>{},
  'documentManifest': <Map<String, dynamic>>[
    <String, dynamic>{
      'referenceId': 'document-1',
      'title': 'Marka tescil belgesi',
      'sha256': List<String>.filled(64, 'e').join(),
      'mimeType': 'application/pdf',
      'sizeBytes': 2048,
    },
  ],
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
};

String _artifactStatusWire(CustomsSubmissionArtifactStatus status) =>
    switch (status) {
      CustomsSubmissionArtifactStatus.legacyNotMaterialized =>
        'legacy_not_materialized',
      CustomsSubmissionArtifactStatus.materializationPending =>
        'materialization_pending',
      CustomsSubmissionArtifactStatus.materializing => 'materializing',
      CustomsSubmissionArtifactStatus.ready => 'ready',
      CustomsSubmissionArtifactStatus.failedRecoverable => 'failed_recoverable',
      CustomsSubmissionArtifactStatus.integrityFailed => 'integrity_failed',
      CustomsSubmissionArtifactStatus.disabled => 'disabled',
      CustomsSubmissionArtifactStatus.unknown => 'unknown',
    };

Map<String, dynamic> _packageToMap(CustomsSubmissionPackage package) =>
    <String, dynamic>{
      'packageId': package.packageId,
      'submissionId': package.submissionId,
      'version': package.version,
      'packageType': package.packageType,
      'sourceSnapshot': package.sourceSnapshot,
      'documentManifest': package.documentManifest
          .map(
            (item) => <String, dynamic>{
              'referenceId': item.referenceId,
              'title': item.title,
              'sha256': item.sha256,
              'mimeType': item.mimeType,
              'sizeBytes': item.sizeBytes,
            },
          )
          .toList(growable: false),
      'evidenceManifest': package.evidenceManifest
          .map(
            (item) => <String, dynamic>{
              'referenceId': item.referenceId,
              'title': item.title,
              'sha256': item.sha256,
              'mimeType': item.mimeType,
              'sizeBytes': item.sizeBytes,
            },
          )
          .toList(growable: false),
      'redactionManifest': package.redactionManifest
          .map(
            (item) => <String, dynamic>{
              'fieldPath': item.fieldPath,
              'action': item.action,
              'reason': item.reason,
            },
          )
          .toList(growable: false),
      'coverLetterText': package.coverLetterText,
      'authoritySummary': package.authoritySummary,
      'legalNeutralityStatement': package.legalNeutralityStatement,
      'aggregateHashAlgorithm': package.aggregateHashAlgorithm,
      'aggregateHash': package.aggregateHash,
      'generatedAt': package.generatedAt,
      'generatedByUid': package.generatedByUid,
      'immutable': package.immutable,
      'artifactStatus': _artifactStatusWire(package.artifactStatus),
      'artifactFormatVersion': package.artifactFormatVersion,
      'sourcePackageHash': package.sourcePackageHash,
      if (package.pdfArtifact != null)
        'pdfArtifact': <String, dynamic>{
          'ready': package.pdfArtifact!.ready,
          'contentType': package.pdfArtifact!.contentType,
          'sizeBytes': package.pdfArtifact!.sizeBytes,
          'sha256': package.pdfArtifact!.sha256,
          'safeFileName': package.pdfArtifact!.safeFileName,
        },
      if (package.jsonManifestArtifact != null)
        'jsonManifestArtifact': <String, dynamic>{
          'ready': package.jsonManifestArtifact!.ready,
          'contentType': package.jsonManifestArtifact!.contentType,
          'sizeBytes': package.jsonManifestArtifact!.sizeBytes,
          'sha256': package.jsonManifestArtifact!.sha256,
          'safeFileName': package.jsonManifestArtifact!.safeFileName,
        },
    };

Map<String, dynamic> _responseMap({
  required String responseId,
  required String submissionId,
  required String responseType,
  required String receivedAt,
  required String summary,
  String? authorityReference,
  List<String> attachmentReferences = const [],
  List<String> attachmentHashes = const [],
  String? requestedDueAt,
  String? outcomeCode,
  String? outcomeFinalityLevel,
  String? officialDocumentDate,
  String? authorityNameSnapshot,
  String? authorityUnitSnapshot,
  String? previousResponseId,
  String? additionalNotes,
  String? attachmentIntegrityStatus,
}) => <String, dynamic>{
  'responseId': responseId,
  'submissionId': submissionId,
  'responseType': responseType,
  'authorityReference': authorityReference,
  'receivedAt': receivedAt,
  'receivedByUid': 'user-1',
  'summary': summary,
  'attachmentReferences': attachmentReferences,
  'attachmentHashes': attachmentHashes,
  'requestedDueAt': requestedDueAt,
  'outcomeCode': outcomeCode,
  'outcomeFinalityLevel': outcomeFinalityLevel,
  'officialDocumentDate': officialDocumentDate,
  'authorityNameSnapshot': authorityNameSnapshot,
  'authorityUnitSnapshot': authorityUnitSnapshot,
  'previousResponseId': previousResponseId,
  'additionalNotes': additionalNotes,
  'attachmentIntegrityStatus': attachmentIntegrityStatus,
  'immutable': true,
};

Map<String, dynamic> _responseToMap(CustomsAuthorityResponse response) =>
    _responseMap(
      responseId: response.responseId,
      submissionId: response.submissionId,
      responseType: response.responseType,
      authorityReference: response.authorityReference,
      receivedAt: response.receivedAt,
      summary: response.summary,
      attachmentReferences: response.attachmentReferences,
      attachmentHashes: response.attachmentHashes,
      requestedDueAt: response.requestedDueAt,
      outcomeCode: response.outcomeCode,
      outcomeFinalityLevel: response.outcomeFinalityLevel,
      officialDocumentDate: response.officialDocumentDate,
      authorityNameSnapshot: response.authorityNameSnapshot,
      authorityUnitSnapshot: response.authorityUnitSnapshot,
      previousResponseId: response.previousResponseId,
      additionalNotes: response.additionalNotes,
      attachmentIntegrityStatus: response.attachmentIntegrityStatus,
    );

Map<String, dynamic> _eventMap({
  required String submissionId,
  required int sequence,
  required String eventType,
  required String? previousStatus,
  required String? nextStatus,
  required String summary,
  required String reason,
  required String recordedAt,
}) => <String, dynamic>{
  'submissionId': submissionId,
  'sequence': sequence,
  'eventType': eventType,
  'previousStatus': previousStatus,
  'nextStatus': nextStatus,
  'summary': summary,
  'reason': reason,
  'actorLabel': 'Yetkili kullanıcı',
  'recordedAt': recordedAt,
};

Map<String, dynamic> _eventToMap(CustomsAuthoritySubmissionEvent event) =>
    _eventMap(
      submissionId: event.submissionId,
      sequence: event.sequence,
      eventType: event.eventType,
      previousStatus: event.previousStatus,
      nextStatus: event.nextStatus,
      summary: event.summary,
      reason: event.reason,
      recordedAt: event.recordedAt,
    );

Map<String, dynamic> _submissionToMap(
  CustomsAuthoritySubmission submission, {
  String? status,
  int? responseCount,
  int? eventCount,
  String? lastEventType,
  String? lastEventAt,
  String? officialReferenceNumber,
  String? receiptRecordedAt,
  String? outcomeResponseId,
  String? outcomeCode,
  String? outcomeFinalityLevel,
  String? authorityReferenceNumber,
  String? officialDocumentDate,
  String? outcomeReceivedAt,
  String? outcomeRecordedAt,
  String? authorityNameSnapshot,
  String? authorityUnitSnapshot,
  String? outcomeSummary,
}) => _submissionMap(
  submissionId: submission.submissionId,
  status: status ?? submission.status,
  submissionType: submission.submissionType,
  targetAuthority: submission.targetAuthority,
  targetUnit: submission.targetUnit,
  protectionProfileId: submission.protectionProfileId,
  interventionId: submission.interventionId,
  title: submission.title,
  humanReviewReference: submission.humanReviewReference,
  rightsHolderApprovalReference: submission.rightsHolderApprovalReference,
  dataMinimizationConfirmed: submission.dataMinimizationConfirmed,
  nonAccusatoryLanguageConfirmed: submission.nonAccusatoryLanguageConfirmed,
  currentPackageId: submission.currentPackageId,
  currentPackageVersion: submission.currentPackageVersion,
  currentPackageHash: submission.currentPackageHash,
  packageCount: submission.packageCount,
  responseCount: responseCount ?? submission.responseCount,
  eventCount: eventCount ?? submission.eventCount,
  channelType: submission.channelType,
  submittedAt: submission.submittedAt,
  externalSubmissionStatement: submission.externalSubmissionStatement,
  externalReferenceType: submission.externalReferenceType,
  externalReferenceValue: submission.externalReferenceValue,
  officialReferenceNumber:
      officialReferenceNumber ?? submission.officialReferenceNumber,
  receiptRecordedAt: receiptRecordedAt ?? submission.receiptRecordedAt,
  outcomeResponseId: outcomeResponseId ?? submission.outcomeResponseId,
  outcomeCode: outcomeCode ?? submission.outcomeCode,
  outcomeFinalityLevel: outcomeFinalityLevel ?? submission.outcomeFinalityLevel,
  authorityReferenceNumber:
      authorityReferenceNumber ?? submission.authorityReferenceNumber,
  officialDocumentDate: officialDocumentDate ?? submission.officialDocumentDate,
  outcomeReceivedAt: outcomeReceivedAt ?? submission.outcomeReceivedAt,
  outcomeRecordedAt: outcomeRecordedAt ?? submission.outcomeRecordedAt,
  authorityNameSnapshot:
      authorityNameSnapshot ?? submission.authorityNameSnapshot,
  authorityUnitSnapshot:
      authorityUnitSnapshot ?? submission.authorityUnitSnapshot,
  outcomeSummary: outcomeSummary ?? submission.outcomeSummary,
  lastEventType: lastEventType ?? submission.lastEventType,
  lastEventAt: lastEventAt ?? submission.lastEventAt ?? submission.updatedAt,
);

CustomsAuthoritySubmissionDetail _detailFromCurrent({
  required CustomsAuthoritySubmissionDetail current,
  required Map<String, dynamic> submission,
  required List<Map<String, dynamic>> responses,
  required List<Map<String, dynamic>> events,
}) => CustomsAuthoritySubmissionDetail.fromMap(<String, dynamic>{
  'contractVersion': 'customs-authority-submission-detail-v1',
  'submission': submission,
  'packages': current.packages.map(_packageToMap).toList(growable: false),
  'responses': responses,
  'events': events,
  'integrityStatus': 'verified',
  'readOnly': true,
  'writesPerformed': 0,
  'scope': current.artifactScope == null
      ? null
      : <String, dynamic>{
          'contractVersion': current.artifactScope!.contractVersion,
          'tenantId': current.artifactScope!.tenantId,
          'canonicalBrandId': current.artifactScope!.canonicalBrandId,
        },
});

CustomsAuthoritySubmission sampleAuthoritySubmission({
  String submissionId = 'submission-1',
  String status = 'draft',
  String submissionType = 'fsmh_protection_application',
  String targetAuthority = 'fsmh_program',
  String? protectionProfileId = 'profile-1',
  String? interventionId,
  String title = 'Bosch FSMH koruma başvurusu',
  String? humanReviewReference,
  String? rightsHolderApprovalReference,
  bool dataMinimizationConfirmed = false,
  bool nonAccusatoryLanguageConfirmed = false,
}) => CustomsAuthoritySubmission.fromMap(
  _submissionMap(
    submissionId: submissionId,
    status: status,
    submissionType: submissionType,
    targetAuthority: targetAuthority,
    protectionProfileId: protectionProfileId,
    interventionId: interventionId,
    title: title,
    humanReviewReference: humanReviewReference,
    rightsHolderApprovalReference: rightsHolderApprovalReference,
    dataMinimizationConfirmed: dataMinimizationConfirmed,
    nonAccusatoryLanguageConfirmed: nonAccusatoryLanguageConfirmed,
  ),
);

CustomsAuthoritySubmissionDetail sampleAuthoritySubmissionDetail({
  String submissionId = 'submission-1',
  String status = 'draft',
  bool includePackage = false,
  bool includeScope = false,
  String artifactStatus = 'legacy_not_materialized',
  bool pdfReady = false,
  bool manifestReady = false,
  String? humanReviewReference,
  String? rightsHolderApprovalReference,
  bool dataMinimizationConfirmed = false,
  bool nonAccusatoryLanguageConfirmed = false,
  String? channelType,
  String? submittedAt,
  String? externalSubmissionStatement,
  String? externalReferenceType,
  String? externalReferenceValue,
  String? officialReferenceNumber,
  String? receiptRecordedAt,
  String? outcomeResponseId,
  String? outcomeCode,
  String? outcomeFinalityLevel,
  String? authorityReferenceNumber,
  String? officialDocumentDate,
  String? outcomeReceivedAt,
  String? outcomeRecordedAt,
  String? authorityNameSnapshot,
  String? authorityUnitSnapshot,
  String? outcomeSummary,
  List<Map<String, dynamic>> responses = const [],
  List<Map<String, dynamic>>? events,
}) {
  final generatedEvents =
      events ??
      <Map<String, dynamic>>[
        _eventMap(
          submissionId: submissionId,
          sequence: 1,
          eventType: 'authority_submission_created',
          previousStatus: null,
          nextStatus: 'draft',
          summary: 'Resmî iletim taslağı oluşturuldu.',
          reason: 'Kaynak kayıt üzerinden insan incelemesi için hazırlandı.',
          recordedAt: '2026-07-25T10:00:00.000Z',
        ),
        if (includePackage)
          _eventMap(
            submissionId: submissionId,
            sequence: 2,
            eventType: 'customs_submission_package_generated',
            previousStatus: 'approved_for_package',
            nextStatus: 'package_generated',
            summary: 'Başvuru paketi üretildi.',
            reason: 'İnsan ve hak sahibi onaylarından sonra paket oluşturuldu.',
            recordedAt: '2026-07-25T10:01:00.000Z',
          ),
        if (submittedAt != null)
          _eventMap(
            submissionId: submissionId,
            sequence: 3,
            eventType: 'customs_submission_recorded_as_submitted_externally',
            previousStatus: 'package_generated',
            nextStatus: 'submitted_externally',
            summary: 'Resmî iletim dış kanalda gönderilmiş olarak kaydedildi.',
            reason:
                externalSubmissionStatement ??
                'Paket yetkili kullanıcı tarafından dış kanalda teslim edildi.',
            recordedAt: '2026-07-25T10:02:00.000Z',
          ),
      ];
  final lastEvent = generatedEvents.last;
  return CustomsAuthoritySubmissionDetail.fromMap(<String, dynamic>{
    'contractVersion': 'customs-authority-submission-detail-v1',
    'submission': _submissionMap(
      submissionId: submissionId,
      status: status,
      humanReviewReference: humanReviewReference,
      rightsHolderApprovalReference: rightsHolderApprovalReference,
      dataMinimizationConfirmed: dataMinimizationConfirmed,
      nonAccusatoryLanguageConfirmed: nonAccusatoryLanguageConfirmed,
      currentPackageId: includePackage ? 'package-1' : null,
      currentPackageVersion: includePackage ? 1 : 0,
      currentPackageHash: includePackage
          ? List<String>.filled(64, 'a').join()
          : null,
      packageCount: includePackage ? 1 : 0,
      responseCount: responses.length,
      eventCount: generatedEvents.length,
      channelType: channelType,
      submittedAt: submittedAt,
      externalSubmissionStatement: externalSubmissionStatement,
      externalReferenceType: externalReferenceType,
      externalReferenceValue: externalReferenceValue,
      officialReferenceNumber: officialReferenceNumber,
      receiptRecordedAt: receiptRecordedAt,
      outcomeResponseId: outcomeResponseId,
      outcomeCode: outcomeCode,
      outcomeFinalityLevel: outcomeFinalityLevel,
      authorityReferenceNumber: authorityReferenceNumber,
      officialDocumentDate: officialDocumentDate,
      outcomeReceivedAt: outcomeReceivedAt,
      outcomeRecordedAt: outcomeRecordedAt,
      authorityNameSnapshot: authorityNameSnapshot,
      authorityUnitSnapshot: authorityUnitSnapshot,
      outcomeSummary: outcomeSummary,
      lastEventType: lastEvent['eventType'] as String,
      lastEventAt: lastEvent['recordedAt'] as String,
    ),
    'packages': includePackage
        ? <Map<String, dynamic>>[
            _packageMap(
              submissionId: submissionId,
              artifactStatus: artifactStatus,
              pdfReady: pdfReady,
              manifestReady: manifestReady,
            ),
          ]
        : const <Map<String, dynamic>>[],
    'responses': responses,
    'events': generatedEvents,
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
}

class FakeCustomsAuthoritySubmissionRepository
    implements CustomsAuthoritySubmissionRepository {
  List<CustomsAuthoritySubmission> submissions = [sampleAuthoritySubmission()];

  int createCalls = 0;
  int detailCalls = 0;
  int generatePackageCalls = 0;
  int externalSubmissionCalls = 0;
  int receiptCalls = 0;
  int authorityResponseCalls = 0;
  int authorityOutcomeCalls = 0;
  int materializeCalls = 0;
  int pdfAuthorizationCalls = 0;
  int manifestAuthorizationCalls = 0;
  CustomsAuthoritySubmissionDraft? lastDraft;
  CustomsSubmissionPackageDraft? lastPackageDraft;
  CustomsExternalSubmissionDraft? lastExternalSubmissionDraft;
  CustomsSubmissionReceiptDraft? lastReceiptDraft;
  CustomsAuthorityResponseDraft? lastAuthorityResponseDraft;
  CustomsAuthorityOutcomeDraft? lastAuthorityOutcomeDraft;
  String? lastPackageTenantId;
  String? lastPackageCanonicalBrandId;
  String? lastPackageSubmissionId;
  String? lastExternalSubmissionTenantId;
  String? lastExternalSubmissionCanonicalBrandId;
  String? lastExternalSubmissionSubmissionId;
  String? lastExternalSubmissionPackageId;
  int? lastExternalSubmissionPackageVersion;
  String? lastExternalSubmissionPackageHash;
  String? lastAuthorityOperationTenantId;
  String? lastAuthorityOperationCanonicalBrandId;
  String? lastAuthorityOperationSubmissionId;
  CustomsAuthoritySubmissionDetail? detail;
  Object? packageGenerationError;
  Object? externalSubmissionError;
  Object? receiptError;
  Object? authorityResponseError;
  Object? authorityOutcomeError;
  Object? materializationError;
  Object? authorizationError;
  Completer<void>? packageGenerationGate;
  Completer<void>? externalSubmissionGate;
  Completer<void>? receiptGate;
  Completer<void>? authorityResponseGate;
  Completer<void>? authorityOutcomeGate;
  Completer<void>? materializationGate;
  Completer<void>? pdfAuthorizationGate;
  Completer<void>? manifestAuthorizationGate;
  final List<String> packageGenerationRequestIds = [];
  final List<String> externalSubmissionRequestIds = [];
  final List<String> receiptRequestIds = [];
  final List<String> authorityResponseRequestIds = [];
  final List<String> authorityOutcomeRequestIds = [];
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
  }) async {
    generatePackageCalls++;
    lastPackageTenantId = tenantId;
    lastPackageCanonicalBrandId = canonicalBrandId;
    lastPackageSubmissionId = submissionId;
    lastPackageDraft = draft;
    packageGenerationRequestIds.add(requestId);
    draft.toRequestMap();
    await packageGenerationGate?.future;
    final error = packageGenerationError;
    if (error != null) throw error;

    final current = detail?.submission;
    final result = CustomsPackageGenerationResult.fromMap(<String, dynamic>{
      'contractVersion': 'customs-submission-package-generate-result-v1',
      'ok': true,
      'duplicate': false,
      'transactionCommitted': true,
      'submission': _submissionMap(
        submissionId: submissionId,
        status: 'package_generated',
        submissionType:
            current?.submissionType ?? 'fsmh_protection_application',
        targetAuthority: current?.targetAuthority ?? 'fsmh_program',
        protectionProfileId: current?.protectionProfileId ?? 'profile-1',
        interventionId: current?.interventionId,
        title: current?.title ?? 'Bosch FSMH koruma başvurusu',
        humanReviewReference:
            current?.humanReviewReference ?? 'review-reference-1',
        rightsHolderApprovalReference:
            current?.rightsHolderApprovalReference ?? 'approval-reference-1',
        dataMinimizationConfirmed: current?.dataMinimizationConfirmed ?? true,
        nonAccusatoryLanguageConfirmed:
            current?.nonAccusatoryLanguageConfirmed ?? true,
        currentPackageId: 'package-1',
        currentPackageVersion: 1,
        currentPackageHash: List<String>.filled(64, 'a').join(),
        packageCount: 1,
      ),
      'package': {
        ..._packageMap(submissionId: submissionId),
        'packageType': draft.packageType.wireValue,
        'documentManifest': draft.documentManifest
            .map((item) => item.toRequestMap())
            .toList(growable: false),
        'evidenceManifest': draft.evidenceManifest
            .map((item) => item.toRequestMap())
            .toList(growable: false),
        'redactionManifest': draft.redactionManifest
            .map((item) => item.toRequestMap())
            .toList(growable: false),
        'coverLetterText': draft.coverLetterText,
        'authoritySummary': draft.authoritySummary,
        'legalNeutralityStatement': draft.legalNeutralityStatement,
      },
    });

    detail = sampleAuthoritySubmissionDetail(
      submissionId: submissionId,
      status: 'package_generated',
      includePackage: true,
      includeScope: true,
      humanReviewReference:
          current?.humanReviewReference ?? 'review-reference-1',
      rightsHolderApprovalReference:
          current?.rightsHolderApprovalReference ?? 'approval-reference-1',
      dataMinimizationConfirmed: current?.dataMinimizationConfirmed ?? true,
      nonAccusatoryLanguageConfirmed:
          current?.nonAccusatoryLanguageConfirmed ?? true,
    );
    return result;
  }

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
  }) async {
    externalSubmissionCalls++;
    lastExternalSubmissionTenantId = tenantId;
    lastExternalSubmissionCanonicalBrandId = canonicalBrandId;
    lastExternalSubmissionSubmissionId = submissionId;
    lastExternalSubmissionPackageId = packageId;
    lastExternalSubmissionPackageVersion = packageVersion;
    lastExternalSubmissionPackageHash = packageHash;
    lastExternalSubmissionDraft = draft;
    externalSubmissionRequestIds.add(requestId);
    draft.toRequestMap();
    await externalSubmissionGate?.future;
    final error = externalSubmissionError;
    if (error != null) throw error;

    final current = detail?.submission;
    final result = CustomsExternalSubmissionResult.fromMap(<String, dynamic>{
      'contractVersion': 'customs-external-submission-record-result-v1',
      'ok': true,
      'duplicate': false,
      'transactionApplied': true,
      'submission': _submissionMap(
        submissionId: submissionId,
        status: 'submitted_externally',
        submissionType:
            current?.submissionType ?? 'fsmh_protection_application',
        targetAuthority: current?.targetAuthority ?? 'fsmh_program',
        protectionProfileId: current?.protectionProfileId ?? 'profile-1',
        interventionId: current?.interventionId,
        title: current?.title ?? 'Bosch FSMH koruma başvurusu',
        humanReviewReference:
            current?.humanReviewReference ?? 'review-reference-1',
        rightsHolderApprovalReference:
            current?.rightsHolderApprovalReference ?? 'approval-reference-1',
        dataMinimizationConfirmed: current?.dataMinimizationConfirmed ?? true,
        nonAccusatoryLanguageConfirmed:
            current?.nonAccusatoryLanguageConfirmed ?? true,
        currentPackageId: packageId,
        currentPackageVersion: packageVersion,
        currentPackageHash: packageHash,
        packageCount: 1,
        channelType: draft.submissionChannel.wireValue,
        submittedAt: draft.submittedAt,
        externalSubmissionStatement: draft.externalSubmissionStatement,
        externalReferenceType: draft.externalReferenceType.wireValue,
        externalReferenceValue: draft.externalReferenceValue,
      ),
      'event': <String, dynamic>{
        'submissionId': submissionId,
        'sequence': 3,
        'eventType': 'customs_submission_recorded_as_submitted_externally',
        'previousStatus': 'package_generated',
        'nextStatus': 'submitted_externally',
        'summary': 'Resmî iletim dış kanalda gönderilmiş olarak kaydedildi.',
        'reason': draft.externalSubmissionStatement,
        'actorLabel': 'Yetkili kullanıcı',
        'recordedAt': '2026-07-25T10:02:00.000Z',
      },
    });

    detail = sampleAuthoritySubmissionDetail(
      submissionId: submissionId,
      status: 'submitted_externally',
      includePackage: true,
      includeScope: true,
      artifactStatus: 'legacy_not_materialized',
      humanReviewReference:
          current?.humanReviewReference ?? 'review-reference-1',
      rightsHolderApprovalReference:
          current?.rightsHolderApprovalReference ?? 'approval-reference-1',
      dataMinimizationConfirmed: current?.dataMinimizationConfirmed ?? true,
      nonAccusatoryLanguageConfirmed:
          current?.nonAccusatoryLanguageConfirmed ?? true,
      channelType: draft.submissionChannel.wireValue,
      submittedAt: draft.submittedAt,
      externalSubmissionStatement: draft.externalSubmissionStatement,
      externalReferenceType: draft.externalReferenceType.wireValue,
      externalReferenceValue: draft.externalReferenceValue,
    );
    return result;
  }

  @override
  Future<CustomsSubmissionReceiptResult> recordReceipt({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsSubmissionReceiptDraft draft,
    required String requestId,
  }) async {
    receiptCalls++;
    lastAuthorityOperationTenantId = tenantId;
    lastAuthorityOperationCanonicalBrandId = canonicalBrandId;
    lastAuthorityOperationSubmissionId = submissionId;
    lastReceiptDraft = draft;
    receiptRequestIds.add(requestId);
    draft.toRequestMap();
    await receiptGate?.future;
    final error = receiptError;
    if (error != null) throw error;

    final current =
        detail ??
        sampleAuthoritySubmissionDetail(
          submissionId: submissionId,
          status: 'submitted_externally',
          includePackage: true,
          includeScope: true,
          submittedAt: '2026-07-25T10:02:00.000Z',
          externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
        );
    final responseId = 'receipt-response-$receiptCalls';
    final response = _responseMap(
      responseId: responseId,
      submissionId: submissionId,
      responseType: 'receipt',
      authorityReference: draft.officialReferenceNumber,
      receivedAt: draft.receivedAt,
      summary: draft.summary,
      attachmentReferences: draft.receiptDocumentReference == null
          ? const []
          : [draft.receiptDocumentReference!],
      attachmentHashes: draft.receiptDocumentHash == null
          ? const []
          : [draft.receiptDocumentHash!],
    );
    final event = _eventMap(
      submissionId: submissionId,
      sequence: current.events.length + 1,
      eventType: 'submission_receipt_recorded',
      previousStatus: current.submission.status,
      nextStatus: 'receipt_recorded',
      summary: 'Resmî alındı kaydedildi.',
      reason: draft.summary,
      recordedAt: draft.receivedAt,
    );
    final responses = <Map<String, dynamic>>[
      ...current.responses.map(_responseToMap),
      response,
    ];
    final events = <Map<String, dynamic>>[
      ...current.events.map(_eventToMap),
      event,
    ];
    final submission = _submissionToMap(
      current.submission,
      status: 'receipt_recorded',
      responseCount: responses.length,
      eventCount: events.length,
      officialReferenceNumber: draft.officialReferenceNumber,
      receiptRecordedAt: draft.receivedAt,
      lastEventType: 'submission_receipt_recorded',
      lastEventAt: draft.receivedAt,
    );
    final result = CustomsSubmissionReceiptResult.fromMap(<String, dynamic>{
      'contractVersion': 'customs-submission-receipt-record-result-v1',
      'ok': true,
      'duplicate': false,
      'transactionCommitted': true,
      'submission': submission,
      'response': response,
    });
    detail = _detailFromCurrent(
      current: current,
      submission: submission,
      responses: responses,
      events: events,
    );
    return result;
  }

  @override
  Future<CustomsAuthorityResponseAppendResult> appendAuthorityResponse({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityResponseDraft draft,
    required String requestId,
  }) async {
    authorityResponseCalls++;
    lastAuthorityOperationTenantId = tenantId;
    lastAuthorityOperationCanonicalBrandId = canonicalBrandId;
    lastAuthorityOperationSubmissionId = submissionId;
    lastAuthorityResponseDraft = draft;
    authorityResponseRequestIds.add(requestId);
    draft.toRequestMap();
    await authorityResponseGate?.future;
    final error = authorityResponseError;
    if (error != null) throw error;

    final current =
        detail ??
        sampleAuthoritySubmissionDetail(
          submissionId: submissionId,
          status: 'submitted_externally',
          includePackage: true,
          includeScope: true,
          submittedAt: '2026-07-25T10:02:00.000Z',
          externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
        );
    final nextStatus =
        draft.responseType ==
            CustomsInterimAuthorityResponseType.informationRequest
        ? 'additional_information_requested'
        : current.submission.status;
    final responseId = 'authority-response-$authorityResponseCalls';
    final response = _responseMap(
      responseId: responseId,
      submissionId: submissionId,
      responseType: draft.responseType.wireValue,
      authorityReference: draft.authorityReference,
      receivedAt: draft.receivedAt,
      summary: draft.summary,
      attachmentReferences: draft.attachmentReferences,
      attachmentHashes: draft.attachmentHashes,
      requestedDueAt: draft.requestedDueAt,
      outcomeCode: draft.outcomeCode?.wireValue,
    );
    final event = _eventMap(
      submissionId: submissionId,
      sequence: current.events.length + 1,
      eventType: 'authority_response_appended',
      previousStatus: current.submission.status,
      nextStatus: nextStatus,
      summary: 'Kurum ara cevabı kaydedildi.',
      reason: draft.summary,
      recordedAt: draft.receivedAt,
    );
    final responses = <Map<String, dynamic>>[
      ...current.responses.map(_responseToMap),
      response,
    ];
    final events = <Map<String, dynamic>>[
      ...current.events.map(_eventToMap),
      event,
    ];
    final submission = _submissionToMap(
      current.submission,
      status: nextStatus,
      responseCount: responses.length,
      eventCount: events.length,
      lastEventType: 'authority_response_appended',
      lastEventAt: draft.receivedAt,
    );
    final result =
        CustomsAuthorityResponseAppendResult.fromMap(<String, dynamic>{
          'contractVersion': 'customs-authority-response-append-result-v1',
          'ok': true,
          'duplicate': false,
          'transactionCommitted': true,
          'submission': submission,
          'response': response,
        });
    detail = _detailFromCurrent(
      current: current,
      submission: submission,
      responses: responses,
      events: events,
    );
    return result;
  }

  @override
  Future<CustomsAuthorityOutcomeResult> recordAuthorityOutcome({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityOutcomeDraft draft,
    required String requestId,
  }) async {
    authorityOutcomeCalls++;
    lastAuthorityOperationTenantId = tenantId;
    lastAuthorityOperationCanonicalBrandId = canonicalBrandId;
    lastAuthorityOperationSubmissionId = submissionId;
    lastAuthorityOutcomeDraft = draft;
    authorityOutcomeRequestIds.add(requestId);
    draft.toRequestMap();
    await authorityOutcomeGate?.future;
    final error = authorityOutcomeError;
    if (error != null) throw error;

    final current =
        detail ??
        sampleAuthoritySubmissionDetail(
          submissionId: submissionId,
          status: 'submitted_externally',
          includePackage: true,
          includeScope: true,
          submittedAt: '2026-07-25T10:02:00.000Z',
          externalSubmissionStatement: 'Paket dış kanalda teslim edildi.',
        );
    final responseId = 'authority-outcome-$authorityOutcomeCalls';
    final response = _responseMap(
      responseId: responseId,
      submissionId: submissionId,
      responseType: draft.responseType.wireValue,
      authorityReference: draft.authorityReferenceNumber,
      receivedAt: draft.receivedAt,
      summary: draft.summary,
      attachmentReferences: draft.attachmentReferences,
      attachmentHashes: draft.attachmentHashes,
      outcomeCode: draft.outcomeCode.wireValue,
      outcomeFinalityLevel: draft.outcomeFinalityLevel.wireValue,
      officialDocumentDate: draft.officialDocumentDate,
      authorityNameSnapshot: draft.authorityNameSnapshot,
      authorityUnitSnapshot: draft.authorityUnitSnapshot,
      previousResponseId: draft.previousResponseId,
      additionalNotes: draft.additionalNotes,
      attachmentIntegrityStatus: 'metadata_only_unverified',
    );
    final firstSequence = current.events.length + 1;
    final outcomeEvent = _eventMap(
      submissionId: submissionId,
      sequence: firstSequence,
      eventType: 'customs_authority_outcome_recorded',
      previousStatus: current.submission.status,
      nextStatus: current.submission.status,
      summary: 'Nihai kurum sonucu kaydedildi.',
      reason: draft.summary,
      recordedAt: draft.receivedAt,
    );
    final concludedEvent = _eventMap(
      submissionId: submissionId,
      sequence: firstSequence + 1,
      eventType: 'customs_authority_submission_concluded',
      previousStatus: current.submission.status,
      nextStatus: 'concluded',
      summary: 'Resmî iletim dosyası sonuçlandırıldı.',
      reason: draft.summary,
      recordedAt: draft.receivedAt,
    );
    final responses = <Map<String, dynamic>>[
      ...current.responses.map(_responseToMap),
      response,
    ];
    final events = <Map<String, dynamic>>[
      ...current.events.map(_eventToMap),
      outcomeEvent,
      concludedEvent,
    ];
    final submission = _submissionToMap(
      current.submission,
      status: 'concluded',
      responseCount: responses.length,
      eventCount: events.length,
      outcomeResponseId: responseId,
      outcomeCode: draft.outcomeCode.wireValue,
      outcomeFinalityLevel: draft.outcomeFinalityLevel.wireValue,
      authorityReferenceNumber: draft.authorityReferenceNumber,
      officialDocumentDate: draft.officialDocumentDate,
      outcomeReceivedAt: draft.receivedAt,
      outcomeRecordedAt: draft.receivedAt,
      authorityNameSnapshot: draft.authorityNameSnapshot,
      authorityUnitSnapshot: draft.authorityUnitSnapshot,
      outcomeSummary: draft.summary,
      lastEventType: 'customs_authority_submission_concluded',
      lastEventAt: draft.receivedAt,
    );
    final result = CustomsAuthorityOutcomeResult.fromMap(<String, dynamic>{
      'contractVersion': 'customs-authority-outcome-record-result-v1',
      'ok': true,
      'duplicate': false,
      'transactionApplied': true,
      'submission': submission,
      'response': response,
      'events': [outcomeEvent, concludedEvent],
    });
    detail = _detailFromCurrent(
      current: current,
      submission: submission,
      responses: responses,
      events: events,
    );
    return result;
  }

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
