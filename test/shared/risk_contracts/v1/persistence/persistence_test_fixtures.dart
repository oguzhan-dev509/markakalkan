import 'package:markakalkan/shared/risk_contracts/v1/idempotency/idempotency_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/identity/identity_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/persistence/persistence_v1.dart';
import 'package:markakalkan/shared/risk_contracts/v1/shared_risk_contracts_v1.dart';

final evaluatedAt = DateTime.parse('2026-07-19T15:00:00Z');
final createdAt = DateTime.parse('2026-07-19T10:00:00Z');

IdentityScope identity({
  String? tenantId = 'tenant-1',
  String? brandId = 'brand-1',
}) => IdentityScope(
  tenantId: tenantId,
  brandId: brandId,
  resolutionStatus: tenantId == null
      ? IdentityResolutionStatus.partial
      : IdentityResolutionStatus.resolved,
);

ProvenanceEnvelope provenance({
  String module = 'traceability',
  String? sourceRecordId = 'record-1',
  String? taskId,
  String? executionId,
  String? findingKey,
}) => ProvenanceEnvelope(
  producerModule: module,
  sourceRecordId: sourceRecordId,
  taskId: taskId,
  executionId: executionId,
  findingKey: findingKey,
  adaptedAt: DateTime.parse('2026-07-19T12:00:00Z'),
  sourceCreatedAt: createdAt,
);

IdentityResolutionResultV1 resolution({
  IdentityResolutionResultStatus status =
      IdentityResolutionResultStatus.resolved,
  String? tenantId = 'tenant-1',
  String? brandId = 'brand-1',
}) => IdentityResolutionResultV1(
  status: status,
  resolvedIdentityScope:
      status == IdentityResolutionResultStatus.conflict ||
          status == IdentityResolutionResultStatus.unresolved
      ? null
      : identity(
          tenantId: status == IdentityResolutionResultStatus.partial
              ? null
              : tenantId,
          brandId: brandId,
        ),
  acceptedClaimRefs: const [],
  rejectedClaimRefs: const [],
  matchedMappingRefs: const [],
  conflicts: status == IdentityResolutionResultStatus.conflict
      ? const ['conflict']
      : const [],
  reasons: const [],
  resolutionAt: evaluatedAt,
  provenance: provenance(),
);

RiskSignalContractV1 signal({
  String module = 'traceability',
  String summary = 'Synthetic risk signal',
  IdentityScope? subjectIdentity,
  List<EvidenceRef> evidence = const [],
  List<CanonicalEntityRef> related = const [],
  CanonicalAssetRef? asset,
  ProvenanceEnvelope? sourceProvenance,
}) => RiskSignalContractV1(
  signalId: 'signal-1',
  identityScope: subjectIdentity ?? identity(),
  canonicalAssetRef: asset,
  signalSource: SignalSource(
    module: module,
    sourceType: 'verification_scan',
    sourceId: 'record-1',
  ),
  signalType: NamespacedValue(namespace: '$module.signal', value: 'suspicious'),
  canonicalSeverity: CanonicalSeverity.high,
  summary: summary,
  evidenceRefs: evidence,
  relatedEntityRefs: related,
  reviewStatus: RiskSignalReviewStatus.newSignal,
  detectedAt: createdAt,
  createdAt: createdAt,
  provenance: sourceProvenance ?? provenance(module: module),
);

SourceIngestionKeyV1 keyFor(String module) => switch (module) {
  'traceability' => const SourceIngestionKeyBuilderV1().traceabilityScan(
    scanId: 'record-1',
  ),
  'digital_market_monitoring' =>
    const SourceIngestionKeyBuilderV1().monitoringSignal(signalId: 'record-1'),
  'digital_detective' =>
    const SourceIngestionKeyBuilderV1().digitalDetectiveExactOccurrence(
      taskId: 'task-1',
      executionId: 'execution-1',
      findingKey: 'finding-1',
    ),
  _ => SourceIngestionKeyV1(
    sourceModule: module,
    sourceType: 'test',
    kind: SourceIngestionKeyKind.exactOccurrence,
    stableSourceParts: const ['record-1'],
  ),
};

RiskSignalPersistenceReadinessRequestV1 signalRequest({
  RiskSignalContractV1? subject,
  IdentityResolutionResultV1? result,
  SourceIngestionKeyV1? key,
  String policyVersion = riskPersistenceReadinessPolicyVersionV1,
}) => RiskSignalPersistenceReadinessRequestV1(
  subject: subject ?? signal(),
  sourceIngestionKey: key ?? keyFor('traceability'),
  identityResolutionResult: result ?? resolution(),
  evaluatedAt: evaluatedAt,
  requestedByModule: 'test',
  policyVersion: policyVersion,
  provenance: provenance(),
);

RiskAssessmentContractV1 risk({
  List<String> reasons = const ['repeated_scan'],
  ScoreValue? score,
  List<CanonicalEntityRef> sourceSignals = const [],
  DateTime? nextReviewAt,
  ProvenanceEnvelope? sourceProvenance,
}) => RiskAssessmentContractV1(
  riskId: 'risk-1',
  identityScope: identity(),
  riskCategory: NamespacedValue(
    namespace: 'traceability.risk',
    value: 'suspicious_scan',
  ),
  canonicalSeverity: CanonicalSeverity.high,
  score: score,
  reasons: reasons,
  sourceSignalRefs: sourceSignals,
  status: RiskAssessmentStatus.identified,
  assessedAt: createdAt,
  nextReviewAt: nextReviewAt,
  createdAt: createdAt,
  provenance: sourceProvenance ?? provenance(),
);

RiskAssessmentPersistenceReadinessRequestV1 riskRequest({
  RiskAssessmentContractV1? subject,
}) => RiskAssessmentPersistenceReadinessRequestV1(
  subject: subject ?? risk(),
  sourceIngestionKey: keyFor('traceability'),
  identityResolutionResult: resolution(),
  evaluatedAt: evaluatedAt,
  requestedByModule: 'test',
  policyVersion: riskPersistenceReadinessPolicyVersionV1,
  provenance: provenance(),
);

CaseCandidateContractV1 candidate({
  CaseCandidateStatus status = CaseCandidateStatus.proposed,
  List<CanonicalEntityRef> signals = const [],
  List<CanonicalEntityRef> risks = const [],
  DateTime? reviewedAt,
  String? reviewedBy,
  CanonicalEntityRef? promotedCaseRef,
}) => CaseCandidateContractV1(
  caseCandidateId: 'candidate-1',
  identityScope: identity(),
  sourceSignalRefs: signals,
  sourceRiskRefs: risks,
  status: status,
  recommendedPriority: CaseCandidatePriority.high,
  title: 'Synthetic candidate',
  summary: 'Synthetic candidate summary',
  deduplicationKey: 'candidate-dedup-1',
  proposedAt: createdAt,
  reviewedAt: reviewedAt,
  reviewedBy: reviewedBy,
  promotedCaseRef: promotedCaseRef,
  provenance: provenance(),
);

CaseCandidatePersistenceReadinessRequestV1 candidateRequest(
  CaseCandidateContractV1 subject,
) => CaseCandidatePersistenceReadinessRequestV1(
  subject: subject,
  identityResolutionResult: resolution(),
  evaluatedAt: evaluatedAt,
  requestedByModule: 'test',
  policyVersion: riskPersistenceReadinessPolicyVersionV1,
  provenance: provenance(),
);

CanonicalEntityRef entity(String id) =>
    CanonicalEntityRef(module: 'test', entityType: 'signal', entityId: id);
