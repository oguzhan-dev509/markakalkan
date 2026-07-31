"use strict";

const CONTRACT_VERSION = "intervention-legal-core-v1";

const COLLECTIONS = Object.freeze({
  LEGAL_TEAM_PROFILES: "legal_team_profiles",
  LEGAL_MATTER_FILES: "legal_matter_files",
  LEGAL_MATTER_ASSIGNMENTS: "legal_matter_assignments",
  LEGAL_ASSESSMENTS: "legal_assessments",
  LEGAL_INTERVENTION_PLANS: "legal_intervention_plans",
  LEGAL_INTERVENTION_ACTIONS: "legal_intervention_actions",
  LEGAL_MATTER_LINKS: "legal_matter_links",
  LEGAL_APPROVAL_REQUESTS: "legal_approval_requests",
  LEGAL_APPROVAL_DECISIONS: "legal_approval_decisions",
  LEGAL_MATTER_EVENTS: "legal_matter_events",
});

const LEGAL_MATTER_STATUSES = Object.freeze([
  "intake_pending",
  "legal_review",
  "evidence_required",
  "strategy_preparation",
  "awaiting_authorization",
  "approved",
  "in_preparation",
  "submitted",
  "in_progress",
  "awaiting_response",
  "escalated",
  "resolved",
  "closed",
  "cancelled",
  "archived",
]);

const ASSESSMENT_STATUSES = Object.freeze([
  "draft",
  "evidence_required",
  "awaiting_lawyer_review",
  "approved",
  "superseded",
  "withdrawn",
]);

const PLAN_STATUSES = Object.freeze([
  "draft",
  "awaiting_lawyer_review",
  "awaiting_client_authorization",
  "approved",
  "active",
  "completed",
  "rejected",
  "cancelled",
  "superseded",
]);

const ACTION_STATUSES = Object.freeze([
  "draft",
  "awaiting_human_review",
  "awaiting_client_authorization",
  "approved",
  "in_preparation",
  "ready_for_execution",
  "executed",
  "awaiting_response",
  "in_progress",
  "additional_information_required",
  "resolved",
  "rejected",
  "withdrawn",
  "cancelled",
  "archived",
]);

const APPROVAL_REQUEST_STATUSES = Object.freeze([
  "pending",
  "approved",
  "rejected",
  "expired",
  "withdrawn",
]);

const PROFESSIONAL_STATUSES = Object.freeze([
  "pending",
  "active",
  "suspended",
  "inactive",
  "archived",
]);

const ROLE_CODES = Object.freeze([
  "legal_operations_specialist",
  "responsible_lawyer",
  "senior_legal_reviewer",
  "operations_manager",
  "field_investigator",
  "evidence_custodian",
  "client_authority",
  "platform_admin",
]);

const LAWYER_APPROVER_ROLES = Object.freeze([
  "responsible_lawyer",
  "senior_legal_reviewer",
]);

const APPROVAL_TYPES = Object.freeze([
  "client_action_authorization",
  "client_budget_authorization",
  "client_litigation_authorization",
  "client_settlement_authorization",
  "lawyer_legal_approval",
  "senior_legal_review",
]);

const LINK_TYPES = Object.freeze([
  "case_evidence_ref",
  "case_review_task",
  "counterfeit_twin_record",
  "customs_protection_profile",
  "customs_border_intervention",
  "customs_authority_submission",
  "risk_operation",
  "shared_risk_signal",
  "field_operation",
  "sample_acquisition",
  "external_proceeding",
]);

const INTERVENTION_ACTION_TYPES = Object.freeze([
  "platform_takedown",
  "cease_and_desist",
  "domain_intervention",
  "social_media_intervention",
  "customs_action",
  "administrative_application",
  "prosecutor_application",
  "criminal_investigation",
  "civil_litigation",
  "interim_injunction",
  "evidence_determination",
  "settlement",
  "compensation_claim",
  "field_investigation",
  "sample_acquisition",
  "continuous_monitoring",
  "other",
]);

class InterventionLegalContractError extends Error {
  constructor(code, message, details = undefined) {
    super(message);
    this.name = "InterventionLegalContractError";
    this.code = code;
    this.details = details;
  }
}

