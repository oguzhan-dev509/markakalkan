/* eslint-disable max-len */
const {createHash} = require("node:crypto");

const PROFILE_STATUSES = Object.freeze([
  "draft",
  "under_review",
  "active",
  "suspended",
  "expired",
  "archived",
]);

const INTERVENTION_STATUSES = Object.freeze([
  "draft",
  "risk_review",
  "under_preliminary_review",
  "temporarily_detained",
  "awaiting_right_holder",
  "authentication_in_progress",
  "infringement_not_confirmed",
  "infringement_suspected",
  "infringement_confirmed",
  "importer_objection",
  "legal_action_required",
  "destruction_pending",
  "destroyed",
  "released",
  "referred_to_authority",
  "closed",
  "archived",
]);

const INTEGRITY_STATUSES = Object.freeze([
  "no_integrity_signal",
  "integrity_signal_detected",
  "explanation_requested",
  "independent_review_required",
  "review_in_progress",
  "signal_not_substantiated",
  "irregularity_confirmed",
  "referred_to_authority",
  "closed",
]);

const PRIORITIES = Object.freeze(["low", "normal", "high", "critical"]);
const SOURCE_TYPES = Object.freeze([
  "customs_notification",
  "brand_report",
  "risk_signal",
  "field_report",
  "law_enforcement_referral",
  "other",
]);
const BORDER_POINT_TYPES = Object.freeze([
  "seaport",
  "airport",
  "land_border",
  "rail",
  "postal_center",
  "free_zone",
  "warehouse",
  "other",
]);
const AUTHENTICATION_RESULTS = Object.freeze([
  "not_started",
  "inconclusive",
  "likely_authentic",
  "likely_counterfeit",
  "confirmed_authentic",
  "confirmed_counterfeit",
]);
const DECLARED_UNITS = Object.freeze([
  "unit",
  "pair",
  "set",
  "box",
  "carton",
  "pallet",
  "kilogram",
  "liter",
  "meter",
  "other",
]);
const CONTRACT = Object.freeze({
  profileCreateRequest: "customs-protection-profile-create-request-v1",
  profileUpdateRequest: "customs-protection-profile-update-request-v1",
  profileTransitionRequest: "customs-protection-profile-transition-request-v1",
  profileListRequest: "customs-protection-profile-list-request-v1",
  profileDetailRequest: "customs-protection-profile-detail-request-v1",
  interventionCreateRequest: "customs-border-intervention-create-request-v1",
  interventionUpdateRequest: "customs-border-intervention-update-request-v1",
  interventionTransitionRequest: "customs-border-intervention-transition-request-v1",
  interventionListRequest: "customs-border-intervention-list-request-v1",
  interventionDetailRequest: "customs-border-intervention-detail-request-v1",
});

class CustomsSecurityError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "CustomsSecurityError";
    this.code = code;
  }
}

function objectRequired(value, field = "request") {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new CustomsSecurityError("invalid-argument", `${field} object required`);
  }
}

function strict(raw, version, fields) {
  objectRequired(raw);
  const allowed = new Set(["contractVersion", ...fields]);
  const extra = Object.keys(raw).filter((key) => !allowed.has(key));
  if (raw.contractVersion !== version || extra.length) {
    throw new CustomsSecurityError("invalid-argument", "request contract invalid");
  }
}

