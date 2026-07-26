import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:markakalkan/core/security/app_check_bootstrap.dart';

typedef CustomsCallable =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> request,
    );

abstract interface class CustomsSecurityRepository {
  Future<CustomsProtectionProfileList> listProfiles({
    String? status,
    String? pageToken,
    int pageSize = 25,
  });

  Future<CustomsProtectionProfile> createProfile(
    CustomsProtectionProfileDraft draft,
  );

  Future<CustomsProtectionProfileCreateAndActivateResult>
  createAndActivateProfile(
    CustomsProtectionProfileDraft draft, {
    required String requestId,
  });

  Future<CustomsProtectionProfileDetail> getProfileDetail(String profileId);

  Future<CustomsProtectionProfile> transitionProfile({
    required String profileId,
    required String nextStatus,
    required String reason,
  });

  Future<CustomsBorderInterventionList> listInterventions({
    String? status,
    String? protectionProfileId,
    String? pageToken,
    int pageSize = 25,
  });

  Future<CustomsBorderIntervention> createIntervention(
    CustomsBorderInterventionDraft draft,
  );

  Future<CustomsBorderInterventionDetail> getInterventionDetail(
    String interventionId,
  );

  Future<CustomsBorderIntervention> transitionIntervention({
    required String interventionId,
    required String nextStatus,
    required String reason,
    String? decisionReference,
    String? humanAssessmentReference,
    String? authorityReference,
  });
}

class CallableCustomsSecurityRepository implements CustomsSecurityRepository {
  CallableCustomsSecurityRepository({
    FirebaseFunctions? functions,
    String Function()? requestIdFactory,
    Future<void> Function()? ensureAppCheckReady,
    CustomsCallable? callable,
  }) : _functions = callable == null
           ? functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3')
           : null,
       _requestIdFactory = requestIdFactory ?? generateCustomsRequestId,
       _ensureAppCheckReady =
           ensureAppCheckReady ?? AppCheckBootstrap.instance.ensureReady,
       _callable = callable;

  final FirebaseFunctions? _functions;
  final String Function() _requestIdFactory;
  final Future<void> Function() _ensureAppCheckReady;
  final CustomsCallable? _callable;

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
  Future<CustomsProtectionProfileList> listProfiles({
    String? status,
    String? pageToken,
    int pageSize = 25,
  }) async {
    final request = <String, dynamic>{
      'contractVersion': 'customs-protection-profile-list-request-v1',
      'pageSize': pageSize,
    };
    if (status != null) request['status'] = status;
    if (pageToken != null) request['pageToken'] = pageToken;
    return CustomsProtectionProfileList.fromMap(
      await _call('listCustomsProtectionProfiles', request),
    );
  }

  @override
  Future<CustomsProtectionProfile> createProfile(
    CustomsProtectionProfileDraft draft,
  ) async {
    final response = await _callProtected('createCustomsProtectionProfile', {
      'contractVersion': 'customs-protection-profile-create-request-v1',
      ...draft.toRequestMap(),
      'requestId': _requestIdFactory(),
    });
    _requireWriteResult(
      response,
      'customs-protection-profile-create-result-v1',
    );
    return CustomsProtectionProfile.fromMap(_map(response['profile']));
  }

  @override
  Future<CustomsProtectionProfileCreateAndActivateResult>
  createAndActivateProfile(
    CustomsProtectionProfileDraft draft, {
    required String requestId,
  }) async {
    final response =
        await _callProtected('createAndActivateCustomsProtectionProfile', {
          'contractVersion':
              'customs-protection-profile-create-and-activate-request-v1',
          ...draft.toRequestMap(),
          'activationConfirmation': true,
          'activationConfirmationVersion':
              'customs-profile-activation-confirmation-v1',
          'activationReason':
              'Profil sahibi, bilgilerin doğru ve güncel olduğunu onaylayarak '
              'profili oluşturup aktifleştirdi.',
          'requestId': requestId,
        });
    if (response['contractVersion'] !=
            'customs-protection-profile-create-and-activate-result-v1' ||
        response['ok'] != true ||
        response['duplicate'] is! bool ||
        response['transactionApplied'] is! bool) {
      throw const FormatException('Geçersiz gümrük güvenliği işlem yanıtı.');
    }
    final duplicate = response['duplicate'] as bool;
    final transactionApplied = response['transactionApplied'] as bool;
    if (duplicate == transactionApplied) {
      throw const FormatException('Geçersiz gümrük güvenliği işlem sonucu.');
    }
    final profile = CustomsProtectionProfile.fromMap(_map(response['profile']));
    if (profile.status != 'active' || profile.eventCount != 3) {
      throw const FormatException(
        'Aktif profil yanıtı güvenli sözleşmeyle eşleşmedi.',
      );
    }
    return CustomsProtectionProfileCreateAndActivateResult(
      profile: profile,
      duplicate: duplicate,
      transactionApplied: transactionApplied,
    );
  }

