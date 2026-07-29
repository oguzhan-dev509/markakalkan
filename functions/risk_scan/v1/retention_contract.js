"use strict";

const {
  assertDocumentId,
  assertEnum,
  assertExactKeys,
  assertIsoTimestamp,
  assertPlainObject,
  runStatuses,
} = require("./contracts");
const {
  canonicalJsonDigestSha256,
} = require("./canonical");

const RETENTION_CONTRACT_VERSION_V1 = "risk-scan-retention-v1";
const DEFAULT_CLEANUP_BATCH_SIZE = 200;
const MAX_CLEANUP_BATCH_SIZE = 500;
const MAX_GRACE_SECONDS = 60 * 60 * 24 * 30;

const terminalCleanupStatuses = Object.freeze([
  "completed",
  "completedWithLimits",
  "failedTerminal",
  "cancelled",
  "expired",
]);

const runDescendantCollections = Object.freeze([
  "findings",
  "observations",
  "channels",
]);

const cleanupStepCodes = Object.freeze([
  "deleteFindings",
  "deleteObservations",
  "deleteChannels",
  "deleteRunRoot",
]);

const deferredTopLevelCollections = Object.freeze([
  "risk_scan_reports",
  "risk_scan_claims",
]);

const retentionPolicies = Object.freeze({
  rateLimits: Object.freeze({
    collectionGroup: "risk_scan_rate_limits",
    isoField: "purgeAt",
    timestampField: "purgeAtTimestamp",
    nativeTtlEligible: true,
    cleanupStrategy: "nativeTtlCandidate",
  }),
  runs: Object.freeze({
    collectionGroup: "risk_scan_runs",
    isoField: "expiresAt",
    timestampField: "expiresAtTimestamp",
    nativeTtlEligible: false,
    cleanupStrategy: "recursiveServerSide",
  }),
  reports: Object.freeze({
    collectionGroup: "risk_scan_reports",
    nativeTtlEligible: false,
    cleanupStrategy: "retentionPolicyDeferred",
  }),
  claims: Object.freeze({
    collectionGroup: "risk_scan_claims",
    nativeTtlEligible: false,
    cleanupStrategy: "retentionPolicyDeferred",
  }),
});

function deepFreeze(value) {
  if (value === null || typeof value !== "object" ||
      Object.isFrozen(value)) {
    return value;
  }
  for (const child of Object.values(value)) {
    deepFreeze(child);
  }
  return Object.freeze(value);
}

function assertNonNegativeInteger(value, label, maximum) {
  if (!Number.isInteger(value) || value < 0 ||
      (maximum !== undefined && value > maximum)) {
    throw new TypeError(`${label} must be a non-negative integer`);
  }
  return value;
}

function assertCleanupBatchSize(value) {
  if (!Number.isInteger(value) ||
      value < 1 ||
      value > MAX_CLEANUP_BATCH_SIZE) {
    throw new TypeError(
        `batchSize must be between 1 and ${MAX_CLEANUP_BATCH_SIZE}`);
  }
  return value;
}

function assertTimestampFactory(timestampFactory) {
  assertPlainObject(timestampFactory, "timestampFactory");
  if (typeof timestampFactory.fromDate !== "function") {
    throw new TypeError("timestampFactory.fromDate must be a function");
  }
  return timestampFactory;
}

function isoToFirestoreTimestamp(value, label, timestampFactory) {
  const normalized = assertIsoTimestamp(value, label);
  const factory = assertTimestampFactory(timestampFactory);
  const sourceDate = new Date(Date.parse(normalized));
  const timestamp = factory.fromDate(sourceDate);

  if (timestamp === null ||
      typeof timestamp !== "object" ||
      typeof timestamp.toDate !== "function") {
    throw new TypeError(`${label} timestamp conversion is invalid`);
  }

  const roundTrip = timestamp.toDate();
  if (!(roundTrip instanceof Date) ||
      !Number.isFinite(roundTrip.getTime()) ||
      roundTrip.getTime() !== sourceDate.getTime()) {
    throw new TypeError(`${label} timestamp round-trip is invalid`);
  }

  return timestamp;
}

function buildRateLimitRetentionFields(input, timestampFactory) {
  assertExactKeys(input, ["purgeAt"], "rateLimitRetention");
  const purgeAt = assertIsoTimestamp(input.purgeAt, "purgeAt");
  return deepFreeze({
    retentionContractVersion: RETENTION_CONTRACT_VERSION_V1,
    purgeAt,
    purgeAtTimestamp: isoToFirestoreTimestamp(
        purgeAt, "purgeAt", timestampFactory),
    nativeTtlEligible: true,
    ttlCollectionGroup: retentionPolicies.rateLimits.collectionGroup,
    ttlField: retentionPolicies.rateLimits.timestampField,
  });
}

function buildRunRetentionFields(input, timestampFactory) {
  assertExactKeys(input, ["expiresAt"], "runRetention");
  const expiresAt = assertIsoTimestamp(input.expiresAt, "expiresAt");
  return deepFreeze({
    retentionContractVersion: RETENTION_CONTRACT_VERSION_V1,
    expiresAt,
    expiresAtTimestamp: isoToFirestoreTimestamp(
        expiresAt, "expiresAt", timestampFactory),
    nativeTtlEligible: false,
    cleanupStrategy: retentionPolicies.runs.cleanupStrategy,
  });
}

