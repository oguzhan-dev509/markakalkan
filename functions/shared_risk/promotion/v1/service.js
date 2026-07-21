/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {buildServerPersistenceFactsV1} = require("../../persistence/v1/server_persistence_facts");
const {buildCreationAuditEventIdV1, encodeParts} = require("../../persistence/v1/document_id");
const {executePersistenceTransactionV1} = require("../../persistence/v1/persistence_transaction_executor");
const {resolveTenantContextV1} = require("../../../risk_operations/v1/service");
const {monitoringProjection, traceabilityProjection} = require("../../../risk_operations/v1/projection");
const {sharedRiskProjection} = require("../../../risk_operations/v1/service");
const {CONTRACT_VERSION, EXACT_PERMISSION, PromotionError,
  promotionRequestV1} = require("./contracts");

const fingerprint = (value) => createHash("sha256")
    .update(JSON.stringify(value)).digest("hex");
const versionOf = (snapshot) => snapshot.updateTime && snapshot.updateTime.toDate ?
  snapshot.updateTime.toDate().toISOString() : null;

async function loadSource({db, context, request, evaluatedAt}) {
  let reference;
  if (request.sourceSystem === "traceability") {
    reference = db.collection("verificationScans").doc(request.sourceRecordId);
  } else if (request.sourceSystem === "monitoring") {
    reference = db.collection("monitoring_signals").doc(request.sourceRecordId);
  } else {
    reference = db.collection("brands").doc(context.uid)
        .collection("digitalDetectiveTasks").doc(request.sourceRecordId);
  }
  const snapshot = await reference.get();
  if (!snapshot.exists) throw new PromotionError("source.not_found");
  const data = snapshot.data() || {};
  const version = versionOf(snapshot) || data.sourceRecordVersion ||
    data.contractVersion || "v1";
  let projection;
  if (request.sourceSystem === "traceability") {
    if (data.ownerUid !== context.uid) throw new PromotionError("source.denied");
    projection = traceabilityProjection({id: snapshot.id,
      data: {...data, sourceRecordVersion: version}, context, evaluatedAt});
  } else if (request.sourceSystem === "monitoring") {
    if (data.tenantId !== context.tenantId || data.brandId !== context.brandId) {
      throw new PromotionError("source.denied");
    }
    projection = monitoringProjection({id: snapshot.id,
      data: {...data, sourceRecordVersion: version}, context, evaluatedAt});
  } else {
    if (data.status !== "completed") throw new PromotionError("source.denied");
    projection = sharedRiskProjection({id: snapshot.id, data: {...data,
      contractVersion: version, tenantId: context.tenantId,
      canonicalSubjectId: snapshot.id, subjectType: "source_record",
      sourceModule: "digital_detective",
      title: data.title || "Dijital Dedektif sonucu",
      riskClass: data.riskClass || "other"}, context, evaluatedAt});
  }
  return Object.freeze({reference, version, projection});
}

function canonicalSignal(projection, evaluatedAt) {
  const stableEvaluationTime = Number.isNaN(
      Date.parse(projection.sourceRecordVersion)) ? evaluatedAt :
    projection.sourceRecordVersion;
  return Object.freeze({schemaVersion: "shared-risk-signal-v1",
    contractVersion: "shared-risk-signal-contract-v1",
    signalId: projection.signalId, canonicalBrandId: projection.canonicalBrandId,
    canonicalSubjectId: projection.canonicalSubjectId,
    sourceSystem: projection.sourceSystem,
    sourceRecordId: projection.sourceRecordId,
    sourceRecordVersion: projection.sourceRecordVersion,
    adapterVersion: projection.adapterVersion,
    projectionFingerprint: projection.projectionFingerprint,
    title: projection.title, summary: projection.summary,
    riskClass: projection.riskClass, severity: projection.severity,
    confidence: projection.confidence,
    evidenceQuality: projection.evidenceQuality,
    caseCandidacy: {...projection.caseCandidacy,
      evaluatedAt: stableEvaluationTime},
    occurredAt: projection.occurredAt, observedAt: projection.observedAt,
    ingestedAt: projection.ingestedAt, timelineSummary: projection.timelineSummary,
    relationshipSummary: projection.relationshipSummary,
    status: "human_review_required", lifecycleVersion: "v1",
    evaluatedAt: stableEvaluationTime});
}

