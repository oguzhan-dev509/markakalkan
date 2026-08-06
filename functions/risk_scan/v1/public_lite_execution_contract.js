"use strict";

const crypto = require("node:crypto");
const {
  assertDocumentId,
  assertEnum,
  assertIsoTimestamp,
  assertNonEmptyString,
  assertPlainObject,
  assertSha256Hex,
  channelCodes,
  channelStatuses,
  contractVersions,
} = require("./contracts");

const PUBLIC_LITE_EXECUTION_COMMAND_VERSION_V1 =
  "risk-scan-public-lite-execution-command-v1";
const PUBLIC_LITE_EXECUTION_RECORD_VERSION_V1 =
  "risk-scan-public-lite-execution-record-v1";
const PUBLIC_LITE_DISPATCH_ENVELOPE_VERSION_V1 =
  "risk-scan-public-lite-dispatch-envelope-v1";
const PUBLIC_LITE_DISPATCH_RECEIPT_VERSION_V1 =
  "risk-scan-public-lite-dispatch-receipt-v1";
const PUBLIC_LITE_EXECUTION_EVENT_TYPE_V1 =
  "risk_scan_run_created";
const PUBLIC_LITE_EXECUTION_ID_NAMESPACE_V1 =
  "risk-scan-public-lite-execution-id-v1";
const PUBLIC_LITE_DISPATCH_MAX_ATTEMPTS = 5;
const PUBLIC_LITE_DISPATCH_LEASE_MS = 5 * 60 * 1000;

const PUBLIC_LITE_EXECUTION_STATUSES = Object.freeze([
  "prepared",
  "dispatching",
  "dispatched",
  "retryableFailure",
  "terminalFailure",
  "completed",
]);

const EXECUTION_TRANSITIONS = Object.freeze({
  prepared: ["dispatching", "terminalFailure"],
  dispatching: [
    "dispatched",
    "retryableFailure",
    "terminalFailure",
  ],
  retryableFailure: ["dispatching", "terminalFailure"],
  dispatched: ["completed", "terminalFailure"],
  terminalFailure: [],
  completed: [],
});

class PublicLiteExecutionContractError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PublicLiteExecutionContractError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new PublicLiteExecutionContractError(code, message);
}

function assertNull(value, label) {
  if (value !== null) {
    fail("failed-precondition", `${label} must be null`);
  }
  return null;
}

function normalizeDate(value, label) {
  const normalized = assertIsoTimestamp(value, label);
  return new Date(normalized);
}

function normalizeHttpOrigin(value, expectedHost) {
  const normalized = assertNonEmptyString(
      value, "target.officialWebsiteCanonicalUrl", 4096);
  let parsed;
  try {
    parsed = new URL(normalized);
  } catch {
    fail(
        "failed-precondition",
        "target.officialWebsiteCanonicalUrl is invalid");
  }
  if (!["http:", "https:"].includes(parsed.protocol) ||
      parsed.username || parsed.password || !parsed.hostname ||
      parsed.pathname !== "/" || parsed.search || parsed.hash) {
    fail(
        "failed-precondition",
        "target.officialWebsiteCanonicalUrl is invalid");
  }
  const host = parsed.hostname.toLowerCase().replace(/\.$/, "");
  if (host !== expectedHost) {
    fail(
        "failed-precondition",
        "target official host does not match canonical URL");
  }
  return normalized;
}

function normalizeTarget(raw) {
  assertPlainObject(raw, "target");
  const officialHost = assertNonEmptyString(
      raw.officialHost, "target.officialHost", 512)
      .toLowerCase()
      .replace(/\.$/, "");
  if (!officialHost || officialHost.includes("/")) {
    fail("failed-precondition", "target.officialHost is invalid");
  }
  return Object.freeze({
    brandNameNormalized: assertNonEmptyString(
        raw.brandNameNormalized,
        "target.brandNameNormalized",
        300),
    officialHost,
    officialWebsiteCanonicalUrl: normalizeHttpOrigin(
        raw.officialWebsiteCanonicalUrl,
        officialHost),
    targetFingerprintSha256: assertSha256Hex(
        raw.targetFingerprintSha256,
        "target.targetFingerprintSha256"),
  });
}

