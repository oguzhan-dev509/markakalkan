import 'package:cloud_functions/cloud_functions.dart';

const String interventionLegalWorkspaceContractVersion =
    'intervention-legal-workspace-v1';
const String interventionLegalWorkspaceCallableName =
    'getInterventionLegalWorkspace';

typedef InterventionLegalCallable =
    Future<Object?> Function(String name, Map<String, Object?> request);

abstract interface class InterventionLegalWorkspaceRepository {
  Future<InterventionLegalWorkspaceSnapshot> loadWorkspace({int limit = 20});
}

final class CallableInterventionLegalWorkspaceRepository
    implements InterventionLegalWorkspaceRepository {
  CallableInterventionLegalWorkspaceRepository({
    FirebaseFunctions? functions,
    InterventionLegalCallable? callable,
  }) : _functions = callable == null
           ? functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3')
           : null,
       _callable = callable;

  final FirebaseFunctions? _functions;
  final InterventionLegalCallable? _callable;

  @override
  Future<InterventionLegalWorkspaceSnapshot> loadWorkspace({
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 50) {
      throw RangeError.range(limit, 1, 50, 'limit');
    }

    final request = <String, Object?>{
      'contractVersion': interventionLegalWorkspaceContractVersion,
      'limit': limit,
    };

    final injected = _callable;
    final Object? raw;
    if (injected != null) {
      raw = await injected(interventionLegalWorkspaceCallableName, request);
    } else {
      final result = await _functions!
          .httpsCallable(interventionLegalWorkspaceCallableName)
          .call(request);
      raw = result.data;
    }

    return InterventionLegalWorkspaceSnapshot.fromMap(_requiredMap(raw, r'$'));
  }
}

final class InterventionLegalWorkspaceSnapshot {
  const InterventionLegalWorkspaceSnapshot({
    required this.generatedAt,
    required this.limit,
    required this.authorityScopeCount,
    required this.counts,
    required this.matters,
  });

  factory InterventionLegalWorkspaceSnapshot.fromMap(Map<String, Object?> map) {
    final contractVersion = _requiredString(
      map['contractVersion'],
      r'$.contractVersion',
    );
    if (contractVersion != interventionLegalWorkspaceContractVersion) {
      throw const FormatException(
        'Müdahale ve Hukuk çalışma alanı sözleşmesi desteklenmiyor.',
      );
    }

    return InterventionLegalWorkspaceSnapshot(
      generatedAt: _requiredDateTime(map['generatedAt'], r'$.generatedAt'),
      limit: _requiredInt(map['limit'], r'$.limit'),
      authorityScopeCount: _requiredInt(
        map['authorityScopeCount'],
        r'$.authorityScopeCount',
      ),
      counts: InterventionLegalWorkspaceCounts.fromMap(
        _requiredMap(map['counts'], r'$.counts'),
      ),
      matters: _requiredList(map['matters'], r'$.matters')
          .asMap()
          .entries
          .map(
            (entry) => InterventionLegalMatterSummary.fromMap(
              _requiredMap(entry.value, r'$.matters[]'),
            ),
          )
          .toList(growable: false),
    );
  }

  final DateTime generatedAt;
  final int limit;
  final int authorityScopeCount;
  final InterventionLegalWorkspaceCounts counts;
  final List<InterventionLegalMatterSummary> matters;
}

final class InterventionLegalWorkspaceCounts {
  const InterventionLegalWorkspaceCounts({
    required this.legalMatterCount,
    required this.activeLegalMatterCount,
    required this.pendingApprovalCount,
    required this.approvedApprovalCount,
    required this.rejectedApprovalCount,
  });

  factory InterventionLegalWorkspaceCounts.fromMap(Map<String, Object?> map) {
    return InterventionLegalWorkspaceCounts(
      legalMatterCount: _requiredInt(
        map['legalMatterCount'],
        r'$.counts.legalMatterCount',
      ),
      activeLegalMatterCount: _requiredInt(
        map['activeLegalMatterCount'],
        r'$.counts.activeLegalMatterCount',
      ),
      pendingApprovalCount: _requiredInt(
        map['pendingApprovalCount'],
        r'$.counts.pendingApprovalCount',
      ),
      approvedApprovalCount: _requiredInt(
        map['approvedApprovalCount'],
        r'$.counts.approvedApprovalCount',
      ),
      rejectedApprovalCount: _requiredInt(
        map['rejectedApprovalCount'],
        r'$.counts.rejectedApprovalCount',
      ),
    );
  }

  final int legalMatterCount;
  final int activeLegalMatterCount;
  final int pendingApprovalCount;
  final int approvedApprovalCount;
  final int rejectedApprovalCount;
}