  @override
  Future<CustomsProtectionProfileDetail> getProfileDetail(
    String profileId,
  ) async {
    return CustomsProtectionProfileDetail.fromMap(
      await _call('getCustomsProtectionProfileDetail', {
        'contractVersion': 'customs-protection-profile-detail-request-v1',
        'profileId': profileId,
      }),
    );
  }

  @override
  Future<CustomsProtectionProfile> transitionProfile({
    required String profileId,
    required String nextStatus,
    required String reason,
  }) async {
    final response =
        await _callProtected('transitionCustomsProtectionProfile', {
          'contractVersion': 'customs-protection-profile-transition-request-v1',
          'profileId': profileId,
          'nextStatus': nextStatus,
          'reason': reason,
          'requestId': _requestIdFactory(),
        });
    _requireWriteResult(
      response,
      'customs-protection-profile-transition-result-v1',
    );
    return CustomsProtectionProfile.fromMap(_map(response['profile']));
  }

  @override
  Future<CustomsBorderInterventionList> listInterventions({
    String? status,
    String? protectionProfileId,
    String? pageToken,
    int pageSize = 25,
  }) async {
    if (status != null && protectionProfileId != null) {
      throw ArgumentError('Durum ve profil filtresi birlikte kullanılamaz.');
    }
    final request = <String, dynamic>{
      'contractVersion': 'customs-border-intervention-list-request-v1',
      'pageSize': pageSize,
    };
    if (status != null) request['status'] = status;
    if (protectionProfileId != null) {
      request['protectionProfileId'] = protectionProfileId;
    }
    if (pageToken != null) request['pageToken'] = pageToken;
    return CustomsBorderInterventionList.fromMap(
      await _call('listCustomsBorderInterventions', request),
    );
  }

  @override
  Future<CustomsBorderIntervention> createIntervention(
    CustomsBorderInterventionDraft draft,
  ) async {
    final response = await _callProtected('createCustomsBorderIntervention', {
      'contractVersion': 'customs-border-intervention-create-request-v1',
      ...draft.toRequestMap(),
      'requestId': _requestIdFactory(),
    });
    _requireWriteResult(
      response,
      'customs-border-intervention-create-result-v1',
    );
    return CustomsBorderIntervention.fromMap(_map(response['intervention']));
  }

  @override
  Future<CustomsBorderInterventionDetail> getInterventionDetail(
    String interventionId,
  ) async {
    return CustomsBorderInterventionDetail.fromMap(
      await _call('getCustomsBorderInterventionDetail', {
        'contractVersion': 'customs-border-intervention-detail-request-v1',
        'interventionId': interventionId,
      }),
    );
  }

  @override
  Future<CustomsBorderIntervention> transitionIntervention({
    required String interventionId,
    required String nextStatus,
    required String reason,
    String? decisionReference,
    String? humanAssessmentReference,
    String? authorityReference,
  }) async {
    final request = <String, dynamic>{
      'contractVersion': 'customs-border-intervention-transition-request-v1',
      'interventionId': interventionId,
      'nextStatus': nextStatus,
      'reason': reason,
      'requestId': _requestIdFactory(),
    };
    if (_present(decisionReference)) {
      request['decisionReference'] = decisionReference!.trim();
    }
    if (_present(humanAssessmentReference)) {
      request['humanAssessmentReference'] = humanAssessmentReference!.trim();
    }
    if (_present(authorityReference)) {
      request['authorityReference'] = authorityReference!.trim();
    }
    final response = await _callProtected(
      'transitionCustomsBorderIntervention',
      request,
    );
    _requireWriteResult(
      response,
      'customs-border-intervention-transition-result-v1',
    );
    return CustomsBorderIntervention.fromMap(_map(response['intervention']));
  }
}

