"use strict";

const {
  assertIsoTimestamp,
  assertNonEmptyString,
  assertPlainObject,
  assertSha256Hex,
} = require("./contracts");
const {
  buildPublicLiteDispatchEnvelope,
} = require("./public_lite_execution_contract");
const {
  PUBLIC_LITE_EXECUTION_COLLECTIONS,
  assertExecutionStorageDocument,
} = require("./public_lite_execution_firestore_port");
const {
  PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION,
  PUBLIC_LITE_PROVIDER_HANDOFF_LEASE_MS,
  PUBLIC_LITE_PROVIDER_HANDOFF_MAX_ATTEMPTS,
  assertPublicLiteProviderHandoffRecord,
  assertPublicLiteProviderHandoffReplay,
  buildPublicLiteAcquisitionCommand,
  buildPublicLiteProviderHandoffRecord,
  canonicalJson,
  derivePublicLiteProviderHandoffLeaseToken,
  normalizePublicLiteAcquisitionDispatchReceipt,
  normalizePublicLiteProviderHandoffRequest,
  sha256Hex,
  updatePublicLiteProviderHandoffRecord,
} = require("./public_lite_provider_handoff_contract");

class PublicLiteProviderHandoffFirestoreError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PublicLiteProviderHandoffFirestoreError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new PublicLiteProviderHandoffFirestoreError(code, message);
}

function assertDb(db) {
  if (!db || typeof db.collection !== "function" ||
      typeof db.runTransaction !== "function") {
    throw new TypeError("db must be a Firestore-compatible instance");
  }
  return db;
}

function providerHandoffRef(db, executionId) {
  return db.collection(PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION)
      .doc(assertSha256Hex(executionId, "executionId"));
}

function executionRef(db, executionId) {
  return db.collection(PUBLIC_LITE_EXECUTION_COLLECTIONS.executions)
      .doc(assertSha256Hex(executionId, "executionId"));
}

function snapshotData(snapshot, label) {
  if (!snapshot || snapshot.exists !== true) {
    fail("not-found", `${label} was not found`);
  }
  return snapshot.data();
}

function assertExecutionMatchesRequest(execution, request) {
  const stored = assertExecutionStorageDocument(execution);
  const normalized = normalizePublicLiteProviderHandoffRequest(request);
  if (stored.executionId !== normalized.executionId ||
      stored.scanRunId !== normalized.scanRunId) {
    fail("conflict", "provider handoff scope conflicts with execution");
  }
  const authoritativeEnvelope = buildPublicLiteDispatchEnvelope(
      stored.command);
  if (sha256Hex(canonicalJson(authoritativeEnvelope)) !==
      normalized.dispatchEnvelopeHash) {
    fail("conflict", "provider handoff envelope conflicts with execution");
  }
  return {execution: stored, request: normalized, authoritativeEnvelope};
}

function assertChildLease(record, {
  ownerId,
  attemptCount,
  leaseToken,
}) {
  const normalizedOwner = assertNonEmptyString(ownerId, "ownerId", 256);
  if (record.state !== "child_dispatching" ||
      record.childDispatchLeaseOwner !== normalizedOwner ||
      record.childDispatchAttemptCount !== attemptCount ||
      record.childDispatchLeaseToken !==
        assertSha256Hex(leaseToken, "leaseToken")) {
    fail("conflict", "child dispatch lease no longer matches");
  }
  return normalizedOwner;
}

