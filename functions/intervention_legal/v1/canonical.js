"use strict";

const crypto = require("node:crypto");
const {
  InterventionLegalContractError,
  requiredString,
  requiredCode,
  requiredCountryCode,
} = require("./contracts");

function normalizeText(value, field, maxLength = 512) {
  return requiredString(value, field, maxLength)
    .normalize("NFKC")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeInternalCode(value, field) {
  return requiredCode(value, field)
    .normalize("NFKC")
    .toLowerCase();
}

function normalizeJurisdictionCode(value) {
  return normalizeInternalCode(value, "jurisdictionCode");
}

function normalizeMatterScopeCode(value) {
  return normalizeInternalCode(value, "matterScopeCode");
}

function normalizeCountryCode(value) {
  return requiredCountryCode(value);
}

function stableValue(value) {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value !== null && typeof value === "object") {
    const output = {};
    for (const key of Object.keys(value).sort()) {
      const child = value[key];
      if (child !== undefined) output[key] = stableValue(child);
    }
    return output;
  }
  return value;
}

function stableStringify(value) {
  return JSON.stringify(stableValue(value));
}

function sha256Hex(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function canonicalPayloadFingerprint(value) {
  if (value === undefined) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      "fingerprint payload is required",
    );
  }
  return sha256Hex(stableStringify(value));
}

function canonicalizeLegalMatterIdentity(input) {
  if (input === null || typeof input !== "object" || Array.isArray(input)) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      "legal matter identity must be an object",
    );
  }
  return Object.freeze({
    tenantId: normalizeText(input.tenantId, "tenantId", 128),
    canonicalBrandId: normalizeText(
      input.canonicalBrandId,
      "canonicalBrandId",
      128,
    ),
    caseId: normalizeText(input.caseId, "caseId", 128),
    jurisdictionCode: normalizeJurisdictionCode(input.jurisdictionCode),
    matterScopeCode: normalizeMatterScopeCode(input.matterScopeCode),
    countryCode: normalizeCountryCode(input.countryCode),
  });
}

function canonicalizeReference(input) {
  if (input === null || typeof input !== "object" || Array.isArray(input)) {
    throw new InterventionLegalContractError(
      "invalid-argument",
      "reference must be an object",
    );
  }
  return Object.freeze({
    referenceType: normalizeInternalCode(
      input.referenceType,
      "referenceType",
    ),
    referenceId: normalizeText(input.referenceId, "referenceId", 256),
  });
}

module.exports = Object.freeze({
  normalizeText,
  normalizeInternalCode,
  normalizeJurisdictionCode,
  normalizeMatterScopeCode,
  normalizeCountryCode,
  stableStringify,
  sha256Hex,
  canonicalPayloadFingerprint,
  canonicalizeLegalMatterIdentity,
  canonicalizeReference,
});
