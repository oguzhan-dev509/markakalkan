/* eslint-disable max-len */
"use strict";

const {immutableSnapshot} = require("./canonical");

const PROFESSIONAL_SERVICES_CONTRACT_VERSION =
  "professional-services-core-v1";
const SERVICE_REQUEST_CONTRACT_VERSION =
  "professional-service-request-v1";
const SERVICE_PROVIDER_CONTRACT_VERSION =
  "professional-service-provider-v1";
const SERVICE_ENGAGEMENT_CONTRACT_VERSION =
  "professional-service-engagement-v1";
const SERVICE_ASSIGNMENT_CONTRACT_VERSION =
  "professional-service-assignment-v1";
const CLIENT_AUTHORIZATION_CONTRACT_VERSION =
  "professional-client-authorization-v1";
const CONFLICT_CHECK_CONTRACT_VERSION =
  "professional-conflict-check-v1";

const SERVICE_FAMILIES = Object.freeze([
  "legal",
  "field_investigation",
]);

const SERVICE_CATALOG = Object.freeze({
  legal_preliminary_assessment: "legal",
  platform_takedown_complaint: "legal",
  cease_and_desist_preparation: "legal",
  counter_notice_appeal: "legal",
  customs_application: "legal",
  administrative_authority_application: "legal",
  ip_legal_advisory: "legal",
  pre_litigation_assessment: "legal",
  litigation_enforcement_referral: "legal",
  settlement_licensing_negotiation: "legal",
  local_counsel_assignment: "legal",
  test_purchase: "field_investigation",
  physical_location_investigation: "field_investigation",
  seller_business_verification: "field_investigation",
  address_activity_verification: "field_investigation",
  product_sample_acquisition: "field_investigation",
  photo_video_documentation: "field_investigation",
  human_osint_deepening: "field_investigation",
  supply_chain_relationship_investigation: "field_investigation",
  local_field_inspection: "field_investigation",
  sample_delivery_to_expert: "field_investigation",
  witness_source_interview_record: "field_investigation",
  customs_detained_goods_inspection: "field_investigation",
});

const SERVICE_PRIORITIES = Object.freeze([
  "low",
  "medium",
  "high",
  "critical",
]);

const PROVIDER_TYPES = Object.freeze([
  "lawyer",
  "ip_attorney",
  "field_investigator",
  "customs_broker",
  "laboratory",
  "expert_witness",
  "product_safety_expert",
  "translator",
  "other_specialist",
]);

const PROVIDER_STATUSES = Object.freeze([
  "pending_verification",
  "active",
  "suspended",
  "expired",
  "revoked",
  "archived",
]);

const QUALIFICATION_STATUSES = Object.freeze([
  "pending_verification",
  "verified_active",
  "expired",
  "suspended",
  "revoked",
]);

const PROFESSIONAL_INSURANCE_STATUSES = Object.freeze([
  "not_required",
  "unknown",
  "verified_active",
  "expired",
]);

const ENGAGEMENT_MODES = Object.freeze([
  "single_service",
  "matter_based",
  "ongoing_retainer",
  "emergency_response",
]);

const ASSIGNMENT_MODES = Object.freeze([
  "human_only",
  "agent_assisted_human",
]);

const BILLING_MODELS = Object.freeze([
  "included_in_plan",
  "fixed_fee",
  "hourly",
  "retainer",
  "per_action",
  "expense_reimbursement",
  "quotation_required",
]);

const CLIENT_AUTHORIZATION_TYPES = Object.freeze([
  "service_scope",
  "budget",
  "data_access",
  "test_purchase",
  "external_submission",
]);

const AUTHORIZATION_DECISIONS = Object.freeze([
  "granted",
  "denied",
  "revoked",
]);

const CONFLICT_CHECK_OUTCOMES = Object.freeze([
  "cleared",
  "potential_conflict",
  "conflict_confirmed",
  "waived",
  "not_required",
]);

const SOURCE_REFERENCE_FIELDS = Object.freeze([
  "riskSignalId",
  "riskOperationId",
  "caseId",
  "evidenceRefId",
  "evidenceObjectId",
  "legalMatterId",
  "authorityActionId",
  "customsSubmissionId",
  "customsInterventionId",
  "counterfeitTwinId",
]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CODE = /^[a-z0-9][a-z0-9_.-]{0,79}$/;
const JURISDICTION = /^(\*|[a-z0-9][a-z0-9-]{1,31})$/;
const CURRENCY = /^[A-Z]{3}$/;
const SHA256 = /^[0-9a-f]{64}$/;

class ProfessionalServicesContractError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ProfessionalServicesContractError";
    this.code = code;
  }
}