class CustomsProtectionProfileDraft {
  const CustomsProtectionProfileDraft({
    required this.profileName,
    required this.rightHolderName,
    required this.authenticationInstructions,
    this.rightHolderReferenceIds = const [],
    this.authorizedRepresentativeIds = const [],
    this.authorizedManufacturerIds = const [],
    this.authorizedImporterIds = const [],
    this.protectedProductIds = const [],
    this.hsCodes = const [],
    this.productCategories = const [],
    this.originCountries = const [],
    this.authorizedImportCountries = const [],
    this.serialVerificationMethods = const [],
    this.securityFeatureSummaries = const [],
    this.counterfeitTwinRecordIds = const [],
    this.productionAssetIds = const [],
    this.riskCountryCodes = const [],
    this.riskRouteSummaries = const [],
    this.emergencyContactIds = const [],
    this.validFrom,
    this.validUntil,
    this.reviewDueAt,
  });

  final String profileName;
  final String rightHolderName;
  final String authenticationInstructions;
  final List<String> rightHolderReferenceIds;
  final List<String> authorizedRepresentativeIds;
  final List<String> authorizedManufacturerIds;
  final List<String> authorizedImporterIds;
  final List<String> protectedProductIds;
  final List<String> hsCodes;
  final List<String> productCategories;
  final List<String> originCountries;
  final List<String> authorizedImportCountries;
  final List<String> serialVerificationMethods;
  final List<String> securityFeatureSummaries;
  final List<String> counterfeitTwinRecordIds;
  final List<String> productionAssetIds;
  final List<String> riskCountryCodes;
  final List<String> riskRouteSummaries;
  final List<String> emergencyContactIds;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? reviewDueAt;

  Map<String, dynamic> toRequestMap() => <String, dynamic>{
    'profileName': profileName.trim(),
    'rightHolderName': rightHolderName.trim(),
    'rightHolderReferenceIds': rightHolderReferenceIds,
    'authorizedRepresentativeIds': authorizedRepresentativeIds,
    'authorizedManufacturerIds': authorizedManufacturerIds,
    'authorizedImporterIds': authorizedImporterIds,
    'protectedProductIds': protectedProductIds,
    'hsCodes': hsCodes,
    'productCategories': productCategories,
    'originCountries': originCountries,
    'authorizedImportCountries': authorizedImportCountries,
    'authenticationInstructions': authenticationInstructions.trim(),
    'serialVerificationMethods': serialVerificationMethods,
    'securityFeatureSummaries': securityFeatureSummaries,
    'counterfeitTwinRecordIds': counterfeitTwinRecordIds,
    'productionAssetIds': productionAssetIds,
    'riskCountryCodes': riskCountryCodes,
    'riskRouteSummaries': riskRouteSummaries,
    'emergencyContactIds': emergencyContactIds,
    if (validFrom != null) 'validFrom': validFrom!.toUtc().toIso8601String(),
    if (validUntil != null) 'validUntil': validUntil!.toUtc().toIso8601String(),
    if (reviewDueAt != null)
      'reviewDueAt': reviewDueAt!.toUtc().toIso8601String(),
  };
}

class CustomsProtectionProfileCreateAndActivateResult {
  const CustomsProtectionProfileCreateAndActivateResult({
    required this.profile,
    required this.duplicate,
    required this.transactionApplied,
  });

  final CustomsProtectionProfile profile;
  final bool duplicate;
  final bool transactionApplied;
}

