import 'package:cloud_functions/cloud_functions.dart';

const String odlaDiscoveryContractVersion = 'odla-workspace-discovery-v1';
const String odlaDetailContractVersion = 'odla-workspace-detail-v1';
const String odlaCustodyIntegrityContextContractVersion =
    'odla-custody-integrity-context-v1';
const String odlaLaboratoryRegistryContextContractVersion =
    'odla-workspace-laboratory-registry-context-v1';
const String odlaWorkspaceCallableName = 'getOdlaVerificationWorkspace';

typedef OdlaCallable =
    Future<Object?> Function(String name, Map<String, Object?> request);

abstract interface class OdlaWorkspaceRepository {
  Future<OdlaDiscoverySnapshot> loadDiscovery();
  Future<OdlaWorkspaceDetail> loadWorkspace(OdlaCaseSummary summary);
}

final class CallableOdlaWorkspaceRepository implements OdlaWorkspaceRepository {
  CallableOdlaWorkspaceRepository({
    FirebaseFunctions? functions,
    OdlaCallable? callable,
  }) : _functions = callable == null
           ? functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3')
           : null,
       _callable = callable;

  final FirebaseFunctions? _functions;
  final OdlaCallable? _callable;

  Future<Object?> _call(Map<String, Object?> request) async {
    final injected = _callable;
    if (injected != null) {
      return injected(odlaWorkspaceCallableName, request);
    }
    final result = await _functions!
        .httpsCallable(odlaWorkspaceCallableName)
        .call(request);
    return result.data;
  }

  @override
  Future<OdlaDiscoverySnapshot> loadDiscovery() async {
    final raw = await _call(<String, Object?>{});
    return OdlaDiscoverySnapshot.fromMap(_requiredMap(raw, r'$'));
  }

  @override
  Future<OdlaWorkspaceDetail> loadWorkspace(OdlaCaseSummary summary) async {
    final raw = await _call(<String, Object?>{
      'caseId': summary.caseId,
      'tenantId': summary.tenantId,
      'brandUid': summary.brandUid,
    });
    return OdlaWorkspaceDetail.fromMap(_requiredMap(raw, r'$'));
  }
}

final class OdlaDiscoverySnapshot {
  const OdlaDiscoverySnapshot({
    required this.tenantId,
    required this.brandUids,
    required this.roles,
    required this.cases,
  });

  factory OdlaDiscoverySnapshot.fromMap(Map<String, Object?> map) {
    final version = _requiredString(
      map['contractVersion'],
      r'$.contractVersion',
    );
    if (version != odlaDiscoveryContractVersion) {
      throw const FormatException('ODLA keşif sözleşmesi desteklenmiyor.');
    }
    if (_requiredString(map['mode'], r'$.mode') != 'discovery') {
      throw const FormatException('ODLA keşif modu geçersiz.');
    }
    return OdlaDiscoverySnapshot(
      tenantId: _requiredString(map['tenantId'], r'$.tenantId'),
      brandUids: _stringList(map['brandUids'], r'$.brandUids'),
      roles: _stringList(map['roles'], r'$.roles'),
      cases: _typedList(map['cases'], r'$.cases', OdlaCaseSummary.fromMap),
    );
  }

  final String tenantId;
  final List<String> brandUids;
  final List<String> roles;
  final List<OdlaCaseSummary> cases;
}

final class OdlaCaseSummary {
  const OdlaCaseSummary({
    required this.caseId,
    required this.tenantId,
    required this.brandUid,
    required this.state,
    this.profileId,
    this.profileCode,
    this.profileVersion,
    this.productClassCode,
    this.countryCode,
  });

  factory OdlaCaseSummary.fromMap(Map<String, Object?> map) {
    return OdlaCaseSummary(
      caseId: _requiredString(map['caseId'], r'$.caseId'),
      tenantId: _requiredString(map['tenantId'], r'$.tenantId'),
      brandUid: _requiredString(map['brandUid'], r'$.brandUid'),
      state: _optionalString(map['state']) ?? 'unknown',
      profileId: _optionalString(map['profileId']),
      profileCode: _optionalString(map['profileCode']),
      profileVersion: _optionalInt(map['profileVersion']),
      productClassCode: _optionalString(map['productClassCode']),
      countryCode: _optionalString(map['countryCode']),
    );
  }

  final String caseId;
  final String tenantId;
  final String brandUid;
  final String state;
  final String? profileId;
  final String? profileCode;
  final int? profileVersion;
  final String? productClassCode;
  final String? countryCode;
}

