/* eslint-disable max-len */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  REQUIRED_STORAGE_METHODS,
  assertClock,
  assertReceiptShape,
  assertStoragePort,
} = require("./storage_contracts");
const {
  ProfessionalServicesContractError,
} = require("./contracts");

function completeStore() {
  return Object.fromEntries(
      REQUIRED_STORAGE_METHODS.map((name) => [name, async () => null]),
  );
}

test("storage port exposes the complete PHO service boundary", () => {
  assert.equal(REQUIRED_STORAGE_METHODS.length, 21);
  assert.deepEqual(REQUIRED_STORAGE_METHODS, [
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
  assert.equal(assertStoragePort(completeStore()).getCommandReceipt instanceof
    Function, true);
});

test("storage port rejects an incomplete implementation", () => {
  assert.throws(
      () => assertStoragePort({getCommandReceipt() {}}),
      (error) => error instanceof ProfessionalServicesContractError &&
        error.code === "failed-precondition" &&
        error.message.includes("resolveSourceScope"),
  );
});

test("clock must return a valid ISO timestamp", () => {
  const valid = () => "2026-08-02T10:00:00.000Z";
  assert.equal(assertClock(valid), valid);
  assert.throws(
      () => assertClock(() => "not-a-date"),
      (error) => error instanceof ProfessionalServicesContractError &&
        error.code === "failed-precondition",
  );
  assert.throws(
      () => assertClock(null),
      (error) => error instanceof ProfessionalServicesContractError &&
        error.code === "failed-precondition",
  );
});

test("receipt shape accepts null and immutable command metadata", () => {
  assert.equal(assertReceiptShape(null), null);
  const receipt = {
    idempotencyKey: "idem-1",
    payloadFingerprint: "a".repeat(64),
    resultType: "professional_service_request",
    resultId: "psr-1",
    actorUid: "user-1",
  };
  assert.equal(assertReceiptShape(receipt), receipt);
});

test("receipt shape rejects missing actor attribution", () => {
  assert.throws(
      () => assertReceiptShape({
        idempotencyKey: "idem-1",
        payloadFingerprint: "a".repeat(64),
        resultType: "professional_service_request",
        resultId: "psr-1",
      }),
      (error) => error instanceof ProfessionalServicesContractError &&
        error.code === "invalid-argument",
  );
});

test("receipt shape rejects a malformed payload fingerprint", () => {
  assert.throws(
      () => assertReceiptShape({
        idempotencyKey: "idem-1",
        payloadFingerprint: "not-a-digest",
        resultType: "professional_service_request",
        resultId: "psr-1",
        actorUid: "user-1",
      }),
      (error) => error instanceof ProfessionalServicesContractError &&
        error.code === "internal",
  );
});