function createPromotionServiceV1({db, persistenceStore, clock,
  projectIdProvider}) {
  return Object.freeze({async execute(raw, invocation) {
    const request = promotionRequestV1(raw);
    if (!invocation || !invocation.uid) throw new PromotionError("auth.required");
    const evaluatedAt = clock.now();
    const context = await resolveTenantContextV1({db, uid: invocation.uid,
      request: {}});
    const membership = await db.collection("tenant_memberships")
        .doc(context.membershipId).get();
    const member = membership.data() || {};
    if (member.status !== "active" || member.role !== "owner") {
      throw new PromotionError("authorization.denied");
    }
    const source = await loadSource({db, context, request, evaluatedAt});
    if (source.version !== request.expectedSourceRecordVersion ||
        source.projection.projectionFingerprint !==
        request.expectedProjectionFingerprint) {
      return Object.freeze({outcome: "conflict", dryRun: request.dryRun,
        blockers: ["source.projection_stale"], transactionCommitted: false,
        writeAttempted: false});
    }
    const signal = canonicalSignal(source.projection, evaluatedAt);
    const canonicalKey = encodeParts([CONTRACT_VERSION, projectIdProvider(),
      context.tenantId, context.brandId, request.sourceSystem,
      request.sourceRecordId, source.version, source.projection.adapterVersion]);
    const facts = buildServerPersistenceFactsV1({authoritativeInput: {
      authenticatedActor: {actorType: "user", uid: invocation.uid},
      resolvedIdentityScope: {tenantId: context.tenantId,
        brandId: context.brandId}, grantedPermissions: [EXACT_PERMISSION],
      subjectType: "risk_signal", subjectId: source.projection.signalId,
      subjectContractVersion: signal.contractVersion,
      canonicalSubjectPayload: signal, sourceModule: request.sourceSystem,
      sourceRecordRef: source.reference.path, sourceRecordVersion: source.version,
      sourceRecordUpdateTime: source.version,
      exactIdempotencyBinding: {canonicalKey,
        purpose: "exact_source_occurrence"},
      readinessDecision: {allowed: true, blockers: [], warnings: [],
        policyVersion: "human-approved-risk-promotion-readiness-v1"},
      serverEvaluationTime: evaluatedAt,
      provenance: {contractVersion: CONTRACT_VERSION,
        projectId: projectIdProvider(), correlationHash:
          fingerprint(request.correlationId).slice(0, 16),
        projectionFingerprint: source.projection.projectionFingerprint,
        adapterVersion: source.projection.adapterVersion},
    }});
    const creationAuditEventId = buildCreationAuditEventIdV1({
      receiptId: facts.receiptId,
      persistenceDocumentId: facts.persistenceDocumentId,
      commandId: facts.commandId});
    if (request.dryRun) {
      return Object.freeze({outcome: "dry_run_ready",
        dryRun: true, signalId: facts.persistenceDocumentId,
        receiptId: facts.receiptId, auditEventId: creationAuditEventId,
        blockers: [], transactionCommitted: false, writeAttempted: false});
    }
    const execution = await executePersistenceTransactionV1({
      store: persistenceStore, facts, sourceVersionStillCurrent: true,
      sourceRecordStillExists: true, plannedAt: evaluatedAt,
      executedAt: clock.now(), sourceRevalidation: {reference: source.reference,
        updateTime: source.version, validate: ({data}) => {
          if (request.sourceSystem === "traceability" &&
              data.ownerUid !== context.uid) return ["source.owner_changed"];
          if (request.sourceSystem === "monitoring" &&
              (data.tenantId !== context.tenantId ||
               data.brandId !== context.brandId)) {
            return ["source.identity_scope_changed"];
          }
          if (request.sourceSystem === "digital_detective" &&
              data.status !== "completed") return ["source.status_changed"];
          return [];
        }}});
    return Object.freeze({outcome: execution.outcome, dryRun: false,
      signalId: execution.persistenceDocumentId, receiptId: execution.receiptId,
      auditEventId: execution.creationAuditEventId,
      blockers: execution.blockers, transactionCommitted:
        execution.transactionCommitted, writeAttempted:
        execution.transactionCommitted});
  }});
}
module.exports = {canonicalSignal, createPromotionServiceV1, loadSource};