function createPublicLiteProviderHandoffFirestorePort(db) {
  assertDb(db);

  async function acceptHandoff({
    request,
    acceptedAt,
    purgeAtTimestamp,
  }) {
    const normalized = normalizePublicLiteProviderHandoffRequest(request);
    const expected = buildPublicLiteProviderHandoffRecord({
      request,
      acceptedAt,
      purgeAtTimestamp,
    });
    const targetExecutionRef = executionRef(db, normalized.executionId);
    const targetHandoffRef = providerHandoffRef(db, normalized.executionId);

    return db.runTransaction(async (transaction) => {
      const executionSnapshot = await transaction.get(targetExecutionRef);
      const handoffSnapshot = await transaction.get(targetHandoffRef);
      const scope = assertExecutionMatchesRequest(
          snapshotData(executionSnapshot, "execution"), request);

      if (handoffSnapshot.exists) {
        const existing = assertPublicLiteProviderHandoffReplay(
            handoffSnapshot.data(), request);
        return {
          outcome: "idempotent_success",
          replayed: true,
          record: existing,
        };
      }
      if (scope.execution.status !== "dispatching") {
        fail(
            "failed-precondition",
            "new provider handoff requires a dispatching execution");
      }
      transaction.create(targetHandoffRef, expected);
      return {outcome: "created", replayed: false, record: expected};
    });
  }

  async function claimChildDispatch({
    executionId,
    ownerId,
    now,
    maxAttempts = PUBLIC_LITE_PROVIDER_HANDOFF_MAX_ATTEMPTS,
  }) {
    const targetHandoffRef = providerHandoffRef(db, executionId);
    const targetExecutionRef = executionRef(db, executionId);
    const normalizedOwner = assertNonEmptyString(ownerId, "ownerId", 256);
    const normalizedNow = assertIsoTimestamp(now, "now");
    if (!Number.isInteger(maxAttempts) || maxAttempts < 1 ||
        maxAttempts > 20) {
      throw new TypeError("maxAttempts is invalid");
    }

    return db.runTransaction(async (transaction) => {
      const handoffSnapshot = await transaction.get(targetHandoffRef);
      const executionSnapshot = await transaction.get(targetExecutionRef);
      const record = assertPublicLiteProviderHandoffRecord(
          snapshotData(handoffSnapshot, "providerHandoff"));
      const execution = assertExecutionStorageDocument(
          snapshotData(executionSnapshot, "execution"));

      if (record.executionId !== execution.executionId ||
          record.scanRunId !== execution.scanRunId) {
        fail("conflict", "provider handoff execution scope is invalid");
      }
      if (["child_dispatched", "completed"].includes(record.state)) {
        return {
          outcome: record.state === "completed" ?
            "completed" : "already_dispatched",
          record,
        };
      }
      if (record.state === "dead_letter") {
        return {outcome: "terminal", record};
      }
      if (record.state === "child_dispatching" &&
          Date.parse(record.childDispatchLeaseUntil) >
            Date.parse(normalizedNow)) {
        return {outcome: "lease_held", record};
      }

      const attemptCount = record.childDispatchAttemptCount + 1;
      if (attemptCount > maxAttempts) {
        const terminal = updatePublicLiteProviderHandoffRecord(record, {
          state: "dead_letter",
          childDispatchLeaseOwner: null,
          childDispatchLeaseToken: null,
          childDispatchLeaseUntil: null,
          lastChildDispatchErrorCode: "child_dispatch_attempts_exhausted",
          lastChildDispatchErrorAt: normalizedNow,
          updatedAt: normalizedNow,
        });
        transaction.update(targetHandoffRef, terminal);
        return {outcome: "terminal", record: terminal};
      }

      const leaseToken = derivePublicLiteProviderHandoffLeaseToken({
        executionId: record.executionId,
        ownerId: normalizedOwner,
        attemptCount,
        now: normalizedNow,
      });
      const leaseUntil = new Date(
          Date.parse(normalizedNow) +
          PUBLIC_LITE_PROVIDER_HANDOFF_LEASE_MS).toISOString();
      const claimed = updatePublicLiteProviderHandoffRecord(record, {
        state: "child_dispatching",
        childDispatchAttemptCount: attemptCount,
        childDispatchLeaseOwner: normalizedOwner,
        childDispatchLeaseToken: leaseToken,
        childDispatchLeaseUntil: leaseUntil,
        updatedAt: normalizedNow,
      });
      const dispatchEnvelope = buildPublicLiteDispatchEnvelope(
          execution.command);
      const command = buildPublicLiteAcquisitionCommand({
        record: claimed,
        dispatchEnvelope,
        attemptCount,
        leaseToken,
      });
      transaction.update(targetHandoffRef, claimed);
      return {
        outcome: "claimed",
        attemptCount,
        leaseToken,
        leaseUntil,
        record: claimed,
        command,
      };
    });
  }

  async function markChildDispatchSucceeded({
    executionId,
    ownerId,
    attemptCount,
    leaseToken,
    receipt,
    dispatchedAt,
  }) {
    const targetRef = providerHandoffRef(db, executionId);
    const normalizedAt = assertIsoTimestamp(dispatchedAt, "dispatchedAt");

    return db.runTransaction(async (transaction) => {
      const record = assertPublicLiteProviderHandoffRecord(snapshotData(
          await transaction.get(targetRef), "providerHandoff"));
      const normalizedReceipt = normalizePublicLiteAcquisitionDispatchReceipt(
          receipt,
          {
            expectedHandoffId: record.handoffId,
            expectedExecutionId: record.executionId,
          });

      if (["child_dispatched", "completed"].includes(record.state)) {
        if (record.childExternalExecutionId !==
            normalizedReceipt.externalExecutionId) {
          fail("conflict", "child dispatch receipt conflicts with stored data");
        }
        return {outcome: "idempotent_success", record};
      }
      assertChildLease(record, {
        ownerId,
        attemptCount,
        leaseToken,
      });
      const updated = updatePublicLiteProviderHandoffRecord(record, {
        state: "child_dispatched",
        childDispatchLeaseOwner: null,
        childDispatchLeaseToken: null,
        childDispatchLeaseUntil: null,
        childExternalExecutionId:
          normalizedReceipt.externalExecutionId,
        childDispatchedAt: normalizedAt,
        updatedAt: normalizedAt,
      });
      transaction.update(targetRef, updated);
      return {outcome: "child_dispatched", record: updated};
    });
  }

  async function markChildDispatchFailed({
    executionId,
    ownerId,
    attemptCount,
    leaseToken,
    failure,
    retryable,
    failedAt,
  }) {
    assertPlainObject(failure, "failure");
    const targetRef = providerHandoffRef(db, executionId);
    const normalizedAt = assertIsoTimestamp(failedAt, "failedAt");

    return db.runTransaction(async (transaction) => {
      const record = assertPublicLiteProviderHandoffRecord(snapshotData(
          await transaction.get(targetRef), "providerHandoff"));
      if (record.state === (retryable ? "failed" : "dead_letter")) {
        return {outcome: "idempotent_success", record};
      }
      assertChildLease(record, {ownerId, attemptCount, leaseToken});
      const updated = updatePublicLiteProviderHandoffRecord(record, {
        state: retryable ? "failed" : "dead_letter",
        childDispatchLeaseOwner: null,
        childDispatchLeaseToken: null,
        childDispatchLeaseUntil: null,
        lastChildDispatchErrorCode: String(
            failure.code || "child_dispatch_failed").slice(0, 100),
        lastChildDispatchErrorAt: normalizedAt,
        updatedAt: normalizedAt,
      });
      transaction.update(targetRef, updated);
      return {
        outcome: retryable ? "retryable_failure" : "terminal_failure",
        record: updated,
      };
    });
  }

  async function getHandoff({executionId}) {
    const snapshot = await providerHandoffRef(db, executionId).get();
    return assertPublicLiteProviderHandoffRecord(
        snapshotData(snapshot, "providerHandoff"));
  }

  return Object.freeze({
    acceptHandoff,
    claimChildDispatch,
    getHandoff,
    markChildDispatchFailed,
    markChildDispatchSucceeded,
  });
}

module.exports = Object.freeze({
  PublicLiteProviderHandoffFirestoreError,
  assertChildLease,
  assertExecutionMatchesRequest,
  createPublicLiteProviderHandoffFirestorePort,
  providerHandoffRef,
});
