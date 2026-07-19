"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const childProcess = require("node:child_process");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const {isPlainRecord} = require("../validators/validator_result");
const {isValidationContext, readValidationContext} =
  require("../validators/context_validation");
const {validateAcquisitionResult} =
  require("../validators/validate_acquisition_result");
const {validateCandidateSource} =
  require("../validators/validate_candidate_source");
const {validateStructuredEvidence} =
  require("../validators/validate_structured_evidence");
const {validateEvidenceBatch} =
  require("../validators/validate_evidence_batch");
const {validateScannerResult} =
  require("../validators/validate_scanner_result");
const {runCodeNodeInIsolatedContext, runRuntimeExpressionInIsolatedContext,
  runRuntimeWithForeignInput} =
  require("./helpers/isolated_n8n_vm");

const ROOT = path.resolve(__dirname, "..");
const REPO_ROOT = path.resolve(ROOT, "..", "..");
const BASELINE_COMMIT = "2065fa44d24508fc3c4769e3fd3ee871d871b6b7";
const BASELINE_BUNDLE_PATH =
  "n8n_contracts/digital_detective/generated/n8n_contract_runtime.js";
const BASELINE_BUNDLE_SHA256 =
  "b1ed7fb1e17aa05d919286e5fa014ba493ff17d80e69e24a331eaba7e24f753a";
const read = (scenario, name) => JSON.parse(fs.readFileSync(path.join(ROOT,
    "fixtures", scenario, `${name}.json`), "utf8"));
const values = (scenario = "synthetic_signal") => ({
  acquisition: read(scenario, "acquisition_result"),
  candidates: read(scenario, "candidate_sources"),
  evidences: read(scenario, "structured_evidence"),
  scanner: read(scenario, "scanner_result"),
});
const foreign = (value) => {
  const realm = vm.createContext({serialized: JSON.stringify(value)});
  return new vm.Script("JSON.parse(serialized)").runInContext(realm);
};
const contexts = (scenario = "synthetic_signal") => {
  const v = values(scenario);
  const root = {taskId: v.acquisition.taskId,
    executionId: v.acquisition.executionId, productionCallback: false};
  return {v, root, candidate: {...root, candidates: v.candidates},
    scanner: {...root, candidates: v.candidates, evidences: v.evidences}};
};
const has = (result, code) => result.errors.some((entry) => entry.code === code);
const pipelineInput = (scenario) => {
  const v = values(scenario);
  return {acquisitionResult: v.acquisition, candidates: v.candidates,
    evidences: v.evidences, scannerResult: v.scanner,
    productionCallback: false};
};
const committedBundle = () => {
  const result = childProcess.spawnSync("git", ["-C", REPO_ROOT, "show",
    `${BASELINE_COMMIT}:${BASELINE_BUNDLE_PATH}`], {
    encoding: "buffer", maxBuffer: 2 * 1024 * 1024,
    shell: false, windowsHide: true,
  });
  if (result.error || result.status !== 0) {
    throw new Error("COMMITTED_BASELINE_BUNDLE_UNAVAILABLE");
  }
  const digest = crypto.createHash("sha256").update(result.stdout).digest("hex");
  assert.equal(digest, BASELINE_BUNDLE_SHA256);
  return result.stdout.toString("utf8");
};
const assertAllValidations = (output) => {
  assert.equal(output.acquisitionValidation.valid, true);
  assert.equal(output.candidateValidations.every((value) => value.valid), true);
  assert.equal(output.evidenceBatchValidation.valid, true);
  assert.equal(output.scannerValidation.valid, true);
};

