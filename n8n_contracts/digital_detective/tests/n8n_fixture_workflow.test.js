"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {runCodeNodeInIsolatedContext} =
  require("./helpers/isolated_n8n_vm");

const ROOT = path.resolve(__dirname, "..");
const WORKFLOW_PATH = path.join(ROOT, "workflows",
    "MarkaKalkan Dijital Dedektif - Contract Fixture Harness - V1.json");
const GOLDEN_PATH = path.resolve(ROOT, "..", "..", "reports",
    "MarkaKalkan Dijital Dedektif 12 Ajan - ALTIN REFERANS - 2026-07-18 - 12-12.json");
const EXPECTED_GOLDEN = "BE24FE2C91C7206197A2B4811F22475528A77EF011EF8A3ACE41D0E9182337A7";
const text = () => fs.readFileSync(WORKFLOW_PATH, "utf8");
const workflow = () => JSON.parse(text());
const clone = (value) => JSON.parse(JSON.stringify(value));
const sha256 = (value) => crypto.createHash("sha256").update(value)
    .digest("hex").toUpperCase();

function runCodeNode(node, inputItems) {
  return runCodeNodeInIsolatedContext(node.parameters.jsCode, inputItems);
}

function codeNode(name) {
  return workflow().nodes.find((node) => node.name === name);
}

function runFixtureChain(initial = [{json: {}}]) {
  const names = ["Fixture Senaryolarını Hazırla", "Contract Runtime Harness",
    "Sonuçları Özetle", "Production Guard — Hard False"];
  return names.reduce((items, name) => runCodeNode(codeNode(name), items), initial);
}

test("workflow JSON exists and parses", () => assert.equal(workflow().nodes.length, 6));
test("workflow root is limited to import fields", () => assert.deepEqual(
    Object.keys(workflow()).sort(),
    ["active", "connections", "name", "nodes", "pinData", "settings"]));