class CustomsBorderInterventionDraft {
  const CustomsBorderInterventionDraft({
    required this.protectionProfileId,
    required this.priority,
    required this.sourceType,
    required this.countryCode,
    required this.customsAuthorityName,
    required this.borderPointType,
    required this.borderPointName,
    required this.declaredProductDescription,
    required this.authenticationResult,
    this.shipmentReference,
    this.containerReference,
    this.cargoReference,
    this.trackingReferences = const [],
    this.declaredHsCode,
    this.declaredQuantity,
    this.declaredUnit,
    this.declaredValue,
    this.declaredCurrency,
    this.suspectedProductIds = const [],
    this.counterfeitTwinRecordIds = const [],
    this.supplyPartnerIds = const [],
    this.supplyFacilityIds = const [],
    this.productionAssetIds = const [],
    this.sourceRiskSignalIds = const [],
    this.detainedAt,
    this.notificationReceivedAt,
    this.responseDeadlineAt,
    this.actionDeadlineAt,
    this.suspicionReasons = const [],
    this.decisionSummary,
    this.decisionReason,
    this.caseId,
    this.assignedUserUid,
    this.reviewerUserUid,
    this.unusualReleaseFlag = false,
    this.decisionEvidenceMismatchFlag = false,
    this.missingRecordOrSampleFlag = false,
    this.postRecordModificationFlag = false,
    this.unexplainedAccelerationFlag = false,
    this.quantityOrDestructionMismatchFlag = false,
    this.independentReviewRequired = false,
  });

  final String protectionProfileId;
  final String priority;
  final String sourceType;
  final String countryCode;
  final String customsAuthorityName;
  final String borderPointType;
  final String borderPointName;
  final String declaredProductDescription;
  final String authenticationResult;
  final String? shipmentReference;
  final String? containerReference;
  final String? cargoReference;
  final List<String> trackingReferences;
  final String? declaredHsCode;
  final double? declaredQuantity;
  final String? declaredUnit;
  final double? declaredValue;
  final String? declaredCurrency;
  final List<String> suspectedProductIds;
  final List<String> counterfeitTwinRecordIds;
  final List<String> supplyPartnerIds;
  final List<String> supplyFacilityIds;
  final List<String> productionAssetIds;
  final List<String> sourceRiskSignalIds;
  final DateTime? detainedAt;
  final DateTime? notificationReceivedAt;
  final DateTime? responseDeadlineAt;
  final DateTime? actionDeadlineAt;
  final List<String> suspicionReasons;
  final String? decisionSummary;
  final String? decisionReason;
  final String? caseId;
  final String? assignedUserUid;
  final String? reviewerUserUid;
  final bool unusualReleaseFlag;
  final bool decisionEvidenceMismatchFlag;
  final bool missingRecordOrSampleFlag;
  final bool postRecordModificationFlag;
  final bool unexplainedAccelerationFlag;
  final bool quantityOrDestructionMismatchFlag;
  final bool independentReviewRequired;

  Map<String, dynamic> toRequestMap() {
    final map = <String, dynamic>{
      'protectionProfileId': protectionProfileId,
      'priority': priority,
      'sourceType': sourceType,
      'countryCode': countryCode.trim().toUpperCase(),
      'customsAuthorityName': customsAuthorityName.trim(),
      'borderPointType': borderPointType,
      'borderPointName': borderPointName.trim(),
      'trackingReferences': trackingReferences,
      'declaredProductDescription': declaredProductDescription.trim(),
      'suspectedProductIds': suspectedProductIds,
      'counterfeitTwinRecordIds': counterfeitTwinRecordIds,
      'supplyPartnerIds': supplyPartnerIds,
      'supplyFacilityIds': supplyFacilityIds,
      'productionAssetIds': productionAssetIds,
      'sourceRiskSignalIds': sourceRiskSignalIds,
      'suspicionReasons': suspicionReasons,
      'authenticationResult': authenticationResult,
      'unusualReleaseFlag': unusualReleaseFlag,
      'decisionEvidenceMismatchFlag': decisionEvidenceMismatchFlag,
      'missingRecordOrSampleFlag': missingRecordOrSampleFlag,
      'postRecordModificationFlag': postRecordModificationFlag,
      'unexplainedAccelerationFlag': unexplainedAccelerationFlag,
      'quantityOrDestructionMismatchFlag': quantityOrDestructionMismatchFlag,
      'independentReviewRequired': independentReviewRequired,
    };
    _optionalText(map, 'shipmentReference', shipmentReference);
    _optionalText(map, 'containerReference', containerReference);
    _optionalText(map, 'cargoReference', cargoReference);
    _optionalText(map, 'declaredHsCode', declaredHsCode);
    _optionalText(map, 'declaredUnit', declaredUnit);
    _optionalText(map, 'declaredCurrency', declaredCurrency?.toUpperCase());
    _optionalText(map, 'decisionSummary', decisionSummary);
    _optionalText(map, 'decisionReason', decisionReason);
    _optionalText(map, 'caseId', caseId);
    _optionalText(map, 'assignedUserUid', assignedUserUid);
    _optionalText(map, 'reviewerUserUid', reviewerUserUid);
    if (declaredQuantity != null) map['declaredQuantity'] = declaredQuantity;
    if (declaredValue != null) map['declaredValue'] = declaredValue;
    if (detainedAt != null) {
      map['detainedAt'] = detainedAt!.toUtc().toIso8601String();
    }
    if (notificationReceivedAt != null) {
      map['notificationReceivedAt'] = notificationReceivedAt!
          .toUtc()
          .toIso8601String();
    }
    if (responseDeadlineAt != null) {
      map['responseDeadlineAt'] = responseDeadlineAt!.toUtc().toIso8601String();
    }
    if (actionDeadlineAt != null) {
      map['actionDeadlineAt'] = actionDeadlineAt!.toUtc().toIso8601String();
    }
    return map;
  }
}