test("committed strict payload predicate rejects a foreign plain object", () => {
  assert.equal(isPlainRecord(foreign({taskId: "t", executionId: "e"})), false);
});
test("realm-safe context predicate accepts a foreign plain object", () => {
  assert.equal(isValidationContext(foreign({taskId: "t", executionId: "e"})),
      true);
});
test("foreign root context validates acquisition", () => {
  const {v, root} = contexts();
  assert.equal(validateAcquisitionResult(v.acquisition, foreign(root)).valid, true);
});
test("foreign root context validates candidate", () => {
  const {v, root} = contexts();
  assert.equal(validateCandidateSource(v.candidates[0], foreign(root)).valid, true);
});
test("foreign candidate context validates evidence", () => {
  const {v, candidate} = contexts();
  assert.equal(validateStructuredEvidence(v.evidences[0],
      foreign(candidate)).valid, true);
});
test("foreign candidate context validates evidence batch", () => {
  const {v, candidate} = contexts();
  assert.equal(validateEvidenceBatch(v.evidences, foreign(candidate)).valid, true);
});
test("foreign scanner context validates scanner result", () => {
  const {v, scanner} = contexts();
  assert.equal(validateScannerResult(v.scanner, foreign(scanner)).valid, true);
});

for (const [name, call] of [
  ["candidate", (v, c) => validateCandidateSource(v.candidates[0], c)],
  ["evidence", (v, c) => validateStructuredEvidence(v.evidences[0], c)],
  ["batch", (v, c) => validateEvidenceBatch(v.evidences, c)],
  ["scanner", (v, c) => validateScannerResult(v.scanner, c)],
]) {
  test(`null-prototype ${name} context is accepted`, () => {
    const {v, root, candidate, scanner} = contexts();
    const source = name === "candidate" ? root : name === "scanner" ?
      scanner : candidate;
    const context = Object.assign(Object.create(null), source);
    assert.equal(call(v, context).valid, true);
  });
  test(`benign proxy ${name} context is accepted`, () => {
    const {v, root, candidate, scanner} = contexts();
    const source = name === "candidate" ? root : name === "scanner" ?
      scanner : candidate;
    assert.equal(call(v, new Proxy(source, {})).valid, true);
  });
}