final class OdlaWorkspaceDetail {
  const OdlaWorkspaceDetail({
    required this.caseRecord,
    required this.custodyEvents,
    required this.testRequests,
    required this.testResults,
    required this.findings,
    required this.appeals,
    required this.custodyIntegrityContext,
    required this.laboratoryRegistryContext,
  });

  factory OdlaWorkspaceDetail.fromMap(Map<String, Object?> map) {
    final version = _requiredString(
      map['contractVersion'],
      r'$.contractVersion',
    );
    if (version != odlaDetailContractVersion) {
      throw const FormatException('ODLA ayrıntı sözleşmesi desteklenmiyor.');
    }
    return OdlaWorkspaceDetail(
      caseRecord: Map<String, Object?>.unmodifiable(
        _requiredMap(map['case'], r'$.case'),
      ),
      custodyEvents: _typedList(
        map['custodyEvents'],
        r'$.custodyEvents',
        OdlaCustodyEvent.fromMap,
      ),
      testRequests: _typedList(
        map['testRequests'],
        r'$.testRequests',
        OdlaTestRequest.fromMap,
      ),
      testResults: _typedList(
        map['testResults'],
        r'$.testResults',
        OdlaTestResult.fromMap,
      ),
      findings: _typedList(map['findings'], r'$.findings', OdlaFinding.fromMap),
      appeals: _typedList(map['appeals'], r'$.appeals', OdlaAppeal.fromMap),
      custodyIntegrityContext: map['custodyIntegrityContext'] == null
          ? OdlaCustodyIntegrityContext.empty()
          : OdlaCustodyIntegrityContext.fromMap(
              _requiredMap(
                map['custodyIntegrityContext'],
                r'$.custodyIntegrityContext',
              ),
            ),
      laboratoryRegistryContext: OdlaLaboratoryRegistryContext.fromMap(
        _requiredMap(
          map['laboratoryRegistryContext'],
          r'$.laboratoryRegistryContext',
        ),
      ),
    );
  }

  final Map<String, Object?> caseRecord;
  final List<OdlaCustodyEvent> custodyEvents;
  final List<OdlaTestRequest> testRequests;
  final List<OdlaTestResult> testResults;
  final List<OdlaFinding> findings;
  final List<OdlaAppeal> appeals;
  final OdlaCustodyIntegrityContext custodyIntegrityContext;
  final OdlaLaboratoryRegistryContext laboratoryRegistryContext;

  String get caseId => _optionalString(caseRecord['caseId']) ?? '';
  String get state => _optionalString(caseRecord['state']) ?? 'unknown';
  String? get tenantId => _optionalString(caseRecord['tenantId']);
  String? get brandUid => _optionalString(caseRecord['brandUid']);
  String? get countryCode => _optionalString(caseRecord['countryCode']);
  String? get profileCode => _optionalString(caseRecord['profileCode']);
  int? get profileVersion => _optionalInt(caseRecord['profileVersion']);
  String? get productClassCode =>
      _optionalString(caseRecord['productClassCode']);
}

final class OdlaCustodyIntegrityContext {
  const OdlaCustodyIntegrityContext({
    required this.contractVersion,
    required this.samples,
    required this.referencedSampleCount,
    required this.establishedSampleCount,
    required this.notEstablishedSampleCount,
    required this.truncated,
  });

  factory OdlaCustodyIntegrityContext.empty() =>
      const OdlaCustodyIntegrityContext(
        contractVersion: odlaCustodyIntegrityContextContractVersion,
        samples: <OdlaSampleCustodyIntegrity>[],
        referencedSampleCount: 0,
        establishedSampleCount: 0,
        notEstablishedSampleCount: 0,
        truncated: false,
      );

  factory OdlaCustodyIntegrityContext.fromMap(Map<String, Object?> map) {
    final version = _requiredString(
      map['contractVersion'],
      r'$.custodyIntegrityContext.contractVersion',
    );
    if (version != odlaCustodyIntegrityContextContractVersion) {
      throw const FormatException(
        'ODLA numune bütünlüğü sözleşmesi desteklenmiyor.',
      );
    }
    return OdlaCustodyIntegrityContext(
      contractVersion: version,
      samples: _typedList(
        map['samples'],
        r'$.custodyIntegrityContext.samples',
        OdlaSampleCustodyIntegrity.fromMap,
      ),
      referencedSampleCount: _optionalInt(map['referencedSampleCount']) ?? 0,
      establishedSampleCount: _optionalInt(map['establishedSampleCount']) ?? 0,
      notEstablishedSampleCount:
          _optionalInt(map['notEstablishedSampleCount']) ?? 0,
      truncated: map['truncated'] == true,
    );
  }