function cleanText(value, field, minimum, maximum, optional = false) {
  if (value == null && optional) return null;
  if (typeof value !== "string") {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  const clean = value.trim();
  const forbidden = [...clean].some((character) => {
    const code = character.charCodeAt(0);
    return code === 127 || (code < 32 && ![9, 10, 13].includes(code));
  });
  if (clean.length < minimum || clean.length > maximum || forbidden) {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  return clean;
}

function enumValue(value, allowed, field, optional = false) {
  if (value == null && optional) return null;
  const clean = cleanText(value, field, 1, 80);
  if (!allowed.includes(clean)) {
    throw new CustomsSecurityError("invalid-argument", `${field} unsupported`);
  }
  return clean;
}

function uuid(value) {
  const clean = cleanText(value, "requestId", 36, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(clean)) {
    throw new CustomsSecurityError("invalid-argument", "requestId invalid");
  }
  return clean.toLowerCase();
}

function iso(value, field, optional = true) {
  if (value == null && optional) return null;
  const clean = cleanText(value, field, 20, 40);
  const parsed = new Date(clean);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString() !== clean) {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  return clean;
}

function countryCode(value, field, optional = false) {
  if (value == null && optional) return null;
  const clean = cleanText(value, field, 2, 2).toUpperCase();
  if (!/^[A-Z]{2}$/.test(clean)) {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  return clean;
}

function currencyCode(value, field, optional = true) {
  if (value == null && optional) return null;
  const clean = cleanText(value, field, 3, 3).toUpperCase();
  if (!/^[A-Z]{3}$/.test(clean)) {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  return clean;
}

function finiteNumber(value, field, minimum, maximum, optional = true) {
  if (value == null && optional) return null;
  if (typeof value !== "number" || !Number.isFinite(value) || value < minimum || value > maximum) {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  return value;
}

function integer(value, field, minimum, maximum, optional = true) {
  if (value == null && optional) return null;
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  return value;
}

function optionalBoolean(value, field) {
  if (value == null) return false;
  if (typeof value !== "boolean") {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  return value;
}

function stringArray(value, field, maximumItems = 50, maximumLength = 300) {
  if (value == null) return Object.freeze([]);
  if (!Array.isArray(value) || value.length > maximumItems) {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  const normalized = value.map((item, index) =>
    cleanText(item, `${field}[${index}]`, 1, maximumLength),
  );
  return Object.freeze([...new Set(normalized)].sort((a, b) => a.localeCompare(b, "tr")));
}

function countryArray(value, field, maximumItems = 50) {
  if (value == null) return Object.freeze([]);
  if (!Array.isArray(value) || value.length > maximumItems) {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  return Object.freeze([...new Set(value.map((item, index) =>
    countryCode(item, `${field}[${index}]`),
  ))].sort());
}

function party(value, field, optional = true) {
  if (value == null && optional) return null;
  objectRequired(value, field);
  const allowed = new Set(["name", "referenceId", "countryCode", "addressSummary"]);
  if (Object.keys(value).some((key) => !allowed.has(key))) {
    throw new CustomsSecurityError("invalid-argument", `${field} invalid`);
  }
  const result = {
    name: cleanText(value.name, `${field}.name`, 1, 240),
  };
  const referenceId = cleanText(value.referenceId, `${field}.referenceId`, 1, 160, true);
  const code = countryCode(value.countryCode, `${field}.countryCode`, true);
  const addressSummary = cleanText(value.addressSummary, `${field}.addressSummary`, 1, 500, true);
  if (referenceId) result.referenceId = referenceId;
  if (code) result.countryCode = code;
  if (addressSummary) result.addressSummary = addressSummary;
  return Object.freeze(result);
}

function pageSize(value) {
  const result = value == null ? 25 : value;
  return integer(result, "pageSize", 1, 50, false);
}

function pageToken(value) {
  return cleanText(value, "pageToken", 1, 1000, true);
}

function profilePayload(raw) {
  const validFrom = iso(raw.validFrom, "validFrom", true);
  const validUntil = iso(raw.validUntil, "validUntil", true);
  const reviewDueAt = iso(raw.reviewDueAt, "reviewDueAt", true);
  if (validFrom && validUntil && validFrom > validUntil) {
    throw new CustomsSecurityError("invalid-argument", "profile validity range invalid");
  }
  return Object.freeze({
    profileName: cleanText(raw.profileName, "profileName", 3, 200),
    rightHolderName: cleanText(raw.rightHolderName, "rightHolderName", 2, 240),
    rightHolderReferenceIds: stringArray(raw.rightHolderReferenceIds, "rightHolderReferenceIds"),
    authorizedRepresentativeIds: stringArray(raw.authorizedRepresentativeIds, "authorizedRepresentativeIds"),
    authorizedManufacturerIds: stringArray(raw.authorizedManufacturerIds, "authorizedManufacturerIds"),
    authorizedImporterIds: stringArray(raw.authorizedImporterIds, "authorizedImporterIds"),
    protectedProductIds: stringArray(raw.protectedProductIds, "protectedProductIds", 100),
    hsCodes: stringArray(raw.hsCodes, "hsCodes", 100, 20),
    productCategories: stringArray(raw.productCategories, "productCategories"),
    originCountries: countryArray(raw.originCountries, "originCountries"),
    authorizedImportCountries: countryArray(raw.authorizedImportCountries, "authorizedImportCountries"),
    authenticationInstructions: cleanText(raw.authenticationInstructions, "authenticationInstructions", 10, 5000),
    serialVerificationMethods: stringArray(raw.serialVerificationMethods, "serialVerificationMethods", 50, 500),
    securityFeatureSummaries: stringArray(raw.securityFeatureSummaries, "securityFeatureSummaries", 100, 500),
    counterfeitTwinRecordIds: stringArray(raw.counterfeitTwinRecordIds, "counterfeitTwinRecordIds", 100),
    productionAssetIds: stringArray(raw.productionAssetIds, "productionAssetIds", 100),
    riskCountryCodes: countryArray(raw.riskCountryCodes, "riskCountryCodes"),
    riskRouteSummaries: stringArray(raw.riskRouteSummaries, "riskRouteSummaries", 100, 500),
    emergencyContactIds: stringArray(raw.emergencyContactIds, "emergencyContactIds", 50),
    validFrom,
    validUntil,
    reviewDueAt,
  });
}

const PROFILE_FIELDS = Object.freeze([
  "tenantId",
  "canonicalBrandId",
  "profileName",
  "rightHolderName",
  "rightHolderReferenceIds",
  "authorizedRepresentativeIds",
  "authorizedManufacturerIds",
  "authorizedImporterIds",
  "protectedProductIds",
  "hsCodes",
  "productCategories",
  "originCountries",
  "authorizedImportCountries",
  "authenticationInstructions",
  "serialVerificationMethods",
  "securityFeatureSummaries",
  "counterfeitTwinRecordIds",
  "productionAssetIds",
  "riskCountryCodes",
  "riskRouteSummaries",
  "emergencyContactIds",
  "validFrom",
  "validUntil",
  "reviewDueAt",
  "requestId",
]);

function profileCreateRequest(raw) {
  strict(raw, CONTRACT.profileCreateRequest, PROFILE_FIELDS);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
    ...profilePayload(raw),
    requestId: uuid(raw.requestId),
  });
}

function profileUpdateRequest(raw) {
  strict(raw, CONTRACT.profileUpdateRequest, ["profileId", ...PROFILE_FIELDS]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    profileId: cleanText(raw.profileId, "profileId", 1, 128),
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
    ...profilePayload(raw),
    requestId: uuid(raw.requestId),
  });
}

function profileTransitionRequest(raw) {
  strict(raw, CONTRACT.profileTransitionRequest, [
    "profileId",
    "tenantId",
    "canonicalBrandId",
    "nextStatus",
    "reason",
    "requestId",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    profileId: cleanText(raw.profileId, "profileId", 1, 128),
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
    nextStatus: enumValue(raw.nextStatus, PROFILE_STATUSES, "nextStatus"),
    reason: cleanText(raw.reason, "reason", 10, 2000),
    requestId: uuid(raw.requestId),
  });
}

function profileListRequest(raw) {
  strict(raw, CONTRACT.profileListRequest, [
    "tenantId",
    "canonicalBrandId",
    "status",
    "pageSize",
    "pageToken",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
    status: enumValue(raw.status, PROFILE_STATUSES, "status", true),
    pageSize: pageSize(raw.pageSize),
    pageToken: pageToken(raw.pageToken),
  });
}

function profileDetailRequest(raw) {
  strict(raw, CONTRACT.profileDetailRequest, [
    "profileId",
    "tenantId",
    "canonicalBrandId",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    profileId: cleanText(raw.profileId, "profileId", 1, 128),
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
  });
}

function interventionPayload(raw) {
  const detainedAt = iso(raw.detainedAt, "detainedAt", true);
  const notificationReceivedAt = iso(raw.notificationReceivedAt, "notificationReceivedAt", true);
  const responseDeadlineAt = iso(raw.responseDeadlineAt, "responseDeadlineAt", true);
  const actionDeadlineAt = iso(raw.actionDeadlineAt, "actionDeadlineAt", true);
  if (responseDeadlineAt && actionDeadlineAt && responseDeadlineAt > actionDeadlineAt) {
    throw new CustomsSecurityError("invalid-argument", "intervention deadline range invalid");
  }
  const declaredValue = finiteNumber(raw.declaredValue, "declaredValue", 0, 1000000000000, true);
  const declaredCurrency = currencyCode(raw.declaredCurrency, "declaredCurrency", true);
  if ((declaredValue == null) !== (declaredCurrency == null)) {
    throw new CustomsSecurityError("invalid-argument", "declared value and currency must be provided together");
  }
  const declaredQuantity = finiteNumber(raw.declaredQuantity, "declaredQuantity", 0, 1000000000000, true);
  const declaredUnit = enumValue(raw.declaredUnit, DECLARED_UNITS, "declaredUnit", true);
  if ((declaredQuantity == null) !== (declaredUnit == null)) {
    throw new CustomsSecurityError("invalid-argument", "declared quantity and unit must be provided together");
  }
  return Object.freeze({
    protectionProfileId: cleanText(raw.protectionProfileId, "protectionProfileId", 1, 128),
    priority: enumValue(raw.priority, PRIORITIES, "priority"),
    sourceType: enumValue(raw.sourceType, SOURCE_TYPES, "sourceType"),
    countryCode: countryCode(raw.countryCode, "countryCode"),
    customsAuthorityName: cleanText(raw.customsAuthorityName, "customsAuthorityName", 2, 240),
    borderPointType: enumValue(raw.borderPointType, BORDER_POINT_TYPES, "borderPointType"),
    borderPointName: cleanText(raw.borderPointName, "borderPointName", 2, 240),
    shipmentReference: cleanText(raw.shipmentReference, "shipmentReference", 1, 200, true),
    containerReference: cleanText(raw.containerReference, "containerReference", 1, 100, true),
    cargoReference: cleanText(raw.cargoReference, "cargoReference", 1, 160, true),
    trackingReferences: stringArray(raw.trackingReferences, "trackingReferences", 50, 200),
    senderParty: party(raw.senderParty, "senderParty", true),
    recipientParty: party(raw.recipientParty, "recipientParty", true),
    importerParty: party(raw.importerParty, "importerParty", true),
    carrierParty: party(raw.carrierParty, "carrierParty", true),
    customsBrokerParty: party(raw.customsBrokerParty, "customsBrokerParty", true),
    declaredProductDescription: cleanText(raw.declaredProductDescription, "declaredProductDescription", 3, 2000),
    declaredHsCode: cleanText(raw.declaredHsCode, "declaredHsCode", 2, 20, true),
    declaredQuantity,
    declaredUnit,
    declaredValue,
    declaredCurrency,
    suspectedProductIds: stringArray(raw.suspectedProductIds, "suspectedProductIds", 100),
    counterfeitTwinRecordIds: stringArray(raw.counterfeitTwinRecordIds, "counterfeitTwinRecordIds", 100),
    supplyPartnerIds: stringArray(raw.supplyPartnerIds, "supplyPartnerIds", 100),
    supplyFacilityIds: stringArray(raw.supplyFacilityIds, "supplyFacilityIds", 100),
    productionAssetIds: stringArray(raw.productionAssetIds, "productionAssetIds", 100),
    sourceRiskSignalIds: stringArray(raw.sourceRiskSignalIds, "sourceRiskSignalIds", 100),
    detainedAt,
    notificationReceivedAt,
    responseDeadlineAt,
    actionDeadlineAt,
    suspicionReasons: stringArray(raw.suspicionReasons, "suspicionReasons", 100, 1000),
    authenticationResult: enumValue(raw.authenticationResult, AUTHENTICATION_RESULTS, "authenticationResult"),
    decisionSummary: cleanText(raw.decisionSummary, "decisionSummary", 1, 2000, true),
    decisionReason: cleanText(raw.decisionReason, "decisionReason", 1, 2000, true),
    caseId: cleanText(raw.caseId, "caseId", 1, 128, true),
    assignedUserUid: cleanText(raw.assignedUserUid, "assignedUserUid", 1, 128, true),
    reviewerUserUid: cleanText(raw.reviewerUserUid, "reviewerUserUid", 1, 128, true),
    unusualReleaseFlag: optionalBoolean(raw.unusualReleaseFlag, "unusualReleaseFlag"),
    decisionEvidenceMismatchFlag: optionalBoolean(raw.decisionEvidenceMismatchFlag, "decisionEvidenceMismatchFlag"),
    missingRecordOrSampleFlag: optionalBoolean(raw.missingRecordOrSampleFlag, "missingRecordOrSampleFlag"),
    postRecordModificationFlag: optionalBoolean(raw.postRecordModificationFlag, "postRecordModificationFlag"),
    unexplainedAccelerationFlag: optionalBoolean(raw.unexplainedAccelerationFlag, "unexplainedAccelerationFlag"),
    quantityOrDestructionMismatchFlag: optionalBoolean(raw.quantityOrDestructionMismatchFlag, "quantityOrDestructionMismatchFlag"),
    independentReviewRequired: optionalBoolean(raw.independentReviewRequired, "independentReviewRequired"),
  });
}

const INTERVENTION_FIELDS = Object.freeze([
  "tenantId",
  "canonicalBrandId",
  "protectionProfileId",
  "priority",
  "sourceType",
  "countryCode",
  "customsAuthorityName",
  "borderPointType",
  "borderPointName",
  "shipmentReference",
  "containerReference",
  "cargoReference",
  "trackingReferences",
  "senderParty",
  "recipientParty",
  "importerParty",
  "carrierParty",
  "customsBrokerParty",
  "declaredProductDescription",
  "declaredHsCode",
  "declaredQuantity",
  "declaredUnit",
  "declaredValue",
  "declaredCurrency",
  "suspectedProductIds",
  "counterfeitTwinRecordIds",
  "supplyPartnerIds",
  "supplyFacilityIds",
  "productionAssetIds",
  "sourceRiskSignalIds",
  "detainedAt",
  "notificationReceivedAt",
  "responseDeadlineAt",
  "actionDeadlineAt",
  "suspicionReasons",
  "authenticationResult",
  "decisionSummary",
  "decisionReason",
  "caseId",
  "assignedUserUid",
  "reviewerUserUid",
  "unusualReleaseFlag",
  "decisionEvidenceMismatchFlag",
  "missingRecordOrSampleFlag",
  "postRecordModificationFlag",
  "unexplainedAccelerationFlag",
  "quantityOrDestructionMismatchFlag",
  "independentReviewRequired",
  "requestId",
]);

function interventionCreateRequest(raw) {
  strict(raw, CONTRACT.interventionCreateRequest, INTERVENTION_FIELDS);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
    ...interventionPayload(raw),
    requestId: uuid(raw.requestId),
  });
}

function interventionUpdateRequest(raw) {
  strict(raw, CONTRACT.interventionUpdateRequest, ["interventionId", ...INTERVENTION_FIELDS]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    interventionId: cleanText(raw.interventionId, "interventionId", 1, 128),
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
    ...interventionPayload(raw),
    requestId: uuid(raw.requestId),
  });
}

function interventionTransitionRequest(raw) {
  strict(raw, CONTRACT.interventionTransitionRequest, [
    "interventionId",
    "tenantId",
    "canonicalBrandId",
    "nextStatus",
    "reason",
    "decisionReference",
    "humanAssessmentReference",
    "authorityReference",
    "requestId",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    interventionId: cleanText(raw.interventionId, "interventionId", 1, 128),
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
    nextStatus: enumValue(raw.nextStatus, INTERVENTION_STATUSES, "nextStatus"),
    reason: cleanText(raw.reason, "reason", 10, 3000),
    decisionReference: cleanText(raw.decisionReference, "decisionReference", 1, 500, true),
    humanAssessmentReference: cleanText(raw.humanAssessmentReference, "humanAssessmentReference", 1, 500, true),
    authorityReference: cleanText(raw.authorityReference, "authorityReference", 1, 500, true),
    requestId: uuid(raw.requestId),
  });
}

function interventionListRequest(raw) {
  strict(raw, CONTRACT.interventionListRequest, [
    "tenantId",
    "canonicalBrandId",
    "status",
    "protectionProfileId",
    "pageSize",
    "pageToken",
  ]);
  const status = enumValue(raw.status, INTERVENTION_STATUSES, "status", true);
  const protectionProfileId = cleanText(raw.protectionProfileId, "protectionProfileId", 1, 128, true);
  if (status && protectionProfileId) {
    throw new CustomsSecurityError("invalid-argument", "choose status or protectionProfileId filter");
  }
  return Object.freeze({
    contractVersion: raw.contractVersion,
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
    status,
    protectionProfileId,
    pageSize: pageSize(raw.pageSize),
    pageToken: pageToken(raw.pageToken),
  });
}

function interventionDetailRequest(raw) {
  strict(raw, CONTRACT.interventionDetailRequest, [
    "interventionId",
    "tenantId",
    "canonicalBrandId",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    interventionId: cleanText(raw.interventionId, "interventionId", 1, 128),
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
  });
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(
        Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

function fingerprint(value) {
  return createHash("sha256")
      .update(JSON.stringify(canonicalize(value)), "utf8")
      .digest("hex");
}

module.exports = {
  AUTHENTICATION_RESULTS,
  BORDER_POINT_TYPES,
  CONTRACT,
  CustomsSecurityError,
  DECLARED_UNITS,
  INTEGRITY_STATUSES,
  INTERVENTION_STATUSES,
  PRIORITIES,
  PROFILE_STATUSES,
  SOURCE_TYPES,
  fingerprint,
  interventionCreateRequest,
  interventionDetailRequest,
  interventionListRequest,
  interventionTransitionRequest,
  interventionUpdateRequest,
  profileCreateRequest,
  profileDetailRequest,
  profileListRequest,
  profileTransitionRequest,
  profileUpdateRequest,
};
