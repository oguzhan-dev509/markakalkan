import 'package:markakalkan/features/customs_security/data/customs_security_repository.dart';

CustomsProtectionProfile sampleProfile({
  String status = 'active',
  String profileId = 'profile-1',
}) => CustomsProtectionProfile(
  profileId: profileId,
  profileNumber: 'GKP-2026-ABC12345',
  profileName: 'Bosch Fren Sistemi Gümrük Profili',
  status: status,
  rightHolderName: 'Robert Bosch GmbH',
  rightHolderReferenceIds: const ['TR-MARKA-123'],
  authorizedRepresentativeIds: const [],
  authorizedManufacturerIds: const ['manufacturer-1'],
  authorizedImporterIds: const ['importer-1'],
  protectedProductIds: const ['product-1'],
  hsCodes: const ['870830'],
  productCategories: const ['Otomotiv yedek parça'],
  originCountries: const ['DE'],
  authorizedImportCountries: const ['TR'],
  authenticationInstructions:
      'Ürün seri numarası ve ambalaj güvenlik işaretleri birlikte doğrulanır.',
  serialVerificationMethods: const ['Seri numarası sorgusu'],
  securityFeatureSummaries: const ['Hologram ve parti kodu'],
  counterfeitTwinRecordIds: const ['twin-1'],
  productionAssetIds: const ['asset-1'],
  riskCountryCodes: const ['CN'],
  riskRouteSummaries: const ['Doğu Asya - Türkiye aktarma rotası'],
  emergencyContactIds: const ['contact-1'],
  validFrom: '2026-01-01T00:00:00.000Z',
  validUntil: '2027-01-01T00:00:00.000Z',
  reviewDueAt: '2026-10-01T00:00:00.000Z',
  eventCount: 3,
  lastEventType: 'protection_profile_status_transitioned',
  lastEventAt: '2026-07-25T08:00:00.000Z',
  createdAt: '2026-07-25T07:00:00.000Z',
  updatedAt: '2026-07-25T08:00:00.000Z',
);

CustomsBorderIntervention sampleIntervention({
  String status = 'under_preliminary_review',
  String interventionId = 'intervention-1',
  String authenticationResult = 'not_started',
  bool integritySignal = false,
}) => CustomsBorderIntervention(
  interventionId: interventionId,
  interventionNumber: 'SGM-2026-ABC12345',
  protectionProfileId: 'profile-1',
  status: status,
  integrityStatus: integritySignal
      ? 'integrity_signal_detected'
      : 'no_integrity_signal',
  priority: 'high',
  sourceType: 'customs_notification',
  countryCode: 'TR',
  customsAuthorityName: 'İstanbul Gümrük Müdürlüğü',
  borderPointType: 'seaport',
  borderPointName: 'Ambarlı Limanı',
  shipmentReference: 'SHIP-2026-001',
  containerReference: 'CONT-001',
  cargoReference: null,
  trackingReferences: const ['TRACK-1'],
  senderParty: null,
  recipientParty: null,
  importerParty: null,
  carrierParty: null,
  customsBrokerParty: null,
  declaredProductDescription: 'Binek araç fren balatası',
  declaredHsCode: '870830',
  declaredQuantity: 500,
  declaredUnit: 'unit',
  declaredValue: null,
  declaredCurrency: null,
  suspectedProductIds: const ['product-1'],
  counterfeitTwinRecordIds: const ['twin-1'],
  supplyPartnerIds: const [],
  supplyFacilityIds: const [],
  productionAssetIds: const [],
  sourceRiskSignalIds: const ['risk-1'],
  detainedAt: null,
  notificationReceivedAt: '2026-07-25T07:00:00.000Z',
  responseDeadlineAt: '2026-07-28T23:59:59.000Z',
  actionDeadlineAt: '2026-07-30T23:59:59.000Z',
  suspicionReasons: const ['Ambalaj güvenlik işareti uyuşmuyor'],
  authenticationResult: authenticationResult,
  decisionSummary: null,
  decisionReason: null,
  caseId: null,
  legalMatterId: null,
  assignedUserUid: null,
  reviewerUserUid: null,
  approvedByUid: null,
  unusualReleaseFlag: integritySignal,
  decisionEvidenceMismatchFlag: false,
  missingRecordOrSampleFlag: false,
  postRecordModificationFlag: false,
  unexplainedAccelerationFlag: false,
  quantityOrDestructionMismatchFlag: false,
  independentReviewRequired: integritySignal,
  eventCount: 2,
  lastEventType: 'border_intervention_status_transitioned',
  lastEventAt: '2026-07-25T08:00:00.000Z',
  createdAt: '2026-07-25T07:00:00.000Z',
  updatedAt: '2026-07-25T08:00:00.000Z',
);

CustomsSecurityEvent sampleEvent({int sequence = 1}) => CustomsSecurityEvent(
  entityType: 'border_intervention',
  entityId: 'intervention-1',
  protectionProfileId: 'profile-1',
  interventionId: 'intervention-1',
  sequence: sequence,
  eventType: sequence == 1
      ? 'border_intervention_created'
      : 'border_intervention_status_transitioned',
  previousStatus: sequence == 1 ? null : 'draft',
  nextStatus: sequence == 1 ? 'draft' : 'under_preliminary_review',
  summary: sequence == 1
      ? 'Sınır müdahale dosyası oluşturuldu.'
      : 'Dosya ön incelemeye alındı.',
  reason: sequence == 1
      ? 'İlk taslak kaydı.'
      : 'Gümrük bildirimi ön inceleme gerektiriyor.',
  actorLabel: 'Yetkili kullanıcı',
  recordedAt: '2026-07-25T0${6 + sequence}:00:00.000Z',
);

