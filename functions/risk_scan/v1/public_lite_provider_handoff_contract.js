"use strict";

const crypto = require("node:crypto");
const {
  assertDocumentId,
  assertEnum,
  assertExactKeys,
  assertIsoTimestamp,
  assertNonEmptyString,
  assertPlainObject,
  assertSha256Hex,
} = require("./contracts");
const {
  normalizePublicLiteDispatchEnvelope,
} = require("./public_lite_execution_contract");

const PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1 =
  "risk-scan-public-lite-provider-handoff-request-v1";
const PUBLIC_LITE_PROVIDER_HANDOFF_RECORD_VERSION_V2 =
  "risk-scan-public-lite-provider-handoff-record-v2";
const PUBLIC_LITE_PROVIDER_HANDOFF_RECEIPT_VERSION_V1 =
  "risk-scan-public-lite-provider-handoff-receipt-v1";
const PUBLIC_LITE_ACQUISITION_COMMAND_VERSION_V1 =
  "risk-scan-public-lite-acquisition-command-v1";
const PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V2 =
  "risk-scan-public-lite-acquisition-dispatch-receipt-v2";
const PUBLIC_LITE_PROVIDER_HANDOFF_STORAGE_VERSION_V2 =
  "risk-scan-public-lite-provider-handoff-storage-v2";
const PUBLIC_LITE_PROVIDER_HANDOFF_STORAGE_ALGORITHM_V1 =
  "sha256-canonical-json-v1";
const PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_VERSION_V1 =
  "risk-scan-public-lite-provider-handoff-reconciliation-v1";
const PUBLIC_LITE_PROVIDER_HANDOFF_ID_NAMESPACE_V1 =
  "risk-scan-public-lite-provider-handoff-id-v1";
const PUBLIC_LITE_PROVIDER_HANDOFF_LEASE_NAMESPACE_V1 =
  "risk-scan-public-lite-provider-handoff-lease-v1";
const PUBLIC_LITE_PROVIDER_CODE = "n8n_public_lite";
const PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION =
  "risk_scan_public_lite_provider_handoffs";
const PUBLIC_LITE_PROVIDER_HANDOFF_LEASE_MS = 5 * 60 * 1000;
const PUBLIC_LITE_PROVIDER_HANDOFF_MAX_ATTEMPTS = 5;
const PUBLIC_LITE_PROVIDER_HANDOFF_RETRY_BASE_MS = 60 * 1000;
const PUBLIC_LITE_PROVIDER_HANDOFF_RETRY_MAX_MS = 15 * 60 * 1000;
const PUBLIC_LITE_PROVIDER_HANDOFF_RETENTION_MS =
  30 * 24 * 60 * 60 * 1000;
const PUBLIC_LITE_ACQUISITION_EXTERNAL_EXECUTION_PREFIX =
  "n8n-handoff:";

const PUBLIC_LITE_PROVIDER_HANDOFF_STATES = Object.freeze([
  "accepted",
  "child_dispatching",
  "child_dispatched",
  "failed",
  "completed",
  "dead_letter",
]);

const PUBLIC_LITE_PROVIDER_HANDOFF_DUE_STATES = Object.freeze([
  "accepted",
  "failed",
  "child_dispatching",
]);

const HANDOFF_TRANSITIONS = Object.freeze({
  accepted: ["child_dispatching", "dead_letter"],
  child_dispatching: [
    "child_dispatching",
    "child_dispatched",
    "failed",
    "completed",
    "dead_letter",
  ],
  child_dispatched: ["completed"],
  failed: ["child_dispatching", "dead_letter"],
  completed: [],
  dead_letter: [],
});

const HANDOFF_REQUEST_KEYS = Object.freeze([
  "contractVersion",
  "providerCode",
  "executionId",
  "scanRunId",
  "gatewayExecutionId",
  "dispatchEnvelope",
]);

const ACQUISITION_DISPATCH_RECEIPT_KEYS = Object.freeze([
  "contractVersion",
  "providerCode",
  "handoffId",
  "executionId",
  "externalExecutionId",
  "acceptedAt",
]);

class PublicLiteProviderHandoffContractError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PublicLiteProviderHandoffContractError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new PublicLiteProviderHandoffContractError(code, message);
}