test("workflow has no versionId", () => assert.equal("versionId" in workflow(), false));
test("workflow has no platform instance fields", () => {
  for (const field of ["id", "meta", "staticData", "triggerCount"]) {
    assert.equal(field in workflow(), false);
  }
});
test("workflow is inactive", () => assert.equal(workflow().active, false));
test("pinData is empty", () => assert.deepEqual(workflow().pinData, {}));
test("workflow has no credential object", () => assert.doesNotMatch(text(), /"credentials"\s*:/i));
test("workflow has no webhook node", () => assert.equal(workflow().nodes.filter((n) => /webhook/i.test(n.type)).length, 0));
test("workflow has no HTTP Request node", () => assert.equal(workflow().nodes.filter((n) => /httpRequest/i.test(n.type)).length, 0));
test("workflow has no AI or OpenAI node", () => assert.equal(workflow().nodes.filter((n) => /(?:langchain|openai|agent)/i.test(n.type)).length, 0));
test("workflow has four Code nodes", () => assert.equal(workflow().nodes.filter((n) => n.type === "n8n-nodes-base.code").length, 4));
test("all Code nodes use runOnceForAllItems", () => {
  for (const node of workflow().nodes.filter((n) => n.type === "n8n-nodes-base.code")) {
    assert.equal(node.parameters.mode, "runOnceForAllItems");
  }
});
test("all Code nodes use $input.all without global items", () => {
  for (const node of workflow().nodes.filter((n) => n.type === "n8n-nodes-base.code")) {
    assert.match(node.parameters.jsCode, /\$input\.all\(\)/);
    assert.doesNotMatch(node.parameters.jsCode,
        /\bitems\s*\.\s*(?:map|forEach|filter|reduce)\s*\(/);
  }
});
test("prepare node produces exact fixture scenarios", () => {
  const values = runCodeNode(codeNode("Fixture Senaryolarını Hazırla"),
      [{json: {ignored: true}}]).map((item) => item.json.scenario);
  assert.deepEqual(values, ["no_signal", "synthetic_signal", "blocked"]);
});
test("runtime bundle is embedded before API call", () => {
  const bundle = fs.readFileSync(path.join(ROOT, "generated",
      "n8n_contract_runtime.js"), "utf8");
  const code = codeNode("Contract Runtime Harness").parameters.jsCode;
  assert.equal(code.startsWith(bundle), true);
  assert.ok(code.lastIndexOf("runFixtureScenario") > bundle.length);
});
test("full workflow Code chain returns expected fixture results", () => {
  const output = runFixtureChain();
  assert.deepEqual(output.map((item) => [item.json.scenario, item.json.guard,
    item.json.findingCount]), [["no_signal", "READY", 0],
    ["synthetic_signal", "READY", 1],
    ["blocked", "NO_ACQUIRED_EVIDENCE", 0]]);
});
test("full chain preserves all three items", () => assert.equal(runFixtureChain().length, 3));
test("production guard is hard false for every item", () => {
  for (const item of runFixtureChain()) {
    assert.equal(item.json.productionAllowed, false);
    assert.equal(item.json.guardReason, "FIXTURE_HARNESS_HARD_FALSE");
  }
});
test("malformed harness item becomes safe result without affecting sibling", () => {
  const output = runCodeNode(codeNode("Contract Runtime Harness"),
      [{json: null}, {json: {scenario: "no_signal"}}]);
  assert.equal(output[0].json.result.valid, false);
  assert.equal(output[0].json.result.errorCode, "FIXTURE_SCENARIO_UNSUPPORTED");
  assert.equal(output[1].json.result.valid, true);
});
test("malformed summary item fails closed", () => {
  const output = runCodeNode(codeNode("Sonuçları Özetle"),
      [{json: {scenario: "bad", result: null}}]);
  assert.deepEqual(output, [{json: {scenario: "", valid: false,
    guard: "FIXTURE_RESULT_INVALID", findingCount: 0}}]);
});
test("Code nodes do not mutate input", () => {
  const input = [{json: {scenario: "no_signal"}}];
  const before = clone(input);
  runCodeNode(codeNode("Contract Runtime Harness"), input);
  assert.deepEqual(input, before);
});
test("callback placeholder is disabled NoOp", () => {
  const node = workflow().nodes.find((n) => n.name === "Callback Placeholder — Disabled");
  assert.equal(node.disabled, true);
  assert.equal(node.type, "n8n-nodes-base.noOp");
  assert.deepEqual(node.parameters, {});
});
test("workflow contains no production callback URL", () => assert.doesNotMatch(text(), /cloudfunctions\.net|firebaseio\.com|run\.app/i));
test("workflow contains no network code", () => assert.doesNotMatch(text(), /\bfetch\s*\(|XMLHttpRequest|WebSocket|axios|https?\.request|child_process/i));
test("workflow contains no production Bosch identifiers", () => assert.doesNotMatch(text(), /11820|5F5I9R6CVbOp7JJtq2sfFVF0Hke2|I8xP1gH2UK6Bwz4oMbnQ|Bosch/i));
test("fixture data uses TEST_FIXTURE marker", () => assert.match(text(), /TEST_FIXTURE/));
test("node IDs are unique and deterministic labels", () => {
  const ids = workflow().nodes.map((node) => node.id);
  assert.equal(new Set(ids).size, ids.length);
  assert.equal(ids.every((id) => /^ddt-fixture-[a-z-]+-v1$/.test(id)), true);
});
test("node names are unique", () => {
  const names = workflow().nodes.map((node) => node.name);
  assert.equal(new Set(names).size, names.length);
});
test("workflow has exactly five connections", () =>
  assert.equal(Object.keys(workflow().connections).length, 5));
test("connection chain reaches disabled placeholder without dangling edge", () => {
  const names = workflow().nodes.map((node) => node.name);
  for (let index = 0; index < names.length - 1; index++) {
    assert.equal(workflow().connections[names[index]].main[0][0].node,
        names[index + 1]);
  }
});
test("golden workflow hash remains unchanged", () => assert.equal(
    sha256(fs.readFileSync(GOLDEN_PATH)), EXPECTED_GOLDEN));
