"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const {runCodeNodeInIsolatedContext} = require("./helpers/isolated_n8n_vm");
const {INTEGRATION_SOURCE_SHA256, LIVE_AGENT_PROMPTS_SHA256,
  LIVE_SOURCE_SHA256, SAFE_WEBHOOK_PATH, WORKFLOW_NAME, promptHash} =
  require("../tools/create_production_candidate_clone");

const ROOT = path.resolve(__dirname, "..");
const WORKFLOW_PATH = path.join(ROOT, "workflows",
    "MarkaKalkan Dijital Dedektif 12 Ajan - Production Candidate Clone - V1.json");
const INTEGRATION_PATH = path.join(ROOT, "workflows",
    "MarkaKalkan Dijital Dedektif 12 Ajan - Contract Integration Clone - V1.json");
const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");
const text = () => fs.readFileSync(WORKFLOW_PATH, "utf8");
const workflow = () => JSON.parse(text());
const node = (name) => workflow().nodes.find((entry) => entry.name === name);
const enabled = (entry) => entry.disabled !== true;

function outgoing(name) {
  const outputs = workflow().connections[name] || {};
  return Object.values(outputs).flat(2).filter(Boolean).map((edge) => edge.node);
}

function reachable(start) {
  const seen = new Set([start]);
  const queue = [start];
  while (queue.length) {
    for (const next of outgoing(queue.shift())) {
      if (!seen.has(next)) {
        seen.add(next);
        queue.push(next);
      }
    }
  }
  return seen;
}

test("both immutable source hashes and live prompt hash are fixed", () => {
  assert.equal(sha256(fs.readFileSync(INTEGRATION_PATH)),
      INTEGRATION_SOURCE_SHA256);
  assert.equal(INTEGRATION_SOURCE_SHA256,
      "c64c3535e6248b3b7b97a4cb6057dfed858f8483f636e65a20f53d30d0be4d0d");
  assert.equal(LIVE_SOURCE_SHA256,
      "d8bdfbfa768c59751e1547a68aa64c9580d6950aaacf642386723650f8553480");
  assert.equal(LIVE_AGENT_PROMPTS_SHA256,
      "bbed2ac46bb873e4045a2099b406d3cefd4f550eb5fc0ac0e4a0bf9716d85a32");
  assert.equal(promptHash(workflow()), LIVE_AGENT_PROMPTS_SHA256);
  const code = node("Production Candidate Deterministic Task").parameters.jsCode;
  assert.match(code, new RegExp(INTEGRATION_SOURCE_SHA256));
  assert.match(code, new RegExp(LIVE_SOURCE_SHA256));
});

test("candidate is inactive, clean and n8n import shaped", () => {
  const value = workflow();
  assert.equal(value.name, WORKFLOW_NAME);
  assert.equal(value.active, false);
  assert.deepEqual(value.pinData, {});
  assert.deepEqual(Object.keys(value).sort(),
      ["active", "connections", "name", "nodes", "pinData", "settings"]);
  for (const key of ["id", "versionId", "meta", "webhookId"]) {
    assert.equal(Object.prototype.hasOwnProperty.call(value, key), false);
  }
  assert.equal(value.nodes.length, 58);
  assert.equal(value.nodes.filter((entry) =>
    entry.id.startsWith("ddt-production-candidate-")).length, 6);
});

test("manual trigger is the only runnable entry and webhook is safe", () => {
  const manual = workflow().nodes.filter((entry) =>
    entry.type === "n8n-nodes-base.manualTrigger" && enabled(entry));
  const webhooks = workflow().nodes.filter((entry) =>
    entry.type === "n8n-nodes-base.webhook");
  assert.equal(manual.length, 1);
  assert.equal(manual[0].name, "Production Candidate Manual Trigger");
  assert.equal(webhooks.length, 1);
  assert.equal(webhooks[0].disabled, true);
  assert.equal(webhooks[0].parameters.path, SAFE_WEBHOOK_PATH);
  assert.equal("webhookId" in webhooks[0], false);
  assert.doesNotMatch(text(), /markakalkan\/digital-detective\/task-created/);
});

test("all agents, OpenAI models and the structured parser are enabled", () => {
  const agents = workflow().nodes.filter((entry) =>
    entry.type === "@n8n/n8n-nodes-langchain.agent");
  const models = workflow().nodes.filter((entry) =>
    entry.type === "@n8n/n8n-nodes-langchain.lmChatOpenAi");
  const parsers = workflow().nodes.filter((entry) =>
    entry.type === "@n8n/n8n-nodes-langchain.outputParserStructured");
  assert.equal(agents.length, 12);
  assert.equal(agents.every(enabled), true);
  assert.equal(models.length, 13);
  assert.equal(models.every(enabled), true);
  assert.equal(parsers.length, 1);
  assert.equal(parsers.every(enabled), true);
});