for (const [name, value] of [
  ["array", []], ["null", null], ["string", "context"], ["number", 1],
]) {
  test(`${name} is not a validation context`, () => {
    assert.equal(isValidationContext(value), false);
    assert.equal(readValidationContext(value), null);
  });
}
for (const [name, value] of [
  ["date", new Date()], ["map", new Map()], ["set", new Set()],
]) {
  test(`${name} without required own fields is rejected`, () => {
    assert.equal(readValidationContext(value), null);
  });
}
test("class instance with own data fields is accepted as context", () => {
  class Context {}
  const value = Object.assign(new Context(), {taskId: "t", executionId: "e"});
  assert.equal(readValidationContext(value).taskId, "t");
});
test("getPrototypeOf trap is never called for a valid context", () => {
  let calls = 0;
  const value = new Proxy({taskId: "t", executionId: "e"}, {
    getPrototypeOf() { calls++; throw new Error("PRIVATE_PROTOTYPE"); },
  });
  assert.equal(readValidationContext(value).executionId, "e");
  assert.equal(calls, 0);
});
test("inherited production callback is ignored", () => {
  const value = Object.assign(Object.create({productionCallback: true}),
      {taskId: "t", executionId: "e"});
  assert.equal(readValidationContext(value).productionCallback, false);
});
test("own accessor context field is rejected without invocation", () => {
  let calls = 0;
  const value = {executionId: "e"};
  Object.defineProperty(value, "taskId", {get() { calls++; return "t"; }});
  assert.equal(readValidationContext(value), null);
  assert.equal(calls, 0);
});
test("own accessor production callback is rejected without invocation", () => {
  let calls = 0;
  const value = {taskId: "t", executionId: "e"};
  Object.defineProperty(value, "productionCallback",
      {get() { calls++; return true; }});
  assert.equal(readValidationContext(value), null);
  assert.equal(calls, 0);
});
test("descriptor trap exception fails context closed", () => {
  const value = new Proxy({taskId: "t", executionId: "e"}, {
    getOwnPropertyDescriptor() { throw new Error("PRIVATE_DESCRIPTOR"); },
  });
  assert.equal(readValidationContext(value), null);
});
test("missing own taskId is rejected", () => {
  const inherited = Object.create({taskId: "t"}); inherited.executionId = "e";
  assert.equal(readValidationContext(inherited), null);
});
test("missing own executionId is rejected", () => {
  assert.equal(readValidationContext({taskId: "t"}), null);
});
test("missing own candidates is rejected when required", () => {
  assert.equal(readValidationContext({taskId: "t", executionId: "e"},
      {candidates: true}), null);
});
test("missing own evidences is rejected when required", () => {
  assert.equal(readValidationContext({taskId: "t", executionId: "e",
    candidates: []}, {candidates: true, evidences: true}), null);
});
test("inherited candidates and evidences are rejected when required", () => {
  const inherited = Object.create({candidates: [], evidences: []});
  inherited.taskId = "t"; inherited.executionId = "e";
  assert.equal(readValidationContext(inherited, {candidates: true}), null);
  assert.equal(readValidationContext(inherited,
      {candidates: true, evidences: true}), null);
});
test("candidate accessor field is invalid without getter invocation", () => {
  const {v, root} = contexts(); let calls = 0;
  const candidate = {...v.candidates[0]};
  Object.defineProperty(candidate, "sourceId",
      {get() { calls++; return v.candidates[0].sourceId; }});
  const output = validateEvidenceBatch(v.evidences,
      {...root, candidates: [candidate]});
  assert.equal(has(output, "CONTEXT_CANDIDATE_INVALID"), true);
  assert.equal(calls, 0);
});
test("candidate inherited field is invalid", () => {
  const {v, root} = contexts();
  const candidate = {...v.candidates[0]};
  const sourceId = candidate.sourceId; delete candidate.sourceId;
  Object.setPrototypeOf(candidate, {sourceId});
  const output = validateEvidenceBatch(v.evidences,
      {...root, candidates: [candidate]});
  assert.equal(has(output, "CONTEXT_CANDIDATE_INVALID"), true);
});
test("evidence accessor field is invalid without getter invocation", () => {
  const {v, root} = contexts(); let calls = 0;
  const evidence = {...v.evidences[0]};
  Object.defineProperty(evidence, "sourceId",
      {get() { calls++; return v.evidences[0].sourceId; }});
  const output = validateScannerResult(v.scanner,
      {...root, candidates: v.candidates, evidences: [evidence]});
  assert.equal(has(output, "CONTEXT_EVIDENCE_INVALID"), true);
  assert.equal(calls, 0);
});

for (const [name, make] of [
  ["getter", () => Object.defineProperty({executionId: "e"}, "taskId",
    {enumerable: true, get() { throw new Error("PRIVATE_GETTER"); }})],
  ["proxy", () => new Proxy({}, {getPrototypeOf() {
    throw new Error("PRIVATE_PROXY");
  }})],
]) {
  test(`${name} context fails candidate validation closed`, () => {
    const {v} = contexts(); let output;
    assert.doesNotThrow(() => { output = validateCandidateSource(v.candidates[0],
      make()); });
    assert.equal(has(output, "CONTEXT_REQUIRED"), true);
    assert.equal(JSON.stringify(output).includes("PRIVATE_"), false);
  });
  test(`${name} context fails evidence batch validation closed`, () => {
    const {v} = contexts(); let output;
    assert.doesNotThrow(() => { output = validateEvidenceBatch(v.evidences,
      make()); });
    assert.equal(has(output, "CONTEXT_REQUIRED"), true);
    assert.equal(JSON.stringify(output).includes("PRIVATE_"), false);
  });
  test(`${name} context fails scanner validation closed`, () => {
    const {v} = contexts(); let output;
    assert.doesNotThrow(() => { output = validateScannerResult(v.scanner,
      make()); });
    assert.equal(has(output, "CONTEXT_REQUIRED"), true);
    assert.equal(JSON.stringify(output).includes("PRIVATE_"), false);
  });
}