class CustomsProtectionProfileList {
  const CustomsProtectionProfileList({
    required this.items,
    required this.nextPageToken,
  });

  final List<CustomsProtectionProfile> items;
  final String? nextPageToken;

  factory CustomsProtectionProfileList.fromMap(Map<String, dynamic> map) {
    _requireReadResult(map, 'customs-protection-profile-list-v1');
    return CustomsProtectionProfileList(
      items: _list(map['items'])
          .map((item) => CustomsProtectionProfile.fromMap(_map(item)))
          .toList(growable: false),
      nextPageToken: _nullableString(map['nextPageToken']),
    );
  }
}

class CustomsProtectionProfileDetail {
  const CustomsProtectionProfileDetail({required this.profile});

  final CustomsProtectionProfile profile;

  factory CustomsProtectionProfileDetail.fromMap(Map<String, dynamic> map) {
    _requireReadResult(map, 'customs-protection-profile-detail-v1');
    return CustomsProtectionProfileDetail(
      profile: CustomsProtectionProfile.fromMap(_map(map['profile'])),
    );
  }
}

class CustomsProtectionProfile {
  const CustomsProtectionProfile({
    required this.profileId,
    required this.profileNumber,
    required this.profileName,
    required this.status,
    required this.rightHolderName,
    required this.rightHolderReferenceIds,
    required this.authorizedRepresentativeIds,
    required this.authorizedManufacturerIds,
    required this.authorizedImporterIds,
    required this.protectedProductIds,
    required this.hsCodes,
    required this.productCategories,
    required this.originCountries,
    required this.authorizedImportCountries,
    required this.authenticationInstructions,
    required this.serialVerificationMethods,
    required this.securityFeatureSummaries,
    required this.counterfeitTwinRecordIds,
    required this.productionAssetIds,
    required this.riskCountryCodes,
    required this.riskRouteSummaries,
    required this.emergencyContactIds,
    required this.eventCount,
    required this.createdAt,
    required this.updatedAt,
    this.validFrom,
    this.validUntil,
    this.reviewDueAt,
    this.lastEventType,
    this.lastEventAt,
  });

  final String profileId;
  final String profileNumber;
  final String profileName;
  final String status;
  final String rightHolderName;
  final List<String> rightHolderReferenceIds;
  final List<String> authorizedRepresentativeIds;
  final List<String> authorizedManufacturerIds;
  final List<String> authorizedImporterIds;
  final List<String> protectedProductIds;
  final List<String> hsCodes;
  final List<String> productCategories;
  final List<String> originCountries;
  final List<String> authorizedImportCountries;
  final String authenticationInstructions;
  final List<String> serialVerificationMethods;
  final List<String> securityFeatureSummaries;
  final List<String> counterfeitTwinRecordIds;
  final List<String> productionAssetIds;
  final List<String> riskCountryCodes;
  final List<String> riskRouteSummaries;
  final List<String> emergencyContactIds;
  final String? validFrom;
  final String? validUntil;
  final String? reviewDueAt;
  final int eventCount;
  final String? lastEventType;
  final String? lastEventAt;
  final String createdAt;
  final String updatedAt;