function sha256Hex(value) {
  return crypto.createHash("sha256")
      .update(String(value), "utf8")
      .digest("hex");
}

function timestampLikeToDate(value, label) {
  let date;
  if (value instanceof Date) {
    date = value;
  } else if (value && typeof value.toDate === "function") {
    date = value.toDate();
  } else if (typeof value === "string") {
    date = new Date(assertIsoTimestamp(value, label));
  } else {
    fail("invalid-argument", `${label} must be a timestamp`);
  }
  if (!(date instanceof Date) || !Number.isFinite(date.getTime())) {
    fail("invalid-argument", `${label} must be a valid timestamp`);
  }
  return date;
}

function canonicalize(value) {
  if (value instanceof Date ||
      (value && typeof value.toDate === "function")) {
    return {$timestamp: timestampLikeToDate(value, "timestamp").toISOString()};
  }
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    return Object.keys(value).sort().reduce((output, key) => {
      output[key] = canonicalize(value[key]);
      return output;
    }, {});
  }
  return value;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function lengthPrefixed(parts) {
  return parts.map((part) => {
    const value = String(part);
    return `${Buffer.byteLength(value, "utf8")}:${value}`;
  }).join("");
}

function derivePublicLiteProviderHandoffId(executionId) {
  return sha256Hex(lengthPrefixed([
    PUBLIC_LITE_PROVIDER_HANDOFF_ID_NAMESPACE_V1,
    assertSha256Hex(executionId, "executionId"),
  ]));
}

function derivePublicLiteProviderHandoffLeaseToken({
  executionId,
  ownerId,
  attemptCount,
  now,
}) {
  if (!Number.isInteger(attemptCount) || attemptCount < 1) {
    fail("invalid-argument", "attemptCount is invalid");
  }
  return sha256Hex(lengthPrefixed([
    PUBLIC_LITE_PROVIDER_HANDOFF_LEASE_NAMESPACE_V1,
    assertSha256Hex(executionId, "executionId"),
    assertNonEmptyString(ownerId, "ownerId", 256),
    attemptCount,
    assertIsoTimestamp(now, "now"),
  ]));
}

function derivePublicLiteAcquisitionExternalExecutionId(handoffId) {
  return PUBLIC_LITE_ACQUISITION_EXTERNAL_EXECUTION_PREFIX +
    assertSha256Hex(handoffId, "handoffId");
}

function publicLiteProviderHandoffRetryDelayMs(attemptCount) {
  if (!Number.isInteger(attemptCount) || attemptCount < 1 ||
      attemptCount > PUBLIC_LITE_PROVIDER_HANDOFF_MAX_ATTEMPTS) {
    fail("invalid-argument", "attemptCount is outside retry policy");
  }
  return Math.min(
      PUBLIC_LITE_PROVIDER_HANDOFF_RETRY_BASE_MS *
        (2 ** (attemptCount - 1)),
      PUBLIC_LITE_PROVIDER_HANDOFF_RETRY_MAX_MS);
}

function publicLiteProviderHandoffRetryDueAt({attemptCount, failedAt}) {
  const failedDate = timestampLikeToDate(failedAt, "failedAt");
  return new Date(
      failedDate.getTime() +
      publicLiteProviderHandoffRetryDelayMs(attemptCount));
}

function normalizePublicLiteProviderHandoffRequest(raw) {
  assertExactKeys(raw, HANDOFF_REQUEST_KEYS, "handoffRequest");
  if (raw.contractVersion !==
      PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1) {
    fail("invalid-argument", "handoff request contract is unsupported");
  }
  if (raw.providerCode !== PUBLIC_LITE_PROVIDER_CODE) {
    fail("invalid-argument", "handoff providerCode is unsupported");
  }
  const executionId = assertSha256Hex(raw.executionId, "executionId");
  const scanRunId = assertDocumentId(raw.scanRunId, "scanRunId");
  const dispatchEnvelope = normalizePublicLiteDispatchEnvelope(
      raw.dispatchEnvelope,
      {expectedExecutionId: executionId, expectedScanRunId: scanRunId});
  return Object.freeze({
    contractVersion: PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1,
    providerCode: PUBLIC_LITE_PROVIDER_CODE,
    executionId,
    scanRunId,
    gatewayExecutionId: assertNonEmptyString(
        raw.gatewayExecutionId, "gatewayExecutionId", 256),
    dispatchEnvelope,
    dispatchEnvelopeHash: sha256Hex(canonicalJson(dispatchEnvelope)),
  });
}

