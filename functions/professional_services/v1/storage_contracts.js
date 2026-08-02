/* eslint-disable max-len */
"use strict";

const {
  ProfessionalServicesContractError,
  requiredString,
} = require("./contracts");

const REQUIRED_STORAGE_METHODS = Object.freeze([
  "getCommandReceipt",
  "resolveSourceScope",
  "resolveProfessionalServiceAuthority",
  "getServiceRequestById",
  "createServiceRequestAtomic",
  "transitionServiceRequestAtomic",
  "getClientAuthorizationById",
  "getServiceEngagementById",
  "createServiceEngagementAtomic",
  "getServiceProviderById",
  "resolveConflictCheck",
  "getServiceAssignmentById",
  "createServiceAssignmentAtomic",
  "getAgentTaskById",
  "getAgentRunById",
  "createAgentRunAtomic",
  "getAgentOutputDraftById",
  "createAgentOutputDraftAtomic",
  "getAgentHumanReviewById",
  "recordAgentHumanReviewAtomic",
  "publishAgentOutputAtomic",
]);

function fail(code, message) {
  throw new ProfessionalServicesContractError(code, message);
}

function objectRequired(value, field) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    fail("failed-precondition", `${field} invalid`);
  }
  return value;
}

function assertStoragePort(store) {
  objectRequired(store, "store");
  const missing = REQUIRED_STORAGE_METHODS.filter(
      (name) => typeof store[name] !== "function",
  );
  if (missing.length > 0) {
    fail("failed-precondition",
        `storage port is incomplete: ${missing.join(", ")}`);
  }
  return store;
}

function assertClock(clock) {
  if (typeof clock !== "function") {
    fail("failed-precondition", "clock must be a function");
  }
  const value = clock();
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    fail("failed-precondition",
        "clock must return an ISO-8601 timestamp");
  }
  return clock;
}

function assertReceiptShape(receipt) {
  if (receipt === null || receipt === undefined) {
    return null;
  }
  objectRequired(receipt, "receipt");
  for (const field of [
    "idempotencyKey",
    "payloadFingerprint",
    "resultType",
    "resultId",
    "actorUid",
  ]) {
    requiredString(receipt[field], `receipt.${field}`, 1, 256);
  }
  if (!/^[0-9a-f]{64}$/.test(
      String(receipt.payloadFingerprint).toLowerCase())) {
    fail("internal", "receipt.payloadFingerprint invalid");
  }
  return receipt;
}

module.exports = Object.freeze({
  REQUIRED_STORAGE_METHODS,
  assertClock,
  assertReceiptShape,
  assertStoragePort,
});
