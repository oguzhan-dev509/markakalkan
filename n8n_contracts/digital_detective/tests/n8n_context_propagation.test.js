"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const {isolatedGlobalTypes, runCodeNodeInIsolatedContext,
  runRuntimeExpressionInIsolatedContext} =
  require("./helpers/isolated_n8n_vm");

const ROOT = path.resolve(__dirname, "..");
const BUNDLE_PATH = path.join(ROOT, "generated", "n8n_contract_runtime.js");
const MANIFEST_PATH = path.join(ROOT, "generated",
    "n8n_contract_runtime.manifest.json");
const WORKFLOW_PATH = path.join(ROOT, "workflows",
    "MarkaKalkan Dijital Dedektif - Contract Fixture Harness - V1.json");
const GOLDEN_PATH = path.resolve(ROOT, "..", "..", "reports",
    "MarkaKalkan Dijital Dedektif 12 Ajan - ALTIN REFERANS - 2026-07-18 - 12-12.json");
const GOLDEN_SHA256 =
  "BE24FE2C91C7206197A2B4811F22475528A77EF011EF8A3ACE41D0E9182337A7";
const clone = (value) => JSON.parse(JSON.stringify(value));
const hash = (value) => crypto.createHash("sha256").update(value)
    .digest("hex");

function runtime() {
  const bundle = fs.readFileSync(BUNDLE_PATH, "utf8");
  return {
    runFixtureScenario: (name) => runRuntimeExpressionInIsolatedContext(
        bundle, `MarkaKalkanDdtRuntime.runFixtureScenario(${JSON.stringify(name)})`),
    runContractPipeline: (input) => runRuntimeExpressionInIsolatedContext(
        bundle, `MarkaKalkanDdtRuntime.runContractPipeline(${JSON.stringify(input)})`),
  };
}

function runPipeline(input) {
  const bundle = fs.readFileSync(BUNDLE_PATH, "utf8");
  return runRuntimeExpressionInIsolatedContext(bundle,
      `MarkaKalkanDdtRuntime.runContractPipeline(${JSON.stringify(input)})`);
}

function fixtureInput(name) {
  const directory = path.join(ROOT, "fixtures", name);
  const read = (file) => JSON.parse(fs.readFileSync(path.join(directory, file),
      "utf8"));
  return {
    acquisitionResult: read("acquisition_result.json"),
    candidates: read("candidate_sources.json"),
    evidences: read("structured_evidence.json"),
    scannerResult: read("scanner_result.json"),
    productionCallback: false,
  };
}

function assertNoContextRequired(result) {
  const validations = [result.acquisitionValidation,
    ...result.candidateValidations, result.evidenceBatchValidation,
    result.scannerValidation];
  for (const validation of validations) {
    assert.equal(validation.errors.some((entry) =>
      entry.code === "CONTEXT_REQUIRED"), false);
  }
}

function runWorkflowCode(node, inputItems) {
  return runCodeNodeInIsolatedContext(node.parameters.jsCode, inputItems);
}

function runWorkflowChain() {
  const workflow = JSON.parse(fs.readFileSync(WORKFLOW_PATH, "utf8"));
  const names = ["Fixture Senaryolarını Hazırla", "Contract Runtime Harness",
    "Sonuçları Özetle", "Production Guard — Hard False"];
  return names.reduce((items, name) => runWorkflowCode(
      workflow.nodes.find((node) => node.name === name), items), [{json: {}}]);
}

test("real CONTEXT_REQUIRED regression is absent for all generated fixtures", () => {
  for (const scenario of ["no_signal", "synthetic_signal", "blocked"]) {
    const result = runtime().runFixtureScenario(scenario);
    assertNoContextRequired(result);
  }
});
for (const name of ["process", "require", "module", "Buffer", "TextEncoder",
  "TextDecoder", "URL", "URLSearchParams", "fetch", "crypto", "items", "$json"]) {
  test(`isolated workflow context has no ${name} global`, () => {
    assert.equal(isolatedGlobalTypes()[name], "undefined");
  });
}
test("root taskId propagates from acquisition result", () => {
  const result = runPipeline(fixtureInput("no_signal"));
  assert.equal(result.acquisitionValidation.valid, true);
  assert.equal(result.candidateValidations[0].valid, true);
});
test("root executionId propagates from acquisition result", () => {
  const result = runPipeline(fixtureInput("no_signal"));
  assert.equal(result.evidenceBatchValidation.valid, true);
  assert.equal(result.scannerValidation.valid, true);
});
test("acquisition validator receives complete root context", () => {
  assert.equal(runPipeline(fixtureInput("no_signal"))
      .acquisitionValidation.valid, true);
});
test("candidate validator receives complete root context", () => {
  assert.equal(runPipeline(fixtureInput("no_signal"))
      .candidateValidations[0].valid, true);
});
test("evidence batch receives root context and candidates", () => {
  assert.equal(runPipeline(fixtureInput("synthetic_signal"))
      .evidenceBatchValidation.valid, true);
});
test("scanner receives root context candidates and evidences", () => {
  assert.equal(runPipeline(fixtureInput("synthetic_signal"))
      .scannerValidation.valid, true);
});
test("nested acquisition candidate validation uses root context", () => {
  const result = runPipeline(fixtureInput("no_signal"));
  assert.equal(result.acquisitionValidation.errors.some((entry) =>
    entry.path.startsWith("candidates[0].")), false);
});

