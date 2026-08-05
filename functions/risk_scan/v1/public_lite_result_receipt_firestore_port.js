"use strict";

const crypto = require("node:crypto");
const {
  assertDocumentId,
  assertExactKeys,
  assertIsoTimestamp,
  assertNonEmptyString,
  assertPlainObject,
  assertSha256Hex,
} = require("./contracts");
const {
  PUBLIC_LITE_EXECUTION_COLLECTIONS,
  assertExecutionStorageDocument,
  canonicalize,
} = require("./public_lite_execution_firestore_port");

const PUBLIC_LITE_RESULT_ENVELOPE_VERSION_V1 =
  "risk-scan-public-lite-result-envelope-v1";
const PUBLIC_LITE_RESULT_RECEIPT_VERSION_V1 =
  "risk-scan-public-lite-result-receipt-v1";
const PUBLIC_LITE_RESULT_RECEIPT_STORAGE_VERSION_V1 =
  "risk-scan-public-lite-result-receipt-storage-v1";
const PUBLIC_LITE_RESULT_RECEIPT_STORAGE_ALGORITHM_V1 =
  "sha256-canonical-json-v1";
const PUBLIC_LITE_RESULT_RECEIPT_ID_NAMESPACE_V1 =
  "risk-scan-public-lite-result-receipt-id-v1";
const PUBLIC_LITE_RESULT_MAX_CANONICAL_BYTES = 700000;
const PUBLIC_LITE_RESULT_MAX_DEPTH = 8;
const PUBLIC_LITE_RESULT_MAX_ARRAY_LENGTH = 500;
const PUBLIC_LITE_RESULT_MAX_OBJECT_KEYS = 500;
const PUBLIC_LITE_RESULT_MAX_STRING_BYTES = 32768;

const PUBLIC_LITE_RESULT_COLLECTIONS = Object.freeze({
  receipts: "risk_scan_public_lite_result_receipts",
  executions: PUBLIC_LITE_EXECUTION_COLLECTIONS.executions,
});

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