final class InterventionLegalOperationAuthorityProjection {
  const InterventionLegalOperationAuthorityProjection({
    required this.operationCode,
    required this.canonicalBrandId,
    required this.operationAuthorityGranted,
    required this.authoritySource,
  });

  factory InterventionLegalOperationAuthorityProjection.fromMap(
    Map<String, Object?> map, {
    required String expectedOperationCode,
    required String expectedCanonicalBrandId,
  }) {
    final operationCode = _requiredString(
      map['operationCode'],
      r'$.matters[].capabilityAccess.LEGAL_ACTION[].operationCode',
    );
    final canonicalBrandId = _requiredString(
      map['canonicalBrandId'],
      r'$.matters[].capabilityAccess.LEGAL_ACTION[].canonicalBrandId',
    );
    if (operationCode != expectedOperationCode) {
      throw const FormatException(
        'Hukuki işlem yetki operationCode kapsamı eşleşmiyor.',
      );
    }
    if (canonicalBrandId != expectedCanonicalBrandId) {
      throw const FormatException(
        'Hukuki işlem yetki marka kapsamı eşleşmiyor.',
      );
    }
    return InterventionLegalOperationAuthorityProjection(
      operationCode: operationCode,
      canonicalBrandId: canonicalBrandId,
      operationAuthorityGranted: _requiredBool(
        map['operationAuthorityGranted'],
        r'$.matters[].capabilityAccess.LEGAL_ACTION[].operationAuthorityGranted',
      ),
      authoritySource: _requiredString(
        map['authoritySource'],
        r'$.matters[].capabilityAccess.LEGAL_ACTION[].authoritySource',
      ),
    );
  }

  final String operationCode;
  final String canonicalBrandId;
  final bool operationAuthorityGranted;
  final String authoritySource;
}

final class InterventionLegalMatterCapabilityAccess {
  const InterventionLegalMatterCapabilityAccess({
    required this.legalActionByOperationCode,
  });

  const InterventionLegalMatterCapabilityAccess.empty()
    : legalActionByOperationCode =
          const <String, InterventionLegalOperationAuthorityProjection>{};

  factory InterventionLegalMatterCapabilityAccess.fromMatterMap(
    Map<String, Object?> matter,
  ) {
    final canonicalBrandId = _requiredString(
      matter['canonicalBrandId'],
      r'$.matters[].canonicalBrandId',
    );
    final rawCapability = matter['capabilityAccess'];
    if (rawCapability == null) {
      return const InterventionLegalMatterCapabilityAccess.empty();
    }
    final capability = _requiredMap(
      rawCapability,
      r'$.matters[].capabilityAccess',
    );
    final rawLegalAction = capability['LEGAL_ACTION'];
    if (rawLegalAction == null) {
      return const InterventionLegalMatterCapabilityAccess.empty();
    }
    final legalAction = _requiredMap(
      rawLegalAction,
      r'$.matters[].capabilityAccess.LEGAL_ACTION',
    );
    final parsed = <String, InterventionLegalOperationAuthorityProjection>{};
    for (final entry in legalAction.entries) {
      final operationCode = entry.key.trim();
      if (operationCode.isEmpty) {
        throw const FormatException('Hukuki işlem operationCode boş olamaz.');
      }
      parsed[operationCode] =
          InterventionLegalOperationAuthorityProjection.fromMap(
            _requiredMap(
              entry.value,
              r'$.matters[].capabilityAccess.LEGAL_ACTION[]',
            ),
            expectedOperationCode: operationCode,
            expectedCanonicalBrandId: canonicalBrandId,
          );
    }
    return InterventionLegalMatterCapabilityAccess(
      legalActionByOperationCode: Map.unmodifiable(parsed),
    );
  }

  final Map<String, InterventionLegalOperationAuthorityProjection>
  legalActionByOperationCode;

  InterventionLegalOperationAuthorityProjection? legalAction(
    String operationCode,
  ) => legalActionByOperationCode[operationCode.trim()];
}

final class InterventionLegalMatterSummary {
  const InterventionLegalMatterSummary({
    required this.legalMatterId,
    required this.caseId,
    required this.tenantId,
    required this.canonicalBrandId,
    required this.jurisdictionCode,
    required this.countryCode,
    required this.matterScopeCode,
    required this.priorityCode,
    required this.title,
    required this.status,
    required this.version,
    required this.sourceSystemCode,
    required this.sourceRecordId,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUid,
    required this.updatedByUid,
    required this.statusChangedByUid,
    this.capabilityAccess =
        const InterventionLegalMatterCapabilityAccess.empty(),
    required this.approvalRequests,
    required this.approvalDecisions,
  });

