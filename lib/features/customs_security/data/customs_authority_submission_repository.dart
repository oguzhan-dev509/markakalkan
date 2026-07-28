import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

typedef CustomsAuthorityCallable =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> request,
    );

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

  Future<CustomsPackageGenerationResult> generatePackage({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsSubmissionPackageDraft draft,
    required String requestId,
  });

  Future<CustomsExternalSubmissionResult> recordExternalSubmission({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required String packageId,
    required int packageVersion,
    required String packageHash,
    required CustomsExternalSubmissionDraft draft,
    required String requestId,
  });

  Future<CustomsSubmissionReceiptResult> recordReceipt({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsSubmissionReceiptDraft draft,
    required String requestId,
  });

  Future<CustomsAuthorityResponseAppendResult> appendAuthorityResponse({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityResponseDraft draft,
    required String requestId,
  });

  Future<CustomsAuthorityOutcomeResult> recordAuthorityOutcome({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityOutcomeDraft draft,
    required String requestId,
  });

  Future<CustomsPackageMaterializationResult> materializePackageArtifact({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required String packageId,
    required String requestId,
  });

  Future<CustomsPackageDownloadAuthorization> authorizePackageDownload({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required String packageId,
    required CustomsArtifactType artifactType,
    required String requestId,
  });
}

