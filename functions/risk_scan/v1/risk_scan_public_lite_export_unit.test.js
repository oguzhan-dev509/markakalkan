"use strict";

const assert = require("node:assert/strict");
const {spawnSync} = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  HRT_PUBLIC_LITE_SECRET_KEY,
  PUBLIC_LITE_FUNCTION_NAMES,
  callableOptions,
} = require("./public_lite_callable");

const FUNCTIONS_ROOT = path.resolve(__dirname, "../..");
const INDEX_PATH = path.join(FUNCTIONS_ROOT, "index.js");
const INDEX_SOURCE = fs.readFileSync(INDEX_PATH, "utf8");
const EXPECTED_EXPORTS = Object.freeze([
  "startPublicLiteRiskScan",
  "getPublicLiteRiskScanStatus",
  "getPublicLiteRiskScanReport",
]);

function occurrenceCount(text, needle) {
  return text.split(needle).length - 1;
}

let runtimeProbe;

function loadRuntimeProbe() {
  if (runtimeProbe) return runtimeProbe;
  const script = [
    "\"use strict\";",
    "const functions = require(\"./index.js\");",
    `const names = ${JSON.stringify(EXPECTED_EXPORTS)};`,
    "const result = Object.fromEntries(",
    "    names.map((name) => [name, typeof functions[name]]));",
    "process.stdout.write(\"HRT_EXPORT_PROBE=\" + JSON.stringify(result));",
  ].join("\n");
  const child = spawnSync(
      process.execPath,
      ["-e", script],
      {
        cwd: FUNCTIONS_ROOT,
        encoding: "utf8",
        env: {
          ...process.env,
          GCLOUD_PROJECT: "demo-markakalkan-hrt-1d-1e",
          GOOGLE_CLOUD_PROJECT: "demo-markakalkan-hrt-1d-1e",
        },
        timeout: 30000,
      },
  );
  assert.equal(
      child.status,
      0,
      `index load failed\nstdout:\n${child.stdout}\nstderr:\n${child.stderr}`,
  );
  const marker = "HRT_EXPORT_PROBE=";
  const markerIndex = child.stdout.lastIndexOf(marker);
  assert.notEqual(markerIndex, -1, "runtime export probe marker missing");
  runtimeProbe = JSON.parse(child.stdout.slice(markerIndex + marker.length));
  return runtimeProbe;
}

test("public callable function names are stable", () => {
  assert.deepEqual(
      Object.values(PUBLIC_LITE_FUNCTION_NAMES),
      EXPECTED_EXPORTS,
  );
});

test("start callable options bind the HRT secret", () => {
  const options = callableOptions("start");
  assert.equal(options.enforceAppCheck, true);
  assert.equal(options.maxInstances, 1);
  assert.deepEqual(options.secrets, [HRT_PUBLIC_LITE_SECRET_KEY]);
});

test("status callable options enforce App Check without a secret", () => {
  const options = callableOptions("status");
  assert.equal(options.enforceAppCheck, true);
  assert.equal(options.maxInstances, 3);
  assert.equal(Object.hasOwn(options, "secrets"), false);
});

test("report callable options enforce App Check without a secret", () => {
  const options = callableOptions("report");
  assert.equal(options.enforceAppCheck, true);
  assert.equal(options.maxInstances, 3);
  assert.equal(Object.hasOwn(options, "secrets"), false);
});

test("index requires the Public Lite callable module exactly once", () => {
  assert.equal(
      occurrenceCount(
          INDEX_SOURCE,
          "require(\"./risk_scan/v1/public_lite_callable\")",
      ),
      1,
  );
});

test("index imports each Public Lite builder exactly once", () => {
  for (const builder of [
    "buildStartPublicLiteRiskScan",
    "buildGetPublicLiteRiskScanStatus",
    "buildGetPublicLiteRiskScanReport",
  ]) {
    assert.equal(occurrenceCount(INDEX_SOURCE, builder), 2);
  }
});

test("index exports each Public Lite callable exactly once", () => {
  for (const name of EXPECTED_EXPORTS) {
    assert.equal(
        occurrenceCount(INDEX_SOURCE, `exports.${name} =`),
        1,
    );
  }
});

test("index never reads the HRT secret value directly", () => {
  assert.equal(
      INDEX_SOURCE.includes("HRT_PUBLIC_LITE_SECRET_KEY.value"),
      false,
  );
  assert.equal(
      INDEX_SOURCE.includes("process.env.HRT_PUBLIC_LITE_SECRET_KEY"),
      false,
  );
});

test("functions index loads successfully in an isolated process", () => {
  const probe = loadRuntimeProbe();
  assert.deepEqual(Object.keys(probe), EXPECTED_EXPORTS);
});

test("runtime index exports all three Public Lite callables", () => {
  const probe = loadRuntimeProbe();
  assert.deepEqual(probe, {
    startPublicLiteRiskScan: "function",
    getPublicLiteRiskScanStatus: "function",
    getPublicLiteRiskScanReport: "function",
  });
});