const FORBIDDEN_RESULT_KEYS = Object.freeze(new Set([
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

class PublicLiteResultReceiptError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PublicLiteResultReceiptError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new PublicLiteResultReceiptError(code, message);
}

function assertDb(db) {
  if (!db || typeof db.collection !== "function" ||
      typeof db.runTransaction !== "function") {
    throw new TypeError("db must be a Firestore-compatible instance");
  }
  return db;
}

function isPlainJsonObject(value) {
  if (value === null || typeof value !== "object") return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function normalizeJsonValue(value, label = "resultPayload", depth = 0) {
  if (depth > PUBLIC_LITE_RESULT_MAX_DEPTH) {
    throw new TypeError(`${label} exceeds the maximum nesting depth`);
  }
  if (value === null || typeof value === "boolean") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new TypeError(`${label} contains a non-finite number`);
    }
    return value;
  }
  if (typeof value === "string") {
    if (Buffer.byteLength(value, "utf8") >
        PUBLIC_LITE_RESULT_MAX_STRING_BYTES) {
      throw new TypeError(`${label} contains an oversized string`);
    }
    return value;
  }
  if (Array.isArray(value)) {
    if (value.length > PUBLIC_LITE_RESULT_MAX_ARRAY_LENGTH) {
      throw new TypeError(`${label} contains an oversized array`);
    }
    return value.map((item, index) => normalizeJsonValue(
        item, `${label}[${index}]`, depth + 1));
  }
  if (!isPlainJsonObject(value)) {
    throw new TypeError(`${label} must contain JSON-safe values only`);
  }
  const keys = Object.keys(value);
  if (keys.length > PUBLIC_LITE_RESULT_MAX_OBJECT_KEYS) {
    throw new TypeError(`${label} contains too many keys`);
  }
  const output = {};
  for (const key of keys.sort()) {
    const normalizedKey = assertNonEmptyString(
        key, `${label}.key`, 180);
    if (FORBIDDEN_RESULT_KEYS.has(normalizedKey.toLowerCase())) {
      throw new TypeError(`${label} contains a forbidden key`);
    }
    output[normalizedKey] = normalizeJsonValue(
        value[key], `${label}.${normalizedKey}`, depth + 1);
  }
  return output;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function sha256Hex(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function lengthPrefixed(parts) {
  return parts.map((part) => {
    const value = String(part);
    return `${Buffer.byteLength(value, "utf8")}:${value}`;
  }).join("");
}

function derivePublicLiteResultReceiptId({executionId, providerEventId}) {
  return sha256Hex(lengthPrefixed([
    PUBLIC_LITE_RESULT_RECEIPT_ID_NAMESPACE_V1,
    assertSha256Hex(executionId, "executionId"),
    assertNonEmptyString(providerEventId, "providerEventId", 256),
  ]));
}

function normalizePublicLiteResultEnvelope(raw) {
  assertExactKeys(raw, RESULT_ENVELOPE_KEYS, "resultEnvelope");
  if (raw.contractVersion !== PUBLIC_LITE_RESULT_ENVELOPE_VERSION_V1) {
    throw new TypeError("resultEnvelope contractVersion is unsupported");
  }
  const resultPayload = normalizeJsonValue(raw.resultPayload);
  const payloadCanonical = canonicalJson(resultPayload);
  const payloadBytes = Buffer.byteLength(payloadCanonical, "utf8");
  if (payloadBytes > PUBLIC_LITE_RESULT_MAX_CANONICAL_BYTES) {
    throw new TypeError("resultPayload exceeds the maximum canonical size");
  }
  return Object.freeze({
    contractVersion: PUBLIC_LITE_RESULT_ENVELOPE_VERSION_V1,
    providerCode: assertNonEmptyString(
        raw.providerCode, "providerCode", 80),
    externalExecutionId: assertNonEmptyString(
        raw.externalExecutionId, "externalExecutionId", 256),
    providerEventId: assertNonEmptyString(
        raw.providerEventId, "providerEventId", 256),
    executionId: assertSha256Hex(raw.executionId, "executionId"),
    scanRunId: assertDocumentId(raw.scanRunId, "scanRunId"),
    completedAt: assertIsoTimestamp(raw.completedAt, "completedAt"),
    resultPayload,
    resultPayloadDigestSha256: sha256Hex(payloadCanonical),
    resultPayloadCanonicalBytes: payloadBytes,
  });
}

function resultReceiptStorageFingerprint(document) {
  assertPlainObject(document, "resultReceipt");
  const fingerprintPayload = {...document};
  delete fingerprintPayload.storageFingerprintSha256;
  return sha256Hex(canonicalJson(fingerprintPayload));
}

function withResultReceiptStorageFingerprint(document) {
  return {
    ...document,
    storageFingerprintSha256:
      resultReceiptStorageFingerprint(document),
  };
}

function buildPublicLiteResultReceiptDocument({envelope, receivedAt}) {
  const normalized = normalizePublicLiteResultEnvelope(envelope);
  const normalizedReceivedAt = assertIsoTimestamp(receivedAt, "receivedAt");
  const receiptId = derivePublicLiteResultReceiptId(normalized);
  return withResultReceiptStorageFingerprint({
    contractVersion: PUBLIC_LITE_RESULT_RECEIPT_VERSION_V1,
    storageVersion: PUBLIC_LITE_RESULT_RECEIPT_STORAGE_VERSION_V1,
    storageFingerprintAlgorithm:
      PUBLIC_LITE_RESULT_RECEIPT_STORAGE_ALGORITHM_V1,
    receiptId,
    executionId: normalized.executionId,
    scanRunId: normalized.scanRunId,
    providerCode: normalized.providerCode,
    externalExecutionId: normalized.externalExecutionId,
    providerEventId: normalized.providerEventId,
    providerCompletedAt: normalized.completedAt,
    resultPayload: normalized.resultPayload,
    resultPayloadDigestSha256:
      normalized.resultPayloadDigestSha256,
    resultPayloadCanonicalBytes:
      normalized.resultPayloadCanonicalBytes,
    processingStatus: "received",
    processingAttemptCount: 0,
    receivedAt: normalizedReceivedAt,
    updatedAt: normalizedReceivedAt,
    immutable: true,
  });
}

function assertPublicLiteResultReceiptDocument(document) {
  assertPlainObject(document, "resultReceipt");
  if (document.contractVersion !==
      PUBLIC_LITE_RESULT_RECEIPT_VERSION_V1 ||
      document.storageVersion !==
      PUBLIC_LITE_RESULT_RECEIPT_STORAGE_VERSION_V1 ||
      document.storageFingerprintAlgorithm !==
      PUBLIC_LITE_RESULT_RECEIPT_STORAGE_ALGORITHM_V1 ||
      document.processingStatus !== "received" ||
      document.processingAttemptCount !== 0 ||
      document.immutable !== true) {
    fail("conflict", "stored result receipt contract is invalid");
  }
  assertSha256Hex(document.receiptId, "receiptId");
  assertSha256Hex(document.executionId, "executionId");
  assertDocumentId(document.scanRunId, "scanRunId");
  assertNonEmptyString(document.providerCode, "providerCode", 80);
  assertNonEmptyString(
      document.externalExecutionId, "externalExecutionId", 256);
  assertNonEmptyString(document.providerEventId, "providerEventId", 256);
  assertIsoTimestamp(document.providerCompletedAt, "providerCompletedAt");
  assertIsoTimestamp(document.receivedAt, "receivedAt");
  assertIsoTimestamp(document.updatedAt, "updatedAt");
  normalizeJsonValue(document.resultPayload);
  assertSha256Hex(
      document.resultPayloadDigestSha256,
      "resultPayloadDigestSha256");
  if (!Number.isInteger(document.resultPayloadCanonicalBytes) ||
      document.resultPayloadCanonicalBytes < 0 ||
      document.resultPayloadCanonicalBytes >
        PUBLIC_LITE_RESULT_MAX_CANONICAL_BYTES) {
    fail("conflict", "stored result receipt size is invalid");
  }
  const expected = resultReceiptStorageFingerprint(document);
  if (document.storageFingerprintSha256 !== expected) {
    fail("conflict", "stored result receipt fingerprint is invalid");
  }
  return document;
}

function snapshotData(snapshot, label) {
  if (!snapshot || snapshot.exists !== true) {
    fail("not-found", `${label} was not found`);
  }
  return snapshot.data();
}

function executionRef(db, executionId) {
  return db.collection(PUBLIC_LITE_RESULT_COLLECTIONS.executions)
      .doc(assertSha256Hex(executionId, "executionId"));
}

function resultReceiptRef(db, receiptId) {
  return db.collection(PUBLIC_LITE_RESULT_COLLECTIONS.receipts)
      .doc(assertSha256Hex(receiptId, "receiptId"));
}

function assertReceiptReplay(existing, expected) {
  assertPublicLiteResultReceiptDocument(existing);
  assertPublicLiteResultReceiptDocument(expected);
  const replayFields = [
    "receiptId",
    "executionId",
    "scanRunId",
    "providerCode",
    "externalExecutionId",
    "providerEventId",
    "providerCompletedAt",
    "resultPayloadDigestSha256",
    "resultPayloadCanonicalBytes",
  ];
  if (replayFields.some((field) => existing[field] !== expected[field])) {
    fail("conflict", "result receipt replay conflicts with stored data");
  }
  return existing;
}

async function persistPublicLiteResultReceipt(db, {
  envelope,
  receivedAt,
}) {
  assertDb(db);
  const receipt = buildPublicLiteResultReceiptDocument({
    envelope,
    receivedAt,
  });
  const targetExecutionRef = executionRef(db, receipt.executionId);
  const targetReceiptRef = resultReceiptRef(db, receipt.receiptId);

  return db.runTransaction(async (transaction) => {
    const executionSnapshot = await transaction.get(targetExecutionRef);
    const receiptSnapshot = await transaction.get(targetReceiptRef);
    const execution = assertExecutionStorageDocument(
        snapshotData(executionSnapshot, "execution"));

    if (receiptSnapshot.exists) {
      if (execution.scanRunId !== receipt.scanRunId ||
          execution.providerCode !== receipt.providerCode ||
          execution.externalExecutionId !== receipt.externalExecutionId) {
        fail("conflict", "result receipt does not match dispatch scope");
      }
      assertReceiptReplay(receiptSnapshot.data(), receipt);
      return {
        outcome: "idempotent_success",
        duplicate: true,
        receiptId: receipt.receiptId,
      };
    }

    if (execution.status !== "dispatched") {
      fail(
          "failed-precondition",
          "new result receipt requires a dispatched execution");
    }

    if (execution.scanRunId !== receipt.scanRunId ||
        execution.providerCode !== receipt.providerCode ||
        execution.externalExecutionId !== receipt.externalExecutionId) {
      fail("conflict", "result receipt does not match dispatch scope");
    }

    transaction.create(targetReceiptRef, receipt);
    return {
      outcome: "created",
      duplicate: false,
      receiptId: receipt.receiptId,
    };
  });
}

async function getPublicLiteResultReceipt(db, {receiptId}) {
  assertDb(db);
  const snapshot = await resultReceiptRef(db, receiptId).get();
  return assertPublicLiteResultReceiptDocument(
      snapshotData(snapshot, "resultReceipt"));
}

module.exports = Object.freeze({
  FORBIDDEN_RESULT_KEYS,
  PUBLIC_LITE_RESULT_COLLECTIONS,
  PUBLIC_LITE_RESULT_ENVELOPE_VERSION_V1,
  PUBLIC_LITE_RESULT_MAX_CANONICAL_BYTES,
  PUBLIC_LITE_RESULT_RECEIPT_STORAGE_ALGORITHM_V1,
  PUBLIC_LITE_RESULT_RECEIPT_STORAGE_VERSION_V1,
  PUBLIC_LITE_RESULT_RECEIPT_VERSION_V1,
  PublicLiteResultReceiptError,
  assertPublicLiteResultReceiptDocument,
  buildPublicLiteResultReceiptDocument,
  canonicalJson,
  derivePublicLiteResultReceiptId,
  getPublicLiteResultReceipt,
  normalizeJsonValue,
  normalizePublicLiteResultEnvelope,
  persistPublicLiteResultReceipt,
  resultReceiptStorageFingerprint,
  sha256Hex,
  withResultReceiptStorageFingerprint,
});
