"use strict";

const {
  assertDocumentId,
  assertExactKeys,
  assertIsoTimestamp,
  assertPlainObject,
  assertSha256Hex,
} = require("./contracts");
const {
  assertCleanupPlanReplay,
  assertCleanupProgress,
  buildRunRecursiveCleanupPlan,
  cleanupStepCodes,
  deferredTopLevelCollections,
} = require("./retention_contract");
const {
  assertRunRetentionStorage,
} = require("./retention_firestore_adapter");

const CLEANUP_COLLECTIONS = Object.freeze({
  deleteFindings: "findings",
  deleteObservations: "observations",
  deleteChannels: "channels",
});
const RUNS_COLLECTION = "risk_scan_runs";

class RiskScanCleanupError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "RiskScanCleanupError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new RiskScanCleanupError(code, message);
}

function assertDb(db) {
  if (!db ||
      typeof db.collection !== "function" ||
      typeof db.batch !== "function" ||
      typeof db.runTransaction !== "function") {
    throw new TypeError("db must be a Firestore-compatible instance");
  }
  return db;
}

function assertCleanupRequest(input) {
  assertPlainObject(input, "cleanupRequest");
  assertExactKeys(
      input,
      [
        "scanRunId",
        "now",
        "minimumGraceSeconds",
        "batchSize",
        "expectedCleanupPlanDigestSha256",
      ],
      "cleanupRequest");

  const request = {
    scanRunId: assertDocumentId(input.scanRunId, "scanRunId"),
    now: assertIsoTimestamp(input.now, "now"),
  };
  if (input.minimumGraceSeconds !== undefined) {
    request.minimumGraceSeconds = input.minimumGraceSeconds;
  }
  if (input.batchSize !== undefined) {
    request.batchSize = input.batchSize;
  }
  if (input.expectedCleanupPlanDigestSha256 !== undefined) {
    request.expectedCleanupPlanDigestSha256 = assertSha256Hex(
        input.expectedCleanupPlanDigestSha256,
        "expectedCleanupPlanDigestSha256");
  }
  return Object.freeze(request);
}

function runRef(db, scanRunId) {
  return db.collection(RUNS_COLLECTION).doc(scanRunId);
}

function collectionForStep(rootRef, stepCode) {
  const collectionName = CLEANUP_COLLECTIONS[stepCode];
  if (!collectionName) {
    throw new TypeError(`cleanup step ${stepCode} is not a collection step`);
  }
  return rootRef.collection(collectionName);
}

function assertExpectedPlanDigest(plan, expectedDigest) {
  if (expectedDigest === undefined) return plan;
  if (plan.cleanupPlanDigestSha256 !== expectedDigest) {
    fail("conflict", "cleanup plan digest does not match expected digest");
  }
  return plan;
}

function buildProgressResult({
  plan,
  outcome,
  completedStepCodes,
  stepCode,
  deletedCount,
  remainingInStep,
}) {
  const progress = assertCleanupProgress(plan, completedStepCodes);
  return Object.freeze({
    outcome,
    scanRunId: plan.scanRunId,
    cleanupPlanDigestSha256: plan.cleanupPlanDigestSha256,
    completedStepCodes: progress.completedStepCodes,
    nextStepCode: progress.nextStepCode,
    complete: progress.complete,
    stepCode,
    deletedCount,
    remainingInStep,
    deferredTopLevelCollections: Object.freeze([
      ...deferredTopLevelCollections,
    ]),
  });
}

function buildMissingResult(request) {
  return Object.freeze({
    outcome: "idempotent_success",
    scanRunId: request.scanRunId,
    cleanupPlanDigestSha256:
      request.expectedCleanupPlanDigestSha256 ?? null,
    completedStepCodes: Object.freeze([...cleanupStepCodes]),
    nextStepCode: null,
    complete: true,
    stepCode: "deleteRunRoot",
    deletedCount: 0,
    remainingInStep: false,
    deferredTopLevelCollections: Object.freeze([
      ...deferredTopLevelCollections,
    ]),
  });
}