  final String contractVersion;
  final List<OdlaSampleCustodyIntegrity> samples;
  final int referencedSampleCount;
  final int establishedSampleCount;
  final int notEstablishedSampleCount;
  final bool truncated;
}

final class OdlaSampleCustodyIntegrity {
  const OdlaSampleCustodyIntegrity._(this.raw);

  factory OdlaSampleCustodyIntegrity.fromMap(Map<String, Object?> map) =>
      OdlaSampleCustodyIntegrity._(Map<String, Object?>.unmodifiable(map));

  final Map<String, Object?> raw;

  String get sampleId => _requiredString(raw['sampleId'], r'$.sampleId');
  int get eventCount => _optionalInt(raw['eventCount']) ?? 0;
  String? get latestEventId => _optionalString(raw['latestEventId']);
  int? get latestEventSequence => _optionalInt(raw['latestEventSequence']);
  String? get currentSealId => _optionalString(raw['currentSealId']);
  List<String> get sealIds => _optionalStringList(raw['sealIds']);
  int get sealChangeCount => _optionalInt(raw['sealChangeCount']) ?? 0;
  int get openingEventCount => _optionalInt(raw['openingEventCount']) ?? 0;
  bool get hasSealChange => raw['hasSealChange'] == true;
  String get appendOnlyStatus =>
      _optionalString(raw['appendOnlyStatus']) ?? 'NOT_ESTABLISHED';
  String get integrityStatus =>
      _optionalString(raw['integrityStatus']) ?? 'NOT_ESTABLISHED';
  String get integrityCode =>
      _optionalString(raw['integrityCode']) ?? 'NO_CUSTODY_EVENTS';
  String get hashIntegrityStatus =>
      _optionalString(raw['hashIntegrityStatus']) ?? 'NOT_ESTABLISHED';
  String get sequenceIntegrityStatus =>
      _optionalString(raw['sequenceIntegrityStatus']) ?? 'NOT_ESTABLISHED';
  String get predecessorIntegrityStatus =>
      _optionalString(raw['predecessorIntegrityStatus']) ?? 'NOT_ESTABLISHED';
  int get evidenceReferenceCount =>
      _optionalInt(raw['evidenceReferenceCount']) ?? 0;
  List<String> get testRequestIds => _optionalStringList(raw['testRequestIds']);
  List<String> get testResultIds => _optionalStringList(raw['testResultIds']);
  List<String> get appealIds => _optionalStringList(raw['appealIds']);
  Map<String, Object?> get testResultIntegritySummary =>
      raw['testResultIntegritySummary'] is Map
      ? Map<String, Object?>.unmodifiable(
          _requiredMap(
            raw['testResultIntegritySummary'],
            r'$.testResultIntegritySummary',
          ),
        )
      : const <String, Object?>{};
}

final class OdlaLaboratoryRegistryContext {
  const OdlaLaboratoryRegistryContext({
    required this.contractVersion,
    required this.laboratories,
    required this.referencedLaboratoryCount,
    required this.resolvedLaboratoryCount,
    required this.legacyUnknownCount,
    required this.truncated,
  });

  factory OdlaLaboratoryRegistryContext.fromMap(Map<String, Object?> map) {
    final version = _requiredString(
      map['contractVersion'],
      r'$.laboratoryRegistryContext.contractVersion',
    );
    if (version != odlaLaboratoryRegistryContextContractVersion) {
      throw const FormatException(
        'ODLA laboratuvar sicili bağlamı sözleşmesi desteklenmiyor.',
      );
    }
    return OdlaLaboratoryRegistryContext(
      contractVersion: version,
      laboratories: _typedList(
        map['laboratories'],
        r'$.laboratoryRegistryContext.laboratories',
        OdlaLaboratoryContext.fromMap,
      ),
      referencedLaboratoryCount:
          _optionalInt(map['referencedLaboratoryCount']) ?? 0,
      resolvedLaboratoryCount:
          _optionalInt(map['resolvedLaboratoryCount']) ?? 0,
      legacyUnknownCount: _optionalInt(map['legacyUnknownCount']) ?? 0,
      truncated: map['truncated'] == true,
    );
  }

