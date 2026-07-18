"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {createHash} = require("../build/crypto_shim");
const {runRuntimeExpressionInIsolatedContext} =
  require("./helpers/isolated_n8n_vm");

const ROOT = path.resolve(__dirname, "..");
const BUNDLE_PATH = path.join(ROOT, "generated", "n8n_contract_runtime.js");
const MANIFEST_PATH = path.join(ROOT, "generated", "n8n_contract_runtime.manifest.json");
const bundle = () => fs.readFileSync(BUNDLE_PATH, "utf8");
const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");

function runtime() {
  return {
    runFixtureScenario: (name) => runRuntimeExpressionInIsolatedContext(bundle(),
        `MarkaKalkanDdtRuntime.runFixtureScenario(${JSON.stringify(name)})`),
    runContractPipeline: (input) => runRuntimeExpressionInIsolatedContext(bundle(),
        `MarkaKalkanDdtRuntime.runContractPipeline(${JSON.stringify(input)})`),
  };
}

function fixtureInput(name) {
  const directory = path.join(ROOT, "fixtures", name);
  const read = (file) => JSON.parse(fs.readFileSync(path.join(directory, file), "utf8"));
  return {acquisitionResult:read("acquisition_result.json"),
    candidates:read("candidate_sources.json"),
    evidences:read("structured_evidence.json"),
    scannerResult:read("scanner_result.json"), productionCallback:false};
}

test("runtime bundle exists", () => assert.equal(fs.existsSync(BUNDLE_PATH), true));
test("runtime bundle parses and executes", () => assert.ok(runtime()));
test("runtime global API is an object", () => assert.equal(typeof runtime(), "object"));
test("runContractPipeline is public", () => assert.equal(typeof runtime().runContractPipeline, "function"));
test("runFixtureScenario is public", () => assert.equal(typeof runtime().runFixtureScenario, "function"));
test("no_signal is READY with zero findings", () => {
  const value = runtime().runFixtureScenario("no_signal");
  assert.equal(value.valid, true); assert.equal(value.scannerInvocation.reason, "READY");
  assert.equal(value.findingCount, 0);
});
test("synthetic_signal is READY with one finding", () => {
  const value = runtime().runFixtureScenario("synthetic_signal");
  assert.equal(value.valid, true); assert.equal(value.scannerInvocation.reason, "READY");
  assert.equal(value.findingCount, 1);
});
test("blocked has no acquired evidence and zero findings", () => {
  const value = runtime().runFixtureScenario("blocked");
  assert.equal(value.valid, true);
  assert.equal(value.scannerInvocation.reason, "NO_ACQUIRED_EVIDENCE");
  assert.equal(value.findingCount, 0);
});
test("unknown fixture is rejected with exact code", () => assert.deepEqual(
    JSON.parse(JSON.stringify(runtime().runFixtureScenario("unknown"))),
    {valid:false, errorCode:"FIXTURE_SCENARIO_UNSUPPORTED"}));
test("pipeline does not mutate input", () => {
  const input = fixtureInput("synthetic_signal");
  const before = JSON.stringify(input); runtime().runContractPipeline(input);
  assert.equal(JSON.stringify(input), before);
});
test("malformed input fails closed without exception detail", () => {
  const value = runtime().runContractPipeline(null);
  assert.equal(value.valid, false); assert.equal(value.errorCode, "PIPELINE_INPUT_INVALID");
  assert.equal("stack" in value, false); assert.equal("message" in value, false);
});
test("production fixture callback is hard blocked", () => {
  const input = fixtureInput("synthetic_signal"); input.productionCallback = true;
  const value = runtime().runContractPipeline(input);
  assert.equal(value.valid, false);
  assert.equal(value.scannerInvocation.reason, "TEST_FIXTURE_PRODUCTION_CALLBACK");
  assert.equal(value.findingCount, 0);
});
test("bundle contains no require call", () => assert.doesNotMatch(bundle(), /require\s*\(/));
test("bundle contains no import declaration", () => assert.doesNotMatch(bundle(), /(^|\n)\s*import\s/m));
test("bundle contains no module.exports", () => assert.doesNotMatch(bundle(), /module\.exports/));
test("bundle contains no filesystem runtime dependency", () => assert.doesNotMatch(bundle(), /node:fs|require\s*\(["'](?:fs|path)["']/));
test("bundle contains no environment or network primitive", () => assert.doesNotMatch(bundle(), /process\.env|\bfetch\s*\(|axios|https?\.request|child_process/));
test("bundle contains no dynamic evaluator", () => assert.doesNotMatch(bundle(), /\beval\s*\(|new\s+Function/));
test("crypto shim SHA-256 equals Node crypto byte-for-byte", () => {
  const input = "Türkçe TEST_FIXTURE\n😀";
  assert.equal(createHash("sha256").update(input, "utf8").digest("hex"), sha256(input));
});
test("manifest bundle hash and byte count match artifact", () => {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
  const bytes = fs.readFileSync(BUNDLE_PATH);
  assert.equal(manifest.bundleSha256, sha256(bytes));
  assert.equal(manifest.bundleBytes, bytes.length);
});
test("manifest source hashes match every schema validator and fixture", () => {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
  for (const group of [manifest.schemaHashes, manifest.validatorHashes,
    manifest.fixtureHashes, manifest.runtimeSourceHashes,
    manifest.buildSourceHashes, manifest.testProvenanceHashes]) {
    for (const [relative, expected] of Object.entries(group)) {
      assert.equal(sha256(fs.readFileSync(path.join(ROOT, relative))), expected);
    }
  }
  assert.equal(Object.keys(manifest.schemaHashes).length, 4);
  assert.equal(Object.keys(manifest.validatorHashes).length, 11);
  assert.equal(Object.keys(manifest.fixtureHashes).length, 15);
  assert.deepEqual(Object.keys(manifest.runtimeSourceHashes),
      ["runtime/n8n_contract_runtime_entry.js", "runtime/portable_primitives.js"]);
  assert.deepEqual(Object.keys(manifest.buildSourceHashes),
      ["build/crypto_shim.js", "build/generate_n8n_runtime.js"]);
  assert.deepEqual(Object.keys(manifest.testProvenanceHashes),
      ["tests/helpers/isolated_n8n_vm.js"]);
});
test("manifest declares deterministic offline runtime", () => {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
  assert.deepEqual(manifest.externalRuntimeDependencies, []);
  assert.equal(manifest.generatedAtPolicy, "deterministic-no-wall-clock");
  assert.equal(manifest.containsCredentials, false);
  assert.equal(manifest.containsNetworkCalls, false);
  assert.equal(manifest.sourceContractCommit,
      "6362b6e0558d25e04da7cf5b366464f0538827fe");
  assert.equal(Object.prototype.hasOwnProperty.call(manifest, "sourceCommit"), false);
});
test("four schema identifiers are unique", () => {
  const ids = fs.readdirSync(path.join(ROOT, "schemas"))
      .filter((name) => name.endsWith(".json"))
      .map((name) => JSON.parse(fs.readFileSync(path.join(ROOT, "schemas", name), "utf8")).$id);
  assert.equal(ids.length, 4); assert.equal(new Set(ids).size, 4);
});