function isPlainObject(value) {
  return value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype;
}

function objectRequired(value, field = "payload") {
  if (!isPlainObject(value)) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      `${field} must be a plain object`,
    );
  }
  return value;
}

function exactKeys(value, allowed, required = []) {
  objectRequired(value);
  const allowedSet = new Set(allowed);
  const unsupported = Object.keys(value).filter((key) => !allowedSet.has(key));
  if (unsupported.length > 0) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      "unsupported request fields",
      {unsupported},
    );
  }
  const missing = required.filter(
    (key) => value[key] === undefined || value[key] === null,
  );
  if (missing.length > 0) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      "required request fields missing",
      {missing},
    );
  }
  return value;
}

function requiredString(value, field, maxLength = 256) {
  if (typeof value !== "string") {
    throw new InterventionLegalContractError(
      "invalid-argument",
      `${field} must be a string`,
    );
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maxLength) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      `${field} length is invalid`,
    );
  }
  return normalized;
}

function optionalString(value, field, maxLength = 256) {
  if (value === undefined || value === null || value === "") return null;
  return requiredString(value, field, maxLength);
}

function requiredCode(value, field, maxLength = 96) {
  const normalized = requiredString(value, field, maxLength).toLowerCase();
  if (!/^[a-z0-9][a-z0-9._:-]*$/.test(normalized)) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      `${field} must be a language-independent code`,
    );
  }
  return normalized;
}

function optionalCode(value, field, maxLength = 96) {
  if (value === undefined || value === null || value === "") return null;
  return requiredCode(value, field, maxLength);
}

function requiredCountryCode(value, field = "countryCode") {
  const normalized = requiredString(value, field, 2).toUpperCase();
  if (!/^[A-Z]{2}$/.test(normalized)) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      `${field} must be ISO 3166-1 alpha-2`,
    );
  }
  return normalized;
}

function enumValue(value, allowed, field) {
  const normalized = requiredString(value, field, 96);
  if (!allowed.includes(normalized)) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      `${field} is unsupported`,
      {value: normalized, allowed},
    );
  }
  return normalized;
}

function optionalBoolean(value, field, defaultValue = false) {
  if (value === undefined || value === null) return defaultValue;
  if (typeof value !== "boolean") {
    throw new InterventionLegalContractError(
      "invalid-argument",
      `${field} must be boolean`,
    );
  }
  return value;
}

function requiredStringArray(value, field, maxItems = 100) {
  if (!Array.isArray(value) || value.length > maxItems) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      `${field} must be an array with at most ${maxItems} items`,
    );
  }
  const normalized = value.map((item, index) =>
    requiredString(item, `${field}[${index}]`, 256));
  if (new Set(normalized).size !== normalized.length) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      `${field} must not contain duplicates`,
    );
  }
  return Object.freeze(normalized);
}

function baseCommand(raw, extraAllowed, extraRequired, options = {}) {
  const allowed = [
    "contractVersion",
    "requestId",
    "idempotencyKey",
    ...extraAllowed,
  ];
  const required = [
    "contractVersion",
    "requestId",
    "idempotencyKey",
    ...extraRequired,
  ];
  if (options.expectedVersion) {
    allowed.push("expectedVersion");
    required.push("expectedVersion");
  }
  exactKeys(raw, allowed, required);
  if (raw.contractVersion !== CONTRACT_VERSION) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      "contractVersion is unsupported",
    );
  }
  const result = {
    contractVersion: CONTRACT_VERSION,
    requestId: requiredString(raw.requestId, "requestId", 128),
    idempotencyKey: requiredString(raw.idempotencyKey, "idempotencyKey", 256),
  };
  if (options.expectedVersion) {
    if (!Number.isSafeInteger(raw.expectedVersion) || raw.expectedVersion < 0) {
      throw new InterventionLegalContractError(
        "invalid-argument",
        "expectedVersion must be a non-negative safe integer",
      );
    }
    result.expectedVersion = raw.expectedVersion;
  }
  return result;
}