function providerHandoffStorageFingerprint(document) {
  assertPlainObject(document, "providerHandoff");
  const copy = {...document};
  delete copy.storageFingerprintSha256;
  return sha256Hex(canonicalJson(copy));
}

function withProviderHandoffStorageFingerprint(document) {
  const output = {
    ...document,
    storageVersion: PUBLIC_LITE_PROVIDER_HANDOFF_STORAGE_VERSION_V2,
    storageFingerprintAlgorithm:
      PUBLIC_LITE_PROVIDER_HANDOFF_STORAGE_ALGORITHM_V1,
  };
  output.storageFingerprintSha256 =
    providerHandoffStorageFingerprint(output);
  return output;
}

function buildPublicLiteProviderHandoffRecord({
  request,
  acceptedAt,
  purgeAtTimestamp,
}) {
  const normalized = normalizePublicLiteProviderHandoffRequest(request);
  const normalizedAcceptedAt = assertIsoTimestamp(acceptedAt, "acceptedAt");
  const acceptedDate = new Date(normalizedAcceptedAt);
  const purgeDate = timestampLikeToDate(
      purgeAtTimestamp, "purgeAtTimestamp");
  if (purgeDate.getTime() <= acceptedDate.getTime()) {
    fail("invalid-argument", "purgeAtTimestamp must follow acceptedAt");
  }
  return withProviderHandoffStorageFingerprint({
    contractVersion: PUBLIC_LITE_PROVIDER_HANDOFF_RECORD_VERSION_V2,
    handoffId: derivePublicLiteProviderHandoffId(normalized.executionId),
    executionId: normalized.executionId,
    scanRunId: normalized.scanRunId,
    providerCode: normalized.providerCode,
    gatewayExecutionId: normalized.gatewayExecutionId,
    dispatchEnvelopeHash: normalized.dispatchEnvelopeHash,
    state: "accepted",
    acceptedAt: normalizedAcceptedAt,
    createdAt: normalizedAcceptedAt,
    updatedAt: normalizedAcceptedAt,
    childDispatchAttemptCount: 0,
    childDispatchLeaseOwner: null,
    childDispatchLeaseToken: null,
    childDispatchLeaseUntil: null,
    childDispatchDueAtTimestamp: acceptedDate,
    lastChildDispatchErrorCode: null,
    lastChildDispatchErrorAt: null,
    childExternalExecutionId: null,
    childDispatchedAt: null,
    completedAt: null,
    deadLetteredAt: null,
    purgeAtTimestamp: purgeDate,
  });
}

function assertNullableString(value, label, maximum = 512) {
  if (value === null) return null;
  return assertNonEmptyString(value, label, maximum);
}

function assertNullableTimestamp(value, label) {
  if (value === null) return null;
  return assertIsoTimestamp(value, label);
}

function assertNullableTimestampLike(value, label) {
  if (value === null) return null;
  timestampLikeToDate(value, label);
  return value;
}