  final String contractVersion;
  final List<OdlaLaboratoryContext> laboratories;
  final int referencedLaboratoryCount;
  final int resolvedLaboratoryCount;
  final int legacyUnknownCount;
  final bool truncated;

  OdlaLaboratoryContext? laboratoryById(String? laboratoryId) {
    if (laboratoryId == null || laboratoryId.isEmpty) return null;
    for (final laboratory in laboratories) {
      if (laboratory.laboratoryId == laboratoryId) return laboratory;
    }
    return null;
  }
}

final class OdlaLaboratoryContext {
  const OdlaLaboratoryContext({
    required this.laboratoryId,
    required this.laboratory,
    required this.registryStatus,
    required this.verificationStatus,
    required this.accreditations,
    required this.scopes,
    required this.coverageContexts,
    required this.registryResolutionStatus,
  });

  factory OdlaLaboratoryContext.fromMap(Map<String, Object?> map) {
    final laboratoryValue = map['laboratory'];
    return OdlaLaboratoryContext(
      laboratoryId: _requiredString(
        map['laboratoryId'],
        r'$.laboratoryRegistryContext.laboratories[].laboratoryId',
      ),
      laboratory: laboratoryValue == null
          ? null
          : Map<String, Object?>.unmodifiable(
              _requiredMap(
                laboratoryValue,
                r'$.laboratoryRegistryContext.laboratories[].laboratory',
              ),
            ),
      registryStatus: _optionalString(map['registryStatus']) ?? 'UNKNOWN',
      verificationStatus:
          _optionalString(map['verificationStatus']) ?? 'UNVERIFIED',
      accreditations: _typedList(
        map['accreditations'],
        r'$.laboratoryRegistryContext.laboratories[].accreditations',
        OdlaLaboratoryAccreditation.fromMap,
      ),
      scopes: _typedList(
        map['scopes'],
        r'$.laboratoryRegistryContext.laboratories[].scopes',
        OdlaLaboratoryScope.fromMap,
      ),
      coverageContexts: _typedList(
        map['coverageContexts'],
        r'$.laboratoryRegistryContext.laboratories[].coverageContexts',
        OdlaLaboratoryCoverageContext.fromMap,
      ),
      registryResolutionStatus:
          _optionalString(map['registryResolutionStatus']) ?? 'UNKNOWN',
    );
  }

  final String laboratoryId;
  final Map<String, Object?>? laboratory;
  final String registryStatus;
  final String verificationStatus;
  final List<OdlaLaboratoryAccreditation> accreditations;
  final List<OdlaLaboratoryScope> scopes;
  final List<OdlaLaboratoryCoverageContext> coverageContexts;
  final String registryResolutionStatus;

  String? get displayName => _optionalString(laboratory?['displayName']);
  String? get legalName => _optionalString(laboratory?['legalName']);
  String? get countryCode => _optionalString(laboratory?['countryCode']);
  String? get registrationAuthorityId =>
      _optionalString(laboratory?['registrationAuthorityId']);
  String? get registrationNumber =>
      _optionalString(laboratory?['registrationNumber']);
}

final class OdlaLaboratoryAccreditation {
  const OdlaLaboratoryAccreditation._(this.raw);

  factory OdlaLaboratoryAccreditation.fromMap(Map<String, Object?> map) =>
      OdlaLaboratoryAccreditation._(Map<String, Object?>.unmodifiable(map));

  final Map<String, Object?> raw;

  String? get accreditationId => _optionalString(raw['accreditationId']);
  String? get standardCode => _optionalString(raw['standardCode']);
  String? get certificateNumber => _optionalString(raw['certificateNumber']);
  String? get accreditationBodyId =>
      _optionalString(raw['accreditationBodyId']);
  String? get accreditationBodyTypeCode =>
      _optionalString(raw['accreditationBodyTypeCode']);
  String? get validFrom => _optionalString(raw['validFrom']);
  String? get validUntil => _optionalString(raw['validUntil']);
  String? get status => _optionalString(raw['status']);
  String? get verificationStatus => _optionalString(raw['verificationStatus']);
}

final class OdlaLaboratoryScope {
  const OdlaLaboratoryScope._(this.raw);

  factory OdlaLaboratoryScope.fromMap(Map<String, Object?> map) =>
      OdlaLaboratoryScope._(Map<String, Object?>.unmodifiable(map));

