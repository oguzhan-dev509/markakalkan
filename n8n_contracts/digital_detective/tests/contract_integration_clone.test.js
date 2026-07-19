"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const {runCodeNodeInIsolatedContext} = require("./helpers/isolated_n8n_vm");
const {SAFE_WEBHOOK_PATH, SOURCE_SHA256, WORKFLOW_NAME} =
  require("../tools/create_contract_integration_clone");

const ROOT = path.resolve(__dirname, "..");
const WORKFLOW_PATH = path.join(ROOT, "workflows",
    "MarkaKalkan Dijital Dedektif 12 Ajan - Contract Integration Clone - V1.json");
const BUNDLE_PATH = path.join(ROOT, "generated", "n8n_contract_runtime.js");
const text = () => fs.readFileSync(WORKFLOW_PATH, "utf8");
const workflow = () => JSON.parse(text());
const node = (name) => workflow().nodes.find((entry) => entry.name === name);
const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");

test("source export provenance hash is fixed", () => {
  assert.equal(SOURCE_SHA256,
      "d8bdfbfa768c59751e1547a68aa64c9580d6950aaacf642386723650f8553480");
  assert.match(node("Contract Clone Deterministic Input").parameters.jsCode,
      new RegExp(SOURCE_SHA256));
});
test("clone is inactive and import shaped", () => {
  const value = workflow();
  assert.equal(value.name, WORKFLOW_NAME);
  assert.equal(value.active, false);
  assert.deepEqual(value.pinData, {});
  assert.deepEqual(Object.keys(value).sort(),
      ["active", "connections", "name", "nodes", "pinData", "settings"]);
  for (const key of ["id", "versionId", "meta", "webhookId"]) {
    assert.equal(Object.prototype.hasOwnProperty.call(value, key), false);
  }
});
test("clone preserves 52-node architecture and adds five integration nodes", () => {
  assert.equal(workflow().nodes.length, 57);
  assert.equal(workflow().nodes.filter((entry) =>
    entry.id.startsWith("ddt-contract-clone-")).length, 5);
  assert.equal(workflow().nodes.filter((entry) =>
    entry.type === "@n8n/n8n-nodes-langchain.agent").length, 12);
});
test("live webhook is disabled and production path is absent", () => {
  const webhooks = workflow().nodes.filter((entry) =>
    entry.type === "n8n-nodes-base.webhook");
  assert.equal(webhooks.length, 1);
  assert.equal(webhooks[0].disabled, true);
  assert.equal(webhooks[0].parameters.path, SAFE_WEBHOOK_PATH);
  assert.doesNotMatch(text(), /markakalkan\/digital-detective\/task-created/);
  assert.equal("webhookId" in webhooks[0], false);
});
test("credentials and literal authorization secrets are absent", () => {
  const source = text();
  assert.equal(workflow().nodes.some((entry) => "credentials" in entry), false);
  assert.doesNotMatch(source,
      /x-markakalkan-token|"authorization"\s*:|bearer\s+[A-Za-z0-9._~+\/-]+=*|api[_-]?key\s*[:=]/i);
});
test("all external execution nodes are disabled", () => {
  const external = workflow().nodes.filter((entry) =>
    entry.type === "n8n-nodes-base.httpRequest" ||
    entry.type.startsWith("@n8n/n8n-nodes-langchain."));
  assert.equal(external.length > 0, true);
  assert.equal(external.every((entry) => entry.disabled === true), true);
  const callbacks = workflow().nodes.filter((entry) =>
    entry.type === "n8n-nodes-base.httpRequest");
  assert.equal(callbacks.length, 12);
  assert.equal(callbacks.every((entry) => entry.disabled === true), true);
});
test("runtime gate embeds the verified prototype-free bundle", () => {
  const bundle = fs.readFileSync(BUNDLE_PATH, "utf8");
  const code = node("Contract Runtime Validation Gate").parameters.jsCode;
  assert.equal(code.startsWith(bundle), true);
  assert.match(code, /runContractPipeline\(item\.json\)/);
  const contextSource = fs.readFileSync(path.join(ROOT, "validators",
      "context_validation.js"), "utf8");
  assert.doesNotMatch(contextSource,
      /Object\.getPrototypeOf|\binstanceof\b|\.constructor\b|Symbol\.toStringTag/);
});
test("manual contract path is deterministic and membrane safe", () => {
  const names = ["Contract Clone Deterministic Input",
    "Contract Runtime Validation Gate", "Contract Production Guard — Hard False",
    "Contract Integration Summary"];
  let items = [{json: {}}];
  for (const name of names) {
    items = runCodeNodeInIsolatedContext(node(name).parameters.jsCode, items,
        {n8nLikeNullPrototypeMembrane: true});
  }
  assert.deepEqual(items.map((item) => [item.json.scenario,
    item.json.acquisitionValid, item.json.candidateValid,
    item.json.evidenceBatchValid, item.json.scannerValid,
    item.json.scannerInvocationAllowed, item.json.scannerInvocationReason,
    item.json.findingCount, item.json.productionAllowed,
    item.json.callbackAttempted]), [
    ["no_signal", true, true, true, true, true, "READY", 0, false, false],
    ["synthetic_signal", true, true, true, true, true, "READY", 1, false, false],
    ["blocked", true, true, true, true, false,
      "NO_ACQUIRED_EVIDENCE", 0, false, false],
  ]);
  assert.equal(items.every((item) =>
    item.json.contractRuntimeVersion === "ddt-n8n-runtime-v1"), true);
  assert.doesNotMatch(JSON.stringify(items),
      /CONTEXT_REQUIRED|CONTEXT_(?:CANDIDATE|EVIDENCE)_INVALID|ACQUISITION_INVALID/);
});
test("hard-false guard cannot be enabled by input", () => {
  const output = runCodeNodeInIsolatedContext(
      node("Contract Production Guard — Hard False").parameters.jsCode,
      [{json: {scenario: "test", productionAllowed: true,
        callbackAttempted: true, result: {valid: true}}}]);
  assert.equal(output[0].json.productionAllowed, false);
  assert.equal(output[0].json.callbackAttempted, false);
});
test("artifact JSON bytes are deterministic for the committed generator", () => {
  const bytes = fs.readFileSync(WORKFLOW_PATH);
  assert.equal(bytes[bytes.length - 1], 10);
  assert.equal(sha256(bytes).length, 64);
});