function normalizeRun(raw) {
  assertPlainObject(raw, "run");
  if (raw.contractVersion !== contractVersions.run) {
    fail("failed-precondition", "run contract is unsupported");
  }
  if (raw.scanMode !== "quick" ||
      raw.accessTier !== "publicLite" ||
      raw.identityMode !== "anonymous") {
    fail("failed-precondition", "run is not Public Lite quick mode");
  }
  if (raw.status !== "created") {
    fail("failed-precondition", "run must be created");
  }
  assertNull(raw.tenantId, "run.tenantId");
  assertNull(raw.canonicalBrandId, "run.canonicalBrandId");
  assertNull(raw.createdByUid, "run.createdByUid");

  return Object.freeze({
    scanRunId: assertDocumentId(raw.scanRunId, "run.scanRunId"),
    requestId: assertNonEmptyString(
        raw.requestId, "run.requestId", 180),
    requestFingerprintSha256: assertSha256Hex(
        raw.requestFingerprintSha256,
        "run.requestFingerprintSha256"),
    deduplicationFingerprintSha256: assertSha256Hex(
        raw.deduplicationFingerprintSha256,
        "run.deduplicationFingerprintSha256"),
    target: normalizeTarget(raw.target),
    createdAt: assertIsoTimestamp(raw.createdAt, "run.createdAt"),
    expiresAt: assertIsoTimestamp(raw.expiresAt, "run.expiresAt"),
  });
}

function normalizeChannels(rawChannels, scanRunId) {
  if (!Array.isArray(rawChannels) ||
      rawChannels.length !== channelCodes.length) {
    fail("failed-precondition", "all Public Lite channels are required");
  }
  const seen = new Set();
  for (const raw of rawChannels) {
    assertPlainObject(raw, "channel");
    const channelCode = assertEnum(
        raw.channelCode, channelCodes, "channel.channelCode");
    if (seen.has(channelCode)) {
      fail("failed-precondition", "channel set contains duplicates");
    }
    seen.add(channelCode);
    if (raw.scanRunId !== scanRunId) {
      fail("failed-precondition", "channel belongs to another run");
    }
    assertEnum(
        raw.status, channelStatuses, "channel.status");
  }
  if (channelCodes.some((channelCode) => !seen.has(channelCode))) {
    fail("failed-precondition", "channel set is incomplete");
  }
  return Object.freeze([...channelCodes]);
}

function lengthPrefixed(parts) {
  return parts.map((part) => {
    const value = String(part);
    return `${Buffer.byteLength(value, "utf8")}:${value}`;
  }).join("");
}

function deriveExecutionId({scanRunId, requestFingerprintSha256}) {
  return crypto.createHash("sha256")
      .update(lengthPrefixed([
        PUBLIC_LITE_EXECUTION_ID_NAMESPACE_V1,
        assertDocumentId(scanRunId, "scanRunId"),
        assertSha256Hex(
            requestFingerprintSha256,
            "requestFingerprintSha256"),
      ]), "utf8")
      .digest("hex");
}