  final Map<String, Object?> raw;

  String? get scopeId => _optionalString(raw['scopeId']);
  String? get accreditationId => _optionalString(raw['accreditationId']);
  String? get testTypeCode => _optionalString(raw['testTypeCode']);
  String? get methodCode => _optionalString(raw['methodCode']);
  String? get status => _optionalString(raw['status']);
}

final class OdlaLaboratoryCoverageContext {
  const OdlaLaboratoryCoverageContext._(this.raw);

  factory OdlaLaboratoryCoverageContext.fromMap(Map<String, Object?> map) =>
      OdlaLaboratoryCoverageContext._(Map<String, Object?>.unmodifiable(map));

  final Map<String, Object?> raw;

  String? get referenceType => _optionalString(raw['referenceType']);
  String? get referenceId => _optionalString(raw['referenceId']);
  String? get accreditationId => _optionalString(raw['accreditationId']);
  String? get scopeId => _optionalString(raw['scopeId']);
  String? get persistedCoverageStatus =>
      _optionalString(raw['persistedCoverageStatus']);
  String? get persistedCoverageReasonCode =>
      _optionalString(raw['persistedCoverageReasonCode']);
  String? get verificationStatus => _optionalString(raw['verificationStatus']);
  String? get registryMatchStatus =>
      _optionalString(raw['registryMatchStatus']);
}

final class OdlaCustodyEvent {
  const OdlaCustodyEvent._(this.raw);
  factory OdlaCustodyEvent.fromMap(Map<String, Object?> map) =>
      OdlaCustodyEvent._(Map<String, Object?>.unmodifiable(map));

  final Map<String, Object?> raw;
  String? get eventId => _optionalString(raw['eventId']);
  String? get sampleId => _optionalString(raw['sampleId']);
  int? get eventSequence => _optionalInt(raw['eventSequence']);
  String? get eventType => _optionalString(raw['eventType']);
  String? get occurredAt => _optionalScalarText(raw['occurredAt']);
  String? get actorType => _optionalString(raw['actorType']);
  String? get actorId => _optionalString(raw['actorId']);
  String? get locationCode => _optionalString(raw['locationCode']);
  String? get sealId => _optionalString(raw['sealId']);
  String? get previousEventId => _optionalString(raw['previousEventId']);
  List<String> get evidenceRefs => _optionalStringList(raw['evidenceRefs']);
}

final class OdlaTestRequest {
  const OdlaTestRequest._(this.raw);
  factory OdlaTestRequest.fromMap(Map<String, Object?> map) =>
      OdlaTestRequest._(Map<String, Object?>.unmodifiable(map));

  final Map<String, Object?> raw;
  String? get testRequestId => _optionalString(raw['testRequestId']);
  String? get sampleId => _optionalString(raw['sampleId']);
  String? get laboratoryId => _optionalString(raw['laboratoryId']);
  String? get testQuestionCode => _optionalString(raw['testQuestionCode']);
  String? get methodCode => _optionalString(raw['methodCode']);
  int? get requestSequence => _optionalInt(raw['requestSequence']);
  String? get appealOfTestRequestId =>
      _optionalString(raw['appealOfTestRequestId']);
  String? get requestedByType => _optionalString(raw['requestedByType']);
  String? get state => _optionalString(raw['state']);
  String? get createdAt => _optionalScalarText(raw['createdAt']);
  String? get updatedAt => _optionalScalarText(raw['updatedAt']);
}

final class OdlaTestResult {
  const OdlaTestResult._(this.raw);
  factory OdlaTestResult.fromMap(Map<String, Object?> map) =>
      OdlaTestResult._(Map<String, Object?>.unmodifiable(map));

  final Map<String, Object?> raw;
  String? get testResultId => _optionalString(raw['testResultId']);
  String? get testRequestId => _optionalString(raw['testRequestId']);
  String? get sampleId => _optionalString(raw['sampleId']);
  String? get laboratoryId => _optionalString(raw['laboratoryId']);
  String? get laboratoryReportId => _optionalString(raw['laboratoryReportId']);
  String? get methodCode => _optionalString(raw['methodCode']);
  String? get resultCode => _optionalString(raw['resultCode']);
  String? get resultSummaryCode => _optionalString(raw['resultSummaryCode']);
  bool? get custodyIntegrityVerified =>
      _optionalBool(raw['custodyIntegrityVerified']);
  bool? get referenceIntegrityVerified =>
      _optionalBool(raw['referenceIntegrityVerified']);
  String? get reportedAt => _optionalScalarText(raw['reportedAt']);
  String? get receivedAt => _optionalScalarText(raw['receivedAt']);
  String? get reportSha256 => _optionalString(raw['reportSha256']);
}

