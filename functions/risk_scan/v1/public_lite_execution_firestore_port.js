"use strict";

const crypto = require("node:crypto");
const {
  assertDocumentId,
  assertIsoTimestamp,
  assertPlainObject,
  assertSha256Hex,
  channelCodes,
} = require("./contracts");
const {
  PUBLIC_LITE_DISPATCH_LEASE_MS,
  PUBLIC_LITE_EXECUTION_RECORD_VERSION_V1,
  assertExecutionCommand,
  assertExecutionTransition,
  normalizeDispatchOwnerId,
  normalizeDispatchReceipt,
} = require("./public_lite_execution_contract");
const {
  assertChannelTransition,
  assertRunTransition,
} = require("./lifecycle");
const {withStorageFingerprint} = require("./storage_documents");

const PUBLIC_LITE_EXECUTION_STORAGE_VERSION_V1 =
  "risk-scan-public-lite-execution-storage-v1";
const PUBLIC_LITE_EXECUTION_STORAGE_ALGORITHM_V1 =
  "sha256-canonical-json-v1";
const PUBLIC_LITE_EXECUTION_COLLECTIONS = Object.freeze({
  executions: "risk_scan_public_lite_executions",
  runs: "risk_scan_runs",
  channels: "channels",
});

class PublicLiteExecutionFirestoreError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PublicLiteExecutionFirestoreError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new PublicLiteExecutionFirestoreError(code, message);
}

function assertDb(db) {
  if (!db || typeof db.collection !== "function" ||
      typeof db.runTransaction !== "function") {
    throw new TypeError("db must be a Firestore-compatible instance");
  }
  return db;
}

function executionRef(db, executionId) {
  return db.collection(PUBLIC_LITE_EXECUTION_COLLECTIONS.executions)
      .doc(assertSha256Hex(executionId, "executionId"));
}

function runRef(db, scanRunId) {
  return db.collection(PUBLIC_LITE_EXECUTION_COLLECTIONS.runs)
      .doc(assertDocumentId(scanRunId, "scanRunId"));
}

function channelRef(rootRef, channelCode) {
  if (!channelCodes.includes(channelCode)) {
    throw new TypeError("channelCode is invalid");
  }
  return rootRef.collection(PUBLIC_LITE_EXECUTION_COLLECTIONS.channels)
      .doc(channelCode);
}

function snapshotData(snapshot, label) {
  if (!snapshot || snapshot.exists !== true) {
    fail("not-found", `${label} was not found`);
  }
  return snapshot.data();
}

function canonicalize(value) {
  if (Array.isArray(value)) {
    return value.map(canonicalize);
  }
  if (value && typeof value === "object") {
    return Object.keys(value).sort().reduce((output, key) => {
      output[key] = canonicalize(value[key]);
      return output;
    }, {});
  }
  return value;
}

function executionStorageFingerprint(document) {
  const copy = {...document};
  delete copy.storageFingerprintSha256;
  return crypto.createHash("sha256")
      .update(JSON.stringify(canonicalize(copy)), "utf8")
      .digest("hex");
}

function withExecutionStorageFingerprint(document) {
  const output = {
    ...document,
    storageSchemaVersion: PUBLIC_LITE_EXECUTION_STORAGE_VERSION_V1,
    storageFingerprintAlgorithm:
      PUBLIC_LITE_EXECUTION_STORAGE_ALGORITHM_V1,
  };
  output.storageFingerprintSha256 =
    executionStorageFingerprint(output);
  return output;
}

function assertExecutionStorageDocument(document, label = "execution") {
  assertPlainObject(document, label);
  if (document.storageSchemaVersion !==
      PUBLIC_LITE_EXECUTION_STORAGE_VERSION_V1 ||
      document.storageFingerprintAlgorithm !==
      PUBLIC_LITE_EXECUTION_STORAGE_ALGORITHM_V1) {
    fail("conflict", `${label} storage contract is unsupported`);
  }
  const expected = executionStorageFingerprint(document);
  if (document.storageFingerprintSha256 !== expected) {
    fail("conflict", `${label} storage fingerprint is invalid`);
  }
  assertSha256Hex(document.executionId, `${label}.executionId`);
  assertDocumentId(document.scanRunId, `${label}.scanRunId`);
  assertPlainObject(document.command, `${label}.command`);
  assertExecutionCommand(document.command);
  if (document.command.executionId !== document.executionId ||
      document.command.scanRunId !== document.scanRunId) {
    fail("conflict", `${label} command scope is invalid`);
  }
  return document;
}

