/* eslint-disable max-len */
"use strict";

const {immutableSnapshot} = require("./canonical");
const {
  ProfessionalServicesContractError,
  normalizeSourceReferences,
  requiredCode,
  requiredSha256,
  requiredString,
  requiredUid,
  requiredUuid,
} = require("./contracts");

const AGENT_RUN_REQUEST_CONTRACT_VERSION =
  "professional-agent-run-request-v1";
const AGENT_OUTPUT_DRAFT_CONTRACT_VERSION =
  "professional-agent-output-draft-v1";
const AGENT_HUMAN_REVIEW_CONTRACT_VERSION =
  "professional-agent-human-review-v1";

const AGENT_CATALOG = Object.freeze({
  legal_intake_triage: Object.freeze([
    "case_intake_summary",
    "missing_information_detection",
  ]),
  evidence_timeline_preparer: Object.freeze([
    "evidence_classification",
    "chronology_draft",
    "source_gap_detection",
  ]),
  form_prefill: Object.freeze([
    "structured_form_prefill",
    "field_source_mapping",
    "required_field_validation",
  ]),
  legal_document_drafter: Object.freeze([
    "legal_working_draft",
    "fact_source_linking",
    "unverified_claim_marking",
  ]),
  authority_platform_compliance: Object.freeze([
    "submission_requirement_check",
    "evidence_sufficiency_checklist",
  ]),
  deadline_workflow_controller: Object.freeze([
    "deadline_monitoring",
    "approval_gate_monitoring",
    "sla_risk_detection",
  ]),
  delivery_package_preparer: Object.freeze([
    "attachment_ordering",
    "manifest_preparation",
    "package_integrity_check",
  ]),
  multilingual_legal_document: Object.freeze([
    "controlled_translation_draft",
    "terminology_consistency_check",
  ]),
});

const AGENT_OUTPUT_TYPES = Object.freeze([
  "legal_intake_summary",
  "evidence_timeline",
  "prefilled_form",
  "legal_document_draft",
  "compliance_checklist",
  "deadline_workflow",
  "delivery_package_manifest",
  "multilingual_document_draft",
]);

const CONFIDENTIALITY_CLASSES = Object.freeze([
  "operational_shared",
  "client_confidential",
  "professional_restricted",
  "legal_privilege_asserted",
  "evidence_restricted",
  "public_release_candidate",
]);

const PRIVILEGE_CLAIM_STATUSES = Object.freeze([
  "none",
  "asserted_pending_lawyer_review",
  "lawyer_confirmed",
  "waived",
  "disputed",
]);

const CONFIDENCE_LEVELS = Object.freeze([
  "not_scored",
  "low",
  "medium",
  "high",
]);

const HUMAN_REVIEW_DECISIONS = Object.freeze([
  "approved",
  "revision_requested",
  "rejected",
]);

const SHA256 = /^[0-9a-f]{64}$/;

function fail(message) {
  throw new ProfessionalServicesContractError("invalid-argument", message);
}

function objectRequired(value, field = "request") {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    fail(`${field} invalid`);
  }
  return value;
}

function strict(raw, contractVersion, fields) {
  objectRequired(raw);
  const allowed = new Set(["contractVersion", ...fields]);
  if (raw.contractVersion !== contractVersion ||
      Object.keys(raw).some((key) => !allowed.has(key))) {
    fail("request contract invalid");
  }
}

function enumValue(value, values, field) {
  if (!values.includes(value)) {
    fail(`${field} invalid`);
  }
  return value;
}

function isoInstant(value, field) {
  const clean = requiredString(value, field, 1, 80);
  const milliseconds = Date.parse(clean);
  if (!Number.isFinite(milliseconds)) {
    fail(`${field} invalid`);
  }
  return new Date(milliseconds).toISOString();
}

function positiveInteger(value, field, maximum) {
  if (!Number.isSafeInteger(value) || value < 0 || value > maximum) {
    fail(`${field} invalid`);
  }
  return value;
}

function codeArray(value, field, maximumItems) {
  if (!Array.isArray(value) || value.length > maximumItems) {
    fail(`${field} invalid`);
  }
  const result = value.map((item, index) =>
    requiredCode(item, `${field}[${index}]`));
  if (new Set(result).size !== result.length) {
    fail(`${field} contains duplicates`);
  }
  return result;
}