function assertPublicLiteProviderHandoffRecord(document) {
  assertPlainObject(document, "providerHandoff");
  if (document.contractVersion !==
      PUBLIC_LITE_PROVIDER_HANDOFF_RECORD_VERSION_V2 ||
      document.storageVersion !==
      PUBLIC_LITE_PROVIDER_HANDOFF_STORAGE_VERSION_V2 ||
      document.storageFingerprintAlgorithm !==
      PUBLIC_LITE_PROVIDER_HANDOFF_STORAGE_ALGORITHM_V1) {
    fail("conflict", "provider handoff storage contract is unsupported");
  }
  if (document.storageFingerprintSha256 !==
      providerHandoffStorageFingerprint(document)) {
    fail("conflict", "provider handoff storage fingerprint is invalid");
  }
  assertSha256Hex(document.handoffId, "handoffId");
  assertSha256Hex(document.executionId, "executionId");
  assertDocumentId(document.scanRunId, "scanRunId");
  if (document.providerCode !== PUBLIC_LITE_PROVIDER_CODE) {
    fail("conflict", "provider handoff providerCode is invalid");
  }
  assertNonEmptyString(
      document.gatewayExecutionId, "gatewayExecutionId", 256);
  assertSha256Hex(document.dispatchEnvelopeHash, "dispatchEnvelopeHash");
  assertEnum(
      document.state, PUBLIC_LITE_PROVIDER_HANDOFF_STATES, "handoff.state");
  assertIsoTimestamp(document.acceptedAt, "acceptedAt");
  assertIsoTimestamp(document.createdAt, "createdAt");
  assertIsoTimestamp(document.updatedAt, "updatedAt");
  if (!Number.isInteger(document.childDispatchAttemptCount) ||
      document.childDispatchAttemptCount < 0 ||
      document.childDispatchAttemptCount > 100) {
    fail("conflict", "childDispatchAttemptCount is invalid");
  }
  assertNullableString(
      document.childDispatchLeaseOwner, "childDispatchLeaseOwner", 256);
  if (document.childDispatchLeaseToken !== null) {
    assertSha256Hex(
        document.childDispatchLeaseToken, "childDispatchLeaseToken");
  }
  assertNullableTimestamp(
      document.childDispatchLeaseUntil, "childDispatchLeaseUntil");
  assertNullableTimestampLike(
      document.childDispatchDueAtTimestamp,
      "childDispatchDueAtTimestamp");
  assertNullableString(
      document.lastChildDispatchErrorCode,
      "lastChildDispatchErrorCode",
      100);
  assertNullableTimestamp(
      document.lastChildDispatchErrorAt, "lastChildDispatchErrorAt");
  assertNullableString(
      document.childExternalExecutionId,
      "childExternalExecutionId",
      256);
  assertNullableTimestamp(document.childDispatchedAt, "childDispatchedAt");
  assertNullableTimestamp(document.completedAt, "completedAt");
  assertNullableTimestamp(document.deadLetteredAt, "deadLetteredAt");
  timestampLikeToDate(document.purgeAtTimestamp, "purgeAtTimestamp");

  const dueState = PUBLIC_LITE_PROVIDER_HANDOFF_DUE_STATES
      .includes(document.state);
  if (dueState && document.childDispatchDueAtTimestamp === null) {
    fail("conflict", "due provider handoff has no due timestamp");
  }
  if (!dueState && document.childDispatchDueAtTimestamp !== null) {
    fail("conflict", "terminal provider handoff retains a due timestamp");
  }
  if (document.state === "dead_letter" &&
      document.deadLetteredAt === null) {
    fail("conflict", "dead-letter provider handoff has no timestamp");
  }
  if (document.state !== "dead_letter" &&
      document.deadLetteredAt !== null) {
    fail("conflict", "non-dead-letter provider handoff has a timestamp");
  }
  return document;
}

function assertPublicLiteProviderHandoffReplay(existing, request) {
  assertPublicLiteProviderHandoffRecord(existing);
  const normalized = normalizePublicLiteProviderHandoffRequest(request);
  if (existing.executionId !== normalized.executionId ||
      existing.scanRunId !== normalized.scanRunId ||
      existing.providerCode !== normalized.providerCode ||
      existing.dispatchEnvelopeHash !== normalized.dispatchEnvelopeHash) {
    fail("conflict", "provider handoff replay conflicts with stored data");
  }
  return existing;
}

function buildPublicLiteProviderHandoffReceipt({record, replayed}) {
  const normalized = assertPublicLiteProviderHandoffRecord(record);
  if (typeof replayed !== "boolean") {
    throw new TypeError("replayed must be boolean");
  }
  return Object.freeze({
    contractVersion: PUBLIC_LITE_PROVIDER_HANDOFF_RECEIPT_VERSION_V1,
    providerCode: normalized.providerCode,
    handoffId: normalized.handoffId,
    executionId: normalized.executionId,
    scanRunId: normalized.scanRunId,
    gatewayExecutionId: normalized.gatewayExecutionId,
    acceptedAt: normalized.acceptedAt,
    state: "accepted",
    replayed,
  });
}

