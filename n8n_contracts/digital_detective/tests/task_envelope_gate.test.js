"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const {runCodeNodeInIsolatedContext} =
  require("./helpers/isolated_n8n_vm");
const {validateTaskEnvelope} = require("../validators/task_envelope");
const {OUTPUT_NAME, SCENARIOS, WORKFLOW_NAME, serializeWorkflow} =
  require("../tools/create_task_envelope_gate_fixture");

const ROOT = path.resolve(__dirname, "..");
const WORKFLOW_PATH = path.join(ROOT, "workflows", OUTPUT_NAME);
const VALID = {
  taskId: "task-001", tenantId: "tenant-001", brandId: "brand-001",
  taskType: "digital_market_intelligence", target: "Public web target",
  priority: "high", createdAt: "2026-07-19T00:00:00.000Z",
};
const FIXTURE_VALID = {
  taskId: "fixture-task-001", tenantId: "fixture-tenant-001",
  brandId: "fixture-brand-001", taskType: "digital_market_intelligence",
  target: "Fixture target", priority: "normal",
  createdAt: "2026-07-19T00:00:00.000Z",
};
const INVALID = {valid: false, reason: "TASK_ENVELOPE_INVALID",
  snapshot: null};
const workflow = () => JSON.parse(fs.readFileSync(WORKFLOW_PATH, "utf8"));
const node = (name) => workflow().nodes.find((entry) => entry.name === name);
const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");

test("valid task returns a trimmed null-prototype planning snapshot", () => {
  const input = {...VALID, taskId: "  task-001  ", priority: " HIGH ",
    ignoredExtra: "must-not-cross"};
  const output = validateTaskEnvelope(input);
  assert.equal(output.valid, true);
  assert.equal(output.reason, "READY_FOR_PLANNING");
  assert.equal(Object.getPrototypeOf(output.snapshot), null);
  assert.deepEqual({...output.snapshot}, VALID);
  assert.equal("ignoredExtra" in output.snapshot, false);
});

for (const [name, input] of [
  ["null", null], ["array", []], ["string", "task"],
  ["missing taskId", (({taskId, ...rest}) => rest)(VALID)],
  ["empty target", {...VALID, target: "  "}],
  ["non-string createdAt", {...VALID, createdAt: 123}],
  ["unsupported priority", {...VALID, priority: "urgent"}],
]) {
  test(`${name} fails with the deterministic result`, () => {
    assert.deepEqual(validateTaskEnvelope(input), INVALID);
  });
}

test("inherited required field is rejected", () => {
  const input = {...VALID};
  delete input.taskId;
  const inherited = Object.assign(Object.create({taskId: VALID.taskId}), input);
  assert.deepEqual(validateTaskEnvelope(inherited), INVALID);
});

test("accessor is rejected without invoking its getter", () => {
  let calls = 0;
  const input = {...VALID};
  Object.defineProperty(input, "taskId", {enumerable: true,
    get() { calls++; throw new Error("PRIVATE_GETTER"); }});
  assert.deepEqual(validateTaskEnvelope(input), INVALID);
  assert.equal(calls, 0);
});

test("descriptor proxy exception fails closed without escaping", () => {
  const input = new Proxy({...VALID}, {getOwnPropertyDescriptor() {
    throw new Error("PRIVATE_DESCRIPTOR");
  }});
  let output;
  assert.doesNotThrow(() => { output = validateTaskEnvelope(input); });
  assert.deepEqual(output, INVALID);
  assert.doesNotMatch(JSON.stringify(output), /PRIVATE_DESCRIPTOR/);
});

test("get and getPrototypeOf proxy traps are never invoked", () => {
  let getCalls = 0;
  let prototypeCalls = 0;
  const input = new Proxy({...VALID}, {
    get() { getCalls++; throw new Error("PRIVATE_GET"); },
    getPrototypeOf() { prototypeCalls++; throw new Error("PRIVATE_PROTO"); },
  });
  assert.equal(validateTaskEnvelope(input).valid, true);
  assert.equal(getCalls, 0);
  assert.equal(prototypeCalls, 0);
});

test("validator does not mutate input or nested identity", () => {
  const input = {...VALID};
  const before = JSON.stringify(input);
  validateTaskEnvelope(input);
  assert.equal(JSON.stringify(input), before);
});

test("foreign-realm object is accepted", () => {
  const context = vm.createContext({serialized: JSON.stringify(VALID)});
  const foreign = new vm.Script("JSON.parse(serialized)").runInContext(context);
  assert.equal(validateTaskEnvelope(foreign).valid, true);
});