test("only OpenAI model nodes retain credential references", () => {
  const credentialed = workflow().nodes.filter((entry) => "credentials" in entry);
  assert.equal(credentialed.length, 13);
  assert.equal(credentialed.every((entry) =>
    entry.type === "@n8n/n8n-nodes-langchain.lmChatOpenAi"), true);
  assert.equal(credentialed.every((entry) =>
    Object.keys(entry.credentials).length === 1 &&
    Object.prototype.hasOwnProperty.call(entry.credentials, "openAiApi")), true);
  assert.doesNotMatch(text(),
      /x-markakalkan-token|"authorization"\s*:|bearer\s+[A-Za-z0-9._~+\/-]+=*|api[_-]?key\s*[:=]/i);
});

test("twelve callbacks are disabled, disconnected and manual-unreachable", () => {
  const callbacks = workflow().nodes.filter((entry) =>
    entry.type === "n8n-nodes-base.httpRequest");
  assert.equal(callbacks.length, 12);
  assert.equal(callbacks.every((entry) => entry.disabled === true), true);
  const callbackNames = new Set(callbacks.map((entry) => entry.name));
  const allTargets = Object.values(workflow().connections)
      .flatMap((outputs) => Object.values(outputs).flat(2))
      .filter(Boolean).map((edge) => edge.node);
  assert.equal(allTargets.some((name) => callbackNames.has(name)), false);
  const fromManual = reachable("Production Candidate Manual Trigger");
  assert.equal([...callbackNames].some((name) => fromManual.has(name)), false);
});

test("preflight is an unavoidable ancestor of task planning", () => {
  assert.deepEqual(outgoing("Production Candidate Manual Trigger"),
      ["Production Candidate Deterministic Task"]);
  assert.deepEqual(outgoing("Production Candidate Deterministic Task"),
      ["Contract Preflight Gate"]);
  assert.deepEqual(outgoing("Contract Preflight Gate"),
      ["Production Candidate Guard — Hard False"]);
  assert.deepEqual(outgoing("Production Candidate Guard — Hard False"),
      ["Production Candidate Preflight Summary"]);
  assert.deepEqual(outgoing("Production Candidate Preflight Summary"),
      ["Contract Preflight Route"]);
  assert.deepEqual(outgoing("Contract Preflight Route"),
      ["Ajan Görev Zarfını Hazırla"]);
});

test("deterministic cross-realm preflight reaches READY and preserves task fields", () => {
  const names = ["Production Candidate Deterministic Task",
    "Contract Preflight Gate", "Production Candidate Guard — Hard False",
    "Production Candidate Preflight Summary", "Contract Preflight Route"];
  let items = [{json: {}}];
  for (const name of names) {
    items = runCodeNodeInIsolatedContext(node(name).parameters.jsCode, items,
        {n8nLikeNullPrototypeMembrane: true});
  }
  assert.equal(items.length, 1);
  assert.deepEqual({...items[0].json}, {
    taskId: "pc-v1-safe-test",
    tenantId: "tenant-production-candidate-test",
    brandId: "brand-production-candidate-test",
    taskType: "digital_detective_contract_candidate",
    target: "MarkaKalkan Test Markası / MK Test Ürünü / Açık Web",
    priority: "normal", country: "Türkiye", city: "İstanbul",
    searchTerms: ["example.com", "mk-production-candidate-v1"],
    contractRuntimeVersion: "ddt-n8n-runtime-v1",
    acquisitionValid: true, candidateValid: true,
    evidenceBatchValid: true, scannerValid: true,
    scannerInvocationAllowed: true, scannerInvocationReason: "READY",
    findingCount: 0, expectedAgentCount: 12, enabledAgentCount: 12,
    enabledModelCount: 13, disabledCallbackCount: 12,
    candidateMode: true, productionAllowed: false, callbackAttempted: false,
  });
});

test("invalid contract input cannot reach an agent", () => {
  let items = [{json: {taskId: "invalid", productionAllowed: true,
    callbackAttempted: true}}];
  for (const name of ["Contract Preflight Gate",
    "Production Candidate Guard — Hard False",
    "Production Candidate Preflight Summary", "Contract Preflight Route"]) {
    items = runCodeNodeInIsolatedContext(node(name).parameters.jsCode, items,
        {n8nLikeNullPrototypeMembrane: true});
  }
  assert.deepEqual(items, []);
});

test("hard-false membrane cannot be overridden by input", () => {
  const output = runCodeNodeInIsolatedContext(
      node("Production Candidate Guard — Hard False").parameters.jsCode,
      [{json: {productionAllowed: true, callbackAttempted: true}}],
      {n8nLikeNullPrototypeMembrane: true});
  assert.equal(output[0].json.productionAllowed, false);
  assert.equal(output[0].json.callbackAttempted, false);
});
