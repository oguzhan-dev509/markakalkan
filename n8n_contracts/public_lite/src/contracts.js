"use strict";

const crypto = require("node:crypto");

const DISPATCH_ENVELOPE_VERSION =
  "risk-scan-public-lite-dispatch-envelope-v1";
const DISPATCH_RECEIPT_VERSION =
  "risk-scan-public-lite-dispatch-receipt-v1";
const RESULT_ENVELOPE_VERSION =
  "risk-scan-public-lite-result-envelope-v1";
const PROVIDER_RESULT_VERSION =
  "risk-scan-public-lite-provider-result-v1";
const PROVIDER_CODE = "n8n_public_lite";

const CHANNEL_CODES = Object.freeze([
  "similarDomains",
  "openWeb",
  "marketplaceLimited",
]);

const CHANNEL_RESULT_STATUSES = Object.freeze([
  "completed",
  "dataUnavailable",
  "failed",
]);

const EXECUTION_RESULT_STATUSES = Object.freeze([
  "completed",
  "partial",
  "failed",
]);

const FORBIDDEN_KEYS = Object.freeze(new Set([
  "__proto__",
  "prototype",
  "constructor",
  "authorization",
  "cookie",
  "set-cookie",
  "accesskey",
  "access_key",
  "access-key",
  "accesstoken",
  "access_token",
  "access-token",
  "secret",
  "token",
  "password",
  "passwd",
]));

const DISPATCH_KEYS = Object.freeze([
  "contractVersion",
  "executionId",
  "scanRunId",
  "scanMode",
  "accessTier",
  "identityMode",
  "target",
  "channelCodes",
  "requestedAt",
  "expiresAt",
  "trace",
]);

const TARGET_KEYS = Object.freeze([
  "brandNameNormalized",
  "officialHost",
  "officialWebsiteCanonicalUrl",
  "targetFingerprintSha256",
]);

const TRACE_KEYS = Object.freeze([
  "sourceEventId",
  "requestId",
  "requestFingerprintSha256",
]);

const RESULT_ENVELOPE_KEYS = Object.freeze([
  "contractVersion",
  "providerCode",
  "externalExecutionId",
  "providerEventId",
  "executionId",
  "scanRunId",
  "completedAt",
  "resultPayload",
]);

const PROVIDER_RESULT_KEYS = Object.freeze([
  "contractVersion",
  "executionStatus",
  "channels",
  "summary",
  "engine",
]);

const CHANNEL_RESULT_KEYS = Object.freeze([
  "channelCode",
  "status",
  "startedAt",
  "completedAt",
  "observations",
  "diagnostics",
]);

const OBSERVATION_KEYS = Object.freeze([
  "observationId",
  "observedAt",
  "sourceUrl",
  "sourceHost",
  "sourceType",
  "title",
  "snippet",
  "imageUrls",
  "signals",
  "evidence",
]);

class PublicLiteWorkflowContractError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PublicLiteWorkflowContractError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new PublicLiteWorkflowContractError(code, message);
}

function isPlainObject(value) {
  if (value === null || typeof value !== "object") return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function assertPlainObject(value, label) {
  if (!isPlainObject(value)) {
    fail("invalid_argument", `${label} must be a plain object`);
  }
  return value;
}

function assertExactKeys(value, expected, label) {
  assertPlainObject(value, label);
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (actual.length !== wanted.length ||
      actual.some((key, index) => key !== wanted[index])) {
    fail("invalid_argument", `${label} keys are invalid`);
  }
  return value;
}

function assertString(value, label, maximum = 4096) {
  if (typeof value !== "string") {
    fail("invalid_argument", `${label} must be a string`);
  }
  const normalized = value.trim();
  if (!normalized || Buffer.byteLength(normalized, "utf8") > maximum) {
    fail("invalid_argument", `${label} is empty or too long`);
  }
  return normalized;
}

function assertSha256(value, label) {
  const normalized = assertString(value, label, 64).toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(normalized)) {
    fail("invalid_argument", `${label} must be a SHA-256 hex digest`);
  }
  return normalized;
}

function assertDocumentId(value, label) {
  const normalized = assertString(value, label, 180);
  if (normalized.includes("/") || normalized === "." || normalized === "..") {
    fail("invalid_argument", `${label} is not a valid document id`);
  }
  return normalized;
}

