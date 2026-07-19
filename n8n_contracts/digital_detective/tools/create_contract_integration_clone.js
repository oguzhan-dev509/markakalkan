"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const SOURCE_SHA256 =
  "d8bdfbfa768c59751e1547a68aa64c9580d6950aaacf642386723650f8553480";
const OUTPUT_NAME =
  "MarkaKalkan Dijital Dedektif 12 Ajan - Contract Integration Clone - V1.json";
const WORKFLOW_NAME =
  "MarkaKalkan Dijital Dedektif 12 Ajan — CONTRACT INTEGRATION CLONE — V1";
const SAFE_WEBHOOK_PATH =
  "markakalkan/digital-detective/contract-integration-clone-v1";
const SCENARIOS = ["no_signal", "synthetic_signal", "blocked"];

const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");
const readJson = (location) => JSON.parse(fs.readFileSync(location, "utf8"));

function fixtureInput(scenario) {
  const directory = path.join(ROOT, "fixtures", scenario);
  return {
    scenario,
    acquisitionResult: readJson(path.join(directory, "acquisition_result.json")),
    candidates: readJson(path.join(directory, "candidate_sources.json")),
    evidences: readJson(path.join(directory, "structured_evidence.json")),
    scannerResult: readJson(path.join(directory, "scanner_result.json")),
    productionCallback: false,
  };
}

function integrationNodes(bundle) {
  const inputs = SCENARIOS.map(fixtureInput);
  const inputCode = `const SOURCE_EXPORT_SHA256 = "${SOURCE_SHA256}";
void SOURCE_EXPORT_SHA256;
void $input.all();
return ${JSON.stringify(inputs)}.map((json) => ({json}));`;
  const gateCode = `${bundle}
const inputItems = $input.all();
return inputItems.map((item) => {
  try {
    const scenario = typeof item?.json?.scenario === "string" ? item.json.scenario : "";
    const result = MarkaKalkanDdtRuntime.runContractPipeline(item.json);
    return {json: {scenario, result}};
  } catch (_) {
    return {json: {scenario: "", result: {valid: false,
      errorCode: "CONTRACT_INTEGRATION_EXCEPTION", scannerInvocation:
      {allowed: false, reason: "CONTRACT_INTEGRATION_EXCEPTION"}, findingCount: 0}}};
  }
});`;
  const guardCode = `const inputItems = $input.all();
return inputItems.map((item) => ({json: {
  scenario: typeof item?.json?.scenario === "string" ? item.json.scenario : "",
  result: item?.json?.result && typeof item.json.result === "object" ? item.json.result : null,
  productionAllowed: false,
  callbackAttempted: false,
}}));`;
  const summaryCode = `const inputItems = $input.all();
return inputItems.map((item) => {
  const result = item?.json?.result;
  const candidates = Array.isArray(result?.candidateValidations) ? result.candidateValidations : [];
  return {json: {
    scenario: typeof item?.json?.scenario === "string" ? item.json.scenario : "",
    contractRuntimeVersion: typeof result?.contractRuntimeVersion === "string" ? result.contractRuntimeVersion : "",
    acquisitionValid: result?.acquisitionValidation?.valid === true,
    candidateValid: candidates.length > 0 && candidates.every((entry) => entry?.valid === true),
    evidenceBatchValid: result?.evidenceBatchValidation?.valid === true,
    scannerValid: result?.scannerValidation?.valid === true,
    scannerInvocationAllowed: result?.scannerInvocation?.allowed === true,
    scannerInvocationReason: typeof result?.scannerInvocation?.reason === "string" ? result.scannerInvocation.reason : "CONTRACT_RESULT_INVALID",
    findingCount: Number.isSafeInteger(result?.findingCount) ? result.findingCount : 0,
    productionAllowed: false,
    callbackAttempted: false,
  }};
});`;
  const mode = "runOnceForAllItems";
  return [
    {parameters: {}, id: "ddt-contract-clone-manual-v1",
      name: "Contract Clone Manual Trigger", type: "n8n-nodes-base.manualTrigger",
      typeVersion: 1, position: [2240, 1440]},
    {parameters: {mode, jsCode: inputCode}, id: "ddt-contract-clone-input-v1",
      name: "Contract Clone Deterministic Input", type: "n8n-nodes-base.code",
      typeVersion: 2, position: [2460, 1440]},
    {parameters: {mode, jsCode: gateCode}, id: "ddt-contract-clone-runtime-v1",
      name: "Contract Runtime Validation Gate", type: "n8n-nodes-base.code",
      typeVersion: 2, position: [2680, 1440]},
    {parameters: {mode, jsCode: guardCode}, id: "ddt-contract-clone-guard-v1",
      name: "Contract Production Guard — Hard False", type: "n8n-nodes-base.code",
      typeVersion: 2, position: [2900, 1440]},
    {parameters: {mode, jsCode: summaryCode}, id: "ddt-contract-clone-summary-v1",
      name: "Contract Integration Summary", type: "n8n-nodes-base.code",
      typeVersion: 2, position: [3120, 1440]},
  ];
}

function sanitizeLiveNode(node) {
  const clean = JSON.parse(JSON.stringify(node));
  delete clean.credentials;
  delete clean.webhookId;
  if (clean.type === "n8n-nodes-base.webhook") {
    clean.disabled = true;
    clean.parameters = {...clean.parameters, path: SAFE_WEBHOOK_PATH};
  }
  if (clean.type === "n8n-nodes-base.httpRequest" ||
      clean.type.startsWith("@n8n/n8n-nodes-langchain.")) {
    clean.disabled = true;
  }
  return clean;
}

function createClone(sourceBytes, bundle) {
  if (sha256(sourceBytes) !== SOURCE_SHA256) {
    throw new Error("SOURCE_EXPORT_SHA256_MISMATCH");
  }
  const source = JSON.parse(sourceBytes.toString("utf8"));
  const added = integrationNodes(bundle);
  const connections = JSON.parse(JSON.stringify(source.connections || {}));
  for (let index = 0; index < added.length - 1; index++) {
    connections[added[index].name] = {main: [[{node: added[index + 1].name,
      type: "main", index: 0}]]};
  }
  return {
    name: WORKFLOW_NAME,
    nodes: [...source.nodes.map(sanitizeLiveNode), ...added],
    connections,
    settings: {executionOrder: "v1"},
    pinData: {},
    active: false,
  };
}

function main() {
  const sourcePath = process.argv[2];
  if (!sourcePath) throw new Error("SOURCE_EXPORT_PATH_REQUIRED");
  const outputPath = process.argv[3] || path.join(ROOT, "workflows", OUTPUT_NAME);
  const sourceBytes = fs.readFileSync(path.resolve(sourcePath));
  const bundle = fs.readFileSync(path.join(ROOT, "generated",
      "n8n_contract_runtime.js"), "utf8");
  const clone = createClone(sourceBytes, bundle);
  fs.writeFileSync(path.resolve(outputPath), `${JSON.stringify(clone, null, 2)}\n`,
      "utf8");
}

if (require.main === module) main();

module.exports = {OUTPUT_NAME, SAFE_WEBHOOK_PATH, SOURCE_SHA256, WORKFLOW_NAME,
  createClone};