test("old committed bundle reproduces real n8n foreign-realm baseline", () => {
  const bundle = committedBundle();
  for (const scenario of ["no_signal", "synthetic_signal", "blocked"]) {
    const output = runRuntimeWithForeignInput(bundle, pipelineInput(scenario));
    assert.equal(output.valid, false);
    assert.equal(output.acquisitionValidation.valid, true);
    assert.equal(output.candidateValidations[0].valid, true);
    assert.equal(output.evidenceBatchValidation.valid, false);
    assert.equal(has(output.evidenceBatchValidation,
        "CONTEXT_CANDIDATE_INVALID"), true);
    assert.equal(output.scannerValidation.valid, false);
    assert.equal(has(output.scannerValidation, "CONTEXT_CANDIDATE_INVALID"), true);
    assert.deepEqual(output.scannerInvocation,
        {allowed: false, reason: "EVIDENCE_BATCH_INVALID"});
    assert.equal(output.findingCount, 0);
  }
});

test("old committed bundle runFixtureScenario remains realm-local", () => {
  const output = runRuntimeExpressionInIsolatedContext(committedBundle(),
      'MarkaKalkanDdtRuntime.runFixtureScenario("no_signal")');
  assert.equal(output.valid, true);
  assertAllValidations(output);
  assert.deepEqual(output.scannerInvocation, {allowed: true, reason: "READY"});
  assert.equal(output.findingCount, 0);
});

for (const [scenario, allowed, reason, findings] of [
  ["no_signal", true, "READY", 0],
  ["synthetic_signal", true, "READY", 1],
  ["blocked", false, "NO_ACQUIRED_EVIDENCE", 0],
]) {
  test(`generated bundle accepts foreign-realm ${scenario} input`, () => {
    const bundle = fs.readFileSync(path.join(ROOT, "generated",
        "n8n_contract_runtime.js"), "utf8");
    const output = runRuntimeWithForeignInput(bundle, pipelineInput(scenario));
    assert.equal(output.valid, true);
    assertAllValidations(output);
    assert.equal(output.scannerInvocation.allowed, allowed);
    assert.equal(output.scannerInvocation.reason, reason);
    assert.equal(output.findingCount, findings);
  });
}

test("generated workflow passes the n8n-like null-prototype membrane", () => {
  const workflow = JSON.parse(fs.readFileSync(path.join(ROOT, "workflows",
      "MarkaKalkan Dijital Dedektif - Contract Fixture Harness - V1.json"),
  "utf8"));
  const names = ["Fixture Senaryolarını Hazırla", "Contract Runtime Harness",
    "Sonuçları Özetle", "Production Guard — Hard False"];
  let items = [{json: {}}];
  for (const name of names) {
    const node = workflow.nodes.find((entry) => entry.name === name);
    items = runCodeNodeInIsolatedContext(node.parameters.jsCode, items,
        {n8nLikeNullPrototypeMembrane: true});
  }
  assert.deepEqual(items.map((item) => [item.json.scenario, item.json.valid,
    item.json.guard, item.json.findingCount, item.json.productionAllowed]), [
    ["no_signal", true, "READY", 0, false],
    ["synthetic_signal", true, "READY", 1, false],
    ["blocked", true, "NO_ACQUIRED_EVIDENCE", 0, false],
  ]);
  assert.doesNotMatch(JSON.stringify(items), /CONTEXT_REQUIRED|CONTEXT_(?:CANDIDATE|EVIDENCE)_INVALID|ACQUISITION_INVALID/);
});
test("context validation source is prototype-free", () => {
  const source = fs.readFileSync(path.join(ROOT, "validators",
      "context_validation.js"), "utf8");
  assert.doesNotMatch(source,
      /Object\.getPrototypeOf|\binstanceof\b|\.constructor\b|Symbol\.toStringTag/);
});