function assertPublicLiteProviderHandoffTransition(from, to) {
  assertEnum(from, PUBLIC_LITE_PROVIDER_HANDOFF_STATES, "handoff.from");
  assertEnum(to, PUBLIC_LITE_PROVIDER_HANDOFF_STATES, "handoff.to");
  if (from === to && from !== "child_dispatching") {
    fail("failed-precondition", "provider handoff transition is invalid");
  }
  if (from !== to && !HANDOFF_TRANSITIONS[from].includes(to)) {
    fail("failed-precondition", "provider handoff transition is invalid");
  }
  return to;
}

function updatePublicLiteProviderHandoffRecord(record, patch) {
  const current = assertPublicLiteProviderHandoffRecord(record);
  assertPlainObject(patch, "handoffPatch");
  if (patch.state !== undefined && patch.state !== current.state) {
    assertPublicLiteProviderHandoffTransition(current.state, patch.state);
  }
  const next = withProviderHandoffStorageFingerprint({
    ...current,
    ...patch,
  });
  return assertPublicLiteProviderHandoffRecord(next);
}

function buildPublicLiteAcquisitionCommand({
  record,
  dispatchEnvelope,
  attemptCount,
  leaseToken,
}) {
  const handoff = assertPublicLiteProviderHandoffRecord(record);
  const envelope = normalizePublicLiteDispatchEnvelope(
      dispatchEnvelope,
      {
        expectedExecutionId: handoff.executionId,
        expectedScanRunId: handoff.scanRunId,
      });
  const digest = sha256Hex(canonicalJson(envelope));
  if (digest !== handoff.dispatchEnvelopeHash) {
    fail("conflict", "acquisition envelope conflicts with handoff record");
  }
  if (!Number.isInteger(attemptCount) || attemptCount < 1 ||
      attemptCount > PUBLIC_LITE_PROVIDER_HANDOFF_MAX_ATTEMPTS) {
    fail("invalid-argument", "attempt is outside child dispatch policy");
  }
  return Object.freeze({
    contractVersion: PUBLIC_LITE_ACQUISITION_COMMAND_VERSION_V1,
    handoffId: handoff.handoffId,
    executionId: handoff.executionId,
    scanRunId: handoff.scanRunId,
    dispatchEnvelope: envelope,
    attempt: attemptCount,
    leaseToken: assertSha256Hex(leaseToken, "leaseToken"),
  });
}

function normalizePublicLiteAcquisitionDispatchReceipt(raw, {
  expectedHandoffId,
  expectedExecutionId,
} = {}) {
  assertExactKeys(
      raw,
      ACQUISITION_DISPATCH_RECEIPT_KEYS,
      "acquisitionDispatchReceipt");
  if (raw.contractVersion !==
      PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V2) {
    fail("invalid-argument", "acquisition receipt contract is unsupported");
  }
  if (raw.providerCode !== PUBLIC_LITE_PROVIDER_CODE) {
    fail("invalid-argument", "acquisition receipt provider is unsupported");
  }
  const handoffId = assertSha256Hex(raw.handoffId, "handoffId");
  const executionId = assertSha256Hex(raw.executionId, "executionId");
  if (expectedHandoffId !== undefined &&
      handoffId !== assertSha256Hex(
          expectedHandoffId, "expectedHandoffId")) {
    fail("failed-precondition", "acquisition receipt handoffId mismatches");
  }
  if (expectedExecutionId !== undefined &&
      executionId !== assertSha256Hex(
          expectedExecutionId, "expectedExecutionId")) {
    fail("failed-precondition", "acquisition receipt executionId mismatches");
  }
  const externalExecutionId = assertNonEmptyString(
      raw.externalExecutionId, "externalExecutionId", 256);
  if (externalExecutionId !==
      derivePublicLiteAcquisitionExternalExecutionId(handoffId)) {
    fail(
        "failed-precondition",
        "acquisition receipt externalExecutionId mismatches handoff");
  }
  return Object.freeze({
    contractVersion:
      PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V2,
    providerCode: PUBLIC_LITE_PROVIDER_CODE,
    handoffId,
    executionId,
    externalExecutionId,
    acceptedAt: assertIsoTimestamp(raw.acceptedAt, "acceptedAt"),
  });
}