test("validator source uses descriptors and avoids prototype identity", () => {
  const source = fs.readFileSync(path.join(ROOT, "validators",
      "task_envelope.js"), "utf8");
  assert.match(source, /Object\.prototype\.hasOwnProperty\.call/);
  assert.match(source, /Object\.getOwnPropertyDescriptor/);
  assert.match(source, /Object\.create\(null\)/);
  assert.doesNotMatch(source,
      /Object\.getPrototypeOf|\binstanceof\b|\.constructor\b|Symbol\.toStringTag/);
});

test("fixture is inactive, import-safe and has only a manual entry", () => {
  const value = workflow();
  assert.equal(value.name, WORKFLOW_NAME);
  assert.equal(value.active, false);
  assert.deepEqual(value.pinData, {});
  assert.deepEqual(Object.keys(value).sort(),
      ["active", "connections", "name", "nodes", "pinData", "settings"]);
  for (const key of ["id", "versionId", "meta", "webhookId"]) {
    assert.equal(Object.prototype.hasOwnProperty.call(value, key), false);
  }
  assert.equal(value.nodes.length, 3);
  assert.equal(Object.keys(value.connections).length, 2);
  assert.equal(value.nodes.filter((entry) =>
    entry.type === "n8n-nodes-base.manualTrigger").length, 1);
  assert.equal(value.nodes.filter((entry) =>
    /trigger$/i.test(entry.type) &&
    entry.type !== "n8n-nodes-base.manualTrigger").length, 0);
});

test("fixture has no network, AI, callback, credential or dangerous flag", () => {
  const value = workflow();
  assert.equal(value.nodes.some((entry) =>
    entry.type === "n8n-nodes-base.httpRequest" ||
    entry.type.startsWith("@n8n/n8n-nodes-langchain.")), false);
  assert.equal(value.nodes.some((entry) => "credentials" in entry), false);
  const source = fs.readFileSync(WORKFLOW_PATH, "utf8");
  assert.doesNotMatch(source, /productionAllowed\s*[:=]\s*true/);
  assert.doesNotMatch(source, /callbackAttempted\s*[:=]\s*true/);
  assert.doesNotMatch(source,
      /x-markakalkan-token|"authorization"\s*:|bearer\s+[A-Za-z0-9._~+\/-]+=*|api[_-]?key\s*[:=]/i);
});

test("fixture runs all five scenarios through the n8n membrane", () => {
  let items = [{json: {}}];
  for (const name of ["Task Envelope Scenarios", "Task Envelope Gate"]) {
    items = runCodeNodeInIsolatedContext(node(name).parameters.jsCode, items,
        {n8nLikeNullPrototypeMembrane: true});
  }
  assert.deepEqual(items.map((item) => [item.json.scenario, item.json.valid,
    item.json.reason, item.json.getterInvocations,
    item.json.productionAllowed, item.json.callbackAttempted]), [
    ["valid_task", true, "READY_FOR_PLANNING", 0, false, false],
    ["missing_task_id", false, "TASK_ENVELOPE_INVALID", 0, false, false],
    ["inherited_field", false, "TASK_ENVELOPE_INVALID", 0, false, false],
    ["accessor_field", false, "TASK_ENVELOPE_INVALID", 0, false, false],
    ["proxy_descriptor_error", false, "TASK_ENVELOPE_INVALID", 0, false, false],
  ]);
  assert.deepEqual(items[0].json.snapshot, FIXTURE_VALID);
  assert.deepEqual(SCENARIOS, items.map((item) => item.json.scenario));
});

test("generator is byte-for-byte deterministic", () => {
  const first = serializeWorkflow();
  const second = serializeWorkflow();
  assert.equal(first, second);
  assert.equal(first, fs.readFileSync(WORKFLOW_PATH, "utf8"));
  assert.equal(sha256(first), sha256(second));
});

test("previous clone artifacts remain byte-for-byte unchanged", () => {
  const hashes = [
    ["MarkaKalkan Dijital Dedektif 12 Ajan - Contract Integration Clone - V1.json",
      "c64c3535e6248b3b7b97a4cb6057dfed858f8483f636e65a20f53d30d0be4d0d"],
    ["MarkaKalkan Dijital Dedektif 12 Ajan - Production Candidate Clone - V1.json",
      "69f4e1b2222f8f1d00dd4ad04a4ac4630fa33cfa01d366002c85216342dfdc6f"],
  ];
  for (const [name, expected] of hashes) {
    assert.equal(sha256(fs.readFileSync(path.join(ROOT, "workflows", name))),
        expected);
  }
});