function fail(message, code = "invalid-argument") {
  throw new ProfessionalServicesContractError(code, message);
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

function requiredString(value, field, minimum = 1, maximum = 2000) {
  if (typeof value !== "string") {
    fail(`${field} invalid`);
  }
  const clean = value.trim();
  if (clean.length < minimum || clean.length > maximum) {
    fail(`${field} invalid`);
  }
  for (const character of clean) {
    const code = character.charCodeAt(0);
    if (code === 127 || (code < 32 && ![9, 10, 13].includes(code))) {
      fail(`${field} invalid`);
    }
  }
  return clean;
}

function optionalString(value, field, maximum = 2000) {
  if (value == null) {
    return null;
  }
  return requiredString(value, field, 1, maximum);
}

function requiredCode(value, field) {
  const clean = requiredString(value, field, 1, 80).toLowerCase();
  if (!CODE.test(clean)) {
    fail(`${field} invalid`);
  }
  return clean;
}

function requiredUid(value, field) {
  return requiredString(value, field, 1, 128);
}

function requiredUuid(value, field) {
  const clean = requiredString(value, field, 36, 36).toLowerCase();
  if (!UUID.test(clean)) {
    fail(`${field} invalid`);
  }
  return clean;
}

function requiredSha256(value, field) {
  const clean = requiredString(value, field, 64, 64).toLowerCase();
  if (!SHA256.test(clean)) {
    fail(`${field} invalid`);
  }
  return clean;
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

function jurisdictionCode(value, field = "jurisdictionCode") {
  const clean = requiredString(value, field, 1, 32).toLowerCase();
  if (!JURISDICTION.test(clean)) {
    fail(`${field} invalid`);
  }
  return clean;
}

function stringArray(value, field, maximumItems, itemMaximum = 160) {
  if (!Array.isArray(value) || value.length > maximumItems) {
    fail(`${field} invalid`);
  }
  const result = value.map((item, index) =>
    requiredString(item, `${field}[${index}]`, 1, itemMaximum));
  if (new Set(result).size !== result.length) {
    fail(`${field} contains duplicates`);
  }
  return result;
}

function codeArray(value, field, maximumItems, allowEmpty = false) {
  const result = stringArray(value, field, maximumItems, 80)
      .map((item, index) => requiredCode(item, `${field}[${index}]`));
  if (!allowEmpty && result.length === 0) {
    fail(`${field} required`);
  }
  return result;
}

function jurisdictionArray(value, field, maximumItems) {
  const result = stringArray(value, field, maximumItems, 32)
      .map((item, index) => jurisdictionCode(item, `${field}[${index}]`));
  if (result.length === 0) {
    fail(`${field} required`);
  }
  return result;
}

function positiveInteger(value, field, maximum = Number.MAX_SAFE_INTEGER,
    allowZero = false) {
  const minimum = allowZero ? 0 : 1;
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    fail(`${field} invalid`);
  }
  return value;
}

function booleanValue(value, field) {
  if (typeof value !== "boolean") {
    fail(`${field} invalid`);
  }
  return value;
}

function normalizeSourceReferences(raw) {
  objectRequired(raw, "sourceReferences");
  const extras = Object.keys(raw)
      .filter((key) => !SOURCE_REFERENCE_FIELDS.includes(key));
  if (extras.length > 0) {
    fail("sourceReferences invalid");
  }
  const result = {};
  for (const field of SOURCE_REFERENCE_FIELDS) {
    if (raw[field] != null) {
      result[field] = requiredString(raw[field], `sourceReferences.${field}`,
          1, 128);
    }
  }
  if (Object.keys(result).length === 0) {
    fail("at least one canonical source reference required");
  }
  return immutableSnapshot(result);
}

function normalizeScope(raw) {
  objectRequired(raw, "scope");
  const allowed = new Set(["summary", "inclusions", "exclusions"]);
  if (Object.keys(raw).some((key) => !allowed.has(key))) {
    fail("scope invalid");
  }
  return immutableSnapshot({
    summary: requiredString(raw.summary, "scope.summary", 10, 3000),
    inclusions: stringArray(raw.inclusions, "scope.inclusions", 50, 500),
    exclusions: stringArray(raw.exclusions, "scope.exclusions", 50, 500),
  });
}

function parseServiceRequest(raw) {
  strict(raw, SERVICE_REQUEST_CONTRACT_VERSION, [
    "requestId",
    "tenantId",
    "canonicalBrandId",
    "serviceCode",
    "priority",
    "jurisdictionCode",
    "sourceReferences",
    "title",
    "objective",
    "scope",
    "requestedByUid",
    "requestedAt",
  ]);
  const serviceCode = requiredCode(raw.serviceCode, "serviceCode");
  const serviceFamily = SERVICE_CATALOG[serviceCode];
  if (!serviceFamily) {
    fail("serviceCode unsupported");
  }
  return immutableSnapshot({
    contractVersion: raw.contractVersion,
    requestId: requiredUuid(raw.requestId, "requestId"),
    tenantId: requiredString(raw.tenantId, "tenantId", 1, 128),
    canonicalBrandId: requiredString(raw.canonicalBrandId,
        "canonicalBrandId", 1, 128),
    serviceCode,
    serviceFamily,
    priority: enumValue(raw.priority, SERVICE_PRIORITIES, "priority"),
    jurisdictionCode: jurisdictionCode(raw.jurisdictionCode),
    sourceReferences: normalizeSourceReferences(raw.sourceReferences),
    title: requiredString(raw.title, "title", 5, 180),
    objective: requiredString(raw.objective, "objective", 10, 3000),
    scope: normalizeScope(raw.scope),
    requestedByUid: requiredUid(raw.requestedByUid, "requestedByUid"),
    requestedAt: isoInstant(raw.requestedAt, "requestedAt"),
  });
}

function parseQualification(raw, index) {
  objectRequired(raw, `qualifications[${index}]`);
  const allowed = new Set([
    "qualificationCode",
    "issuingAuthority",
    "jurisdictionCode",
    "credentialReference",
    "validFrom",
    "validUntil",
    "status",
  ]);
  if (Object.keys(raw).some((key) => !allowed.has(key))) {
    fail(`qualifications[${index}] invalid`);
  }
  const validFrom = isoInstant(raw.validFrom,
      `qualifications[${index}].validFrom`);
  const validUntil = raw.validUntil == null ? null :
    isoInstant(raw.validUntil, `qualifications[${index}].validUntil`);
  if (validUntil && Date.parse(validUntil) <= Date.parse(validFrom)) {
    fail(`qualifications[${index}].validUntil invalid`);
  }
  return immutableSnapshot({
    qualificationCode: requiredCode(raw.qualificationCode,
        `qualifications[${index}].qualificationCode`),
    issuingAuthority: requiredString(raw.issuingAuthority,
        `qualifications[${index}].issuingAuthority`, 2, 240),
    jurisdictionCode: jurisdictionCode(raw.jurisdictionCode,
        `qualifications[${index}].jurisdictionCode`),
    credentialReference: requiredString(raw.credentialReference,
        `qualifications[${index}].credentialReference`, 2, 240),
    validFrom,
    validUntil,
    status: enumValue(raw.status, QUALIFICATION_STATUSES,
        `qualifications[${index}].status`),
  });
}

function parseServiceProvider(raw) {
  strict(raw, SERVICE_PROVIDER_CONTRACT_VERSION, [
    "providerId",
    "providerType",
    "displayName",
    "organizationName",
    "status",
    "expertiseCodes",
    "jurisdictionCodes",
    "languageCodes",
    "qualifications",
    "professionalInsuranceStatus",
    "conflictCheckRequired",
    "verifiedAt",
    "verifiedByUid",
  ]);
  if (!Array.isArray(raw.qualifications) ||
      raw.qualifications.length === 0 ||
      raw.qualifications.length > 50) {
    fail("qualifications invalid");
  }
  return immutableSnapshot({
    contractVersion: raw.contractVersion,
    providerId: requiredString(raw.providerId, "providerId", 1, 128),
    providerType: enumValue(raw.providerType, PROVIDER_TYPES, "providerType"),
    displayName: requiredString(raw.displayName, "displayName", 2, 180),
    organizationName: optionalString(raw.organizationName,
        "organizationName", 240),
    status: enumValue(raw.status, PROVIDER_STATUSES, "status"),
    expertiseCodes: codeArray(raw.expertiseCodes, "expertiseCodes", 50),
    jurisdictionCodes: jurisdictionArray(raw.jurisdictionCodes,
        "jurisdictionCodes", 100),
    languageCodes: codeArray(raw.languageCodes, "languageCodes", 30),
    qualifications: raw.qualifications.map(parseQualification),
    professionalInsuranceStatus: enumValue(
        raw.professionalInsuranceStatus,
        PROFESSIONAL_INSURANCE_STATUSES,
        "professionalInsuranceStatus",
    ),
    conflictCheckRequired: booleanValue(raw.conflictCheckRequired,
        "conflictCheckRequired"),
    verifiedAt: isoInstant(raw.verifiedAt, "verifiedAt"),
    verifiedByUid: requiredUid(raw.verifiedByUid, "verifiedByUid"),
  });
}


function parseServiceEngagement(raw) {
  strict(raw, SERVICE_ENGAGEMENT_CONTRACT_VERSION, [
    "serviceRequestId",
    "engagementMode",
    "scopeFingerprintSha256",
    "clientAuthorizationId",
    "budgetAuthorizationId",
    "createdByUid",
    "createdAt",
  ]);
  return immutableSnapshot({
    contractVersion: raw.contractVersion,
    serviceRequestId: requiredString(raw.serviceRequestId,
        "serviceRequestId", 1, 128),
    engagementMode: enumValue(raw.engagementMode,
        ENGAGEMENT_MODES, "engagementMode"),
    scopeFingerprintSha256: requiredSha256(raw.scopeFingerprintSha256,
        "scopeFingerprintSha256"),
    clientAuthorizationId: requiredString(raw.clientAuthorizationId,
        "clientAuthorizationId", 1, 128),
    budgetAuthorizationId: raw.budgetAuthorizationId == null ? null :
      requiredString(raw.budgetAuthorizationId,
          "budgetAuthorizationId", 1, 128),
    createdByUid: requiredUid(raw.createdByUid, "createdByUid"),
    createdAt: isoInstant(raw.createdAt, "createdAt"),
  });
}

function parseServiceAssignment(raw) {
  strict(raw, SERVICE_ASSIGNMENT_CONTRACT_VERSION, [
    "serviceRequestId",
    "serviceEngagementId",
    "providerId",
    "assignmentMode",
    "assignedByUid",
    "supervisingUid",
    "jurisdictionCode",
    "scope",
    "billingModel",
    "currencyCode",
    "estimatedAmountMinorUnits",
    "slaFirstResponseMinutes",
    "slaCompletionMinutes",
    "dueAt",
    "assignedAt",
  ]);
  const currencyCode = requiredString(raw.currencyCode,
      "currencyCode", 3, 3).toUpperCase();
  if (!CURRENCY.test(currencyCode)) {
    fail("currencyCode invalid");
  }
  return immutableSnapshot({
    contractVersion: raw.contractVersion,
    serviceRequestId: requiredString(raw.serviceRequestId,
        "serviceRequestId", 1, 128),
    serviceEngagementId: optionalString(raw.serviceEngagementId,
        "serviceEngagementId", 128),
    providerId: requiredString(raw.providerId, "providerId", 1, 128),
    assignmentMode: enumValue(raw.assignmentMode,
        ASSIGNMENT_MODES, "assignmentMode"),
    assignedByUid: requiredUid(raw.assignedByUid, "assignedByUid"),
    supervisingUid: requiredUid(raw.supervisingUid, "supervisingUid"),
    jurisdictionCode: jurisdictionCode(raw.jurisdictionCode),
    scope: normalizeScope(raw.scope),
    billingModel: enumValue(raw.billingModel,
        BILLING_MODELS, "billingModel"),
    currencyCode,
    estimatedAmountMinorUnits: positiveInteger(
        raw.estimatedAmountMinorUnits,
        "estimatedAmountMinorUnits",
        1000000000000,
        true,
    ),
    slaFirstResponseMinutes: positiveInteger(
        raw.slaFirstResponseMinutes,
        "slaFirstResponseMinutes",
        525600,
    ),
    slaCompletionMinutes: positiveInteger(
        raw.slaCompletionMinutes,
        "slaCompletionMinutes",
        5256000,
    ),
    dueAt: isoInstant(raw.dueAt, "dueAt"),
    assignedAt: isoInstant(raw.assignedAt, "assignedAt"),
  });
}

function parseClientAuthorization(raw) {
  strict(raw, CLIENT_AUTHORIZATION_CONTRACT_VERSION, [
    "serviceRequestId",
    "authorizationType",
    "decision",
    "scopeFingerprintSha256",
    "amountMinorUnits",
    "currencyCode",
    "decidedByUid",
    "decisionNote",
    "decidedAt",
  ]);
  const amountMinorUnits = raw.amountMinorUnits == null ? null :
    positiveInteger(raw.amountMinorUnits, "amountMinorUnits",
        1000000000000, true);
  const currencyCode = raw.currencyCode == null ? null :
    requiredString(raw.currencyCode, "currencyCode", 3, 3).toUpperCase();
  if (currencyCode && !CURRENCY.test(currencyCode)) {
    fail("currencyCode invalid");
  }
  if ((amountMinorUnits == null) !== (currencyCode == null)) {
    fail("authorization amount and currency must be provided together");
  }
  return immutableSnapshot({
    contractVersion: raw.contractVersion,
    serviceRequestId: requiredString(raw.serviceRequestId,
        "serviceRequestId", 1, 128),
    authorizationType: enumValue(raw.authorizationType,
        CLIENT_AUTHORIZATION_TYPES, "authorizationType"),
    decision: enumValue(raw.decision,
        AUTHORIZATION_DECISIONS, "decision"),
    scopeFingerprintSha256: requiredSha256(raw.scopeFingerprintSha256,
        "scopeFingerprintSha256"),
    amountMinorUnits,
    currencyCode,
    decidedByUid: requiredUid(raw.decidedByUid, "decidedByUid"),
    decisionNote: requiredString(raw.decisionNote,
        "decisionNote", 3, 2000),
    decidedAt: isoInstant(raw.decidedAt, "decidedAt"),
    immutable: true,
  });
}

function parseConflictCheck(raw) {
  strict(raw, CONFLICT_CHECK_CONTRACT_VERSION, [
    "serviceRequestId",
    "providerId",
    "outcome",
    "checkedByUid",
    "authorizedByUid",
    "note",
    "checkedAt",
  ]);
  const outcome = enumValue(raw.outcome,
      CONFLICT_CHECK_OUTCOMES, "outcome");
  const authorizedByUid = optionalString(raw.authorizedByUid,
      "authorizedByUid", 128);
  if (outcome === "waived" && !authorizedByUid) {
    fail("waiver authorization required");
  }
  return immutableSnapshot({
    contractVersion: raw.contractVersion,
    serviceRequestId: requiredString(raw.serviceRequestId,
        "serviceRequestId", 1, 128),
    providerId: requiredString(raw.providerId, "providerId", 1, 128),
    outcome,
    checkedByUid: requiredUid(raw.checkedByUid, "checkedByUid"),
    authorizedByUid,
    note: requiredString(raw.note, "note", 3, 2000),
    checkedAt: isoInstant(raw.checkedAt, "checkedAt"),
    immutable: true,
  });
}

module.exports = Object.freeze({
  ASSIGNMENT_MODES,
  AUTHORIZATION_DECISIONS,
  BILLING_MODELS,
  CLIENT_AUTHORIZATION_CONTRACT_VERSION,
  CLIENT_AUTHORIZATION_TYPES,
  CONFLICT_CHECK_CONTRACT_VERSION,
  CONFLICT_CHECK_OUTCOMES,
  ENGAGEMENT_MODES,
  PROFESSIONAL_INSURANCE_STATUSES,
  PROFESSIONAL_SERVICES_CONTRACT_VERSION,
  PROVIDER_STATUSES,
  PROVIDER_TYPES,
  QUALIFICATION_STATUSES,
  SERVICE_ASSIGNMENT_CONTRACT_VERSION,
  SERVICE_CATALOG,
  SERVICE_ENGAGEMENT_CONTRACT_VERSION,
  SERVICE_FAMILIES,
  SERVICE_PRIORITIES,
  SERVICE_PROVIDER_CONTRACT_VERSION,
  SERVICE_REQUEST_CONTRACT_VERSION,
  SOURCE_REFERENCE_FIELDS,
  ProfessionalServicesContractError,
  normalizeScope,
  normalizeSourceReferences,
  parseClientAuthorization,
  parseConflictCheck,
  parseServiceAssignment,
  parseServiceEngagement,
  parseServiceProvider,
  parseServiceRequest,
  requiredCode,
  requiredSha256,
  requiredString,
  requiredUid,
  requiredUuid,
});
