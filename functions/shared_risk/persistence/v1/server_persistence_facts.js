const {createHash} = require("node:crypto");

const {buildPersistenceDocumentIdV1,
  buildPersistenceReceiptIdV1, encodeParts} = require("./document_id");
const {ALLOWED_SOURCE_MODULES, EXACT_PERMISSIONS, TARGETS,
  immutableSnapshot} = require("./storage_contracts");
const {validatePayloadLimitsV1} = require("./payload_limits");

const FINGERPRINT_ALGORITHM = "sha256-canonical-json-v1";

function required(value, field) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new TypeError(`${field} is required`);
  }
  return value.trim();
}

function canonicalize(value, key) {
  if (Array.isArray(value)) {
    const values = value.map((item) => canonicalize(item));
    if (["evidenceRefs", "relatedEntityRefs", "sourceSignalRefs",
      "sourceRiskRefs"].includes(key)) {
      values.sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
    }
    return values;
  }
  if (value && typeof value === "object") {
    const result = {};
    for (const childKey of Object.keys(value).sort()) {
      result[childKey] = canonicalize(value[childKey], childKey);
    }
    return result;
  }
  return value;
}

function fingerprint(payload) {
  const canonical = JSON.stringify(canonicalize(payload));
  return createHash("sha256").update(canonical, "utf8").digest("hex");
}

function commandId(input) {
  return encodeParts([
    "persistence-command-v1",
    input.subjectType,
    input.subjectId,
    input.targetNamespace,
    input.exactIdempotencyBinding.canonicalKey,
    input.resolvedIdentityScope.tenantId,
  ]);
}

function buildServerPersistenceFactsV1({authoritativeInput}) {
  if (!authoritativeInput || typeof authoritativeInput !== "object") {
    throw new TypeError("authoritativeInput is required");
  }
  const input = authoritativeInput;
  if (!input.authenticatedActor ||
      typeof input.authenticatedActor !== "object") {
    throw new TypeError("authenticatedActor is required");
  }
  required(input.authenticatedActor.uid, "authenticated actor uid");
  const tenantId = required(input.resolvedIdentityScope &&
    input.resolvedIdentityScope.tenantId, "resolved tenantId");
  const subjectType = required(input.subjectType, "subjectType");
  const subjectId = required(input.subjectId, "subjectId");
  const expectedTarget = TARGETS[subjectType];
  if (!expectedTarget) throw new TypeError("subjectType is unsupported");
  const canonicalSubjectPayload = immutableSnapshot(
      input.canonicalSubjectPayload,
  );
  const sourceModule = required(input.sourceModule, "sourceModule");
  const permissions = Object.freeze([...new Set(
      (input.grantedPermissions || []).map((value) => required(value,
          "permission")),
  )].sort());
  const exactBinding = immutableSnapshot(input.exactIdempotencyBinding);
  required(exactBinding.canonicalKey, "exact idempotency key");
  if (exactBinding.purpose !== (subjectType === "case_candidate" ?
    "case_candidate_initial_persistence" : "exact_source_occurrence")) {
    throw new TypeError("exact idempotency binding purpose is invalid");
  }
  const facts = {
    authenticatedActor: immutableSnapshot(input.authenticatedActor),
    resolvedIdentityScope: immutableSnapshot({
      tenantId,
      brandId: input.resolvedIdentityScope.brandId || null,
    }),
    grantedPermissions: permissions,
    subjectType,
    subjectId,
    subjectContractVersion: required(input.subjectContractVersion,
        "subjectContractVersion"),
    canonicalSubjectPayload,
    fingerprintAlgorithm: FINGERPRINT_ALGORITHM,
    subjectFingerprint: fingerprint(canonicalSubjectPayload),
    exactIdempotencyBinding: exactBinding,
    targetNamespace: expectedTarget,
    sourceModule,
    sourceRecordRef: required(input.sourceRecordRef, "sourceRecordRef"),
    sourceRecordVersion: input.sourceRecordVersion || null,
    sourceRecordUpdateTime: input.sourceRecordUpdateTime || null,
    readinessDecision: immutableSnapshot(input.readinessDecision),
    serverEvaluationTime: required(input.serverEvaluationTime,
        "serverEvaluationTime"),
    commandRequestedAt: input.commandRequestedAt || null,
    provenance: immutableSnapshot(input.provenance),
  };
  facts.commandId = commandId(facts);
  facts.persistenceDocumentId = buildPersistenceDocumentIdV1({
    tenantId,
    targetNamespace: expectedTarget,
    idempotencyCanonicalKey: exactBinding.canonicalKey,
  });
  facts.receiptId = buildPersistenceReceiptIdV1(facts.persistenceDocumentId);
  const blockers = [...validatePayloadLimitsV1(canonicalSubjectPayload,
      facts.provenance)];
  if (!permissions.includes(EXACT_PERMISSIONS[subjectType])) {
    blockers.push("authorization.exact_permission_missing");
  }
  if (!facts.readinessDecision || facts.readinessDecision.allowed !== true ||
      (facts.readinessDecision.blockers || []).length > 0) {
    blockers.push("readiness.server_decision_denied");
  }
  if (!ALLOWED_SOURCE_MODULES.includes(sourceModule)) {
    blockers.push("source.module_unsupported");
  }
  facts.validationBlockers = Object.freeze([...new Set(blockers)].sort());
  return immutableSnapshot(facts);
}

module.exports = {
  FINGERPRINT_ALGORITHM,
  buildServerPersistenceFactsV1,
  canonicalize,
};