function parseAgentRunRequest(raw) {
  strict(raw, AGENT_RUN_REQUEST_CONTRACT_VERSION, [
    "requestId",
    "serviceRequestId",
    "serviceAssignmentId",
    "agentCode",
    "agentVersion",
    "modelProvider",
    "modelName",
    "modelVersion",
    "promptTemplateVersion",
    "initiatedByUid",
    "supervisingUid",
    "sourceReferences",
    "inputManifestHashSha256",
    "confidentialityClass",
    "privilegeClaimStatus",
    "startedAt",
  ]);
  const agentCode = requiredCode(raw.agentCode, "agentCode");
  if (!AGENT_CATALOG[agentCode]) {
    fail("agentCode unsupported");
  }
  const confidentialityClass = enumValue(raw.confidentialityClass,
      CONFIDENTIALITY_CLASSES, "confidentialityClass");
  const privilegeClaimStatus = enumValue(raw.privilegeClaimStatus,
      PRIVILEGE_CLAIM_STATUSES, "privilegeClaimStatus");
  if (confidentialityClass === "legal_privilege_asserted" &&
      privilegeClaimStatus === "none") {
    fail("privilege claim status required");
  }
  return immutableSnapshot({
    contractVersion: raw.contractVersion,
    requestId: requiredUuid(raw.requestId, "requestId"),
    serviceRequestId: requiredString(raw.serviceRequestId,
        "serviceRequestId", 1, 128),
    serviceAssignmentId: raw.serviceAssignmentId == null ? null :
      requiredString(raw.serviceAssignmentId,
          "serviceAssignmentId", 1, 128),
    agentCode,
    agentCapabilities: AGENT_CATALOG[agentCode],
    agentVersion: requiredCode(raw.agentVersion, "agentVersion"),
    modelProvider: requiredCode(raw.modelProvider, "modelProvider"),
    modelName: requiredString(raw.modelName, "modelName", 1, 160),
    modelVersion: requiredString(raw.modelVersion,
        "modelVersion", 1, 160),
    promptTemplateVersion: requiredCode(raw.promptTemplateVersion,
        "promptTemplateVersion"),
    initiatedByUid: requiredUid(raw.initiatedByUid, "initiatedByUid"),
    supervisingUid: requiredUid(raw.supervisingUid, "supervisingUid"),
    sourceReferences: normalizeSourceReferences(raw.sourceReferences),
    inputManifestHashSha256: requiredSha256(
        raw.inputManifestHashSha256,
        "inputManifestHashSha256",
    ),
    confidentialityClass,
    privilegeClaimStatus,
    startedAt: isoInstant(raw.startedAt, "startedAt"),
    humanApprovalRequired: true,
  });
}

function parseAgentOutputDraft(raw) {
  strict(raw, AGENT_OUTPUT_DRAFT_CONTRACT_VERSION, [
    "agentRunId",
    "outputType",
    "outputHashSha256",
    "outputBytes",
    "sourceReferenceCount",
    "confidenceLevel",
    "warningCodes",
    "generatedAt",
  ]);
  const outputHashSha256 = requiredString(raw.outputHashSha256,
      "outputHashSha256", 64, 64).toLowerCase();
  if (!SHA256.test(outputHashSha256)) {
    fail("outputHashSha256 invalid");
  }
  return immutableSnapshot({
    contractVersion: raw.contractVersion,
    agentRunId: requiredString(raw.agentRunId, "agentRunId", 1, 128),
    outputType: enumValue(raw.outputType,
        AGENT_OUTPUT_TYPES, "outputType"),
    outputHashSha256,
    outputBytes: positiveInteger(raw.outputBytes,
        "outputBytes", 5000000),
    sourceReferenceCount: positiveInteger(raw.sourceReferenceCount,
        "sourceReferenceCount", 10000),
    confidenceLevel: enumValue(raw.confidenceLevel,
        CONFIDENCE_LEVELS, "confidenceLevel"),
    warningCodes: codeArray(raw.warningCodes, "warningCodes", 100),
    generatedAt: isoInstant(raw.generatedAt, "generatedAt"),
    reviewStatus: "pending_human_review",
    publishable: false,
    immutable: true,
  });
}

function parseAgentHumanReview(raw) {
  strict(raw, AGENT_HUMAN_REVIEW_CONTRACT_VERSION, [
    "agentRunId",
    "outputDraftId",
    "expectedDraftHashSha256",
    "decision",
    "reviewedByUid",
    "reviewNote",
    "reviewedAt",
  ]);
  return immutableSnapshot({
    contractVersion: raw.contractVersion,
    agentRunId: requiredString(raw.agentRunId, "agentRunId", 1, 128),
    outputDraftId: requiredString(raw.outputDraftId,
        "outputDraftId", 1, 128),
    expectedDraftHashSha256: requiredSha256(
        raw.expectedDraftHashSha256,
        "expectedDraftHashSha256",
    ),
    decision: enumValue(raw.decision,
        HUMAN_REVIEW_DECISIONS, "decision"),
    reviewedByUid: requiredUid(raw.reviewedByUid, "reviewedByUid"),
    reviewNote: requiredString(raw.reviewNote,
        "reviewNote", 3, 3000),
    reviewedAt: isoInstant(raw.reviewedAt, "reviewedAt"),
    immutable: true,
  });
}

function assertAgentOutputPublishable(outputDraft, humanReview) {
  objectRequired(outputDraft, "outputDraft");
  objectRequired(humanReview, "humanReview");
  if (outputDraft.agentRunId !== humanReview.agentRunId ||
      outputDraft.outputHashSha256 !==
        humanReview.expectedDraftHashSha256) {
    fail("human review does not match output draft");
  }
  if (humanReview.decision !== "approved") {
    fail("agent output is not approved");
  }
  if (!humanReview.reviewedByUid) {
    fail("human reviewer required");
  }
  return true;
}

module.exports = Object.freeze({
  AGENT_CATALOG,
  AGENT_HUMAN_REVIEW_CONTRACT_VERSION,
  AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
  AGENT_OUTPUT_TYPES,
  AGENT_RUN_REQUEST_CONTRACT_VERSION,
  CONFIDENCE_LEVELS,
  CONFIDENTIALITY_CLASSES,
  HUMAN_REVIEW_DECISIONS,
  PRIVILEGE_CLAIM_STATUSES,
  assertAgentOutputPublishable,
  parseAgentHumanReview,
  parseAgentOutputDraft,
  parseAgentRunRequest,
});