  factory InterventionLegalMatterSummary.fromMap(Map<String, Object?> map) {
    return InterventionLegalMatterSummary(
      legalMatterId: _requiredString(
        map['legalMatterId'],
        r'$.matters[].legalMatterId',
      ),
      caseId: _requiredString(map['caseId'], r'$.matters[].caseId'),
      tenantId: _requiredString(map['tenantId'], r'$.matters[].tenantId'),
      canonicalBrandId: _requiredString(
        map['canonicalBrandId'],
        r'$.matters[].canonicalBrandId',
      ),
      jurisdictionCode: _requiredString(
        map['jurisdictionCode'],
        r'$.matters[].jurisdictionCode',
      ),
      countryCode: _optionalString(
        map['countryCode'],
        r'$.matters[].countryCode',
      ),
      matterScopeCode: _optionalString(
        map['matterScopeCode'],
        r'$.matters[].matterScopeCode',
      ),
      priorityCode: _optionalString(
        map['priorityCode'],
        r'$.matters[].priorityCode',
      ),
      title: _optionalString(map['title'], r'$.matters[].title'),
      status: _requiredString(map['status'], r'$.matters[].status'),
      version: _requiredInt(map['version'], r'$.matters[].version'),
      sourceSystemCode: _optionalString(
        map['sourceSystemCode'],
        r'$.matters[].sourceSystemCode',
      ),
      sourceRecordId: _optionalString(
        map['sourceRecordId'],
        r'$.matters[].sourceRecordId',
      ),
      createdAt: _optionalDateTime(map['createdAt'], r'$.matters[].createdAt'),
      updatedAt: _optionalDateTime(map['updatedAt'], r'$.matters[].updatedAt'),
      createdByUid: _optionalString(
        map['createdByUid'],
        r'$.matters[].createdByUid',
      ),
      updatedByUid: _optionalString(
        map['updatedByUid'],
        r'$.matters[].updatedByUid',
      ),
      statusChangedByUid: _optionalString(
        map['statusChangedByUid'],
        r'$.matters[].statusChangedByUid',
      ),
      capabilityAccess: InterventionLegalMatterCapabilityAccess.fromMatterMap(
        map,
      ),
      approvalRequests:
          _requiredList(
                map['approvalRequests'],
                r'$.matters[].approvalRequests',
              )
              .map(
                (item) => InterventionLegalApprovalRequestSummary.fromMap(
                  _requiredMap(item, r'$.matters[].approvalRequests[]'),
                ),
              )
              .toList(growable: false),
      approvalDecisions:
          _requiredList(
                map['approvalDecisions'],
                r'$.matters[].approvalDecisions',
              )
              .map(
                (item) => InterventionLegalApprovalDecisionSummary.fromMap(
                  _requiredMap(item, r'$.matters[].approvalDecisions[]'),
                ),
              )
              .toList(growable: false),
    );
  }

  final String legalMatterId;
  final String caseId;
  final String tenantId;
  final String canonicalBrandId;
  final String jurisdictionCode;
  final String? countryCode;
  final String? matterScopeCode;
  final String? priorityCode;
  final String? title;
  final String status;
  final int version;
  final String? sourceSystemCode;
  final String? sourceRecordId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdByUid;
  final String? updatedByUid;
  final String? statusChangedByUid;
  final InterventionLegalMatterCapabilityAccess capabilityAccess;
  final List<InterventionLegalApprovalRequestSummary> approvalRequests;
  final List<InterventionLegalApprovalDecisionSummary> approvalDecisions;
}

final class InterventionLegalApprovalRequestSummary {
  const InterventionLegalApprovalRequestSummary({
    required this.approvalRequestId,
    required this.legalMatterId,
    required this.approvalType,
    required this.status,
    required this.version,
    required this.requestSequence,
    required this.requestReasonCode,
    required this.requestNote,
    required this.preparedByUid,
    required this.decisionId,
    required this.decidedByUid,
    required this.createdAt,
    required this.updatedAt,
    required this.decidedAt,
  });

  factory InterventionLegalApprovalRequestSummary.fromMap(
    Map<String, Object?> map,
  ) {
    return InterventionLegalApprovalRequestSummary(
      approvalRequestId: _requiredString(
        map['approvalRequestId'],
        r'$.approvalRequests[].approvalRequestId',
      ),
      legalMatterId: _requiredString(
        map['legalMatterId'],
        r'$.approvalRequests[].legalMatterId',
      ),
      approvalType: _requiredString(
        map['approvalType'],
        r'$.approvalRequests[].approvalType',
      ),
      status: _requiredString(map['status'], r'$.approvalRequests[].status'),
      version: _requiredInt(map['version'], r'$.approvalRequests[].version'),
      requestSequence: _requiredInt(
        map['requestSequence'],
        r'$.approvalRequests[].requestSequence',
      ),
      requestReasonCode: _optionalString(
        map['requestReasonCode'],
        r'$.approvalRequests[].requestReasonCode',
      ),
      requestNote: _optionalString(
        map['requestNote'],
        r'$.approvalRequests[].requestNote',
      ),
      preparedByUid: _optionalString(
        map['preparedByUid'],
        r'$.approvalRequests[].preparedByUid',
      ),
      decisionId: _optionalString(
        map['decisionId'],
        r'$.approvalRequests[].decisionId',
      ),
      decidedByUid: _optionalString(
        map['decidedByUid'],
        r'$.approvalRequests[].decidedByUid',
      ),
      createdAt: _optionalDateTime(
        map['createdAt'],
        r'$.approvalRequests[].createdAt',
      ),
      updatedAt: _optionalDateTime(
        map['updatedAt'],
        r'$.approvalRequests[].updatedAt',
      ),
      decidedAt: _optionalDateTime(
        map['decidedAt'],
        r'$.approvalRequests[].decidedAt',
      ),
    );
  }