function assertIsoTimestamp(value, label) {
  const normalized = assertString(value, label, 64);
  const timestamp = Date.parse(normalized);
  if (!Number.isFinite(timestamp) ||
      new Date(timestamp).toISOString() !== normalized) {
    fail("invalid_argument", `${label} must be canonical ISO-8601`);
  }
  return normalized;
}

function assertEnum(value, allowed, label) {
  if (!allowed.includes(value)) {
    fail("invalid_argument", `${label} is unsupported`);
  }
  return value;
}

function assertArray(value, label, maximum = 500) {
  if (!Array.isArray(value) || value.length > maximum) {
    fail("invalid_argument", `${label} must be a bounded array`);
  }
  return value;
}

function assertSafeJson(value, label = "value", depth = 0) {
  if (depth > 8) {
    fail("invalid_argument", `${label} exceeds maximum nesting depth`);
  }
  if (value === null || typeof value === "boolean") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      fail("invalid_argument", `${label} contains a non-finite number`);
    }
    return value;
  }
  if (typeof value === "string") {
    if (Buffer.byteLength(value, "utf8") > 32768) {
      fail("invalid_argument", `${label} contains an oversized string`);
    }
    return value;
  }
  if (Array.isArray(value)) {
    if (value.length > 500) {
      fail("invalid_argument", `${label} contains an oversized array`);
    }
    return value.map((item, index) =>
      assertSafeJson(item, `${label}[${index}]`, depth + 1));
  }
  assertPlainObject(value, label);
  const keys = Object.keys(value);
  if (keys.length > 500) {
    fail("invalid_argument", `${label} contains too many keys`);
  }
  const output = {};
  for (const key of keys.sort()) {
    const normalizedKey = assertString(key, `${label}.key`, 180);
    if (FORBIDDEN_KEYS.has(normalizedKey.toLowerCase())) {
      fail("invalid_argument", `${label} contains a forbidden key`);
    }
    output[normalizedKey] =
      assertSafeJson(value[key], `${label}.${normalizedKey}`, depth + 1);
  }
  return output;
}

function normalizeOrigin(value, expectedHost) {
  const normalized = assertString(value, "target.officialWebsiteCanonicalUrl");
  let parsed;
  try {
    parsed = new URL(normalized);
  } catch {
    fail("invalid_argument", "target official URL is invalid");
  }
  const host = parsed.hostname.toLowerCase().replace(/\.$/, "");
  if (!["http:", "https:"].includes(parsed.protocol) ||
      parsed.username || parsed.password || !host ||
      parsed.pathname !== "/" || parsed.search || parsed.hash ||
      host !== expectedHost) {
    fail("invalid_argument", "target official URL is invalid");
  }
  return normalized;
}

function normalizeTarget(raw) {
  assertExactKeys(raw, TARGET_KEYS, "target");
  const officialHost = assertString(
      raw.officialHost, "target.officialHost", 512)
      .toLowerCase()
      .replace(/\.$/, "");
  if (officialHost.includes("/") || officialHost.includes(":")) {
    fail("invalid_argument", "target.officialHost is invalid");
  }
  return Object.freeze({
    brandNameNormalized: assertString(
      raw.brandNameNormalized, "target.brandNameNormalized", 300),
    officialHost,
    officialWebsiteCanonicalUrl: normalizeOrigin(
      raw.officialWebsiteCanonicalUrl,
      officialHost,
    ),
    targetFingerprintSha256: assertSha256(
      raw.targetFingerprintSha256,
      "target.targetFingerprintSha256",
    ),
  });
}

function normalizeChannels(raw) {
  const channels = assertArray(raw, "channelCodes", CHANNEL_CODES.length);
  if (channels.length !== CHANNEL_CODES.length ||
      channels.some((value, index) => value !== CHANNEL_CODES[index])) {
    fail("invalid_argument", "channelCodes must use the canonical channel set");
  }
  return Object.freeze([...CHANNEL_CODES]);
}