final class OdlaFinding {
  const OdlaFinding._(this.raw);
  factory OdlaFinding.fromMap(Map<String, Object?> map) =>
      OdlaFinding._(Map<String, Object?>.unmodifiable(map));

  final Map<String, Object?> raw;
  String? get findingId => _optionalString(raw['findingId']);
  int? get findingVersion => _optionalInt(raw['findingVersion']);
  String? get findingCode => _optionalString(raw['findingCode']);
  String? get confidenceBand => _optionalString(raw['confidenceBand']);
  List<String> get reasonCodes => _optionalStringList(raw['reasonCodes']);
  String? get healthSafetyImpact => _optionalString(raw['healthSafetyImpact']);
  String? get marketplaceRecommendationCode =>
      _optionalString(raw['marketplaceRecommendationCode']);
  String? get authorityEscalationCode =>
      _optionalString(raw['authorityEscalationCode']);
  String? get supersedesFindingId =>
      _optionalString(raw['supersedesFindingId']);
  String? get createdAt => _optionalScalarText(raw['createdAt']);
}

final class OdlaAppeal {
  const OdlaAppeal._(this.raw);
  factory OdlaAppeal.fromMap(Map<String, Object?> map) =>
      OdlaAppeal._(Map<String, Object?>.unmodifiable(map));

  final Map<String, Object?> raw;
  String? get appealId => _optionalString(raw['appealId']);
  int? get appealSequence => _optionalInt(raw['appealSequence']);
  String? get appellantType => _optionalString(raw['appellantType']);
  String? get challengedFindingId =>
      _optionalString(raw['challengedFindingId']);
  String? get requestedRemedyCode =>
      _optionalString(raw['requestedRemedyCode']);
  String? get reserveSampleId => _optionalString(raw['reserveSampleId']);
  String? get secondLaboratoryId => _optionalString(raw['secondLaboratoryId']);
  String? get state => _optionalString(raw['state']);
  String? get createdAt => _optionalScalarText(raw['createdAt']);
  String? get updatedAt => _optionalScalarText(raw['updatedAt']);
}

Map<String, Object?> _requiredMap(Object? value, String path) {
  if (value is! Map) throw FormatException('$path nesne olmalıdır.');
  return value.map(
    (key, dynamic item) => MapEntry(key.toString(), item as Object?),
  );
}

List<Object?> _requiredList(Object? value, String path) {
  if (value is! List) throw FormatException('$path liste olmalıdır.');
  return value.cast<Object?>();
}

List<T> _typedList<T>(
  Object? value,
  String path,
  T Function(Map<String, Object?> map) decoder,
) => List<T>.unmodifiable(
  _requiredList(value, path).asMap().entries.map(
    (entry) => decoder(_requiredMap(entry.value, '$path[${entry.key}]')),
  ),
);

List<String> _stringList(Object? value, String path) =>
    List<String>.unmodifiable(
      _requiredList(
        value,
        path,
      ).map((item) => _requiredString(item, '$path[]')),
    );

String _requiredString(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path metin olmalıdır.');
  }
  return value.trim();
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('ODLA metin alanı geçersiz.');
  }
  final cleaned = value.trim();
  return cleaned.isEmpty ? null : cleaned;
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw const FormatException('ODLA tam sayı alanı geçersiz.');
}

bool? _optionalBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  throw const FormatException('ODLA boolean alanı geçersiz.');
}

String? _optionalScalarText(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }
  if (value is num || value is bool || value is DateTime) {
    return value.toString();
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    final nanos = value['_nanoseconds'] ?? value['nanoseconds'];
    if (seconds != null) return nanos == null ? '$seconds' : '$seconds.$nanos';
  }
  return value.toString();
}

List<String> _optionalStringList(Object? value) {
  if (value == null) return const <String>[];
  if (value is! List) {
    throw const FormatException('ODLA metin listesi alanı geçersiz.');
  }
  return List<String>.unmodifiable(
    value.map((item) {
      if (item is! String) {
        throw const FormatException('ODLA metin listesi öğesi geçersiz.');
      }
      return item;
    }),
  );
}