function parseCreateLegalMatterCommand(raw) {
  const base = baseCommand(
    raw,
    [
      "actorUid",
      "tenantId",
      "canonicalBrandId",
      "caseId",
      "jurisdictionCode",
      "matterScopeCode",
      "countryCode",
      "priorityCode",
      "title",
      "sourceSystemCode",
      "sourceRecordId",
    ],
    [
      "actorUid",
      "tenantId",
      "canonicalBrandId",
      "caseId",
      "jurisdictionCode",
      "matterScopeCode",
      "countryCode",
    ],
  );
  return Object.freeze({
    ...base,
    actorUid: requiredString(raw.actorUid, "actorUid", 128),
    tenantId: requiredString(raw.tenantId, "tenantId", 128),
    canonicalBrandId: requiredString(
      raw.canonicalBrandId,
      "canonicalBrandId",
      128,
    ),
    caseId: requiredString(raw.caseId, "caseId", 128),
    jurisdictionCode: requiredCode(
      raw.jurisdictionCode,
      "jurisdictionCode",
    ),
    matterScopeCode: requiredCode(raw.matterScopeCode, "matterScopeCode"),
    countryCode: requiredCountryCode(raw.countryCode),
    priorityCode: optionalCode(raw.priorityCode, "priorityCode"),
    title: optionalString(raw.title, "title", 300),
    sourceSystemCode: optionalCode(
      raw.sourceSystemCode,
      "sourceSystemCode",
    ),
    sourceRecordId: optionalString(raw.sourceRecordId, "sourceRecordId", 256),
  });
}

function parseTransitionLegalMatterCommand(raw) {
  const base = baseCommand(
    raw,
    ["actorUid", "legalMatterId", "nextStatus", "reasonCode", "note"],
    ["actorUid", "legalMatterId", "nextStatus", "reasonCode"],
    {expectedVersion: true},
  );
  return Object.freeze({
    ...base,
    actorUid: requiredString(raw.actorUid, "actorUid", 128),
    legalMatterId: requiredString(raw.legalMatterId, "legalMatterId", 128),
    nextStatus: enumValue(
      raw.nextStatus,
      LEGAL_MATTER_STATUSES,
      "nextStatus",
    ),
    reasonCode: requiredCode(raw.reasonCode, "reasonCode"),
    note: optionalString(raw.note, "note", 2000),
  });
}

function parseApprovalDecisionCommand(raw) {
  const base = baseCommand(
    raw,
    [
      "expectedApprovalRequestVersion",
      "approvalRequestId",
      "legalMatterId",
      "approvalType",
      "decision",
      "decisionReasonCode",
      "decisionNote",
      "decidedByUid",
    ],
    [
      "expectedApprovalRequestVersion",
      "approvalRequestId",
      "legalMatterId",
      "approvalType",
      "decision",
      "decisionReasonCode",
      "decidedByUid",
    ],
  );
  if (
    !Number.isSafeInteger(raw.expectedApprovalRequestVersion) ||
    raw.expectedApprovalRequestVersion < 0
  ) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      "expectedApprovalRequestVersion must be a non-negative safe integer",
    );
  }
  return Object.freeze({
    ...base,
    expectedApprovalRequestVersion: raw.expectedApprovalRequestVersion,
    approvalRequestId: requiredString(
      raw.approvalRequestId,
      "approvalRequestId",
      128,
    ),
    legalMatterId: requiredString(raw.legalMatterId, "legalMatterId", 128),
    approvalType: enumValue(raw.approvalType, APPROVAL_TYPES, "approvalType"),
    decision: enumValue(raw.decision, ["approved", "rejected"], "decision"),
    decisionReasonCode: requiredCode(
      raw.decisionReasonCode,
      "decisionReasonCode",
    ),
    decisionNote: optionalString(raw.decisionNote, "decisionNote", 2000),
    decidedByUid: requiredString(raw.decidedByUid, "decidedByUid", 128),
  });
}