function normalizeDispatchEnvelope(raw) {
  assertExactKeys(raw, DISPATCH_KEYS, "dispatchEnvelope");
  if (raw.contractVersion !== DISPATCH_ENVELOPE_VERSION ||
      raw.scanMode !== "quick" ||
      raw.accessTier !== "publicLite" ||
      raw.identityMode !== "anonymous") {
    fail("invalid_argument", "dispatch envelope mode is unsupported");
  }
  assertExactKeys(raw.trace, TRACE_KEYS, "dispatchEnvelope.trace");
  const requestedAt = assertIsoTimestamp(
    raw.requestedAt, "dispatchEnvelope.requestedAt");
  const expiresAt = assertIsoTimestamp(
    raw.expiresAt, "dispatchEnvelope.expiresAt");
  if (Date.parse(expiresAt) <= Date.parse(requestedAt)) {
    fail("invalid_argument", "dispatch envelope is already expired");
  }
  const normalized = {
    contractVersion: DISPATCH_ENVELOPE_VERSION,
    executionId: assertSha256(
      raw.executionId, "dispatchEnvelope.executionId"),
    scanRunId: assertDocumentId(
      raw.scanRunId, "dispatchEnvelope.scanRunId"),
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    target: normalizeTarget(raw.target),
    channelCodes: normalizeChannels(raw.channelCodes),
    requestedAt,
    expiresAt,
    trace: Object.freeze({
      sourceEventId: assertString(
        raw.trace.sourceEventId,
        "dispatchEnvelope.trace.sourceEventId",
        512,
      ),
      requestId: assertString(
        raw.trace.requestId,
        "dispatchEnvelope.trace.requestId",
        180,
      ),
      requestFingerprintSha256: assertSha256(
        raw.trace.requestFingerprintSha256,
        "dispatchEnvelope.trace.requestFingerprintSha256",
      ),
    }),
  };
  assertSafeJson(normalized, "dispatchEnvelope");
  return Object.freeze(normalized);
}

function buildDispatchReceipt({externalExecutionId, acceptedAt}) {
  return Object.freeze({
    contractVersion: DISPATCH_RECEIPT_VERSION,
    providerCode: PROVIDER_CODE,
    externalExecutionId: assertString(
      externalExecutionId, "externalExecutionId", 256),
    acceptedAt: assertIsoTimestamp(acceptedAt, "acceptedAt"),
  });
}

function normalizeObservation(raw, label) {
  assertExactKeys(raw, OBSERVATION_KEYS, label);
  const imageUrls = assertArray(raw.imageUrls, `${label}.imageUrls`, 20)
      .map((value, index) =>
        assertString(value, `${label}.imageUrls[${index}]`, 4096));
  const parsedUrl = new URL(assertString(raw.sourceUrl, `${label}.sourceUrl`));
  if (!["http:", "https:"].includes(parsedUrl.protocol) ||
      parsedUrl.username || parsedUrl.password) {
    fail("invalid_argument", `${label}.sourceUrl is invalid`);
  }
  const sourceHost = assertString(
    raw.sourceHost, `${label}.sourceHost`, 512)
      .toLowerCase()
      .replace(/\.$/, "");
  if (parsedUrl.hostname.toLowerCase().replace(/\.$/, "") !== sourceHost) {
    fail("invalid_argument", `${label}.sourceHost does not match sourceUrl`);
  }
  return Object.freeze({
    observationId: assertString(
      raw.observationId, `${label}.observationId`, 180),
    observedAt: assertIsoTimestamp(
      raw.observedAt, `${label}.observedAt`),
    sourceUrl: parsedUrl.toString(),
    sourceHost,
    sourceType: assertString(
      raw.sourceType, `${label}.sourceType`, 80),
    title: assertString(raw.title, `${label}.title`, 500),
    snippet: assertString(raw.snippet, `${label}.snippet`, 4000),
    imageUrls,
    signals: assertSafeJson(raw.signals, `${label}.signals`),
    evidence: assertSafeJson(raw.evidence, `${label}.evidence`),
  });
}

function normalizeChannelResult(raw, index) {
  const label = `channels[${index}]`;
  assertExactKeys(raw, CHANNEL_RESULT_KEYS, label);
  const channelCode = assertEnum(
    raw.channelCode, CHANNEL_CODES, `${label}.channelCode`);
  const status = assertEnum(
    raw.status, CHANNEL_RESULT_STATUSES, `${label}.status`);
  const startedAt = assertIsoTimestamp(
    raw.startedAt, `${label}.startedAt`);
  const completedAt = assertIsoTimestamp(
    raw.completedAt, `${label}.completedAt`);
  if (Date.parse(completedAt) < Date.parse(startedAt)) {
    fail("invalid_argument", `${label} completion precedes start`);
  }
  const observations = assertArray(
    raw.observations, `${label}.observations`, 100)
      .map((item, observationIndex) =>
        normalizeObservation(
          item,
          `${label}.observations[${observationIndex}]`,
        ));
  if (status !== "completed" && observations.length > 0) {
    fail(
      "invalid_argument",
      `${label} cannot contain observations unless completed`,
    );
  }
  return Object.freeze({
    channelCode,
    status,
    startedAt,
    completedAt,
    observations,
    diagnostics: assertSafeJson(raw.diagnostics, `${label}.diagnostics`),
  });
}