  factory CustomsProtectionProfile.fromMap(Map<String, dynamic> map) =>
      CustomsProtectionProfile(
        profileId: _string(map, 'profileId'),
        profileNumber: _string(map, 'profileNumber'),
        profileName: _string(map, 'profileName'),
        status: _string(map, 'status'),
        rightHolderName: _string(map, 'rightHolderName'),
        rightHolderReferenceIds: _strings(map['rightHolderReferenceIds']),
        authorizedRepresentativeIds: _strings(
          map['authorizedRepresentativeIds'],
        ),
        authorizedManufacturerIds: _strings(map['authorizedManufacturerIds']),
        authorizedImporterIds: _strings(map['authorizedImporterIds']),
        protectedProductIds: _strings(map['protectedProductIds']),
        hsCodes: _strings(map['hsCodes']),
        productCategories: _strings(map['productCategories']),
        originCountries: _strings(map['originCountries']),
        authorizedImportCountries: _strings(map['authorizedImportCountries']),
        authenticationInstructions: _string(map, 'authenticationInstructions'),
        serialVerificationMethods: _strings(map['serialVerificationMethods']),
        securityFeatureSummaries: _strings(map['securityFeatureSummaries']),
        counterfeitTwinRecordIds: _strings(map['counterfeitTwinRecordIds']),
        productionAssetIds: _strings(map['productionAssetIds']),
        riskCountryCodes: _strings(map['riskCountryCodes']),
        riskRouteSummaries: _strings(map['riskRouteSummaries']),
        emergencyContactIds: _strings(map['emergencyContactIds']),
        validFrom: _nullableString(map['validFrom']),
        validUntil: _nullableString(map['validUntil']),
        reviewDueAt: _nullableString(map['reviewDueAt']),
        eventCount: _integer(map, 'eventCount'),
        lastEventType: _nullableString(map['lastEventType']),
        lastEventAt: _nullableString(map['lastEventAt']),
        createdAt: _string(map, 'createdAt'),
        updatedAt: _string(map, 'updatedAt'),
      );
}

class CustomsBorderInterventionList {
  const CustomsBorderInterventionList({
    required this.items,
    required this.nextPageToken,
  });

  final List<CustomsBorderIntervention> items;
  final String? nextPageToken;

  factory CustomsBorderInterventionList.fromMap(Map<String, dynamic> map) {
    _requireReadResult(map, 'customs-border-intervention-list-v1');
    return CustomsBorderInterventionList(
      items: _list(map['items'])
          .map((item) => CustomsBorderIntervention.fromMap(_map(item)))
          .toList(growable: false),
      nextPageToken: _nullableString(map['nextPageToken']),
    );
  }
}

class CustomsBorderInterventionDetail {
  const CustomsBorderInterventionDetail({
    required this.intervention,
    required this.events,
    required this.integrityStatus,
  });

  final CustomsBorderIntervention intervention;
  final List<CustomsSecurityEvent> events;
  final String integrityStatus;

  factory CustomsBorderInterventionDetail.fromMap(Map<String, dynamic> map) {
    _requireReadResult(map, 'customs-border-intervention-detail-v1');
    return CustomsBorderInterventionDetail(
      intervention: CustomsBorderIntervention.fromMap(
        _map(map['intervention']),
      ),
      events: _list(map['events'])
          .map((item) => CustomsSecurityEvent.fromMap(_map(item)))
          .toList(growable: false),
      integrityStatus: _string(map, 'integrityStatus'),
    );
  }
}

class CustomsBorderIntervention {
  const CustomsBorderIntervention({
    required this.interventionId,
    required this.interventionNumber,
    required this.protectionProfileId,
    required this.status,
    required this.integrityStatus,
    required this.priority,
    required this.sourceType,
    required this.countryCode,
    required this.customsAuthorityName,
    required this.borderPointType,
    required this.borderPointName,
    required this.trackingReferences,
    required this.declaredProductDescription,
    required this.suspectedProductIds,
    required this.counterfeitTwinRecordIds,
    required this.supplyPartnerIds,
    required this.supplyFacilityIds,
    required this.productionAssetIds,
    required this.sourceRiskSignalIds,
    required this.suspicionReasons,
    required this.authenticationResult,
    required this.unusualReleaseFlag,
    required this.decisionEvidenceMismatchFlag,
    required this.missingRecordOrSampleFlag,
    required this.postRecordModificationFlag,
    required this.unexplainedAccelerationFlag,
    required this.quantityOrDestructionMismatchFlag,
    required this.independentReviewRequired,
    required this.eventCount,
    required this.createdAt,
    required this.updatedAt,
    this.shipmentReference,
    this.containerReference,
    this.cargoReference,
    this.senderParty,
    this.recipientParty,
    this.importerParty,
    this.carrierParty,
    this.customsBrokerParty,
    this.declaredHsCode,
    this.declaredQuantity,
    this.declaredUnit,
    this.declaredValue,
    this.declaredCurrency,
    this.detainedAt,
    this.notificationReceivedAt,
    this.responseDeadlineAt,
    this.actionDeadlineAt,
    this.decisionSummary,
    this.decisionReason,
    this.caseId,
    this.legalMatterId,
    this.assignedUserUid,
    this.reviewerUserUid,
    this.approvedByUid,
    this.lastEventType,
    this.lastEventAt,
  });