function buildPublicLiteExecutionCommand({
  eventId,
  eventTime,
  eventType = PUBLIC_LITE_EXECUTION_EVENT_TYPE_V1,
  run,
  channels,
}) {
  const normalizedEventId = assertNonEmptyString(
      eventId, "eventId", 512);
  if (eventType !== PUBLIC_LITE_EXECUTION_EVENT_TYPE_V1) {
    fail("invalid-argument", "eventType is unsupported");
  }
  const normalizedEventTime = assertIsoTimestamp(
      eventTime, "eventTime");
  const normalizedRun = normalizeRun(run);
  const normalizedChannels = normalizeChannels(
      channels, normalizedRun.scanRunId);
  const eventDate = normalizeDate(normalizedEventTime, "eventTime");
  const expiryDate = normalizeDate(
      normalizedRun.expiresAt, "run.expiresAt");
  if (expiryDate.getTime() <= eventDate.getTime()) {
    fail("failed-precondition", "run expired before execution dispatch");
  }

  const executionId = deriveExecutionId(normalizedRun);
  return Object.freeze({
    contractVersion: PUBLIC_LITE_EXECUTION_COMMAND_VERSION_V1,
    executionId,
    eventId: normalizedEventId,
    eventType,
    eventTime: normalizedEventTime,
    scanRunId: normalizedRun.scanRunId,
    requestId: normalizedRun.requestId,
    requestFingerprintSha256:
      normalizedRun.requestFingerprintSha256,
    deduplicationFingerprintSha256:
      normalizedRun.deduplicationFingerprintSha256,
    target: normalizedRun.target,
    channelCodes: normalizedChannels,
    requestedAt: normalizedRun.createdAt,
    expiresAt: normalizedRun.expiresAt,
  });
}

function buildPublicLiteExecutionRecord(command) {
  assertExecutionCommand(command);
  return Object.freeze({
    contractVersion: PUBLIC_LITE_EXECUTION_RECORD_VERSION_V1,
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    requestFingerprintSha256:
      command.requestFingerprintSha256,
    status: "prepared",
    attemptCount: 0,
    leaseOwner: null,
    leaseExpiresAt: null,
    externalExecutionId: null,
    providerCode: null,
    lastFailureCode: null,
    lastFailureMessage: null,
    preparedAt: command.eventTime,
    updatedAt: command.eventTime,
    dispatchedAt: null,
    completedAt: null,
  });
}

function assertExecutionCommand(command) {
  assertPlainObject(command, "command");
  if (command.contractVersion !==
      PUBLIC_LITE_EXECUTION_COMMAND_VERSION_V1) {
    fail("invalid-argument", "execution command contract is unsupported");
  }
  const expectedId = deriveExecutionId(command);
  if (command.executionId !== expectedId) {
    fail("invalid-argument", "executionId is not deterministic");
  }
  assertNonEmptyString(command.eventId, "command.eventId", 512);
  if (command.eventType !== PUBLIC_LITE_EXECUTION_EVENT_TYPE_V1) {
    fail("invalid-argument", "command.eventType is unsupported");
  }
  assertIsoTimestamp(command.eventTime, "command.eventTime");
  assertDocumentId(command.scanRunId, "command.scanRunId");
  assertNonEmptyString(command.requestId, "command.requestId", 180);
  assertSha256Hex(
      command.requestFingerprintSha256,
      "command.requestFingerprintSha256");
  assertSha256Hex(
      command.deduplicationFingerprintSha256,
      "command.deduplicationFingerprintSha256");
  normalizeTarget(command.target);
  normalizeChannels(
      command.channelCodes.map((channelCode) => ({
        scanRunId: command.scanRunId,
        channelCode,
        status: "queued",
      })),
      command.scanRunId);
  assertIsoTimestamp(command.requestedAt, "command.requestedAt");
  assertIsoTimestamp(command.expiresAt, "command.expiresAt");
  return command;
}

function buildPublicLiteDispatchEnvelope(command) {
  assertExecutionCommand(command);
  return Object.freeze({
    contractVersion: PUBLIC_LITE_DISPATCH_ENVELOPE_VERSION_V1,
    executionId: command.executionId,
    scanRunId: command.scanRunId,
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    target: command.target,
    channelCodes: command.channelCodes,
    requestedAt: command.requestedAt,
    expiresAt: command.expiresAt,
    trace: Object.freeze({
      sourceEventId: command.eventId,
      requestId: command.requestId,
      requestFingerprintSha256:
        command.requestFingerprintSha256,
    }),
  });
}

