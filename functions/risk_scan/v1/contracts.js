"use strict";

const STORAGE_SCHEMA_VERSION_V1 = "risk-scan-storage-v1";
const PUBLIC_PROJECTION_VERSION_V1 = "risk-scan-public-lite-projection-v1";
const RATE_LIMIT_CONTRACT_VERSION_V1 = "risk-scan-rate-limit-v1";

function freezeValues(values) {
  return Object.freeze([...values]);
}

const contractVersions = Object.freeze({
  target: "risk-scan-target-v1",
  run: "risk-scan-run-v1",
  channel: "risk-scan-channel-v1",
  observation: "risk-scan-observation-v1",
  finding: "risk-scan-finding-v1",
  report: "risk-scan-report-v1",
  claim: "risk-scan-claim-v1",
});

const scanModes = freezeValues(["quick"]);
const accessTiers = freezeValues(["publicLite", "registered"]);
const identityModes = freezeValues(["anonymous", "resolved"]);
const runStatuses = freezeValues([
  "created",
  "validatingTarget",
  "queued",
  "acquiring",
  "assessing",
  "reporting",
  "completed",
  "completedWithLimits",
  "failedRetryable",
  "failedTerminal",
  "cancelled",
  "expired",
]);
const coverageStatuses = freezeValues([
  "complete",
  "limited",
  "insufficient",
]);
const channelCodes = freezeValues([
  "similarDomains",
  "openWeb",
  "marketplaceLimited",
]);
const channelStatuses = freezeValues([
  "queued",
  "acquiring",
  "assessing",
  "completed",
  "completedWithLimits",
  "failedRetryable",
  "failedTerminal",
  "skipped",
]);
const observationSourceTypes = freezeValues([
  "domain",
  "webPage",
  "marketplaceListing",
]);
const acquisitionStatuses = freezeValues([
  "discovered",
  "acquired",
  "acquiredWithLimits",
  "failedRetryable",
  "failedTerminal",
  "excluded",
]);
const findingTypes = freezeValues([
  "similarDomain",
  "brandNameSimilarity",
  "contentSimilarity",
  "marketplaceListingSignal",
]);
const riskLevels = freezeValues(["low", "medium", "high", "critical"]);
const confidenceLevels = freezeValues(["low", "medium", "high"]);
const impactLevels = freezeValues(["low", "medium", "high", "critical"]);
const interventionDifficulties = freezeValues([
  "easy",
  "moderate",
  "difficult",
]);
const reviewStatuses = freezeValues([
  "signal",
  "reviewRequired",
  "suspicious",
  "confirmed",
  "falsePositive",
]);
const recommendationCodes = freezeValues([
  "reviewFinding",
  "compareWithOfficialSource",
  "monitorSource",
  "noImmediateAction",
]);
const promotionStatuses = freezeValues(["notRequested", "promoted"]);
const reportRecommendedActions = freezeValues([
  "reviewTopFindings",
  "claimScan",
  "startHumanReview",
  "noImmediateAction",
]);
const claimStatuses = freezeValues([
  "issued",
  "claimed",
  "expired",
  "revoked",
]);

function isPlainObject(value) {
  if (value === null || typeof value !== "object") return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function assertPlainObject(value, label) {
  if (!isPlainObject(value)) {
    throw new TypeError(`${label} must be a plain object`);
  }
  return value;
}

function assertEnum(value, allowed, label) {
  if (!allowed.includes(value)) {
    throw new TypeError(`${label} is invalid`);
  }
  return value;
}

function assertNonEmptyString(value, label, maximum = 512) {
  if (typeof value !== "string") {
    throw new TypeError(`${label} must be a string`);
  }
  const normalized = value.trim();
  if (!normalized || Buffer.byteLength(normalized, "utf8") > maximum) {
    throw new TypeError(`${label} is invalid`);
  }
  return normalized;
}

function assertOptionalString(value, label, maximum = 512) {
  if (value === null || value === undefined) return null;
  return assertNonEmptyString(value, label, maximum);
}

function assertIsoTimestamp(value, label) {
  const normalized = assertNonEmptyString(value, label, 64);
  const parsed = Date.parse(normalized);
  if (!Number.isFinite(parsed) || !normalized.includes("T")) {
    throw new TypeError(`${label} must be an ISO timestamp`);
  }
  return normalized;
}

function assertSha256Hex(value, label) {
  const normalized = assertNonEmptyString(value, label, 64);
  if (!/^[a-f0-9]{64}$/.test(normalized)) {
    throw new TypeError(`${label} must be lowercase SHA-256 hex`);
  }
  return normalized;
}

function assertDocumentId(value, label) {
  const normalized = assertNonEmptyString(value, label, 180);
  if (normalized.includes("/") || normalized === "." || normalized === "..") {
    throw new TypeError(`${label} must be a Firestore document id`);
  }
  return normalized;
}

function assertExactKeys(value, allowedKeys, label) {
  assertPlainObject(value, label);
  const unexpected = Object.keys(value).filter(
      (key) => !allowedKeys.includes(key));
  if (unexpected.length > 0) {
    throw new TypeError(
        `${label} has unexpected keys: ${unexpected.sort().join(", ")}`);
  }
  return value;
}

module.exports = {
  PUBLIC_PROJECTION_VERSION_V1,
  RATE_LIMIT_CONTRACT_VERSION_V1,
  STORAGE_SCHEMA_VERSION_V1,
  accessTiers,
  acquisitionStatuses,
  assertDocumentId,
  assertEnum,
  assertExactKeys,
  assertIsoTimestamp,
  assertNonEmptyString,
  assertOptionalString,
  assertPlainObject,
  assertSha256Hex,
  channelCodes,
  channelStatuses,
  claimStatuses,
  confidenceLevels,
  contractVersions,
  coverageStatuses,
  findingTypes,
  identityModes,
  impactLevels,
  interventionDifficulties,
  isPlainObject,
  observationSourceTypes,
  promotionStatuses,
  recommendationCodes,
  reportRecommendedActions,
  reviewStatuses,
  riskLevels,
  runStatuses,
  scanModes,
};
