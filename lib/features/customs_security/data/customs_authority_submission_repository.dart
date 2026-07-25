import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

abstract interface class CustomsAuthoritySubmissionRepository {
  Future<CustomsAuthoritySubmissionList> listSubmissions({
    String? status,
    String? targetAuthority,
    String? pageToken,
    int pageSize = 25,
  });

  Future<CustomsAuthoritySubmission> createSubmission(
    CustomsAuthoritySubmissionDraft draft,
  );

  Future<CustomsAuthoritySubmission> updateSubmission({
    required String submissionId,
    required CustomsAuthoritySubmissionUpdateDraft draft,
  });

  Future<CustomsAuthoritySubmission> transitionSubmission({
    required String submissionId,
    required String nextStatus,
    required String reason,
    String? submittedAt,
    String? externalSubmissionStatement,
  });

  Future<CustomsAuthoritySubmissionDetail> getSubmissionDetail(
    String submissionId,
  );
}

class CallableCustomsAuthoritySubmissionRepository
    implements CustomsAuthoritySubmissionRepository {
  CallableCustomsAuthoritySubmissionRepository({
    FirebaseFunctions? functions,
    String Function()? requestIdFactory,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3'),
       _requestIdFactory =
           requestIdFactory ?? generateCustomsAuthoritySubmissionRequestId;

  final FirebaseFunctions _functions;
  final String Function() _requestIdFactory;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> request,
  ) async {
    final result = await _functions.httpsCallable(name).call(request);
    return _map(_normalize(result.data));
  }

  @override
  Future<CustomsAuthoritySubmissionList> listSubmissions({
    String? status,
    String? targetAuthority,
    String? pageToken,
    int pageSize = 25,
  }) async {
    if (_present(status) && _present(targetAuthority)) {
      throw ArgumentError(
        'Durum ve hedef kurum filtresi birlikte kullanılamaz.',
      );
    }
    final request = <String, dynamic>{
      'contractVersion': 'customs-authority-submission-list-request-v1',
      'pageSize': pageSize,
    };
    _optionalText(request, 'status', status);
    _optionalText(request, 'targetAuthority', targetAuthority);
    _optionalText(request, 'pageToken', pageToken);
    return CustomsAuthoritySubmissionList.fromMap(
      await _call('listCustomsAuthoritySubmissions', request),
    );
  }

  @override
  Future<CustomsAuthoritySubmission> createSubmission(
    CustomsAuthoritySubmissionDraft draft,
  ) async {
    final response = await _call('createCustomsAuthoritySubmission', {
      'contractVersion': 'customs-authority-submission-create-request-v1',
      ...draft.toRequestMap(),
      'requestId': _requestIdFactory(),
    });
    _requireWriteResult(
      response,
      'customs-authority-submission-create-result-v1',
    );
    return CustomsAuthoritySubmission.fromMap(_map(response['submission']));
  }

  @override
  Future<CustomsAuthoritySubmission> updateSubmission({
    required String submissionId,
    required CustomsAuthoritySubmissionUpdateDraft draft,
  }) async {
    final response = await _call('updateCustomsAuthoritySubmission', {
      'contractVersion': 'customs-authority-submission-update-request-v1',
      'submissionId': submissionId,
      ...draft.toRequestMap(),
      'requestId': _requestIdFactory(),
    });
    _requireWriteResult(
      response,
      'customs-authority-submission-update-result-v1',
    );
    return CustomsAuthoritySubmission.fromMap(_map(response['submission']));
  }

  @override
  Future<CustomsAuthoritySubmission> transitionSubmission({
    required String submissionId,
    required String nextStatus,
    required String reason,
    String? submittedAt,
    String? externalSubmissionStatement,
  }) async {
    final request = <String, dynamic>{
      'contractVersion': 'customs-authority-submission-transition-request-v1',
      'submissionId': submissionId,
      'nextStatus': nextStatus,
      'reason': reason,
      'requestId': _requestIdFactory(),
    };
    _optionalText(request, 'submittedAt', submittedAt);
    _optionalText(
      request,
      'externalSubmissionStatement',
      externalSubmissionStatement,
    );
    final response = await _call(
      'transitionCustomsAuthoritySubmission',
      request,
    );
    _requireWriteResult(
      response,
      'customs-authority-submission-transition-result-v1',
    );
    return CustomsAuthoritySubmission.fromMap(_map(response['submission']));
  }

  @override
  Future<CustomsAuthoritySubmissionDetail> getSubmissionDetail(
    String submissionId,
  ) async {
    return CustomsAuthoritySubmissionDetail.fromMap(
      await _call('getCustomsAuthoritySubmissionDetail', {
        'contractVersion': 'customs-authority-submission-detail-request-v1',
        'submissionId': submissionId,
      }),
    );
  }
}

class EmptyCustomsAuthoritySubmissionRepository
    implements CustomsAuthoritySubmissionRepository {
  const EmptyCustomsAuthoritySubmissionRepository();

  @override
  Future<CustomsAuthoritySubmissionList> listSubmissions({
    String? status,
    String? targetAuthority,
    String? pageToken,
    int pageSize = 25,
  }) async =>
      const CustomsAuthoritySubmissionList(items: [], nextPageToken: null);

  Never _unsupported() {
    throw UnsupportedError('Resmî iletim yazma işlemi yapılandırılmadı.');
  }

  @override
  Future<CustomsAuthoritySubmission> createSubmission(
    CustomsAuthoritySubmissionDraft draft,
  ) async => _unsupported();

  @override
  Future<CustomsAuthoritySubmissionDetail> getSubmissionDetail(
    String submissionId,
  ) async => _unsupported();

  @override
  Future<CustomsAuthoritySubmission> transitionSubmission({
    required String submissionId,
    required String nextStatus,
    required String reason,
    String? submittedAt,
    String? externalSubmissionStatement,
  }) async => _unsupported();

  @override
  Future<CustomsAuthoritySubmission> updateSubmission({
    required String submissionId,
    required CustomsAuthoritySubmissionUpdateDraft draft,
  }) async => _unsupported();
}

class CustomsAuthoritySubmissionDraft {
  const CustomsAuthoritySubmissionDraft({
    required this.submissionType,
    required this.targetAuthority,
    required this.incidentReference,
    required this.title,
    required this.authoritySummary,
    this.targetUnit,
    this.channelType,
    this.protectionProfileId,
    this.interventionId,
    this.caseId,
    this.legalMatterId,
    this.humanReviewReference,
    this.rightsHolderApprovalReference,
    this.dataMinimizationConfirmed = false,
    this.nonAccusatoryLanguageConfirmed = false,
  });

  final String submissionType;
  final String targetAuthority;
  final String? targetUnit;
  final String? channelType;
  final String? protectionProfileId;
  final String? interventionId;
  final String? caseId;
  final String? legalMatterId;
  final String incidentReference;
  final String title;
  final String authoritySummary;
  final String? humanReviewReference;
  final String? rightsHolderApprovalReference;
  final bool dataMinimizationConfirmed;
  final bool nonAccusatoryLanguageConfirmed;

  Map<String, dynamic> toRequestMap() {
    if (!_present(protectionProfileId) && !_present(interventionId)) {
      throw ArgumentError(
        'Koruma profili veya sınır müdahalesi kaynağı gerekir.',
      );
    }
    final map = <String, dynamic>{
      'submissionType': submissionType,
      'targetAuthority': targetAuthority,
      'incidentReference': incidentReference.trim(),
      'title': title.trim(),
      'authoritySummary': authoritySummary.trim(),
      'dataMinimizationConfirmed': dataMinimizationConfirmed,
      'nonAccusatoryLanguageConfirmed': nonAccusatoryLanguageConfirmed,
    };
    _optionalText(map, 'targetUnit', targetUnit);
    _optionalText(map, 'channelType', channelType);
    _optionalText(map, 'protectionProfileId', protectionProfileId);
    _optionalText(map, 'interventionId', interventionId);
    _optionalText(map, 'caseId', caseId);
    _optionalText(map, 'legalMatterId', legalMatterId);
    _optionalText(map, 'humanReviewReference', humanReviewReference);
    _optionalText(
      map,
      'rightsHolderApprovalReference',
      rightsHolderApprovalReference,
    );
    return map;
  }
}

class CustomsAuthoritySubmissionUpdateDraft {
  const CustomsAuthoritySubmissionUpdateDraft({
    required this.title,
    required this.authoritySummary,
    required this.dataMinimizationConfirmed,
    required this.nonAccusatoryLanguageConfirmed,
    this.targetUnit,
    this.channelType,
    this.humanReviewReference,
    this.rightsHolderApprovalReference,
  });

  final String? targetUnit;
  final String? channelType;
  final String title;
  final String authoritySummary;
  final String? humanReviewReference;
  final String? rightsHolderApprovalReference;
  final bool dataMinimizationConfirmed;
  final bool nonAccusatoryLanguageConfirmed;

  Map<String, dynamic> toRequestMap() {
    final map = <String, dynamic>{
      'title': title.trim(),
      'authoritySummary': authoritySummary.trim(),
      'dataMinimizationConfirmed': dataMinimizationConfirmed,
      'nonAccusatoryLanguageConfirmed': nonAccusatoryLanguageConfirmed,
    };
    _optionalText(map, 'targetUnit', targetUnit);
    _optionalText(map, 'channelType', channelType);
    _optionalText(map, 'humanReviewReference', humanReviewReference);
    _optionalText(
      map,
      'rightsHolderApprovalReference',
      rightsHolderApprovalReference,
    );
    return map;
  }
}

class CustomsAuthoritySubmissionList {
  const CustomsAuthoritySubmissionList({
    required this.items,
    required this.nextPageToken,
  });

  final List<CustomsAuthoritySubmission> items;
  final String? nextPageToken;

  factory CustomsAuthoritySubmissionList.fromMap(Map<String, dynamic> map) {
    _requireReadResult(map, 'customs-authority-submission-list-v1');
    return CustomsAuthoritySubmissionList(
      items: _list(map['items'])
          .map((item) => CustomsAuthoritySubmission.fromMap(_map(item)))
          .toList(growable: false),
      nextPageToken: _nullableString(map['nextPageToken']),
    );
  }
}

class CustomsAuthoritySubmissionDetail {
  const CustomsAuthoritySubmissionDetail({
    required this.submission,
    required this.packages,
    required this.responses,
    required this.events,
    required this.integrityStatus,
  });

  final CustomsAuthoritySubmission submission;
  final List<CustomsSubmissionPackage> packages;
  final List<CustomsAuthorityResponse> responses;
  final List<CustomsAuthoritySubmissionEvent> events;
  final String integrityStatus;

  factory CustomsAuthoritySubmissionDetail.fromMap(Map<String, dynamic> map) {
    _requireReadResult(map, 'customs-authority-submission-detail-v1');
    return CustomsAuthoritySubmissionDetail(
      submission: CustomsAuthoritySubmission.fromMap(_map(map['submission'])),
      packages: _list(map['packages'])
          .map((item) => CustomsSubmissionPackage.fromMap(_map(item)))
          .toList(growable: false),
      responses: _list(map['responses'])
          .map((item) => CustomsAuthorityResponse.fromMap(_map(item)))
          .toList(growable: false),
      events: _list(map['events'])
          .map((item) => CustomsAuthoritySubmissionEvent.fromMap(_map(item)))
          .toList(growable: false),
      integrityStatus: _string(map, 'integrityStatus'),
    );
  }
}

class CustomsAuthoritySubmission {
  const CustomsAuthoritySubmission({
    required this.submissionId,
    required this.submissionNumber,
    required this.submissionType,
    required this.targetAuthority,
    required this.incidentReference,
    required this.title,
    required this.authoritySummary,
    required this.status,
    required this.dataMinimizationConfirmed,
    required this.nonAccusatoryLanguageConfirmed,
    required this.duplicateCheckKey,
    required this.currentPackageVersion,
    required this.preparedByUid,
    required this.packageCount,
    required this.responseCount,
    required this.eventCount,
    required this.createdAt,
    required this.updatedAt,
    this.targetUnit,
    this.channelType,
    this.protectionProfileId,
    this.interventionId,
    this.caseId,
    this.legalMatterId,
    this.humanReviewReference,
    this.rightsHolderApprovalReference,
    this.currentPackageId,
    this.currentPackageHash,
    this.reviewedByUid,
    this.approvedByUid,
    this.submittedByUid,
    this.submittedAt,
    this.externalSubmissionStatement,
    this.officialReferenceNumber,
    this.receiptRecordedAt,
    this.lastEventType,
    this.lastEventAt,
  });

  final String submissionId;
  final String submissionNumber;
  final String submissionType;
  final String targetAuthority;
  final String? targetUnit;
  final String? channelType;
  final String? protectionProfileId;
  final String? interventionId;
  final String? caseId;
  final String? legalMatterId;
  final String incidentReference;
  final String title;
  final String authoritySummary;
  final String status;
  final String? humanReviewReference;
  final String? rightsHolderApprovalReference;
  final bool dataMinimizationConfirmed;
  final bool nonAccusatoryLanguageConfirmed;
  final String duplicateCheckKey;
  final String? currentPackageId;
  final int currentPackageVersion;
  final String? currentPackageHash;
  final String preparedByUid;
  final String? reviewedByUid;
  final String? approvedByUid;
  final String? submittedByUid;
  final String? submittedAt;
  final String? externalSubmissionStatement;
  final String? officialReferenceNumber;
  final String? receiptRecordedAt;
  final int packageCount;
  final int responseCount;
  final int eventCount;
  final String? lastEventType;
  final String? lastEventAt;
  final String createdAt;
  final String updatedAt;

  factory CustomsAuthoritySubmission.fromMap(Map<String, dynamic> map) =>
      CustomsAuthoritySubmission(
        submissionId: _string(map, 'submissionId'),
        submissionNumber: _string(map, 'submissionNumber'),
        submissionType: _string(map, 'submissionType'),
        targetAuthority: _string(map, 'targetAuthority'),
        targetUnit: _nullableString(map['targetUnit']),
        channelType: _nullableString(map['channelType']),
        protectionProfileId: _nullableString(map['protectionProfileId']),
        interventionId: _nullableString(map['interventionId']),
        caseId: _nullableString(map['caseId']),
        legalMatterId: _nullableString(map['legalMatterId']),
        incidentReference: _string(map, 'incidentReference'),
        title: _string(map, 'title'),
        authoritySummary: _string(map, 'authoritySummary'),
        status: _string(map, 'status'),
        humanReviewReference: _nullableString(map['humanReviewReference']),
        rightsHolderApprovalReference: _nullableString(
          map['rightsHolderApprovalReference'],
        ),
        dataMinimizationConfirmed: map['dataMinimizationConfirmed'] == true,
        nonAccusatoryLanguageConfirmed:
            map['nonAccusatoryLanguageConfirmed'] == true,
        duplicateCheckKey: _string(map, 'duplicateCheckKey'),
        currentPackageId: _nullableString(map['currentPackageId']),
        currentPackageVersion: _integer(map, 'currentPackageVersion'),
        currentPackageHash: _nullableString(map['currentPackageHash']),
        preparedByUid: _string(map, 'preparedByUid'),
        reviewedByUid: _nullableString(map['reviewedByUid']),
        approvedByUid: _nullableString(map['approvedByUid']),
        submittedByUid: _nullableString(map['submittedByUid']),
        submittedAt: _nullableString(map['submittedAt']),
        externalSubmissionStatement: _nullableString(
          map['externalSubmissionStatement'],
        ),
        officialReferenceNumber: _nullableString(
          map['officialReferenceNumber'],
        ),
        receiptRecordedAt: _nullableString(map['receiptRecordedAt']),
        packageCount: _integer(map, 'packageCount'),
        responseCount: _integer(map, 'responseCount'),
        eventCount: _integer(map, 'eventCount'),
        lastEventType: _nullableString(map['lastEventType']),
        lastEventAt: _nullableString(map['lastEventAt']),
        createdAt: _string(map, 'createdAt'),
        updatedAt: _string(map, 'updatedAt'),
      );
}

class CustomsSubmissionPackage {
  const CustomsSubmissionPackage({
    required this.packageId,
    required this.submissionId,
    required this.version,
    required this.packageType,
    required this.sourceSnapshot,
    required this.documentManifest,
    required this.evidenceManifest,
    required this.redactionManifest,
    required this.coverLetterText,
    required this.authoritySummary,
    required this.legalNeutralityStatement,
    required this.aggregateHashAlgorithm,
    required this.aggregateHash,
    required this.generatedAt,
    required this.generatedByUid,
    required this.immutable,
  });

  final String packageId;
  final String submissionId;
  final int version;
  final String packageType;
  final Map<String, dynamic> sourceSnapshot;
  final List<CustomsSubmissionManifestItem> documentManifest;
  final List<CustomsSubmissionManifestItem> evidenceManifest;
  final List<CustomsSubmissionRedactionItem> redactionManifest;
  final String coverLetterText;
  final String authoritySummary;
  final String legalNeutralityStatement;
  final String aggregateHashAlgorithm;
  final String aggregateHash;
  final String generatedAt;
  final String generatedByUid;
  final bool immutable;

  factory CustomsSubmissionPackage.fromMap(Map<String, dynamic> map) =>
      CustomsSubmissionPackage(
        packageId: _string(map, 'packageId'),
        submissionId: _string(map, 'submissionId'),
        version: _integer(map, 'version'),
        packageType: _string(map, 'packageType'),
        sourceSnapshot: _map(map['sourceSnapshot']),
        documentManifest: _list(map['documentManifest'])
            .map((item) => CustomsSubmissionManifestItem.fromMap(_map(item)))
            .toList(growable: false),
        evidenceManifest: _list(map['evidenceManifest'])
            .map((item) => CustomsSubmissionManifestItem.fromMap(_map(item)))
            .toList(growable: false),
        redactionManifest: _list(map['redactionManifest'])
            .map((item) => CustomsSubmissionRedactionItem.fromMap(_map(item)))
            .toList(growable: false),
        coverLetterText: _string(map, 'coverLetterText'),
        authoritySummary: _string(map, 'authoritySummary'),
        legalNeutralityStatement: _string(map, 'legalNeutralityStatement'),
        aggregateHashAlgorithm: _string(map, 'aggregateHashAlgorithm'),
        aggregateHash: _string(map, 'aggregateHash'),
        generatedAt: _string(map, 'generatedAt'),
        generatedByUid: _string(map, 'generatedByUid'),
        immutable: map['immutable'] == true,
      );
}

class CustomsSubmissionManifestItem {
  const CustomsSubmissionManifestItem({
    required this.referenceId,
    required this.title,
    required this.sha256,
    this.mimeType,
    this.sizeBytes,
  });

  final String referenceId;
  final String title;
  final String sha256;
  final String? mimeType;
  final int? sizeBytes;

  factory CustomsSubmissionManifestItem.fromMap(Map<String, dynamic> map) =>
      CustomsSubmissionManifestItem(
        referenceId: _string(map, 'referenceId'),
        title: _string(map, 'title'),
        sha256: _string(map, 'sha256'),
        mimeType: _nullableString(map['mimeType']),
        sizeBytes: _nullableInteger(map['sizeBytes']),
      );
}

class CustomsSubmissionRedactionItem {
  const CustomsSubmissionRedactionItem({
    required this.fieldPath,
    required this.action,
    required this.reason,
  });

  final String fieldPath;
  final String action;
  final String reason;

  factory CustomsSubmissionRedactionItem.fromMap(Map<String, dynamic> map) =>
      CustomsSubmissionRedactionItem(
        fieldPath: _string(map, 'fieldPath'),
        action: _string(map, 'action'),
        reason: _string(map, 'reason'),
      );
}

class CustomsAuthorityResponse {
  const CustomsAuthorityResponse({
    required this.responseId,
    required this.submissionId,
    required this.responseType,
    required this.receivedAt,
    required this.receivedByUid,
    required this.summary,
    required this.attachmentReferences,
    required this.attachmentHashes,
    required this.immutable,
    this.authorityReference,
    this.requestedDueAt,
    this.outcomeCode,
  });

  final String responseId;
  final String submissionId;
  final String responseType;
  final String? authorityReference;
  final String receivedAt;
  final String receivedByUid;
  final String summary;
  final List<String> attachmentReferences;
  final List<String> attachmentHashes;
  final String? requestedDueAt;
  final String? outcomeCode;
  final bool immutable;

  factory CustomsAuthorityResponse.fromMap(Map<String, dynamic> map) =>
      CustomsAuthorityResponse(
        responseId: _string(map, 'responseId'),
        submissionId: _string(map, 'submissionId'),
        responseType: _string(map, 'responseType'),
        authorityReference: _nullableString(map['authorityReference']),
        receivedAt: _string(map, 'receivedAt'),
        receivedByUid: _string(map, 'receivedByUid'),
        summary: _string(map, 'summary'),
        attachmentReferences: _strings(map['attachmentReferences']),
        attachmentHashes: _strings(map['attachmentHashes']),
        requestedDueAt: _nullableString(map['requestedDueAt']),
        outcomeCode: _nullableString(map['outcomeCode']),
        immutable: map['immutable'] == true,
      );
}

class CustomsAuthoritySubmissionEvent {
  const CustomsAuthoritySubmissionEvent({
    required this.submissionId,
    required this.sequence,
    required this.eventType,
    required this.summary,
    required this.reason,
    required this.actorLabel,
    required this.recordedAt,
    this.previousStatus,
    this.nextStatus,
  });

  final String submissionId;
  final int sequence;
  final String eventType;
  final String? previousStatus;
  final String? nextStatus;
  final String summary;
  final String reason;
  final String actorLabel;
  final String recordedAt;

  factory CustomsAuthoritySubmissionEvent.fromMap(Map<String, dynamic> map) =>
      CustomsAuthoritySubmissionEvent(
        submissionId: _string(map, 'submissionId'),
        sequence: _integer(map, 'sequence'),
        eventType: _string(map, 'eventType'),
        previousStatus: _nullableString(map['previousStatus']),
        nextStatus: _nullableString(map['nextStatus']),
        summary: _string(map, 'summary'),
        reason: _string(map, 'reason'),
        actorLabel: _string(map, 'actorLabel'),
        recordedAt: _string(map, 'recordedAt'),
      );
}

String generateCustomsAuthoritySubmissionRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

void _requireReadResult(Map<String, dynamic> map, String version) {
  if (map['contractVersion'] != version ||
      map['readOnly'] != true ||
      map['writesPerformed'] != 0) {
    throw const FormatException('Geçersiz resmî iletim okuma yanıtı.');
  }
}

void _requireWriteResult(Map<String, dynamic> map, String version) {
  if (map['contractVersion'] != version || map['ok'] != true) {
    throw const FormatException('Geçersiz resmî iletim işlem yanıtı.');
  }
}

bool _present(String? value) => value != null && value.trim().isNotEmpty;

void _optionalText(Map<String, dynamic> map, String key, String? value) {
  if (_present(value)) map[key] = value!.trim();
}

dynamic _normalize(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), _normalize(item)));
  }
  if (value is Iterable) return value.map(_normalize).toList(growable: false);
  return value;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Nesne biçimi geçersiz.');
}

List<dynamic> _list(dynamic value) {
  if (value is List<dynamic>) return value;
  if (value is Iterable) return value.toList(growable: false);
  throw const FormatException('Liste biçimi geçersiz.');
}

List<String> _strings(dynamic value) =>
    _list(value).map((item) => item.toString()).toList(growable: false);

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$key alanı geçersiz.');
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw const FormatException('Metin alanı geçersiz.');
}

int _integer(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('$key alanı geçersiz.');
}

int? _nullableInteger(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw const FormatException('Tam sayı alanı geçersiz.');
}