function normalizeProviderResult(raw) {
  assertExactKeys(raw, PROVIDER_RESULT_KEYS, "providerResult");
  if (raw.contractVersion !== PROVIDER_RESULT_VERSION) {
    fail("invalid_argument", "provider result contract is unsupported");
  }
  const channels = assertArray(
    raw.channels, "providerResult.channels", CHANNEL_CODES.length)
      .map(normalizeChannelResult);
  if (channels.length !== CHANNEL_CODES.length ||
      channels.some(
        (channel, index) => channel.channelCode !== CHANNEL_CODES[index],
      )) {
    fail("invalid_argument", "provider result channel set is invalid");
  }
  const observationCount = channels.reduce(
    (sum, channel) => sum + channel.observations.length,
    0,
  );
  const completedChannelCount = channels.filter(
    (channel) => channel.status === "completed",
  ).length;
  const dataUnavailableChannelCount = channels.filter(
    (channel) => channel.status === "dataUnavailable",
  ).length;
  const failedChannelCount = channels.filter(
    (channel) => channel.status === "failed",
  ).length;
  const expectedSummary = {
    completedChannelCount,
    dataUnavailableChannelCount,
    failedChannelCount,
    observationCount,
  };
  assertExactKeys(
    raw.summary,
    Object.keys(expectedSummary),
    "providerResult.summary",
  );
  for (const [key, value] of Object.entries(expectedSummary)) {
    if (raw.summary[key] !== value) {
      fail("invalid_argument", `providerResult.summary.${key} is invalid`);
    }
  }
  assertExactKeys(
    raw.engine,
    ["engineCode", "engineVersion"],
    "providerResult.engine",
  );
  return Object.freeze({
    contractVersion: PROVIDER_RESULT_VERSION,
    executionStatus: assertEnum(
      raw.executionStatus,
      EXECUTION_RESULT_STATUSES,
      "providerResult.executionStatus",
    ),
    channels,
    summary: Object.freeze(expectedSummary),
    engine: Object.freeze({
      engineCode: assertString(
        raw.engine.engineCode, "providerResult.engine.engineCode", 100),
      engineVersion: assertString(
        raw.engine.engineVersion, "providerResult.engine.engineVersion", 100),
    }),
  });
}

function buildResultEnvelope({
  dispatchEnvelope,
  dispatchReceipt,
  providerEventId,
  completedAt,
  resultPayload,
}) {
  const dispatch = normalizeDispatchEnvelope(dispatchEnvelope);
  const receipt = buildDispatchReceipt(dispatchReceipt);
  const normalizedResult = normalizeProviderResult(resultPayload);
  return Object.freeze({
    contractVersion: RESULT_ENVELOPE_VERSION,
    providerCode: PROVIDER_CODE,
    externalExecutionId: receipt.externalExecutionId,
    providerEventId: assertString(
      providerEventId, "providerEventId", 256),
    executionId: dispatch.executionId,
    scanRunId: dispatch.scanRunId,
    completedAt: assertIsoTimestamp(completedAt, "completedAt"),
    resultPayload: normalizedResult,
  });
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (!isPlainObject(value)) return value;
  return Object.keys(value).sort().reduce((output, key) => {
    output[key] = canonicalize(value[key]);
    return output;
  }, {});
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function sha256Hex(value) {
  return crypto.createHash("sha256")
      .update(String(value), "utf8")
      .digest("hex");
}

module.exports = Object.freeze({
  CHANNEL_CODES,
  CHANNEL_RESULT_STATUSES,
  DISPATCH_ENVELOPE_VERSION,
  DISPATCH_RECEIPT_VERSION,
  EXECUTION_RESULT_STATUSES,
  FORBIDDEN_KEYS,
  PROVIDER_CODE,
  PROVIDER_RESULT_VERSION,
  PublicLiteWorkflowContractError,
  RESULT_ENVELOPE_VERSION,
  assertSafeJson,
  buildDispatchReceipt,
  buildResultEnvelope,
  canonicalJson,
  normalizeChannelResult,
  normalizeDispatchEnvelope,
  normalizeProviderResult,
  sha256Hex,
});