function buildExecutionStorageDocument({command, record}) {
  assertExecutionCommand(command);
  assertPlainObject(record, "record");
  if (record.contractVersion !==
      PUBLIC_LITE_EXECUTION_RECORD_VERSION_V1 ||
      record.executionId !== command.executionId ||
      record.scanRunId !== command.scanRunId ||
      record.status !== "prepared" ||
      record.attemptCount !== 0 ||
      record.leaseOwner !== null ||
      record.leaseExpiresAt !== null) {
    throw new TypeError("execution record is invalid");
  }
  return withExecutionStorageFingerprint({
    ...record,
    command,
  });
}

function assertReplayMatch(existing, expected) {
  assertExecutionStorageDocument(existing, "existingExecution");
  assertExecutionStorageDocument(expected, "expectedExecution");
  if (existing.executionId !== expected.executionId ||
      existing.scanRunId !== expected.scanRunId ||
      existing.requestFingerprintSha256 !==
        expected.requestFingerprintSha256 ||
      existing.command.eventId !== expected.command.eventId ||
      existing.command.requestFingerprintSha256 !==
        expected.command.requestFingerprintSha256) {
    fail("conflict", "execution replay conflicts with stored data");
  }
  return existing;
}

function assertRunScope(run, command) {
  assertPlainObject(run, "run");
  if (run.scanRunId !== command.scanRunId ||
      run.requestId !== command.requestId ||
      run.requestFingerprintSha256 !==
        command.requestFingerprintSha256 ||
      run.deduplicationFingerprintSha256 !==
        command.deduplicationFingerprintSha256 ||
      run.identityMode !== "anonymous" ||
      run.accessTier !== "publicLite" ||
      run.scanMode !== "quick" ||
      run.tenantId !== null ||
      run.canonicalBrandId !== null ||
      run.createdByUid !== null ||
      run.target?.targetFingerprintSha256 !==
        command.target.targetFingerprintSha256) {
    fail("conflict", "run does not match execution command scope");
  }
  return run;
}

function assertChannelScope(channel, scanRunId, channelCode) {
  assertPlainObject(channel, "channel");
  if (channel.scanRunId !== scanRunId ||
      channel.channelCode !== channelCode) {
    fail("conflict", "channel scope does not match its path");
  }
  return channel;
}

function updateRunDocument(run, nextStatus, updatedAt) {
  if (run.status !== nextStatus) {
    assertRunTransition(run.status, nextStatus);
  }
  return withStorageFingerprint({
    ...run,
    status: nextStatus,
    updatedAt: assertIsoTimestamp(updatedAt, "updatedAt"),
  });
}

function updateChannelDocument(channel, nextStatus, updatedAt, patch = {}) {
  if (channel.status !== nextStatus) {
    assertChannelTransition(channel.status, nextStatus);
  }
  return withStorageFingerprint({
    ...channel,
    ...patch,
    status: nextStatus,
    updatedAt: assertIsoTimestamp(updatedAt, "updatedAt"),
  });
}

function updateExecutionDocument(execution, patch) {
  assertExecutionStorageDocument(execution);
  if (patch.status && execution.status !== patch.status) {
    assertExecutionTransition(execution.status, patch.status);
  }
  return withExecutionStorageFingerprint({
    ...execution,
    ...patch,
  });
}

function assertLeaseMatch(execution, {ownerId, attemptCount}) {
  const normalizedOwner = normalizeDispatchOwnerId(ownerId);
  if (execution.status !== "dispatching" ||
      execution.leaseOwner !== normalizedOwner ||
      execution.attemptCount !== attemptCount) {
    fail("conflict", "dispatch lease no longer matches");
  }
  return normalizedOwner;
}

async function readRunAndChannels(transaction, rootRef, scanRunId) {
  const runSnapshot = await transaction.get(rootRef);
  const refs = channelCodes.map((code) => channelRef(rootRef, code));
  const snapshots = [];
  for (const ref of refs) snapshots.push(await transaction.get(ref));
  const run = snapshotData(runSnapshot, "run");
  const channels = snapshots.map((snapshot, index) =>
    assertChannelScope(
        snapshotData(snapshot, `channel[${index}]`),
        scanRunId,
        channelCodes[index]));
  return {run, channels, refs};
}