  final String interventionId;
  final String interventionNumber;
  final String protectionProfileId;
  final String status;
  final String integrityStatus;
  final String priority;
  final String sourceType;
  final String countryCode;
  final String customsAuthorityName;
  final String borderPointType;
  final String borderPointName;
  final String? shipmentReference;
  final String? containerReference;
  final String? cargoReference;
  final List<String> trackingReferences;
  final Map<String, dynamic>? senderParty;
  final Map<String, dynamic>? recipientParty;
  final Map<String, dynamic>? importerParty;
  final Map<String, dynamic>? carrierParty;
  final Map<String, dynamic>? customsBrokerParty;
  final String declaredProductDescription;
  final String? declaredHsCode;
  final double? declaredQuantity;
  final String? declaredUnit;
  final double? declaredValue;
  final String? declaredCurrency;
  final List<String> suspectedProductIds;
  final List<String> counterfeitTwinRecordIds;
  final List<String> supplyPartnerIds;
  final List<String> supplyFacilityIds;
  final List<String> productionAssetIds;
  final List<String> sourceRiskSignalIds;
  final String? detainedAt;
  final String? notificationReceivedAt;
  final String? responseDeadlineAt;
  final String? actionDeadlineAt;
  final List<String> suspicionReasons;
  final String authenticationResult;
  final String? decisionSummary;
  final String? decisionReason;
  final String? caseId;
  final String? legalMatterId;
  final String? assignedUserUid;
  final String? reviewerUserUid;
  final String? approvedByUid;
  final bool unusualReleaseFlag;
  final bool decisionEvidenceMismatchFlag;
  final bool missingRecordOrSampleFlag;
  final bool postRecordModificationFlag;
  final bool unexplainedAccelerationFlag;
  final bool quantityOrDestructionMismatchFlag;
  final bool independentReviewRequired;
  final int eventCount;
  final String? lastEventType;
  final String? lastEventAt;
  final String createdAt;
  final String updatedAt;

  bool get hasIntegritySignal =>
      unusualReleaseFlag ||
      decisionEvidenceMismatchFlag ||
      missingRecordOrSampleFlag ||
      postRecordModificationFlag ||
      unexplainedAccelerationFlag ||
      quantityOrDestructionMismatchFlag ||
      independentReviewRequired;