function completePublicLiteProviderHandoffRecord(record, {
  externalExecutionId,
  completedAt,
  updatedAt,
}) {
  const current = assertPublicLiteProviderHandoffRecord(record);
  const normalizedExternalExecutionId = assertNonEmptyString(
      externalExecutionId, "externalExecutionId", 256);
  const expectedExternalExecutionId =
    derivePublicLiteAcquisitionExternalExecutionId(current.handoffId);
  if (normalizedExternalExecutionId !== expectedExternalExecutionId) {
    fail("conflict", "result external execution conflicts with handoff");
  }
  const normalizedCompletedAt = assertIsoTimestamp(
      completedAt, "completedAt");
  const normalizedUpdatedAt = assertIsoTimestamp(updatedAt, "updatedAt");
  if (!["child_dispatching", "child_dispatched", "completed"]
      .includes(current.state)) {
    fail("failed-precondition", "provider handoff is not completable");
  }
  if (current.childExternalExecutionId !== null &&
      current.childExternalExecutionId !== normalizedExternalExecutionId) {
    fail("conflict", "result external execution conflicts with handoff");
  }
  if (current.state === "completed") {
    if (current.completedAt !== normalizedCompletedAt) {
      fail("conflict", "completed provider handoff replay conflicts");
    }
    return current;
  }
  return updatePublicLiteProviderHandoffRecord(current, {
    state: "completed",
    childExternalExecutionId: normalizedExternalExecutionId,
    childDispatchLeaseOwner: null,
    childDispatchLeaseToken: null,
    childDispatchLeaseUntil: null,
    childDispatchDueAtTimestamp: null,
    completedAt: normalizedCompletedAt,
    updatedAt: normalizedUpdatedAt,
  });
}

module.exports = Object.freeze({
  HANDOFF_TRANSITIONS,
  PUBLIC_LITE_ACQUISITION_COMMAND_VERSION_V1,
  PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V2,
  PUBLIC_LITE_ACQUISITION_EXTERNAL_EXECUTION_PREFIX,
  PUBLIC_LITE_PROVIDER_CODE,
  PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION,
  PUBLIC_LITE_PROVIDER_HANDOFF_DUE_STATES,
  PUBLIC_LITE_PROVIDER_HANDOFF_LEASE_MS,
  PUBLIC_LITE_PROVIDER_HANDOFF_MAX_ATTEMPTS,
  PUBLIC_LITE_PROVIDER_HANDOFF_RECEIPT_VERSION_V1,
  PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_VERSION_V1,
  PUBLIC_LITE_PROVIDER_HANDOFF_RECORD_VERSION_V2,
  PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1,
  PUBLIC_LITE_PROVIDER_HANDOFF_RETENTION_MS,
  PUBLIC_LITE_PROVIDER_HANDOFF_RETRY_BASE_MS,
  PUBLIC_LITE_PROVIDER_HANDOFF_RETRY_MAX_MS,
  PUBLIC_LITE_PROVIDER_HANDOFF_STATES,
  PUBLIC_LITE_PROVIDER_HANDOFF_STORAGE_ALGORITHM_V1,
  PUBLIC_LITE_PROVIDER_HANDOFF_STORAGE_VERSION_V2,
  PublicLiteProviderHandoffContractError,
  assertPublicLiteProviderHandoffRecord,
  assertPublicLiteProviderHandoffReplay,
  assertPublicLiteProviderHandoffTransition,
  buildPublicLiteAcquisitionCommand,
  buildPublicLiteProviderHandoffReceipt,
  buildPublicLiteProviderHandoffRecord,
  canonicalJson,
  completePublicLiteProviderHandoffRecord,
  derivePublicLiteAcquisitionExternalExecutionId,
  derivePublicLiteProviderHandoffId,
  derivePublicLiteProviderHandoffLeaseToken,
  normalizePublicLiteAcquisitionDispatchReceipt,
  normalizePublicLiteProviderHandoffRequest,
  providerHandoffStorageFingerprint,
  publicLiteProviderHandoffRetryDelayMs,
  publicLiteProviderHandoffRetryDueAt,
  sha256Hex,
  timestampLikeToDate,
  updatePublicLiteProviderHandoffRecord,
  withProviderHandoffStorageFingerprint,
});
