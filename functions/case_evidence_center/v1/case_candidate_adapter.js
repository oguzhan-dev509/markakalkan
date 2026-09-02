/* eslint-disable max-len */
const {createHash} = require("node:crypto");

const CONTRACT_VERSION = "case-candidate-v1";
const ADAPTER_VERSION = "case-candidate-adapter-v1";
const STATUS = "proposed";
const PRIORITIES = Object.freeze(["low", "medium", "high", "critical"]);

function requiredString(value, field, maxLength = 1000) {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`${field}.required`);
  }
  const result = value.trim();
  if (result.length > maxLength) throw new Error(`${field}.too_long`);
  return result;
}

function iso(value, field) {
  const text = requiredString(value, field, 80);
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) throw new Error(`${field}.invalid`);
  return date.toISOString();
}

function priority(value) {
  const result = requiredString(value, "recommendedPriority", 16);
  if (!PRIORITIES.includes(result)) throw new Error("recommendedPriority.invalid");
  return result;
}

function sha256(value) {
  return createHash("sha256").update(String(value)).digest("hex");
}

function deterministicCaseIdentity({
  tenantId,
  canonicalBrandId,
  sourceSystem,
  sourceRecordId,
}) {
  return sha256(
      [
        "case-file-v1",
        tenantId,
        canonicalBrandId,
        sourceSystem,
        sourceRecordId,
      ].join("|"),
  );
}

function deterministicCandidateIdentity({
  tenantId,
  canonicalBrandId,
  sourceSystem,
  sourceRecordId,
}) {
  return sha256(
      [
        "case-candidate-v1",
        tenantId,
        canonicalBrandId,
        sourceSystem,
        sourceRecordId,
      ].join("|"),
  );
}

function buildCanonicalCaseCandidateV1({
  context,
  request,
  sourceProjection,
  recommendedPriority,
}) {
  if (!context || typeof context !== "object") throw new Error("context.required");
  if (!request || typeof request !== "object") throw new Error("request.required");
  if (!sourceProjection || typeof sourceProjection !== "object") {
    throw new Error("sourceProjection.required");
  }

  const tenantId = requiredString(context.tenantId, "context.tenantId", 240);
  const brandId = requiredString(context.brandId, "context.brandId", 240);
  const sourceSystem = requiredString(
      request.sourceSystem,
      "request.sourceSystem",
      40,
  );
  const sourceRecordId = requiredString(
      request.sourceRecordId,
      "request.sourceRecordId",
      240,
  );
  const signalId = requiredString(
      sourceProjection.signalId,
      "sourceProjection.signalId",
      240,
  );
  const title = requiredString(
      sourceProjection.title,
      "sourceProjection.title",
      500,
  );
  const summary = requiredString(
      sourceProjection.summary,
      "sourceProjection.summary",
      5000,
  );

  const localCandidacy = sourceProjection.caseCandidacy;
  if (!localCandidacy || typeof localCandidacy !== "object") {
    throw new Error("sourceProjection.caseCandidacy.required");
  }
  const proposedAt = iso(
      localCandidacy.evaluatedAt,
      "sourceProjection.caseCandidacy.evaluatedAt",
  );

  return Object.freeze({
    caseCandidateId: deterministicCandidateIdentity({
      tenantId,
      canonicalBrandId: brandId,
      sourceSystem,
      sourceRecordId,
    }),
    contractVersion: CONTRACT_VERSION,
    identityScope: {
      tenantId,
      brandId,
      resolutionStatus: "resolved",
      unresolvedReasons: [],
    },
    sourceSignalRefs: [],
    sourceRiskRefs: [{
      module: "risk_operations",
      entityType: "risk_operation",
      entityId: signalId,
    }],
    canonicalAssetRefs: [],
    evidenceRefs: [],
    relatedEntityRefs: [],
    status: STATUS,
    recommendedPriority: priority(recommendedPriority),
    title,
    summary,
    deduplicationKey: deterministicCaseIdentity({
      tenantId,
      canonicalBrandId: brandId,
      sourceSystem,
      sourceRecordId,
    }),
    proposedAt,
    provenance: {
      producerModule: "case_evidence_center",
      producerVersion: ADAPTER_VERSION,
      sourceRecordId,
      adaptedAt: proposedAt,
    },
  });
}

module.exports = {
  ADAPTER_VERSION,
  CONTRACT_VERSION,
  buildCanonicalCaseCandidateV1,
  deterministicCaseIdentity,
};