class FakeCustomsSecurityRepository implements CustomsSecurityRepository {
  FakeCustomsSecurityRepository({
    List<CustomsProtectionProfile>? profiles,
    List<CustomsBorderIntervention>? interventions,
  }) : profiles = profiles ?? [sampleProfile()],
       interventions = interventions ?? [sampleIntervention()];

  List<CustomsProtectionProfile> profiles;
  List<CustomsBorderIntervention> interventions;
  int createProfileCalls = 0;
  int createAndActivateProfileCalls = 0;
  int createInterventionCalls = 0;
  int transitionProfileCalls = 0;
  int transitionInterventionCalls = 0;
  CustomsProtectionProfileDraft? lastProfileDraft;
  final List<String> activationRequestIds = [];
  Object? createAndActivateError;
  bool createAndActivateFailsOnce = false;
  bool createAndActivateDuplicate = false;
  CustomsBorderInterventionDraft? lastInterventionDraft;
  String? lastNextStatus;
  String? lastReason;
  String? lastDecisionReference;
  String? lastHumanAssessmentReference;
  String? lastAuthorityReference;

  @override
  Future<CustomsProtectionProfileList> listProfiles({
    String? status,
    String? pageToken,
    int pageSize = 25,
  }) async {
    final items = status == null
        ? profiles
        : profiles.where((item) => item.status == status).toList();
    return CustomsProtectionProfileList(items: items, nextPageToken: null);
  }

  @override
  Future<CustomsProtectionProfile> createProfile(
    CustomsProtectionProfileDraft draft,
  ) async {
    createProfileCalls++;
    lastProfileDraft = draft;
    final created = sampleProfile(
      status: 'draft',
      profileId: 'profile-created',
    );
    profiles = [...profiles, created];
    return created;
  }

  @override
  Future<CustomsProtectionProfileCreateAndActivateResult>
  createAndActivateProfile(
    CustomsProtectionProfileDraft draft, {
    required String requestId,
  }) async {
    createAndActivateProfileCalls++;
    activationRequestIds.add(requestId);
    lastProfileDraft = draft;
    final error = createAndActivateError;
    if (error != null &&
        (!createAndActivateFailsOnce || createAndActivateProfileCalls == 1)) {
      throw error;
    }
    final created = sampleProfile(
      status: 'active',
      profileId: 'profile-activated',
    );
    profiles = [...profiles, created];
    return CustomsProtectionProfileCreateAndActivateResult(
      profile: created,
      duplicate: createAndActivateDuplicate,
      transactionApplied: !createAndActivateDuplicate,
    );
  }

  @override
  Future<CustomsProtectionProfileDetail> getProfileDetail(
    String profileId,
  ) async => CustomsProtectionProfileDetail(
    profile: profiles.firstWhere((item) => item.profileId == profileId),
  );

  @override
  Future<CustomsProtectionProfile> transitionProfile({
    required String profileId,
    required String nextStatus,
    required String reason,
  }) async {
    transitionProfileCalls++;
    lastNextStatus = nextStatus;
    lastReason = reason;
    final updated = sampleProfile(status: nextStatus, profileId: profileId);
    profiles = [
      for (final item in profiles)
        if (item.profileId == profileId) updated else item,
    ];
    return updated;
  }

  @override
  Future<CustomsBorderInterventionList> listInterventions({
    String? status,
    String? protectionProfileId,
    String? pageToken,
    int pageSize = 25,
  }) async {
    var items = interventions;
    if (status != null) {
      items = items.where((item) => item.status == status).toList();
    }
    if (protectionProfileId != null) {
      items = items
          .where((item) => item.protectionProfileId == protectionProfileId)
          .toList();
    }
    return CustomsBorderInterventionList(items: items, nextPageToken: null);
  }

  @override
  Future<CustomsBorderIntervention> createIntervention(
    CustomsBorderInterventionDraft draft,
  ) async {
    createInterventionCalls++;
    lastInterventionDraft = draft;
    final created = sampleIntervention(
      status: 'draft',
      interventionId: 'intervention-created',
    );
    interventions = [...interventions, created];
    return created;
  }

  @override
  Future<CustomsBorderInterventionDetail> getInterventionDetail(
    String interventionId,
  ) async => CustomsBorderInterventionDetail(
    intervention: interventions.firstWhere(
      (item) => item.interventionId == interventionId,
    ),
    events: [sampleEvent(), sampleEvent(sequence: 2)],
    integrityStatus: 'verified',
  );

  @override
  Future<CustomsBorderIntervention> transitionIntervention({
    required String interventionId,
    required String nextStatus,
    required String reason,
    String? decisionReference,
    String? humanAssessmentReference,
    String? authorityReference,
  }) async {
    transitionInterventionCalls++;
    lastNextStatus = nextStatus;
    lastReason = reason;
    lastDecisionReference = decisionReference;
    lastHumanAssessmentReference = humanAssessmentReference;
    lastAuthorityReference = authorityReference;
    final current = interventions.firstWhere(
      (item) => item.interventionId == interventionId,
    );
    final updated = sampleIntervention(
      status: nextStatus,
      interventionId: interventionId,
      authenticationResult: current.authenticationResult,
      integritySignal: current.hasIntegritySignal,
    );
    interventions = [
      for (final item in interventions)
        if (item.interventionId == interventionId) updated else item,
    ];
    return updated;
  }
}
