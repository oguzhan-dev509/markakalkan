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
const scheduled = require("./scheduled_cleanup");

const PROJECT_ID = "demo-markakalkan-hrt-1d-1k";
const now = new Date("2026-07-30T05:00:00.000Z");
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
function rootRef(scanRunId) {
  return db.collection("risk_scan_runs").doc(scanRunId);
}
function runDocument(scanRunId, overrides = {}) {
  const expiresAt = overrides.expiresAt ||
    "2026-07-30T04:00:00.000Z";
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
async function seedRun(scanRunId, {
  run = runDocument(scanRunId),
  findings = [],
  observations = [],
  channels = [],
} = {}) {
  const root = rootRef(scanRunId);
  await root.set(run);
  const writes = [];
  for (const id of findings) {
    writes.push(root.collection("findings").doc(id).set({id}));
  }
  for (const id of observations) {
    writes.push(root.collection("observations").doc(id).set({id}));
  }
  for (const id of channels) {
    writes.push(root.collection("channels").doc(id).set({id}));
  }
  await Promise.all(writes);
}
function fakeLogger() {
  return {
    infos: [],
    errors: [],
    info(message, data) {
      this.infos.push({message, data});
    },
    warn() {},
    error(message, data) {
      this.errors.push({message, data});
    },
  };
}
function handler(overrides = {}) {
  return scheduled.createScheduledCleanupHandler({
    db,
    logger: fakeLogger(),
    clock: {now: () => now},
    ...overrides,
  });
}
async function rootCount() {
  return (await db.collection("risk_scan_runs").get()).size;
}
async function childCount(scanRunId, collectionName) {
  return (await rootRef(scanRunId).collection(collectionName).get()).size;
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "hrt-1d-1k");
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

test("scheduled cleanup emulator guard is isolated", () => {
  assert.equal(PROJECT_ID.startsWith("demo-"), true);
  assert.match(
      process.env.FIRESTORE_EMULATOR_HOST,
      /^(127\.0\.0\.1|localhost):\d+$/);
});
test("scheduled cleanup deletes one bounded findings batch", async () => {
  await seedRun("run-batch", {
    findings: ["f1", "f2", "f3"],
    observations: ["o1"],
    channels: ["c1"],
  });
  const result = await handler({batchSize: 2})();
  assert.equal(result.scannedCount, 1);
  assert.equal(result.attemptedCount, 1);
  assert.equal(result.progressedCount, 1);
  assert.equal(result.deletedDocumentCount, 2);
  assert.equal(await childCount("run-batch", "findings"), 1);
  assert.equal(await childCount("run-batch", "observations"), 1);
  assert.equal(await childCount("run-batch", "channels"), 1);
});
test("scheduled cleanup excludes a future terminal run", async () => {
  const expiresAt = "2026-07-30T06:00:00.000Z";
  await seedRun("run-future", {
    run: runDocument("run-future", {expiresAt}),
  });
  const result = await handler()();
  assert.equal(result.scannedCount, 0);
  assert.equal(result.attemptedCount, 0);
  assert.equal((await rootRef("run-future").get()).exists, true);
});
test("scheduled cleanup skips an expired non-terminal run", async () => {
  await seedRun("run-queued", {
    run: runDocument("run-queued", {status: "queued"}),
  });
  const result = await handler()();
  assert.equal(result.scannedCount, 1);
  assert.equal(result.skippedNonTerminalCount, 1);
  assert.equal(result.attemptedCount, 0);
  assert.equal((await rootRef("run-queued").get()).exists, true);
});
test("scheduled cleanup applies grace in the query cutoff", async () => {
  const expiresAt = "2026-07-30T04:59:30.000Z";
  await seedRun("run-grace", {
    run: runDocument("run-grace", {expiresAt}),
  });
  const result = await handler({minimumGraceSeconds: 60})();
  assert.equal(result.cutoffAt, "2026-07-30T04:59:00.000Z");
  assert.equal(result.scannedCount, 0);
  assert.equal((await rootRef("run-grace").get()).exists, true);
});
test("scheduled cleanup scan limit bounds Firestore reads", async () => {
  await Promise.all([
    seedRun("run-scan-1"),
    seedRun("run-scan-2"),
    seedRun("run-scan-3"),
  ]);
  const result = await handler({scanLimit: 2, processLimit: 3})();
  assert.equal(result.scannedCount, 2);
  assert.equal(result.attemptedCount, 2);
  assert.equal(await rootCount(), 1);
});
test("scheduled cleanup process limit bounds run attempts", async () => {
  await Promise.all([
    seedRun("run-process-1"),
    seedRun("run-process-2"),
    seedRun("run-process-3"),
  ]);
  const result = await handler({scanLimit: 3, processLimit: 2})();
  assert.equal(result.terminalCandidateCount, 3);
  assert.equal(result.attemptedCount, 2);
  assert.equal(result.skippedProcessLimitCount, 1);
  assert.equal(await rootCount(), 1);
});
test("scheduled root cleanup preserves reports and claims", async () => {
  const scanRunId = "run-deferred";
  await seedRun(scanRunId);
  await db.collection("risk_scan_reports").doc("report-1").set({scanRunId});
  await db.collection("risk_scan_claims").doc("claim-1").set({scanRunId});
  const result = await handler()();
  assert.equal(result.completedCount, 1);
  assert.equal((await rootRef(scanRunId).get()).exists, false);
  assert.equal(
      (await db.collection("risk_scan_reports")
          .doc("report-1").get()).exists,
      true);
  assert.equal(
      (await db.collection("risk_scan_claims")
          .doc("claim-1").get()).exists,
      true);
});