class CallableCustomsAuthoritySubmissionRepository
    implements CustomsAuthoritySubmissionRepository {
  CallableCustomsAuthoritySubmissionRepository({
    FirebaseFunctions? functions,
    String Function()? requestIdFactory,
    Future<void> Function()? ensureAppCheckReady,
    CustomsAuthorityCallable? callable,
  }) : _functions = callable == null
           ? functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3')
           : null,
       _requestIdFactory =
           requestIdFactory ?? generateCustomsAuthoritySubmissionRequestId,
       _ensureAppCheckReady =
           ensureAppCheckReady ?? AppCheckBootstrap.instance.ensureReady,
       _callable = callable;

  final FirebaseFunctions? _functions;
  final String Function() _requestIdFactory;
  final Future<void> Function() _ensureAppCheckReady;
  final CustomsAuthorityCallable? _callable;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> request,
  ) async {
    final injected = _callable;
    if (injected != null) return injected(name, request);
    final result = await _functions!.httpsCallable(name).call(request);
    return _map(_normalize(result.data));
  }

  Future<Map<String, dynamic>> _callProtected(
    String name,
    Map<String, dynamic> request,
  ) async {
    await _ensureAppCheckReady();
    return _call(name, request);
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
    final response = await _callProtected('createCustomsAuthoritySubmission', {
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
    final response = await _callProtected('updateCustomsAuthoritySubmission', {
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
    final response = await _callProtected(
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

  @override
  Future<CustomsPackageGenerationResult> generatePackage({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsSubmissionPackageDraft draft,
    required String requestId,
  }) async {
    final response = await _callProtected('generateCustomsSubmissionPackage', {
      'contractVersion': 'customs-submission-package-generate-request-v1',
      'tenantId': tenantId,
      'canonicalBrandId': canonicalBrandId,
      'submissionId': submissionId,
      ...draft.toRequestMap(),
      'requestId': requestId,
    });
    return CustomsPackageGenerationResult.fromMap(response);
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
    final response = await _callProtected('recordCustomsExternalSubmission', {
      'contractVersion': 'customs-external-submission-record-request-v1',
      'tenantId': tenantId,
      'canonicalBrandId': canonicalBrandId,
      'submissionId': submissionId,
      'packageId': packageId,
      'packageVersion': packageVersion,
      'packageHash': packageHash,
      ...draft.toRequestMap(),
      'requestId': requestId,
    });
    return CustomsExternalSubmissionResult.fromMap(response);
  }

  @override
  Future<CustomsSubmissionReceiptResult> recordReceipt({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsSubmissionReceiptDraft draft,
    required String requestId,
  }) async {
    final response = await _callProtected('recordCustomsSubmissionReceipt', {
      'contractVersion': 'customs-submission-receipt-record-request-v1',
      'tenantId': tenantId,
      'canonicalBrandId': canonicalBrandId,
      'submissionId': submissionId,
      ...draft.toRequestMap(),
      'requestId': requestId,
    });
    return CustomsSubmissionReceiptResult.fromMap(response);
  }

  @override
  Future<CustomsAuthorityResponseAppendResult> appendAuthorityResponse({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityResponseDraft draft,
    required String requestId,
  }) async {
    final response = await _callProtected('appendCustomsAuthorityResponse', {
      'contractVersion': 'customs-authority-response-append-request-v1',
      'tenantId': tenantId,
      'canonicalBrandId': canonicalBrandId,
      'submissionId': submissionId,
      ...draft.toRequestMap(),
      'requestId': requestId,
    });
    return CustomsAuthorityResponseAppendResult.fromMap(response);
  }

  @override
  Future<CustomsAuthorityOutcomeResult> recordAuthorityOutcome({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityOutcomeDraft draft,
    required String requestId,
  }) async {
    final response = await _callProtected('recordCustomsAuthorityOutcome', {
      'contractVersion': 'customs-authority-outcome-record-request-v1',
      'tenantId': tenantId,
      'canonicalBrandId': canonicalBrandId,
      'submissionId': submissionId,
      ...draft.toRequestMap(),
      'requestId': requestId,
    });
    return CustomsAuthorityOutcomeResult.fromMap(response);
  }

  @override
  Future<CustomsPackageMaterializationResult> materializePackageArtifact({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required String packageId,
    required String requestId,
  }) async {
    final response =
        await _callProtected('materializeCustomsSubmissionPackageArtifact', {
          'contractVersion':
              'customs-submission-package-artifact-materialize-request-v1',
          'tenantId': tenantId,
          'canonicalBrandId': canonicalBrandId,
          'submissionId': submissionId,
          'packageId': packageId,
          'requestId': requestId,
        });
    return CustomsPackageMaterializationResult.fromMap(response);
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
    final response =
        await _callProtected('authorizeCustomsSubmissionPackageDownload', {
          'contractVersion':
              'customs-submission-package-download-authorize-request-v1',
          'tenantId': tenantId,
          'canonicalBrandId': canonicalBrandId,
          'submissionId': submissionId,
          'packageId': packageId,
          'artifactType': artifactType.wireValue,
          'requestId': requestId,
        });
    final authorization = CustomsPackageDownloadAuthorization.fromMap(response);
    if (authorization.artifactType != artifactType) {
      throw const FormatException('İndirme artifact türü eşleşmiyor.');
    }
    return authorization;
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
  Future<CustomsPackageGenerationResult> generatePackage({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsSubmissionPackageDraft draft,
    required String requestId,
  }) async => _unsupported();

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
  }) async => _unsupported();

  @override
  Future<CustomsSubmissionReceiptResult> recordReceipt({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsSubmissionReceiptDraft draft,
    required String requestId,
  }) async => _unsupported();

  @override
  Future<CustomsAuthorityResponseAppendResult> appendAuthorityResponse({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityResponseDraft draft,
    required String requestId,
  }) async => _unsupported();

  @override
  Future<CustomsAuthorityOutcomeResult> recordAuthorityOutcome({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required CustomsAuthorityOutcomeDraft draft,
    required String requestId,
  }) async => _unsupported();

  @override
  Future<CustomsPackageMaterializationResult> materializePackageArtifact({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required String packageId,
    required String requestId,
  }) async => _unsupported();

  @override
  Future<CustomsPackageDownloadAuthorization> authorizePackageDownload({
    required String tenantId,
    required String canonicalBrandId,
    required String submissionId,
    required String packageId,
    required CustomsArtifactType artifactType,
    required String requestId,
  }) async => _unsupported();

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

enum CustomsArtifactType {
  pdf('pdf'),
  jsonManifest('json_manifest');

  const CustomsArtifactType(this.wireValue);
  final String wireValue;
}

enum CustomsSubmissionArtifactStatus {
  legacyNotMaterialized,
  materializationPending,
  materializing,
  ready,
  failedRecoverable,
  integrityFailed,
  disabled,
  unknown;

  static CustomsSubmissionArtifactStatus parse(Object? value) =>
      switch (value) {
        'legacy_not_materialized' => legacyNotMaterialized,
        'materialization_pending' => materializationPending,
        'materializing' => materializing,
        'ready' => ready,
        'failed_recoverable' => failedRecoverable,
        'integrity_failed' => integrityFailed,
        'disabled' => disabled,
        null => legacyNotMaterialized,
        _ => unknown,
      };
}

class CustomsAuthoritySubmissionArtifactScope {
  const CustomsAuthoritySubmissionArtifactScope({
    required this.contractVersion,
    required this.tenantId,
    required this.canonicalBrandId,
  });

  final String contractVersion;
  final String tenantId;
  final String canonicalBrandId;

  static CustomsAuthoritySubmissionArtifactScope? tryParse(Object? value) {
    if (value is! Map) return null;
    final map = _map(value);
    if (map['contractVersion'] !=
        'customs-authority-submission-artifact-scope-v1') {
      return null;
    }
    final tenantId = _safeBoundedText(map['tenantId']);
    final brandId = _safeBoundedText(map['canonicalBrandId']);
    if (tenantId == null || brandId == null) return null;
    return CustomsAuthoritySubmissionArtifactScope(
      contractVersion: map['contractVersion'] as String,
      tenantId: tenantId,
      canonicalBrandId: brandId,
    );
  }
}

class CustomsSubmissionArtifactDescriptor {
  const CustomsSubmissionArtifactDescriptor({
    required this.ready,
    this.contentType,
    this.sizeBytes,
    this.sha256,
    this.safeFileName,
  });

  final bool ready;
  final String? contentType;
  final int? sizeBytes;
  final String? sha256;
  final String? safeFileName;

  static CustomsSubmissionArtifactDescriptor? tryParse(Object? value) {
    if (value is! Map) return null;
    final map = _map(value);
    return CustomsSubmissionArtifactDescriptor(
      ready: map['ready'] == true,
      contentType: _nullableString(map['contentType']),
      sizeBytes: _nullableInteger(map['sizeBytes']),
      sha256: _nullableString(map['sha256']),
      safeFileName: _nullableString(map['safeFileName']),
    );
  }
}

class CustomsPackageMaterializationResult {
  const CustomsPackageMaterializationResult({
    required this.contractVersion,
    required this.ok,
    required this.duplicate,
    required this.transactionApplied,
    required this.recovered,
    required this.artifactStatus,
    required this.submissionId,
    required this.packageId,
    required this.packageVersion,
    required this.sourcePackageHash,
  });

  final String contractVersion;
  final bool ok;
  final bool duplicate;
  final bool transactionApplied;
  final bool recovered;
  final CustomsSubmissionArtifactStatus artifactStatus;
  final String submissionId;
  final String packageId;
  final int packageVersion;
  final String sourcePackageHash;

  factory CustomsPackageMaterializationResult.fromMap(
    Map<String, dynamic> map,
  ) {
    const version = 'customs-submission-package-artifact-materialize-result-v1';
    final status = CustomsSubmissionArtifactStatus.parse(map['artifactStatus']);
    if (map['contractVersion'] != version ||
        map['ok'] != true ||
        map['duplicate'] is! bool ||
        map['transactionApplied'] is! bool ||
        map['recovered'] is! bool ||
        status == CustomsSubmissionArtifactStatus.unknown ||
        status == CustomsSubmissionArtifactStatus.legacyNotMaterialized) {
      throw const FormatException('Geçersiz paket oluşturma yanıtı.');
    }
    return CustomsPackageMaterializationResult(
      contractVersion: version,
      ok: true,
      duplicate: map['duplicate'] == true,
      transactionApplied: map['transactionApplied'] == true,
      recovered: map['recovered'] == true,
      artifactStatus: status,
      submissionId: _string(map, 'submissionId'),
      packageId: _string(map, 'packageId'),
      packageVersion: _integer(map, 'packageVersion'),
      sourcePackageHash: _string(map, 'sourcePackageHash'),
    );
  }
}

class CustomsPackageDownloadAuthorization {
  const CustomsPackageDownloadAuthorization({
    required this.contractVersion,
    required this.artifactType,
    required this.downloadUri,
    required this.expiresAt,
    required this.safeFileName,
    required this.contentType,
    required this.sizeBytes,
    required this.sha256,
    required this.generation,
    required this.sourcePackageHash,
  });

  final String contractVersion;
  final CustomsArtifactType artifactType;
  final Uri downloadUri;
  final String expiresAt;
  final String safeFileName;
  final String contentType;
  final int sizeBytes;
  final String generation;
  final String sha256;
  final String sourcePackageHash;

  factory CustomsPackageDownloadAuthorization.fromMap(
    Map<String, dynamic> map,
  ) {
    const version = 'customs-submission-package-download-authorize-result-v1';
    if (map['contractVersion'] != version || map['ok'] != true) {
      throw const FormatException('Geçersiz paket indirme yanıtı.');
    }
    final type = switch (map['artifactType']) {
      'pdf' => CustomsArtifactType.pdf,
      'json_manifest' => CustomsArtifactType.jsonManifest,
      _ => throw const FormatException('Artifact türü geçersiz.'),
    };
    final uri = Uri.tryParse(_string(map, 'downloadUrl'));
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('İndirme bağlantısı geçersiz.');
    }
    return CustomsPackageDownloadAuthorization(
      contractVersion: version,
      artifactType: type,
      downloadUri: uri,
      expiresAt: _string(map, 'expiresAt'),
      safeFileName: _string(map, 'safeFileName'),
      contentType: _string(map, 'contentType'),
      sizeBytes: _integer(map, 'sizeBytes'),
      sha256: _string(map, 'sha256'),
      generation: _string(map, 'generation'),
      sourcePackageHash: _string(map, 'sourcePackageHash'),
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
    this.artifactScope,
  });

  final CustomsAuthoritySubmission submission;
  final List<CustomsSubmissionPackage> packages;
  final List<CustomsAuthorityResponse> responses;
  final List<CustomsAuthoritySubmissionEvent> events;
  final String integrityStatus;
  final CustomsAuthoritySubmissionArtifactScope? artifactScope;

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
      artifactScope: CustomsAuthoritySubmissionArtifactScope.tryParse(
        map['scope'],
      ),
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
    this.externalReferenceType,
    this.externalReferenceValue,
    this.officialReferenceNumber,
    this.receiptRecordedAt,
    this.outcomeResponseId,
    this.outcomeCode,
    this.outcomeFinalityLevel,
    this.authorityReferenceNumber,
    this.officialDocumentDate,
    this.outcomeReceivedAt,
    this.outcomeRecordedAt,
    this.authorityNameSnapshot,
    this.authorityUnitSnapshot,
    this.outcomeSummary,
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
  final String? externalReferenceType;
  final String? externalReferenceValue;
  final String? officialReferenceNumber;
  final String? receiptRecordedAt;
  final String? outcomeResponseId;
  final String? outcomeCode;
  final String? outcomeFinalityLevel;
  final String? authorityReferenceNumber;
  final String? officialDocumentDate;
  final String? outcomeReceivedAt;
  final String? outcomeRecordedAt;
  final String? authorityNameSnapshot;
  final String? authorityUnitSnapshot;
  final String? outcomeSummary;
  final int packageCount;
  final int responseCount;
  final int eventCount;
  final String? lastEventType;
  final String? lastEventAt;
  final String createdAt;
  final String updatedAt;

  factory CustomsAuthoritySubmission.fromMap(
    Map<String, dynamic> map,
  ) => CustomsAuthoritySubmission(
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
    externalReferenceType: _nullableString(map['externalReferenceType']),
    externalReferenceValue: _nullableString(map['externalReferenceValue']),
    officialReferenceNumber: _nullableString(map['officialReferenceNumber']),
    receiptRecordedAt: _nullableString(map['receiptRecordedAt']),
    outcomeResponseId: _nullableString(map['outcomeResponseId']),
    outcomeCode: _nullableString(map['outcomeCode']),
    outcomeFinalityLevel: _nullableString(map['outcomeFinalityLevel']),
    authorityReferenceNumber: _nullableString(map['authorityReferenceNumber']),
    officialDocumentDate: _nullableString(map['officialDocumentDate']),
    outcomeReceivedAt: _nullableString(map['outcomeReceivedAt']),
    outcomeRecordedAt: _nullableString(map['outcomeRecordedAt']),
    authorityNameSnapshot: _nullableString(map['authorityNameSnapshot']),
    authorityUnitSnapshot: _nullableString(map['authorityUnitSnapshot']),
    outcomeSummary: _nullableString(map['outcomeSummary']),
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
    this.artifactStatus = CustomsSubmissionArtifactStatus.legacyNotMaterialized,
    this.artifactFormatVersion,
    this.sourcePackageHash,
    this.pdfArtifact,
    this.jsonManifestArtifact,
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
  final CustomsSubmissionArtifactStatus artifactStatus;
  final String? artifactFormatVersion;
  final String? sourcePackageHash;
  final CustomsSubmissionArtifactDescriptor? pdfArtifact;
  final CustomsSubmissionArtifactDescriptor? jsonManifestArtifact;

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
        artifactStatus: CustomsSubmissionArtifactStatus.parse(
          map['artifactStatus'],
        ),
        artifactFormatVersion: _nullableString(map['artifactFormatVersion']),
        sourcePackageHash: _nullableString(map['sourcePackageHash']),
        pdfArtifact: CustomsSubmissionArtifactDescriptor.tryParse(
          map['pdfArtifact'],
        ),
        jsonManifestArtifact: CustomsSubmissionArtifactDescriptor.tryParse(
          map['jsonManifestArtifact'],
        ),
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

enum CustomsSubmissionPackageType {
  fsmhApplicationPackage('fsmh_application_package'),
  authorityReferralPackage('authority_referral_package'),
  additionalInformationPackage('additional_information_package');

  const CustomsSubmissionPackageType(this.wireValue);
  final String wireValue;
}

enum CustomsSubmissionChannel {
  fsmhPortal('fsmh_portal'),
  officialOnlineForm('official_online_form'),
  electronicSignature('electronic_signature'),
  registeredEmail('registered_email'),
  physicalDelivery('physical_delivery'),
  telephone136('telephone_136'),
  emergency112('emergency_112'),
  officialCorrespondence('official_correspondence'),
  other('other');

  const CustomsSubmissionChannel(this.wireValue);
  final String wireValue;
}

enum CustomsExternalReferenceType {
  none('none'),
  kepMessageId('kep_message_id'),
  portalTransactionId('portal_transaction_id'),
  physicalDeliveryReference('physical_delivery_reference'),
  officialCorrespondenceReference('official_correspondence_reference'),
  telephoneReference('telephone_reference'),
  otherReference('other_reference');

  const CustomsExternalReferenceType(this.wireValue);
  final String wireValue;
}

enum CustomsInterimAuthorityResponseType {
  acknowledgement('acknowledgement'),
  informationRequest('information_request'),
  statusUpdate('status_update'),
  other('other');

  const CustomsInterimAuthorityResponseType(this.wireValue);
  final String wireValue;
}

enum CustomsFinalAuthorityResponseType {
  decision('decision'),
  closureNotice('closure_notice'),
  rejectionNotice('rejection_notice');

  const CustomsFinalAuthorityResponseType(this.wireValue);
  final String wireValue;
}

enum CustomsAuthorityOutcomeCode {
  pending('pending'),
  acceptedForReview('accepted_for_review'),
  actionTaken('action_taken'),
  temporaryMeasureRecorded('temporary_measure_recorded'),
  goodsDetainedOrSuspended('goods_detained_or_suspended'),
  goodsSeizureReported('goods_seizure_reported'),
  noAction('no_action'),
  referredToOtherAuthority('referred_to_other_authority'),
  additionalProcedureRequired('additional_procedure_required'),
  closed('closed'),
  rejected('rejected'),
  other('other');

  const CustomsAuthorityOutcomeCode(this.wireValue);
  final String wireValue;
}

enum CustomsAuthorityOutcomeFinalityLevel {
  informational('informational'),
  preliminary('preliminary'),
  administrativeFinal('administrative_final'),
  judicialFinal('judicial_final'),
  notStated('not_stated');

  const CustomsAuthorityOutcomeFinalityLevel(this.wireValue);
  final String wireValue;
}

enum CustomsRedactionAction {
  remove('remove'),
  mask('mask'),
  generalize('generalize'),
  retain('retain');

  const CustomsRedactionAction(this.wireValue);
  final String wireValue;
}

extension CustomsSubmissionManifestItemRequestMap
    on CustomsSubmissionManifestItem {
  Map<String, dynamic> toRequestMap() {
    final map = <String, dynamic>{
      'referenceId': referenceId.trim(),
      'title': title.trim(),
      'sha256': sha256.trim().toLowerCase(),
    };
    _optionalText(map, 'mimeType', mimeType);
    if (sizeBytes != null) map['sizeBytes'] = sizeBytes;
    return map;
  }
}

extension CustomsSubmissionRedactionItemRequestMap
    on CustomsSubmissionRedactionItem {
  Map<String, dynamic> toRequestMap() => {
    'fieldPath': fieldPath.trim(),
    'action': action.trim(),
    'reason': reason.trim(),
  };
}

class CustomsSubmissionPackageDraft {
  const CustomsSubmissionPackageDraft({
    required this.packageType,
    required this.coverLetterText,
    required this.authoritySummary,
    required this.legalNeutralityStatement,
    this.documentManifest = const [],
    this.evidenceManifest = const [],
    this.redactionManifest = const [],
  });

  final CustomsSubmissionPackageType packageType;
  final String coverLetterText;
  final String authoritySummary;
  final String legalNeutralityStatement;
  final List<CustomsSubmissionManifestItem> documentManifest;
  final List<CustomsSubmissionManifestItem> evidenceManifest;
  final List<CustomsSubmissionRedactionItem> redactionManifest;

  Map<String, dynamic> toRequestMap() {
    if (documentManifest.isEmpty && evidenceManifest.isEmpty) {
      throw ArgumentError('Paket için en az bir belge veya delil gerekir.');
    }
    return {
      'packageType': packageType.wireValue,
      'coverLetterText': coverLetterText.trim(),
      'authoritySummary': authoritySummary.trim(),
      'legalNeutralityStatement': legalNeutralityStatement.trim(),
      'documentManifest': documentManifest
          .map((item) => item.toRequestMap())
          .toList(growable: false),
      'evidenceManifest': evidenceManifest
          .map((item) => item.toRequestMap())
          .toList(growable: false),
      'redactionManifest': redactionManifest
          .map((item) => item.toRequestMap())
          .toList(growable: false),
    };
  }
}

class CustomsExternalSubmissionDraft {
  const CustomsExternalSubmissionDraft({
    required this.submissionChannel,
    required this.submittedAt,
    required this.externalSubmissionStatement,
    required this.externalReferenceType,
    this.externalReferenceValue,
    this.externalSubmissionConfirmed = false,
  });

  static const confirmationVersion =
      'customs-external-submission-confirmation-v1';

  final CustomsSubmissionChannel submissionChannel;
  final String submittedAt;
  final String externalSubmissionStatement;
  final CustomsExternalReferenceType externalReferenceType;
  final String? externalReferenceValue;
  final bool externalSubmissionConfirmed;

  Map<String, dynamic> toRequestMap() {
    if (!externalSubmissionConfirmed) {
      throw ArgumentError('Dış teslim teyidi gerekir.');
    }
    final map = <String, dynamic>{
      'submissionChannel': submissionChannel.wireValue,
      'submittedAt': submittedAt.trim(),
      'externalSubmissionConfirmation': true,
      'externalSubmissionConfirmationVersion': confirmationVersion,
      'externalSubmissionStatement': externalSubmissionStatement.trim(),
      'externalReferenceType': externalReferenceType.wireValue,
    };
    _optionalText(map, 'externalReferenceValue', externalReferenceValue);
    return map;
  }
}

class CustomsSubmissionReceiptDraft {
  const CustomsSubmissionReceiptDraft({
    required this.officialReferenceNumber,
    required this.receivedAt,
    required this.channelType,
    required this.summary,
    this.receiptDocumentReference,
    this.receiptDocumentHash,
  });

  final String officialReferenceNumber;
  final String receivedAt;
  final CustomsSubmissionChannel channelType;
  final String summary;
  final String? receiptDocumentReference;
  final String? receiptDocumentHash;

  Map<String, dynamic> toRequestMap() {
    final map = <String, dynamic>{
      'officialReferenceNumber': officialReferenceNumber.trim(),
      'receivedAt': receivedAt.trim(),
      'channelType': channelType.wireValue,
      'summary': summary.trim(),
    };
    _optionalText(map, 'receiptDocumentReference', receiptDocumentReference);
    _optionalText(map, 'receiptDocumentHash', receiptDocumentHash);
    return map;
  }
}

class CustomsAuthorityResponseDraft {
  const CustomsAuthorityResponseDraft({
    required this.responseType,
    required this.receivedAt,
    required this.summary,
    this.authorityReference,
    this.attachmentReferences = const [],
    this.attachmentHashes = const [],
    this.requestedDueAt,
    this.outcomeCode,
  });

  final CustomsInterimAuthorityResponseType responseType;
  final String? authorityReference;
  final String receivedAt;
  final String summary;
  final List<String> attachmentReferences;
  final List<String> attachmentHashes;
  final String? requestedDueAt;
  final CustomsAuthorityOutcomeCode? outcomeCode;

  Map<String, dynamic> toRequestMap() {
    if (attachmentReferences.length != attachmentHashes.length) {
      throw ArgumentError('Ek referansları ve hash listeleri eşleşmelidir.');
    }
    final map = <String, dynamic>{
      'responseType': responseType.wireValue,
      'receivedAt': receivedAt.trim(),
      'summary': summary.trim(),
      'attachmentReferences': attachmentReferences
          .map((value) => value.trim())
          .toList(growable: false),
      'attachmentHashes': attachmentHashes
          .map((value) => value.trim().toLowerCase())
          .toList(growable: false),
    };
    _optionalText(map, 'authorityReference', authorityReference);
    _optionalText(map, 'requestedDueAt', requestedDueAt);
    if (outcomeCode != null) map['outcomeCode'] = outcomeCode!.wireValue;
    return map;
  }
}

class CustomsAuthorityOutcomeDraft {
  const CustomsAuthorityOutcomeDraft({
    required this.responseType,
    required this.outcomeCode,
    required this.outcomeFinalityLevel,
    required this.authorityReferenceNumber,
    required this.officialDocumentDate,
    required this.receivedAt,
    required this.authorityNameSnapshot,
    required this.summary,
    this.authorityUnitSnapshot,
    this.previousResponseId,
    this.attachmentReferences = const [],
    this.attachmentHashes = const [],
    this.additionalNotes,
    this.humanEntryConfirmed = false,
  });

  static const humanEntryConfirmationVersion =
      'customs-authority-outcome-human-entry-v1';

  final CustomsFinalAuthorityResponseType responseType;
  final CustomsAuthorityOutcomeCode outcomeCode;
  final CustomsAuthorityOutcomeFinalityLevel outcomeFinalityLevel;
  final String authorityReferenceNumber;
  final String officialDocumentDate;
  final String receivedAt;
  final String authorityNameSnapshot;
  final String? authorityUnitSnapshot;
  final String summary;
  final String? previousResponseId;
  final List<String> attachmentReferences;
  final List<String> attachmentHashes;
  final String? additionalNotes;
  final bool humanEntryConfirmed;

  Map<String, dynamic> toRequestMap() {
    if (!humanEntryConfirmed) {
      throw ArgumentError('Kurum sonucu insan girişi teyidi gerektirir.');
    }
    if (attachmentReferences.length != attachmentHashes.length) {
      throw ArgumentError('Ek referansları ve hash listeleri eşleşmelidir.');
    }
    final map = <String, dynamic>{
      'responseType': responseType.wireValue,
      'outcomeCode': outcomeCode.wireValue,
      'outcomeFinalityLevel': outcomeFinalityLevel.wireValue,
      'authorityReferenceNumber': authorityReferenceNumber.trim(),
      'officialDocumentDate': officialDocumentDate.trim(),
      'receivedAt': receivedAt.trim(),
      'authorityNameSnapshot': authorityNameSnapshot.trim(),
      'summary': summary.trim(),
      'humanEntryConfirmation': true,
      'humanEntryConfirmationVersion': humanEntryConfirmationVersion,
      'attachmentReferences': attachmentReferences
          .map((value) => value.trim())
          .toList(growable: false),
      'attachmentHashes': attachmentHashes
          .map((value) => value.trim().toLowerCase())
          .toList(growable: false),
    };
    _optionalText(map, 'authorityUnitSnapshot', authorityUnitSnapshot);
    _optionalText(map, 'previousResponseId', previousResponseId);
    _optionalText(map, 'additionalNotes', additionalNotes);
    return map;
  }
}

class CustomsPackageGenerationResult {
  const CustomsPackageGenerationResult({
    required this.contractVersion,
    required this.ok,
    required this.duplicate,
    required this.transactionCommitted,
    required this.submission,
    required this.package,
  });

  final String contractVersion;
  final bool ok;
  final bool duplicate;
  final bool transactionCommitted;
  final CustomsAuthoritySubmission submission;
  final CustomsSubmissionPackage package;

  factory CustomsPackageGenerationResult.fromMap(Map<String, dynamic> map) {
    const version = 'customs-submission-package-generate-result-v1';
    _requireMutationEnvelope(map, version, 'transactionCommitted');
    return CustomsPackageGenerationResult(
      contractVersion: version,
      ok: true,
      duplicate: map['duplicate'] == true,
      transactionCommitted: map['transactionCommitted'] == true,
      submission: CustomsAuthoritySubmission.fromMap(_map(map['submission'])),
      package: CustomsSubmissionPackage.fromMap(_map(map['package'])),
    );
  }
}

class CustomsExternalSubmissionResult {
  const CustomsExternalSubmissionResult({
    required this.contractVersion,
    required this.ok,
    required this.duplicate,
    required this.transactionApplied,
    required this.submission,
    required this.event,
  });

  final String contractVersion;
  final bool ok;
  final bool duplicate;
  final bool transactionApplied;
  final CustomsAuthoritySubmission submission;
  final CustomsAuthoritySubmissionEvent event;

  factory CustomsExternalSubmissionResult.fromMap(Map<String, dynamic> map) {
    const version = 'customs-external-submission-record-result-v1';
    _requireMutationEnvelope(map, version, 'transactionApplied');
    return CustomsExternalSubmissionResult(
      contractVersion: version,
      ok: true,
      duplicate: map['duplicate'] == true,
      transactionApplied: map['transactionApplied'] == true,
      submission: CustomsAuthoritySubmission.fromMap(_map(map['submission'])),
      event: CustomsAuthoritySubmissionEvent.fromMap(_map(map['event'])),
    );
  }
}

class CustomsSubmissionReceiptResult {
  const CustomsSubmissionReceiptResult({
    required this.contractVersion,
    required this.ok,
    required this.duplicate,
    required this.transactionCommitted,
    required this.submission,
    required this.response,
  });

  final String contractVersion;
  final bool ok;
  final bool duplicate;
  final bool transactionCommitted;
  final CustomsAuthoritySubmission submission;
  final CustomsAuthorityResponse response;

  factory CustomsSubmissionReceiptResult.fromMap(Map<String, dynamic> map) {
    const version = 'customs-submission-receipt-record-result-v1';
    _requireMutationEnvelope(map, version, 'transactionCommitted');
    return CustomsSubmissionReceiptResult(
      contractVersion: version,
      ok: true,
      duplicate: map['duplicate'] == true,
      transactionCommitted: map['transactionCommitted'] == true,
      submission: CustomsAuthoritySubmission.fromMap(_map(map['submission'])),
      response: CustomsAuthorityResponse.fromMap(_map(map['response'])),
    );
  }
}

class CustomsAuthorityResponseAppendResult {
  const CustomsAuthorityResponseAppendResult({
    required this.contractVersion,
    required this.ok,
    required this.duplicate,
    required this.transactionCommitted,
    required this.submission,
    required this.response,
  });

  final String contractVersion;
  final bool ok;
  final bool duplicate;
  final bool transactionCommitted;
  final CustomsAuthoritySubmission submission;
  final CustomsAuthorityResponse response;

  factory CustomsAuthorityResponseAppendResult.fromMap(
    Map<String, dynamic> map,
  ) {
    const version = 'customs-authority-response-append-result-v1';
    _requireMutationEnvelope(map, version, 'transactionCommitted');
    return CustomsAuthorityResponseAppendResult(
      contractVersion: version,
      ok: true,
      duplicate: map['duplicate'] == true,
      transactionCommitted: map['transactionCommitted'] == true,
      submission: CustomsAuthoritySubmission.fromMap(_map(map['submission'])),
      response: CustomsAuthorityResponse.fromMap(_map(map['response'])),
    );
  }
}

class CustomsAuthorityOutcomeResult {
  const CustomsAuthorityOutcomeResult({
    required this.contractVersion,
    required this.ok,
    required this.duplicate,
    required this.transactionApplied,
    required this.submission,
    required this.response,
    required this.events,
  });

  final String contractVersion;
  final bool ok;
  final bool duplicate;
  final bool transactionApplied;
  final CustomsAuthoritySubmission submission;
  final CustomsAuthorityResponse response;
  final List<CustomsAuthoritySubmissionEvent> events;

  factory CustomsAuthorityOutcomeResult.fromMap(Map<String, dynamic> map) {
    const version = 'customs-authority-outcome-record-result-v1';
    _requireMutationEnvelope(map, version, 'transactionApplied');
    final events = _list(map['events'])
        .map((item) => CustomsAuthoritySubmissionEvent.fromMap(_map(item)))
        .toList(growable: false);
    if (events.length != 2) {
      throw const FormatException('Kurum sonucu olay zinciri geçersiz.');
    }
    return CustomsAuthorityOutcomeResult(
      contractVersion: version,
      ok: true,
      duplicate: map['duplicate'] == true,
      transactionApplied: map['transactionApplied'] == true,
      submission: CustomsAuthoritySubmission.fromMap(_map(map['submission'])),
      response: CustomsAuthorityResponse.fromMap(_map(map['response'])),
      events: events,
    );
  }
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
    this.outcomeFinalityLevel,
    this.officialDocumentDate,
    this.authorityNameSnapshot,
    this.authorityUnitSnapshot,
    this.previousResponseId,
    this.additionalNotes,
    this.attachmentIntegrityStatus,
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
  final String? outcomeFinalityLevel;
  final String? officialDocumentDate;
  final String? authorityNameSnapshot;
  final String? authorityUnitSnapshot;
  final String? previousResponseId;
  final String? additionalNotes;
  final String? attachmentIntegrityStatus;
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
        outcomeFinalityLevel: _nullableString(map['outcomeFinalityLevel']),
        officialDocumentDate: _nullableString(map['officialDocumentDate']),
        authorityNameSnapshot: _nullableString(map['authorityNameSnapshot']),
        authorityUnitSnapshot: _nullableString(map['authorityUnitSnapshot']),
        previousResponseId: _nullableString(map['previousResponseId']),
        additionalNotes: _nullableString(map['additionalNotes']),
        attachmentIntegrityStatus: _nullableString(
          map['attachmentIntegrityStatus'],
        ),
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

void _requireMutationEnvelope(
  Map<String, dynamic> map,
  String version,
  String transactionField,
) {
  if (map['contractVersion'] != version ||
      map['ok'] != true ||
      map['duplicate'] is! bool ||
      map[transactionField] is! bool) {
    throw const FormatException('Geçersiz resmî iletim işlem yanıtı.');
  }
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

String? _safeBoundedText(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 256) return null;
  return trimmed;
}

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
