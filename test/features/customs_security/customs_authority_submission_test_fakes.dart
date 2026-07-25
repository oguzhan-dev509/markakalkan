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
}) => CustomsAuthoritySubmissionDetail.fromMap(<String, dynamic>{
  'contractVersion': 'customs-authority-submission-detail-v1',
  'submission': _submissionMap(submissionId: submissionId),
  'packages': const <Map<String, dynamic>>[],
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
});

class FakeCustomsAuthoritySubmissionRepository
    implements CustomsAuthoritySubmissionRepository {
  List<CustomsAuthoritySubmission> submissions = [sampleAuthoritySubmission()];

  int createCalls = 0;
  CustomsAuthoritySubmissionDraft? lastDraft;

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
  ) async => sampleAuthoritySubmissionDetail(submissionId: submissionId);

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