function buildDispatchLease({
  executionId,
  ownerId,
  attemptCount,
  now,
  leaseMs = PUBLIC_LITE_DISPATCH_LEASE_MS,
}) {
  const normalizedNow = normalizeDate(now, "now");
  if (!Number.isInteger(attemptCount) ||
      attemptCount < 1 ||
      attemptCount > PUBLIC_LITE_DISPATCH_MAX_ATTEMPTS) {
    fail("invalid-argument", "attemptCount is outside dispatch policy");
  }
  if (!Number.isInteger(leaseMs) ||
      leaseMs < 30_000 || leaseMs > 15 * 60 * 1000) {
    fail("invalid-argument", "leaseMs is outside dispatch policy");
  }
  return Object.freeze({
    executionId: assertSha256Hex(executionId, "executionId"),
    ownerId: normalizeDispatchOwnerId(ownerId),
    attemptCount,
    leasedAt: normalizedNow.toISOString(),
    leaseExpiresAt: new Date(
        normalizedNow.getTime() + leaseMs).toISOString(),
  });
}

function normalizeDispatchOwnerId(value) {
  return assertNonEmptyString(value, "ownerId", 256);
}

function normalizeDispatchReceipt(raw, {
  expectedExecutionId,
} = {}) {
  assertPlainObject(raw, "receipt");
  if (raw.contractVersion !== PUBLIC_LITE_DISPATCH_RECEIPT_VERSION_V1) {
    fail("invalid-argument", "receipt.contractVersion is unsupported");
  }
  const providerCode = assertNonEmptyString(
      raw.providerCode, "receipt.providerCode", 80);
  if (providerCode !== "n8n_public_lite") {
    fail("invalid-argument", "receipt.providerCode is unsupported");
  }
  const executionId = assertSha256Hex(
      raw.executionId, "receipt.executionId");
  if (expectedExecutionId !== undefined) {
    const expected = assertSha256Hex(
        expectedExecutionId, "expectedExecutionId");
    if (executionId !== expected) {
      fail(
          "failed-precondition",
          "receipt.executionId does not match dispatch envelope");
    }
  }
  return Object.freeze({
    contractVersion: raw.contractVersion,
    providerCode,
    executionId,
    externalExecutionId: assertNonEmptyString(
        raw.externalExecutionId,
        "receipt.externalExecutionId",
        256),
    acceptedAt: assertIsoTimestamp(
        raw.acceptedAt, "receipt.acceptedAt"),
  });
}

function assertExecutionTransition(from, to) {
  assertEnum(
      from, PUBLIC_LITE_EXECUTION_STATUSES, "executionStatus.from");
  assertEnum(
      to, PUBLIC_LITE_EXECUTION_STATUSES, "executionStatus.to");
  if (!EXECUTION_TRANSITIONS[from].includes(to)) {
    fail("failed-precondition", "execution status transition is invalid");
  }
  return to;
}

module.exports = Object.freeze({
  EXECUTION_TRANSITIONS,
  PUBLIC_LITE_DISPATCH_ENVELOPE_VERSION_V1,
  PUBLIC_LITE_DISPATCH_LEASE_MS,
  PUBLIC_LITE_DISPATCH_MAX_ATTEMPTS,
  PUBLIC_LITE_DISPATCH_RECEIPT_VERSION_V1,
  PUBLIC_LITE_EXECUTION_COMMAND_VERSION_V1,
  PUBLIC_LITE_EXECUTION_EVENT_TYPE_V1,
  PUBLIC_LITE_EXECUTION_RECORD_VERSION_V1,
  PUBLIC_LITE_EXECUTION_STATUSES,
  PublicLiteExecutionContractError,
  assertExecutionCommand,
  assertExecutionTransition,
  buildDispatchLease,
  buildPublicLiteDispatchEnvelope,
  buildPublicLiteExecutionCommand,
  buildPublicLiteExecutionRecord,
  deriveExecutionId,
  normalizeDispatchOwnerId,
  normalizeDispatchReceipt,
});