  final String approvalRequestId;
  final String legalMatterId;
  final String approvalType;
  final String status;
  final int version;
  final int requestSequence;
  final String? requestReasonCode;
  final String? requestNote;
  final String? preparedByUid;
  final String? decisionId;
  final String? decidedByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? decidedAt;
}

final class InterventionLegalApprovalDecisionSummary {
  const InterventionLegalApprovalDecisionSummary({
    required this.decisionId,
    required this.approvalRequestId,
    required this.legalMatterId,
    required this.approvalType,
    required this.decision,
    required this.decisionReasonCode,
    required this.decisionNote,
    required this.decidedByUid,
    required this.decidedAt,
    required this.immutable,
  });

  factory InterventionLegalApprovalDecisionSummary.fromMap(
    Map<String, Object?> map,
  ) {
    return InterventionLegalApprovalDecisionSummary(
      decisionId: _requiredString(
        map['decisionId'],
        r'$.approvalDecisions[].decisionId',
      ),
      approvalRequestId: _requiredString(
        map['approvalRequestId'],
        r'$.approvalDecisions[].approvalRequestId',
      ),
      legalMatterId: _requiredString(
        map['legalMatterId'],
        r'$.approvalDecisions[].legalMatterId',
      ),
      approvalType: _requiredString(
        map['approvalType'],
        r'$.approvalDecisions[].approvalType',
      ),
      decision: _requiredString(
        map['decision'],
        r'$.approvalDecisions[].decision',
      ),
      decisionReasonCode: _optionalString(
        map['decisionReasonCode'],
        r'$.approvalDecisions[].decisionReasonCode',
      ),
      decisionNote: _optionalString(
        map['decisionNote'],
        r'$.approvalDecisions[].decisionNote',
      ),
      decidedByUid: _optionalString(
        map['decidedByUid'],
        r'$.approvalDecisions[].decidedByUid',
      ),
      decidedAt: _optionalDateTime(
        map['decidedAt'],
        r'$.approvalDecisions[].decidedAt',
      ),
      immutable: _requiredBool(
        map['immutable'],
        r'$.approvalDecisions[].immutable',
      ),
    );
  }

  final String decisionId;
  final String approvalRequestId;
  final String legalMatterId;
  final String approvalType;
  final String decision;
  final String? decisionReasonCode;
  final String? decisionNote;
  final String? decidedByUid;
  final DateTime? decidedAt;
  final bool immutable;
}

Map<String, Object?> _requiredMap(Object? value, String path) {
  if (value is! Map) {
    throw FormatException('$path nesne olmalıdır.');
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw FormatException('$path yalnız metin anahtarlar içermelidir.');
    }
    result[key] = entry.value;
  }
  return result;
}

List<Object?> _requiredList(Object? value, String path) {
  if (value is! List) {
    throw FormatException('$path liste olmalıdır.');
  }
  return List<Object?>.unmodifiable(value);
}

String _requiredString(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path dolu bir metin olmalıdır.');
  }
  return value.trim();
}

String? _optionalString(Object? value, String path) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$path metin veya null olmalıdır.');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Object? value, String path) {
  if (value is! int) {
    throw FormatException('$path tam sayı olmalıdır.');
  }
  return value;
}

bool _requiredBool(Object? value, String path) {
  if (value is! bool) {
    throw FormatException('$path boolean olmalıdır.');
  }
  return value;
}

DateTime _requiredDateTime(Object? value, String path) {
  final parsed = _optionalDateTime(value, path);
  if (parsed == null) {
    throw FormatException('$path ISO-8601 tarih olmalıdır.');
  }
  return parsed;
}

DateTime? _optionalDateTime(Object? value, String path) {
  if (value == null) {
    return null;
  }
  final raw = _requiredString(value, path);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('$path ISO-8601 tarih olmalıdır.');
  }
  return parsed.toUtc();
}
