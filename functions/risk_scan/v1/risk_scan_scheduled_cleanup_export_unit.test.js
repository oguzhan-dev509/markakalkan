"use strict";

const assert = require("node:assert/strict");
const {spawnSync} = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  REGION,
  SCHEDULE,
  SCHEDULED_CLEANUP_FUNCTION_NAME,
  TIME_ZONE,
  scheduledCleanupOptions,
} = require("./scheduled_cleanup");

const FUNCTIONS_ROOT = path.resolve(__dirname, "../..");
const INDEX_PATH = path.join(FUNCTIONS_ROOT, "index.js");
const INDEX_SOURCE = fs.readFileSync(INDEX_PATH, "utf8");
function occurrenceCount(text, needle) {
  return text.split(needle).length - 1;
}
let runtimeProbe;
function loadRuntimeProbe() {
  if (runtimeProbe) return runtimeProbe;
  const script = [
    "\"use strict\";",
    "const functions = require(\"./index.js\");",
    `const name = ${JSON.stringify(SCHEDULED_CLEANUP_FUNCTION_NAME)};`,
    "const result = {[name]: typeof functions[name]};",
    "process.stdout.write(\"HRT_SCHEDULE_PROBE=\" + JSON.stringify(result));",
  ].join("\n");
  const child = spawnSync(
      process.execPath,
      ["-e", script],
      {
        cwd: FUNCTIONS_ROOT,
        encoding: "utf8",
        env: {
          ...process.env,
          GCLOUD_PROJECT: "demo-markakalkan-hrt-1d-1k",
          GOOGLE_CLOUD_PROJECT: "demo-markakalkan-hrt-1d-1k",
        },
        timeout: 30000,
      },
  );
  assert.equal(
      child.status,
      0,
      `index load failed\nstdout:\n${child.stdout}\nstderr:\n${child.stderr}`,
  );
  const marker = "HRT_SCHEDULE_PROBE=";
  const markerIndex = child.stdout.lastIndexOf(marker);
  assert.notEqual(markerIndex, -1, "runtime schedule probe marker missing");
  runtimeProbe = JSON.parse(child.stdout.slice(markerIndex + marker.length));
  return runtimeProbe;
}

test("scheduled cleanup export name is stable", () => {
  assert.equal(
      SCHEDULED_CLEANUP_FUNCTION_NAME,
      "cleanupExpiredRiskScanRuns");
});
test("scheduled cleanup options bind schedule and timezone", () => {
  const options = scheduledCleanupOptions();
  assert.equal(options.schedule, SCHEDULE);
  assert.equal(options.timeZone, TIME_ZONE);
});
test("scheduled cleanup options bind europe-west3", () => {
  assert.equal(scheduledCleanupOptions().region, REGION);
});
test("scheduled cleanup options prevent concurrent execution", () => {
  const options = scheduledCleanupOptions();
  assert.equal(options.maxInstances, 1);
  assert.equal(options.concurrency, 1);
});
test("scheduled cleanup options have bounded resources", () => {
  const options = scheduledCleanupOptions();
  assert.equal(options.timeoutSeconds, 540);
  assert.equal(options.memory, "256MiB");
});
test("index requires the scheduled cleanup module exactly once", () => {
  assert.equal(
      occurrenceCount(
          INDEX_SOURCE,
          "require(\"./risk_scan/v1/scheduled_cleanup\")"),
      1,
  );
});
test("index imports the scheduled cleanup builder exactly once", () => {
  assert.equal(
      occurrenceCount(INDEX_SOURCE, "buildCleanupExpiredRiskScanRuns"),
      2,
  );
});
test("index exports the scheduled cleanup function exactly once", () => {
  assert.equal(
      occurrenceCount(
          INDEX_SOURCE,
          "exports.cleanupExpiredRiskScanRuns ="),
      1,
  );
});
test("functions index loads successfully with scheduled cleanup", () => {
  const probe = loadRuntimeProbe();
  assert.deepEqual(Object.keys(probe), [SCHEDULED_CLEANUP_FUNCTION_NAME]);
});
test("runtime index exports the scheduled cleanup function", () => {
  assert.deepEqual(loadRuntimeProbe(), {
    cleanupExpiredRiskScanRuns: "function",
  });
});