  factory CustomsBorderIntervention.fromMap(Map<String, dynamic> map) =>
      CustomsBorderIntervention(
        interventionId: _string(map, 'interventionId'),
        interventionNumber: _string(map, 'interventionNumber'),
        protectionProfileId: _string(map, 'protectionProfileId'),
        status: _string(map, 'status'),
        integrityStatus: _string(map, 'integrityStatus'),
        priority: _string(map, 'priority'),
        sourceType: _string(map, 'sourceType'),
        countryCode: _string(map, 'countryCode'),
        customsAuthorityName: _string(map, 'customsAuthorityName'),
        borderPointType: _string(map, 'borderPointType'),
        borderPointName: _string(map, 'borderPointName'),
        shipmentReference: _nullableString(map['shipmentReference']),
        containerReference: _nullableString(map['containerReference']),
        cargoReference: _nullableString(map['cargoReference']),
        trackingReferences: _strings(map['trackingReferences']),
        senderParty: _nullableMap(map['senderParty']),
        recipientParty: _nullableMap(map['recipientParty']),
        importerParty: _nullableMap(map['importerParty']),
        carrierParty: _nullableMap(map['carrierParty']),
        customsBrokerParty: _nullableMap(map['customsBrokerParty']),
        declaredProductDescription: _string(map, 'declaredProductDescription'),
        declaredHsCode: _nullableString(map['declaredHsCode']),
        declaredQuantity: _nullableDouble(map['declaredQuantity']),
        declaredUnit: _nullableString(map['declaredUnit']),
        declaredValue: _nullableDouble(map['declaredValue']),
        declaredCurrency: _nullableString(map['declaredCurrency']),
        suspectedProductIds: _strings(map['suspectedProductIds']),
        counterfeitTwinRecordIds: _strings(map['counterfeitTwinRecordIds']),
        supplyPartnerIds: _strings(map['supplyPartnerIds']),
        supplyFacilityIds: _strings(map['supplyFacilityIds']),
        productionAssetIds: _strings(map['productionAssetIds']),
        sourceRiskSignalIds: _strings(map['sourceRiskSignalIds']),
        detainedAt: _nullableString(map['detainedAt']),
        notificationReceivedAt: _nullableString(map['notificationReceivedAt']),
        responseDeadlineAt: _nullableString(map['responseDeadlineAt']),
        actionDeadlineAt: _nullableString(map['actionDeadlineAt']),
        suspicionReasons: _strings(map['suspicionReasons']),
        authenticationResult: _string(map, 'authenticationResult'),
        decisionSummary: _nullableString(map['decisionSummary']),
        decisionReason: _nullableString(map['decisionReason']),
        caseId: _nullableString(map['caseId']),
        legalMatterId: _nullableString(map['legalMatterId']),
        assignedUserUid: _nullableString(map['assignedUserUid']),
        reviewerUserUid: _nullableString(map['reviewerUserUid']),
        approvedByUid: _nullableString(map['approvedByUid']),
        unusualReleaseFlag: map['unusualReleaseFlag'] == true,
        decisionEvidenceMismatchFlag:
            map['decisionEvidenceMismatchFlag'] == true,
        missingRecordOrSampleFlag: map['missingRecordOrSampleFlag'] == true,
        postRecordModificationFlag: map['postRecordModificationFlag'] == true,
        unexplainedAccelerationFlag: map['unexplainedAccelerationFlag'] == true,
        quantityOrDestructionMismatchFlag:
            map['quantityOrDestructionMismatchFlag'] == true,
        independentReviewRequired: map['independentReviewRequired'] == true,
        eventCount: _integer(map, 'eventCount'),
        lastEventType: _nullableString(map['lastEventType']),
        lastEventAt: _nullableString(map['lastEventAt']),
        createdAt: _string(map, 'createdAt'),
        updatedAt: _string(map, 'updatedAt'),
      );
}

class CustomsSecurityEvent {
  const CustomsSecurityEvent({
    required this.entityType,
    required this.entityId,
    required this.sequence,
    required this.eventType,
    required this.summary,
    required this.reason,
    required this.actorLabel,
    required this.recordedAt,
    this.protectionProfileId,
    this.interventionId,
    this.previousStatus,
    this.nextStatus,
  });

  final String entityType;
  final String entityId;
  final String? protectionProfileId;
  final String? interventionId;
  final int sequence;
  final String eventType;
  final String? previousStatus;
  final String? nextStatus;
  final String summary;
  final String reason;
  final String actorLabel;
  final String recordedAt;

  factory CustomsSecurityEvent.fromMap(Map<String, dynamic> map) =>
      CustomsSecurityEvent(
        entityType: _string(map, 'entityType'),
        entityId: _string(map, 'entityId'),
        protectionProfileId: _nullableString(map['protectionProfileId']),
        interventionId: _nullableString(map['interventionId']),
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

String generateCustomsRequestId() {
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
    throw const FormatException('Geçersiz gümrük güvenliği yanıtı.');
  }
}

void _requireWriteResult(Map<String, dynamic> map, String version) {
  if (map['contractVersion'] != version || map['ok'] != true) {
    throw const FormatException('Geçersiz gümrük güvenliği işlem yanıtı.');
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

Map<String, dynamic>? _nullableMap(dynamic value) {
  if (value == null) return null;
  return _map(value);
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

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw const FormatException('Sayısal alan geçersiz.');
}