async function loadCleanupPlan(rootReference, request) {
  const snapshot = await rootReference.get();
  if (!snapshot.exists) {
    return {snapshot: null, plan: null};
  }
  const run = assertRunRetentionStorage(snapshot.data());
  if (run.scanRunId !== request.scanRunId) {
    fail("conflict", "stored run identity does not match its path");
  }
  const plan = buildRunRecursiveCleanupPlan({
    run,
    now: request.now,
    minimumGraceSeconds: request.minimumGraceSeconds,
    batchSize: request.batchSize,
  });
  assertExpectedPlanDigest(
      plan, request.expectedCleanupPlanDigestSha256);
  return {snapshot, plan};
}

async function deleteQuerySnapshot(db, snapshot) {
  if (snapshot.empty) return 0;
  const batch = db.batch();
  for (const document of snapshot.docs) {
    batch.delete(document.ref);
  }
  await batch.commit();
  return snapshot.size;
}

async function collectionHasDocuments(collectionReference) {
  const snapshot = await collectionReference.limit(1).get();
  return !snapshot.empty;
}

async function deleteRootTransaction(
    db,
    rootReference,
    request,
    expectedPlan,
) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(rootReference);
    if (!snapshot.exists) {
      return buildMissingResult({
        ...request,
        expectedCleanupPlanDigestSha256:
          expectedPlan.cleanupPlanDigestSha256,
      });
    }

    const run = assertRunRetentionStorage(snapshot.data());
    if (run.scanRunId !== request.scanRunId) {
      fail("conflict", "stored run identity does not match its path");
    }

    const currentPlan = buildRunRecursiveCleanupPlan({
      run,
      now: request.now,
      minimumGraceSeconds: request.minimumGraceSeconds,
      batchSize: request.batchSize,
    });
    assertCleanupPlanReplay(expectedPlan, currentPlan);
    assertExpectedPlanDigest(
        currentPlan, request.expectedCleanupPlanDigestSha256);

    transaction.delete(rootReference);
    return buildProgressResult({
      plan: currentPlan,
      outcome: "deleted",
      completedStepCodes: Object.freeze([...cleanupStepCodes]),
      stepCode: "deleteRunRoot",
      deletedCount: 1,
      remainingInStep: false,
    });
  });
}

async function executeRunRecursiveCleanupStep(db, input) {
  assertDb(db);
  const request = assertCleanupRequest(input);
  const rootReference = runRef(db, request.scanRunId);
  const loaded = await loadCleanupPlan(rootReference, request);
  if (!loaded.plan) {
    return buildMissingResult(request);
  }

  const plan = loaded.plan;
  const completedStepCodes = [];

  for (const stepCode of cleanupStepCodes.slice(0, -1)) {
    const collectionReference =
      collectionForStep(rootReference, stepCode);
    const snapshot = await collectionReference
        .limit(plan.batchSize)
        .get();

    if (snapshot.empty) {
      completedStepCodes.push(stepCode);
      continue;
    }

    const deletedCount = await deleteQuerySnapshot(db, snapshot);
    const remainingInStep =
      await collectionHasDocuments(collectionReference);
    if (!remainingInStep) {
      completedStepCodes.push(stepCode);
    }

    return buildProgressResult({
      plan,
      outcome: remainingInStep ? "batch_deleted" : "step_completed",
      completedStepCodes,
      stepCode,
      deletedCount,
      remainingInStep,
    });
  }

  for (const stepCode of cleanupStepCodes.slice(0, -1)) {
    if (await collectionHasDocuments(
        collectionForStep(rootReference, stepCode))) {
      return buildProgressResult({
        plan,
        outcome: "retry_required",
        completedStepCodes: cleanupStepCodes.slice(
            0, cleanupStepCodes.indexOf(stepCode)),
        stepCode,
        deletedCount: 0,
        remainingInStep: true,
      });
    }
  }

  return deleteRootTransaction(
      db, rootReference, request, plan);
}

module.exports = {
  CLEANUP_COLLECTIONS,
  RUNS_COLLECTION,
  RiskScanCleanupError,
  assertCleanupRequest,
  assertDb,
  assertExpectedPlanDigest,
  buildMissingResult,
  buildProgressResult,
  collectionForStep,
  collectionHasDocuments,
  deleteQuerySnapshot,
  executeRunRecursiveCleanupStep,
  loadCleanupPlan,
};