function assertCleanupCandidate(run, options = {}) {
  assertPlainObject(run, "run");
  assertExactKeys(
      options,
      ["now", "minimumGraceSeconds"],
      "cleanupOptions");

  const scanRunId = assertDocumentId(run.scanRunId, "run.scanRunId");
  const status = assertEnum(run.status, runStatuses, "run.status");
  if (!terminalCleanupStatuses.includes(status)) {
    const error = new Error("run is not in a terminal cleanup status");
    error.code = "failed-precondition";
    throw error;
  }

  const expiresAt = assertIsoTimestamp(run.expiresAt, "run.expiresAt");
  const now = assertIsoTimestamp(options.now, "cleanupOptions.now");
  const minimumGraceSeconds = assertNonNegativeInteger(
      options.minimumGraceSeconds ?? 0,
      "cleanupOptions.minimumGraceSeconds",
      MAX_GRACE_SECONDS);

  const eligibleAtMs =
      Date.parse(expiresAt) + (minimumGraceSeconds * 1000);
  if (Date.parse(now) < eligibleAtMs) {
    const error = new Error("run retention window has not elapsed");
    error.code = "failed-precondition";
    throw error;
  }

  return Object.freeze({
    scanRunId,
    status,
    expiresAt,
    eligibleAt: new Date(eligibleAtMs).toISOString(),
    minimumGraceSeconds,
  });
}

function cleanupStep(stepCode, scanRunId) {
  const rootPath = `risk_scan_runs/${scanRunId}`;
  switch (stepCode) {
    case "deleteFindings":
      return {
        stepCode,
        operation: "deleteCollection",
        path: `${rootPath}/findings`,
      };
    case "deleteObservations":
      return {
        stepCode,
        operation: "deleteCollection",
        path: `${rootPath}/observations`,
      };
    case "deleteChannels":
      return {
        stepCode,
        operation: "deleteCollection",
        path: `${rootPath}/channels`,
      };
    case "deleteRunRoot":
      return {
        stepCode,
        operation: "deleteDocument",
        path: rootPath,
      };
    default:
      throw new TypeError("cleanup step code is invalid");
  }
}

function buildRunRecursiveCleanupPlan(input) {
  assertExactKeys(
      input,
      ["run", "now", "minimumGraceSeconds", "batchSize"],
      "cleanupPlan");

  const candidate = assertCleanupCandidate(input.run, {
    now: input.now,
    minimumGraceSeconds: input.minimumGraceSeconds,
  });
  const batchSize = assertCleanupBatchSize(
      input.batchSize ?? DEFAULT_CLEANUP_BATCH_SIZE);

  const payload = {
    retentionContractVersion: RETENTION_CONTRACT_VERSION_V1,
    scanRunId: candidate.scanRunId,
    expectedStatus: candidate.status,
    expiresAt: candidate.expiresAt,
    eligibleAt: candidate.eligibleAt,
    cleanupStrategy: retentionPolicies.runs.cleanupStrategy,
    nativeRunTtlEligible: false,
    rootPath: `risk_scan_runs/${candidate.scanRunId}`,
    batchSize,
    steps: cleanupStepCodes.map(
        (stepCode) => cleanupStep(stepCode, candidate.scanRunId)),
    deferredTopLevelCollections: [...deferredTopLevelCollections],
  };

  return deepFreeze({
    ...payload,
    cleanupPlanDigestSha256: canonicalJsonDigestSha256(payload),
  });
}

function assertCleanupProgress(plan, completedStepCodes) {
  assertPlainObject(plan, "cleanupPlan");
  if (plan.retentionContractVersion !== RETENTION_CONTRACT_VERSION_V1) {
    throw new TypeError("cleanupPlan contract version is invalid");
  }
  if (!Array.isArray(completedStepCodes)) {
    throw new TypeError("completedStepCodes must be an array");
  }
  if (new Set(completedStepCodes).size !== completedStepCodes.length) {
    throw new TypeError("completedStepCodes must not contain duplicates");
  }

  completedStepCodes.forEach((stepCode, index) => {
    assertEnum(stepCode, cleanupStepCodes, `completedStepCodes[${index}]`);
    if (stepCode !== cleanupStepCodes[index]) {
      throw new TypeError("completedStepCodes must be a cleanup prefix");
    }
  });

  const nextStepCode =
      cleanupStepCodes[completedStepCodes.length] ?? null;
  return deepFreeze({
    completedStepCodes: [...completedStepCodes],
    nextStepCode,
    complete: nextStepCode === null,
  });
}

function assertCleanupPlanReplay(existing, expected) {
  assertPlainObject(existing, "existingCleanupPlan");
  assertPlainObject(expected, "expectedCleanupPlan");
  const existingDigest = existing.cleanupPlanDigestSha256;
  const expectedDigest = expected.cleanupPlanDigestSha256;
  if (typeof existingDigest !== "string" ||
      typeof expectedDigest !== "string" ||
      existingDigest !== expectedDigest) {
    const error = new Error("cleanup plan replay conflicts");
    error.code = "conflict";
    throw error;
  }
  return true;
}

module.exports = {
  DEFAULT_CLEANUP_BATCH_SIZE,
  MAX_CLEANUP_BATCH_SIZE,
  MAX_GRACE_SECONDS,
  RETENTION_CONTRACT_VERSION_V1,
  assertCleanupCandidate,
  assertCleanupPlanReplay,
  assertCleanupProgress,
  assertTimestampFactory,
  buildRateLimitRetentionFields,
  buildRunRecursiveCleanupPlan,
  buildRunRetentionFields,
  cleanupStepCodes,
  deferredTopLevelCollections,
  isoToFirestoreTimestamp,
  retentionPolicies,
  runDescendantCollections,
  terminalCleanupStatuses,
};