for (const [scenario, reason, findings, allowed] of [
  ["no_signal", "READY", 0, true],
  ["synthetic_signal", "READY", 1, true],
  ["blocked", "NO_ACQUIRED_EVIDENCE", 0, false],
]) {
  test(`${scenario} completes the full validator chain`, () => {
    const result = runtime().runFixtureScenario(scenario);
    assert.equal(result.valid, true);
    assert.equal(result.acquisitionValidation.valid, true);
    assert.equal(result.candidateValidations[0].valid, true);
    assert.equal(result.evidenceBatchValidation.valid, true);
    assert.equal(result.scannerValidation.valid, true);
    assert.equal(result.scannerInvocation.allowed, allowed);
    assert.equal(result.scannerInvocation.reason, reason);
    assert.equal(result.findingCount, findings);
  });
}

for (const [name, mutate] of [
  ["candidate task mismatch", (input) => { input.candidates[0].taskId = "other"; }],
  ["candidate execution mismatch", (input) => { input.candidates[0].executionId = "other"; }],
  ["evidence task mismatch", (input) => { input.evidences[0].taskId = "other"; }],
  ["evidence execution mismatch", (input) => { input.evidences[0].executionId = "other"; }],
  ["scanner task mismatch", (input) => { input.scannerResult.taskId = "other"; }],
  ["scanner execution mismatch", (input) => { input.scannerResult.executionId = "other"; }],
]) {
  test(`${name} fails closed`, () => {
    const input = fixtureInput("synthetic_signal");
    mutate(input);
    const result = runPipeline(input);
    assert.equal(result.valid, false);
    assert.equal(result.findingCount, 0);
    assert.equal(typeof result.scannerInvocation.reason, "string");
  });
}

test("missing root acquisition taskId fails closed", () => {
  const input = fixtureInput("no_signal"); delete input.acquisitionResult.taskId;
  const result = runPipeline(input);
  assert.equal(result.valid, false); assert.equal(result.findingCount, 0);
});
test("missing root acquisition executionId fails closed", () => {
  const input = fixtureInput("no_signal"); delete input.acquisitionResult.executionId;
  const result = runPipeline(input);
  assert.equal(result.valid, false); assert.equal(result.findingCount, 0);
});
test("production callback remains hard blocked", () => {
  const input = fixtureInput("synthetic_signal"); input.productionCallback = true;
  const result = runPipeline(input);
  assert.equal(result.valid, false);
  assert.equal(result.scannerInvocation.reason, "TEST_FIXTURE_PRODUCTION_CALLBACK");
  assert.equal(result.findingCount, 0);
});
test("test executes the real generated bundle", () => {
  assert.equal(typeof runtime().runContractPipeline, "function");
  assert.match(fs.readFileSync(BUNDLE_PATH, "utf8"), /const rootContext/);
});
test("real generated workflow Code chain has exact results", () => {
  assert.deepEqual(runWorkflowChain().map((item) => [item.json.scenario,
    item.json.valid, item.json.guard, item.json.findingCount]), [
    ["no_signal", true, "READY", 0],
    ["synthetic_signal", true, "READY", 1],
    ["blocked", true, "NO_ACQUIRED_EVIDENCE", 0],
  ]);
});
test("real workflow production guard stays hard false", () => {
  for (const item of runWorkflowChain()) {
    assert.equal(item.json.productionAllowed, false);
    assert.equal(item.json.guardReason, "FIXTURE_HARNESS_HARD_FALSE");
  }
});
test("unsupported workflow scenario does not remove valid siblings", () => {
  const workflow = JSON.parse(fs.readFileSync(WORKFLOW_PATH, "utf8"));
  const harness = workflow.nodes.find((node) =>
    node.name === "Contract Runtime Harness");
  const output = runWorkflowCode(harness, [{json: {scenario: "unsupported"}},
    {json: {scenario: "no_signal"}}]);
  assert.equal(output.length, 2);
  assert.equal(output[0].json.result.errorCode, "FIXTURE_SCENARIO_UNSUPPORTED");
  assert.equal(output[1].json.result.valid, true);
});
test("runtime and workflow do not mutate inputs", () => {
  const input = fixtureInput("synthetic_signal"); const before = clone(input);
  runPipeline(input); assert.deepEqual(input, before);
  runWorkflowChain();
});
test("unexpected input exception does not leak", () => {
  const bundle = fs.readFileSync(BUNDLE_PATH, "utf8");
  const result = runRuntimeExpressionInIsolatedContext(bundle,
      "MarkaKalkanDdtRuntime.runContractPipeline(new Proxy({}, {get(){throw new Error('PRIVATE_DETAIL')}}))");
  assert.equal(result.valid, false);
  assert.equal(JSON.stringify(result).includes("PRIVATE_DETAIL"), false);
});
test("manifest covers runtime and build source hashes", () => {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
  for (const relative of ["runtime/n8n_contract_runtime_entry.js",
    "runtime/portable_primitives.js",
    "build/crypto_shim.js", "build/generate_n8n_runtime.js"]) {
    const group = relative.startsWith("runtime/") ?
      manifest.runtimeSourceHashes : manifest.buildSourceHashes;
    assert.equal(group[relative], hash(fs.readFileSync(path.join(ROOT, relative))));
  }
});
test("generated artifacts have no bundle or workflow drift", () => {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
  const bundle = fs.readFileSync(BUNDLE_PATH);
  const workflow = JSON.parse(fs.readFileSync(WORKFLOW_PATH, "utf8"));
  assert.equal(manifest.bundleSha256, hash(bundle));
  assert.equal(workflow.nodes.find((node) =>
    node.name === "Contract Runtime Harness").parameters.jsCode
      .startsWith(bundle.toString("utf8")), true);
});
test("golden workflow hash remains unchanged", () => assert.equal(
    hash(fs.readFileSync(GOLDEN_PATH)).toUpperCase(), GOLDEN_SHA256));