function assertSegregationOfDuties({preparedByUid, approvedByUid}) {
  const preparer = requiredString(preparedByUid, "preparedByUid", 128);
  const approver = requiredString(approvedByUid, "approvedByUid", 128);
  if (preparer === approver) {
    throw new InterventionLegalContractError(
      "failed-precondition",
      "the sole final legal approver cannot be the preparer",
    );
  }
  return true;
}

function assertLegalProfessionalCanApprove(profile, jurisdictionCode) {
  objectRequired(profile, "profile");
  const status = enumValue(
    profile.status,
    PROFESSIONAL_STATUSES,
    "profile.status",
  );
  if (status !== "active") {
    throw new InterventionLegalContractError(
      "permission-denied",
      "legal professional is not active",
    );
  }
  const roles = requiredStringArray(profile.roleCodes, "profile.roleCodes", 20);
  if (!roles.some((role) => LAWYER_APPROVER_ROLES.includes(role))) {
    throw new InterventionLegalContractError(
      "permission-denied",
      "profile has no lawyer approval role",
    );
  }
  const jurisdictions = requiredStringArray(
    profile.jurisdictionCodes,
    "profile.jurisdictionCodes",
    100,
  ).map((value) => value.toLowerCase());
  const requested = requiredCode(jurisdictionCode, "jurisdictionCode");
  if (!jurisdictions.includes("*") && !jurisdictions.includes(requested)) {
    throw new InterventionLegalContractError(
      "permission-denied",
      "profile does not cover the requested jurisdiction",
    );
  }
  return true;
}

function assertExternalDispatchReadiness(input) {
  objectRequired(input, "dispatchReadiness");
  exactKeys(
    input,
    [
      "documentStatus",
      "immutableApprovedSnapshotExists",
      "lawyerApprovalDecisionExists",
      "clientAuthorizationRequired",
      "clientAuthorizationExists",
      "dataMinimizationConfirmed",
      "artifactIntegrityHash",
    ],
    [
      "documentStatus",
      "immutableApprovedSnapshotExists",
      "lawyerApprovalDecisionExists",
      "clientAuthorizationRequired",
      "clientAuthorizationExists",
      "dataMinimizationConfirmed",
      "artifactIntegrityHash",
    ],
  );

  const failures = [];
  if (input.documentStatus !== "approved") failures.push("document_not_approved");
  if (input.immutableApprovedSnapshotExists !== true) {
    failures.push("approved_snapshot_missing");
  }
  if (input.lawyerApprovalDecisionExists !== true) {
    failures.push("lawyer_approval_missing");
  }
  if (
    input.clientAuthorizationRequired === true &&
    input.clientAuthorizationExists !== true
  ) {
    failures.push("client_authorization_missing");
  }
  if (input.dataMinimizationConfirmed !== true) {
    failures.push("data_minimization_unconfirmed");
  }
  const hash = requiredString(
    input.artifactIntegrityHash,
    "artifactIntegrityHash",
    128,
  ).toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(hash)) {
    failures.push("artifact_integrity_hash_invalid");
  }
  if (failures.length > 0) {
    throw new InterventionLegalContractError(
      "failed-precondition",
      "external dispatch gate is not satisfied",
      {failures},
    );
  }
  return true;
}

module.exports = Object.freeze({
  CONTRACT_VERSION,
  COLLECTIONS,
  LEGAL_MATTER_STATUSES,
  ASSESSMENT_STATUSES,
  PLAN_STATUSES,
  ACTION_STATUSES,
  APPROVAL_REQUEST_STATUSES,
  PROFESSIONAL_STATUSES,
  ROLE_CODES,
  LAWYER_APPROVER_ROLES,
  APPROVAL_TYPES,
  LINK_TYPES,
  INTERVENTION_ACTION_TYPES,
  InterventionLegalContractError,
  objectRequired,
  exactKeys,
  requiredString,
  optionalString,
  requiredCode,
  optionalCode,
  requiredCountryCode,
  enumValue,
  requiredStringArray,
  optionalBoolean,
  parseCreateLegalMatterCommand,
  parseTransitionLegalMatterCommand,
  parseApprovalDecisionCommand,
  assertSegregationOfDuties,
  assertLegalProfessionalCanApprove,
  assertExternalDispatchReadiness,
});
