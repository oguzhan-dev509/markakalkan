"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {taskEnvelopeGateSource} = require("../validators/task_envelope");

const ROOT = path.resolve(__dirname, "..");
const OUTPUT_NAME =
  "MarkaKalkan Dijital Dedektif - Task Envelope Gate Fixture - V1.json";
const WORKFLOW_NAME =
  "MarkaKalkan Dijital Dedektif — TASK ENVELOPE GATE FIXTURE — V1";
const SCENARIOS = ["valid_task", "missing_task_id", "inherited_field",
  "accessor_field", "proxy_descriptor_error"];

function workflowObject() {
  const prepareCode = `void $input.all();
return ${JSON.stringify(SCENARIOS)}.map((scenario) => ({json: {scenario}}));`;
  const gateCode = `${taskEnvelopeGateSource()}
const inputItems = $input.all();
function baseTask() {
  return {taskId: "fixture-task-001", tenantId: "fixture-tenant-001",
    brandId: "fixture-brand-001", taskType: "digital_market_intelligence",
    target: "Fixture target", priority: "normal",
    createdAt: "2026-07-19T00:00:00.000Z", ignoredExtra: "not-copied"};
}
return inputItems.map((item) => {
  const scenario = typeof item?.json?.scenario === "string"
    ? item.json.scenario : "";
  let getterInvocations = 0;
  let task = baseTask();
  if (scenario === "missing_task_id") delete task.taskId;
  if (scenario === "inherited_field") {
    delete task.taskId;
    task = Object.assign(Object.create({taskId: "inherited-task"}), task);
  }
  if (scenario === "accessor_field") {
    delete task.taskId;
    Object.defineProperty(task, "taskId", {enumerable: true,
      get() { getterInvocations++; return "accessor-task"; }});
  }
  if (scenario === "proxy_descriptor_error") {
    task = new Proxy(task, {getOwnPropertyDescriptor() {
      throw new Error("FIXTURE_PRIVATE_DESCRIPTOR_ERROR");
    }});
  }
  if (!${JSON.stringify(SCENARIOS)}.includes(scenario)) task = null;
  const result = validateTaskEnvelope(task);
  return {json: {
    scenario,
    valid: result.valid === true,
    reason: result.reason,
    snapshot: result.snapshot,
    getterInvocations,
    productionAllowed: false,
    callbackAttempted: false,
  }};
});`;
  const mode = "runOnceForAllItems";
  const nodes = [
    {parameters: {}, id: "ddt-task-envelope-manual-v1",
      name: "Manual Trigger", type: "n8n-nodes-base.manualTrigger",
      typeVersion: 1, position: [0, 0]},
    {parameters: {mode, jsCode: prepareCode},
      id: "ddt-task-envelope-scenarios-v1",
      name: "Task Envelope Scenarios", type: "n8n-nodes-base.code",
      typeVersion: 2, position: [240, 0]},
    {parameters: {mode, jsCode: gateCode},
      id: "ddt-task-envelope-gate-v1",
      name: "Task Envelope Gate", type: "n8n-nodes-base.code",
      typeVersion: 2, position: [480, 0]},
  ];
  const connections = {};
  for (let index = 0; index < nodes.length - 1; index++) {
    connections[nodes[index].name] = {main: [[{
      node: nodes[index + 1].name, type: "main", index: 0,
    }]]};
  }
  return {
    name: WORKFLOW_NAME,
    nodes,
    connections,
    settings: {executionOrder: "v1"},
    pinData: {},
    active: false,
  };
}

function serializeWorkflow() {
  return `${JSON.stringify(workflowObject(), null, 2)}\n`;
}

function main() {
  const outputPath = process.argv[2] || path.join(ROOT, "workflows",
      OUTPUT_NAME);
  fs.writeFileSync(path.resolve(outputPath), serializeWorkflow(), "utf8");
}

if (require.main === module) main();

module.exports = {OUTPUT_NAME, SCENARIOS, WORKFLOW_NAME, serializeWorkflow,
  workflowObject};
