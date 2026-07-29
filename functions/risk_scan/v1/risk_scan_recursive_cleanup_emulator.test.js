"use strict";

const assert = require("node:assert/strict");
const {after, before, beforeEach, test} = require("node:test");
const {
  deleteApp,
  getApps,
  initializeApp,
} = require("firebase-admin/app");
const {
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");
const port = require("./recursive_cleanup_firestore_port");

const PROJECT_ID = "demo-markakalkan-hrt-1d-1j";
const scanRunId = "recursive-cleanup-run";
const expiresAt = "2026-07-29T15:00:00.000Z";
const now = "2026-07-29T16:00:00.000Z";
let app;
let db;

function assertEmulatorGuard() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "";
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
    throw new Error("Firestore emulator loopback host is required");
  }
  if (!PROJECT_ID.startsWith("demo-")) {
    throw new Error("Only a demo project is allowed");
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error("Production credentials are forbidden");
  }
  return host;
}

async function clearEmulator() {
  const host = assertEmulatorGuard();
  const url = `http://${host}/emulator/v1/projects/${PROJECT_ID}` +
    "/databases/(default)/documents";
  const response = await fetch(url, {method: "DELETE"});
  if (!response.ok) {
    throw new Error(`emulator cleanup failed: ${response.status}`);
  }
}

function rootRef(id = scanRunId) {
  return db.collection("risk_scan_runs").doc(id);
}

function runDocument(overrides = {}) {
  return {
    scanRunId,
    status: "completed",
    expiresAt,
    expiresAtTimestamp: Timestamp.fromDate(new Date(expiresAt)),
    retentionContractVersion: "risk-scan-retention-v1",
    nativeTtlEligible: false,
    cleanupStrategy: "recursiveServerSide",
    ...overrides,
  };
}

async function seed({
  run = runDocument(),
  findings = [],
  observations = [],
  channels = [],
} = {}) {
  await rootRef().set(run);
  const writes = [];
  for (const id of findings) {
    writes.push(rootRef().collection("findings").doc(id).set({id}));
  }
  for (const id of observations) {
    writes.push(rootRef().collection("observations").doc(id).set({id}));
  }
  for (const id of channels) {
    writes.push(rootRef().collection("channels").doc(id).set({id}));
  }
  await Promise.all(writes);
}

function request(overrides = {}) {
  return {
    scanRunId,
    now,
    batchSize: 2,
    ...overrides,
  };
}

async function count(collectionName) {
  const snapshot = await rootRef().collection(collectionName).get();
  return snapshot.size;
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "hrt-1d-1j");
  db = getFirestore(app);
});

beforeEach(async () => {
  await clearEmulator();
});

after(async () => {
  await clearEmulator();
  if (app && getApps().includes(app)) {
    await deleteApp(app);
  }
});

test("recursive cleanup emulator guard is isolated", () => {
  assert.equal(PROJECT_ID.startsWith("demo-"), true);
  assert.match(
      process.env.FIRESTORE_EMULATOR_HOST,
      /^(127\.0\.0\.1|localhost):\d+$/);
});

test("cleanup rejects a non-terminal run", async () => {
  await seed({run: runDocument({status: "created"})});
  await assert.rejects(
      port.executeRunRecursiveCleanupStep(db, request()),
      (error) => error.code === "failed-precondition");
  assert.equal((await rootRef().get()).exists, true);
});

test("cleanup rejects a run before expiry", async () => {
  const future = "2026-07-30T15:00:00.000Z";
  await seed({
    run: runDocument({
      expiresAt: future,
      expiresAtTimestamp:
        Timestamp.fromDate(new Date(future)),
    }),
  });
  await assert.rejects(
      port.executeRunRecursiveCleanupStep(db, request()),
      (error) => error.code === "failed-precondition");
});

test("findings are deleted in bounded batches first", async () => {
  await seed({
    findings: ["f1", "f2", "f3"],
    observations: ["o1"],
    channels: ["c1"],
  });
  const result = await port.executeRunRecursiveCleanupStep(
      db, request());
  assert.equal(result.stepCode, "deleteFindings");
  assert.equal(result.deletedCount, 2);
  assert.equal(result.remainingInStep, true);
  assert.equal(await count("findings"), 1);
  assert.equal(await count("observations"), 1);
  assert.equal(await count("channels"), 1);
});

test("cleanup advances findings then observations then channels", async () => {
  await seed({
    findings: ["f1"],
    observations: ["o1"],
    channels: ["c1"],
  });
  const steps = [];
  while (steps.length < 3) {
    const result = await port.executeRunRecursiveCleanupStep(
        db, request());
    steps.push(result.stepCode);
  }
  assert.deepEqual(steps, [
    "deleteFindings",
    "deleteObservations",
    "deleteChannels",
  ]);
  assert.equal(await count("findings"), 0);
  assert.equal(await count("observations"), 0);
  assert.equal(await count("channels"), 0);
  assert.equal((await rootRef().get()).exists, true);
});

test("root deletion preserves deferred reports and claims", async () => {
  await seed();
  await db.collection("risk_scan_reports").doc("report-1").set({
    scanRunId,
  });
  await db.collection("risk_scan_claims").doc("claim-1").set({
    scanRunId,
  });
  const result = await port.executeRunRecursiveCleanupStep(
      db, request());
  assert.equal(result.stepCode, "deleteRunRoot");
  assert.equal(result.complete, true);
  assert.equal((await rootRef().get()).exists, false);
  assert.equal(
      (await db.collection("risk_scan_reports")
          .doc("report-1").get()).exists,
      true);
  assert.equal(
      (await db.collection("risk_scan_claims")
          .doc("claim-1").get()).exists,
      true);
});

test("repeated cleanup after deletion is idempotent", async () => {
  await seed();
  const first = await port.executeRunRecursiveCleanupStep(
      db, request());
  const second = await port.executeRunRecursiveCleanupStep(
      db, request({
        expectedCleanupPlanDigestSha256:
          first.cleanupPlanDigestSha256,
      }));
  assert.equal(first.outcome, "deleted");
  assert.equal(second.outcome, "idempotent_success");
  assert.equal(second.complete, true);
});

test("parallel cleanup converges without restoring data", async () => {
  await seed({
    findings: ["f1", "f2"],
    observations: ["o1"],
    channels: ["c1"],
  });
  for (let round = 0; round < 6; round += 1) {
    await Promise.all([
      port.executeRunRecursiveCleanupStep(db, request()),
      port.executeRunRecursiveCleanupStep(db, request()),
    ]);
    if (!(await rootRef().get()).exists) break;
  }
  assert.equal((await rootRef().get()).exists, false);
  assert.equal(await count("findings"), 0);
  assert.equal(await count("observations"), 0);
  assert.equal(await count("channels"), 0);
});