function createPublicLiteExecutionFirestorePort(db) {
  assertDb(db);

  async function prepareExecution({command, record}) {
    const expected = buildExecutionStorageDocument({command, record});
    const targetExecutionRef = executionRef(db, command.executionId);
    const targetRunRef = runRef(db, command.scanRunId);

    return db.runTransaction(async (transaction) => {
      const executionSnapshot = await transaction.get(targetExecutionRef);
      const {run, channels} = await readRunAndChannels(
          transaction, targetRunRef, command.scanRunId);
      assertRunScope(run, command);
      channels.forEach((channel) => {
        if (!["queued", "acquiring", "failedRetryable",
          "failedTerminal", "completed", "completedWithLimits"]
            .includes(channel.status)) {
          fail("failed-precondition", "channel is not execution-ready");
        }
      });

      if (executionSnapshot.exists) {
        assertReplayMatch(executionSnapshot.data(), expected);
        return {outcome: "idempotent_success"};
      }
      if (run.status !== "created") {
        fail("failed-precondition", "new execution requires created run");
      }
      transaction.create(targetExecutionRef, expected);
      return {outcome: "created"};
    });
  }

  async function queueExecution({executionId, scanRunId, updatedAt}) {
    const targetExecutionRef = executionRef(db, executionId);
    const targetRunRef = runRef(db, scanRunId);
    const normalizedAt = assertIsoTimestamp(updatedAt, "updatedAt");

    await db.runTransaction(async (transaction) => {
      const execution = assertExecutionStorageDocument(snapshotData(
          await transaction.get(targetExecutionRef), "execution"));
      if (execution.scanRunId !== scanRunId) {
        fail("conflict", "execution belongs to another run");
      }
      const run = snapshotData(
          await transaction.get(targetRunRef), "run");
      assertRunScope(run, execution.command);
      if (run.status === "created") {
        transaction.update(
            targetRunRef,
            updateRunDocument(run, "validatingTarget", normalizedAt));
      } else if (!["validatingTarget", "queued", "failedRetryable"]
          .includes(run.status)) {
        fail("failed-precondition", "run cannot be queued");
      }
    });

    return db.runTransaction(async (transaction) => {
      const execution = assertExecutionStorageDocument(snapshotData(
          await transaction.get(targetExecutionRef), "execution"));
      const {run, channels, refs} = await readRunAndChannels(
          transaction, targetRunRef, scanRunId);
      assertRunScope(run, execution.command);

      if (run.status === "queued") {
        return {outcome: "idempotent_success"};
      }
      if (run.status === "validatingTarget") {
        transaction.update(
            targetRunRef,
            updateRunDocument(run, "queued", normalizedAt));
        return {outcome: "queued"};
      }
      if (run.status !== "failedRetryable") {
        fail("failed-precondition", "run cannot be requeued");
      }

      transaction.update(
          targetRunRef,
          updateRunDocument(run, "queued", normalizedAt));
      channels.forEach((channel, index) => {
        if (channel.status === "failedRetryable") {
          transaction.update(
              refs[index],
              updateChannelDocument(
                  channel, "queued", normalizedAt, {
                    startedAt: null,
                    completedAt: null,
                  }));
        } else if (channel.status !== "queued") {
          fail("conflict", "retry channel state is inconsistent");
        }
      });
      return {outcome: "queued"};
    });
  }

  async function claimDispatch({
    executionId,
    scanRunId,
    ownerId,
    now,
    maxAttempts,
  }) {
    const targetExecutionRef = executionRef(db, executionId);
    const targetRunRef = runRef(db, scanRunId);
    const normalizedOwner = normalizeDispatchOwnerId(ownerId);
    const normalizedNow = assertIsoTimestamp(now, "now");
    if (!Number.isInteger(maxAttempts) || maxAttempts < 1 ||
        maxAttempts > 20) {
      throw new TypeError("maxAttempts is invalid");
    }

    return db.runTransaction(async (transaction) => {
      const execution = assertExecutionStorageDocument(snapshotData(
          await transaction.get(targetExecutionRef), "execution"));
      const {run, channels, refs} = await readRunAndChannels(
          transaction, targetRunRef, scanRunId);
      assertRunScope(run, execution.command);

      if (["dispatched", "completed"].includes(execution.status)) {
        return {outcome: "already_dispatched"};
      }
      if (execution.status === "terminalFailure") {
        return {outcome: "terminal"};
      }
      if (run.status !== "queued") {
        fail("failed-precondition", "dispatch claim requires queued run");
      }
      if (execution.status === "dispatching" &&
          Date.parse(execution.leaseExpiresAt) > Date.parse(normalizedNow)) {
        return {outcome: "lease_held"};
      }

      const attemptCount = execution.attemptCount + 1;
      if (attemptCount > maxAttempts) {
        const terminalAt = normalizedNow;
        transaction.update(targetExecutionRef, updateExecutionDocument(
            execution, {
              status: "terminalFailure",
              leaseOwner: null,
              leaseExpiresAt: null,
              lastFailureCode: "dispatch_attempts_exhausted",
              lastFailureMessage:
                "Dispatch attempts were exhausted before provider acceptance.",
              updatedAt: terminalAt,
            }));
        transaction.update(
            targetRunRef,
            updateRunDocument(run, "failedTerminal", terminalAt));
        channels.forEach((channel, index) => {
          if (channel.status === "queued") {
            transaction.update(refs[index], updateChannelDocument(
                channel, "failedTerminal", terminalAt, {
                  completedAt: terminalAt,
                }));
          }
        });
        return {outcome: "terminal"};
      }

      const leaseExpiresAt = new Date(
          Date.parse(normalizedNow) + PUBLIC_LITE_DISPATCH_LEASE_MS)
          .toISOString();
      transaction.update(targetExecutionRef, updateExecutionDocument(
          execution, {
            status: "dispatching",
            attemptCount,
            leaseOwner: normalizedOwner,
            leaseExpiresAt,
            updatedAt: normalizedNow,
          }));
      return {outcome: "claimed", attemptCount};
    });
  }

  async function markDispatchSucceeded({
    executionId,
    scanRunId,
    ownerId,
    attemptCount,
    receipt,
    dispatchedAt,
  }) {
    const targetExecutionRef = executionRef(db, executionId);
    const targetRunRef = runRef(db, scanRunId);
    const normalizedReceipt = normalizeDispatchReceipt(receipt, {
      expectedExecutionId: executionId,
    });
    const normalizedAt = assertIsoTimestamp(dispatchedAt, "dispatchedAt");

    return db.runTransaction(async (transaction) => {
      const execution = assertExecutionStorageDocument(snapshotData(
          await transaction.get(targetExecutionRef), "execution"));
      const {run, channels, refs} = await readRunAndChannels(
          transaction, targetRunRef, scanRunId);
      assertRunScope(run, execution.command);

      if (execution.status === "dispatched") {
        if (execution.externalExecutionId !==
              normalizedReceipt.externalExecutionId ||
            execution.providerCode !== normalizedReceipt.providerCode ||
            execution.handoffId !== normalizedReceipt.handoffId) {
          fail("conflict", "dispatch receipt conflicts with stored receipt");
        }
        return {outcome: "idempotent_success"};
      }
      assertLeaseMatch(execution, {ownerId, attemptCount});
      if (run.status !== "queued" ||
          channels.some((channel) => channel.status !== "queued")) {
        fail("conflict", "run bundle is not ready for acquisition");
      }

      transaction.update(targetExecutionRef, updateExecutionDocument(
          execution, {
            status: "dispatched",
            leaseOwner: null,
            leaseExpiresAt: null,
            providerCode: normalizedReceipt.providerCode,
            externalExecutionId: normalizedReceipt.externalExecutionId,
            handoffId: normalizedReceipt.handoffId,
            dispatchedAt: normalizedAt,
            updatedAt: normalizedAt,
          }));
      transaction.update(
          targetRunRef,
          updateRunDocument(run, "acquiring", normalizedAt));
      channels.forEach((channel, index) => {
        transaction.update(refs[index], updateChannelDocument(
            channel, "acquiring", normalizedAt, {
              attemptCount,
              startedAt: normalizedAt,
            }));
      });
      return {outcome: "dispatched"};
    });
  }

  async function markDispatchFailed({
    executionId,
    scanRunId,
    ownerId,
    attemptCount,
    failure,
    retryable,
    failedAt,
  }) {
    assertPlainObject(failure, "failure");
    const targetExecutionRef = executionRef(db, executionId);
    const targetRunRef = runRef(db, scanRunId);
    const normalizedAt = assertIsoTimestamp(failedAt, "failedAt");
    const nextExecutionStatus = retryable ?
      "retryableFailure" : "terminalFailure";
    const nextRunStatus = retryable ?
      "failedRetryable" : "failedTerminal";
    const nextChannelStatus = retryable ?
      "failedRetryable" : "failedTerminal";

    return db.runTransaction(async (transaction) => {
      const execution = assertExecutionStorageDocument(snapshotData(
          await transaction.get(targetExecutionRef), "execution"));
      const {run, channels, refs} = await readRunAndChannels(
          transaction, targetRunRef, scanRunId);
      assertRunScope(run, execution.command);

      if (execution.status === nextExecutionStatus) {
        return {outcome: "idempotent_success"};
      }
      assertLeaseMatch(execution, {ownerId, attemptCount});
      if (run.status !== "queued" ||
          channels.some((channel) => channel.status !== "queued")) {
        fail("conflict", "run bundle is not ready for dispatch failure");
      }

      transaction.update(targetExecutionRef, updateExecutionDocument(
          execution, {
            status: nextExecutionStatus,
            leaseOwner: null,
            leaseExpiresAt: null,
            lastFailureCode: String(failure.code || "dispatch_failed")
                .slice(0, 100),
            lastFailureMessage: String(
                failure.message || "Dispatch failed.").slice(0, 500),
            updatedAt: normalizedAt,
          }));
      transaction.update(
          targetRunRef,
          updateRunDocument(run, nextRunStatus, normalizedAt));
      channels.forEach((channel, index) => {
        transaction.update(refs[index], updateChannelDocument(
            channel, nextChannelStatus, normalizedAt, {
              completedAt: retryable ? null : normalizedAt,
            }));
      });
      return {
        outcome: retryable ?
          "retryable_failure" : "terminal_failure",
      };
    });
  }

  async function getExecution({executionId, scanRunId}) {
    const snapshot = await executionRef(db, executionId).get();
    const execution = assertExecutionStorageDocument(
        snapshotData(snapshot, "execution"));
    if (execution.scanRunId !==
        assertDocumentId(scanRunId, "scanRunId")) {
      fail("not-found", "execution was not found");
    }
    return execution;
  }

  async function markExecutionCompleted({
    executionId,
    scanRunId,
    completedAt,
  }) {
    const targetRef = executionRef(db, executionId);
    const normalizedAt = assertIsoTimestamp(completedAt, "completedAt");
    return db.runTransaction(async (transaction) => {
      const execution = assertExecutionStorageDocument(snapshotData(
          await transaction.get(targetRef), "execution"));
      if (execution.scanRunId !== scanRunId) {
        fail("not-found", "execution was not found");
      }
      if (execution.status === "completed") {
        return {outcome: "idempotent_success"};
      }
      if (execution.status !== "dispatched") {
        fail("failed-precondition", "execution is not dispatched");
      }
      transaction.update(targetRef, updateExecutionDocument(
          execution, {
            status: "completed",
            completedAt: normalizedAt,
            updatedAt: normalizedAt,
          }));
      return {outcome: "completed"};
    });
  }

  return Object.freeze({
    claimDispatch,
    getExecution,
    markDispatchFailed,
    markDispatchSucceeded,
    markExecutionCompleted,
    prepareExecution,
    queueExecution,
  });
}

module.exports = Object.freeze({
  PUBLIC_LITE_EXECUTION_COLLECTIONS,
  PUBLIC_LITE_EXECUTION_STORAGE_ALGORITHM_V1,
  PUBLIC_LITE_EXECUTION_STORAGE_VERSION_V1,
  PublicLiteExecutionFirestoreError,
  assertExecutionStorageDocument,
  buildExecutionStorageDocument,
  canonicalize,
  createPublicLiteExecutionFirestorePort,
  executionStorageFingerprint,
  withExecutionStorageFingerprint,
});
