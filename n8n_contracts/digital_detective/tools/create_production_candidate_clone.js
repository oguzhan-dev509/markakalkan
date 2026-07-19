"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const INTEGRATION_SOURCE_SHA256 =
  "c64c3535e6248b3b7b97a4cb6057dfed858f8483f636e65a20f53d30d0be4d0d";
const LIVE_SOURCE_SHA256 =
  "d8bdfbfa768c59751e1547a68aa64c9580d6950aaacf642386723650f8553480";
const LIVE_AGENT_PROMPTS_SHA256 =
  "bbed2ac46bb873e4045a2099b406d3cefd4f550eb5fc0ac0e4a0bf9716d85a32";
const OUTPUT_NAME =
  "MarkaKalkan Dijital Dedektif 12 Ajan - Production Candidate Clone - V1.json";
const WORKFLOW_NAME =
  "MarkaKalkan Dijital Dedektif 12 Ajan — PRODUCTION CANDIDATE — V1";
const SAFE_WEBHOOK_PATH =
  "markakalkan/digital-detective/production-candidate-v1";
const CLONE_NODE_PREFIX = "ddt-contract-clone-";
const CANDIDATE_NODE_PREFIX = "ddt-production-candidate-";

const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");
const clone = (value) => JSON.parse(JSON.stringify(value));
const readJson = (location) => JSON.parse(fs.readFileSync(location, "utf8"));

function promptHash(workflow) {
  const payload = workflow.nodes
      .filter((node) => node.type === "@n8n/n8n-nodes-langchain.agent")
      .map((node) => [node.name, node.parameters])
      .sort((left, right) => left[0].localeCompare(right[0]));
  return sha256(JSON.stringify(payload));
}

function deterministicTask() {
  const fixtureDirectory = path.join(ROOT, "fixtures", "no_signal");
  return {
    taskId: "pc-v1-safe-test",
    tenantId: "tenant-production-candidate-test",
    brandId: "brand-production-candidate-test",
    taskType: "digital_detective_contract_candidate",
    target: "MarkaKalkan Test Markası / MK Test Ürünü / Açık Web",
    priority: "normal",
    country: "Türkiye",
    city: "İstanbul",
    searchTerms: ["example.com", "mk-production-candidate-v1"],
    acquisitionResult: readJson(path.join(fixtureDirectory,
        "acquisition_result.json")),
    candidates: readJson(path.join(fixtureDirectory,
        "candidate_sources.json")),
    evidences: readJson(path.join(fixtureDirectory,
        "structured_evidence.json")),
    scannerResult: readJson(path.join(fixtureDirectory,
        "scanner_result.json")),
    productionCallback: false,
  };
}

function candidateNodes(bundle) {
  const inputCode = `const INTEGRATION_SOURCE_SHA256 = "${INTEGRATION_SOURCE_SHA256}";
const LIVE_SOURCE_SHA256 = "${LIVE_SOURCE_SHA256}";
void INTEGRATION_SOURCE_SHA256;
void LIVE_SOURCE_SHA256;
void $input.all();
return [{json: ${JSON.stringify(deterministicTask())}}];`;
  const gateCode = `${bundle}
const inputItems = $input.all();
return inputItems.map((item) => {
  const task = item?.json && typeof item.json === "object" ? item.json : {};
  try {
    const contractResult = MarkaKalkanDdtRuntime.runContractPipeline(task);
    return {json: {...task, contractResult}};
  } catch (_) {
    return {json: {...task, contractResult: {valid: false,
      errorCode: "PRODUCTION_CANDIDATE_PREFLIGHT_EXCEPTION",
      scannerInvocation: {allowed: false,
        reason: "PRODUCTION_CANDIDATE_PREFLIGHT_EXCEPTION"},
      findingCount: 0}}};
  }
});`;
  const guardCode = `const inputItems = $input.all();
return inputItems.map((item) => ({json: {
  ...(item?.json && typeof item.json === "object" ? item.json : {}),
  productionAllowed: false,
  callbackAttempted: false,
}}));`;
  const summaryCode = `const inputItems = $input.all();
return inputItems.map((item) => {
  const task = item?.json && typeof item.json === "object" ? item.json : {};
  const result = task.contractResult && typeof task.contractResult === "object"
    ? task.contractResult : {};
  const candidates = Array.isArray(result.candidateValidations)
    ? result.candidateValidations : [];
  return {json: {
    taskId: typeof task.taskId === "string" ? task.taskId : "",
    tenantId: typeof task.tenantId === "string" ? task.tenantId : "",
    brandId: typeof task.brandId === "string" ? task.brandId : "",
    taskType: typeof task.taskType === "string" ? task.taskType : "",
    target: typeof task.target === "string" ? task.target : "",
    priority: typeof task.priority === "string" ? task.priority : "normal",
    country: typeof task.country === "string" ? task.country : "",
    city: typeof task.city === "string" ? task.city : "",
    searchTerms: Array.isArray(task.searchTerms) ? task.searchTerms : [],
    contractRuntimeVersion: typeof result.contractRuntimeVersion === "string"
      ? result.contractRuntimeVersion : "",
    acquisitionValid: result?.acquisitionValidation?.valid === true,
    candidateValid: candidates.length > 0 &&
      candidates.every((entry) => entry?.valid === true),
    evidenceBatchValid: result?.evidenceBatchValidation?.valid === true,
    scannerValid: result?.scannerValidation?.valid === true,
    scannerInvocationAllowed: result?.scannerInvocation?.allowed === true,
    scannerInvocationReason: typeof result?.scannerInvocation?.reason === "string"
      ? result.scannerInvocation.reason : "CONTRACT_RESULT_INVALID",
    findingCount: Number.isSafeInteger(result.findingCount)
      ? result.findingCount : 0,
    expectedAgentCount: 12,
    enabledAgentCount: 12,
    enabledModelCount: 13,
    disabledCallbackCount: 12,
    candidateMode: true,
    productionAllowed: false,
    callbackAttempted: false,
  }};
});`;
  const routeCode = `const inputItems = $input.all();
return inputItems.filter((item) =>
  item?.json?.scannerInvocationAllowed === true &&
  item?.json?.scannerInvocationReason === "READY" &&
  item?.json?.candidateMode === true &&
  item?.json?.productionAllowed === false &&
  item?.json?.callbackAttempted === false);`;
  const mode = "runOnceForAllItems";
  return [
    {parameters: {}, id: `${CANDIDATE_NODE_PREFIX}manual-v1`,
      name: "Production Candidate Manual Trigger",
      type: "n8n-nodes-base.manualTrigger", typeVersion: 1,
      position: [2240, 1440]},
    {parameters: {mode, jsCode: inputCode},
      id: `${CANDIDATE_NODE_PREFIX}input-v1`,
      name: "Production Candidate Deterministic Task",
      type: "n8n-nodes-base.code", typeVersion: 2,
      position: [2460, 1440]},
    {parameters: {mode, jsCode: gateCode},
      id: `${CANDIDATE_NODE_PREFIX}preflight-v1`,
      name: "Contract Preflight Gate",
      type: "n8n-nodes-base.code", typeVersion: 2,
      position: [2680, 1440]},
    {parameters: {mode, jsCode: guardCode},
      id: `${CANDIDATE_NODE_PREFIX}guard-v1`,
      name: "Production Candidate Guard — Hard False",
      type: "n8n-nodes-base.code", typeVersion: 2,
      position: [2900, 1440]},
    {parameters: {mode, jsCode: summaryCode},
      id: `${CANDIDATE_NODE_PREFIX}summary-v1`,
      name: "Production Candidate Preflight Summary",
      type: "n8n-nodes-base.code", typeVersion: 2,
      position: [3120, 1440]},
    {parameters: {mode, jsCode: routeCode},
      id: `${CANDIDATE_NODE_PREFIX}route-v1`,
      name: "Contract Preflight Route",
      type: "n8n-nodes-base.code", typeVersion: 2,
      position: [3340, 1440]},
  ];
}

function withoutTargets(value, removedNames) {
  if (!Array.isArray(value)) return value;
  return value.map((branch) => Array.isArray(branch)
    ? branch.filter((edge) => !removedNames.has(edge?.node)) : branch);
}

function createCandidate(integrationBytes, liveBytes, bundle) {
  if (sha256(integrationBytes) !== INTEGRATION_SOURCE_SHA256) {
    throw new Error("INTEGRATION_SOURCE_SHA256_MISMATCH");
  }
  if (sha256(liveBytes) !== LIVE_SOURCE_SHA256) {
    throw new Error("LIVE_SOURCE_SHA256_MISMATCH");
  }
  const integration = JSON.parse(integrationBytes.toString("utf8"));
  const live = JSON.parse(liveBytes.toString("utf8"));
  if (promptHash(live) !== LIVE_AGENT_PROMPTS_SHA256) {
    throw new Error("LIVE_AGENT_PROMPTS_SHA256_MISMATCH");
  }
  const liveById = new Map(live.nodes.map((node) => [node.id, node]));
  const baseNodes = integration.nodes
      .filter((node) => !node.id.startsWith(CLONE_NODE_PREFIX))
      .map((sourceNode) => {
        const node = clone(sourceNode);
        const liveNode = liveById.get(node.id);
        if (!liveNode) throw new Error(`LIVE_NODE_MISSING:${node.id}`);
        node.parameters = clone(liveNode.parameters);
        delete node.credentials;
        delete node.webhookId;
        if (liveNode.disabled === true) node.disabled = true;
        else delete node.disabled;
        if (node.type === "n8n-nodes-base.webhook") {
          node.disabled = true;
          node.parameters.path = SAFE_WEBHOOK_PATH;
        } else if (node.type === "n8n-nodes-base.httpRequest") {
          node.disabled = true;
        } else if (node.type === "@n8n/n8n-nodes-langchain.lmChatOpenAi") {
          delete node.disabled;
          node.credentials = clone(liveNode.credentials);
        } else if (node.type === "@n8n/n8n-nodes-langchain.agent" ||
            node.type ===
              "@n8n/n8n-nodes-langchain.outputParserStructured") {
          delete node.disabled;
        }
        return node;
      });
  const callbacks = new Set(baseNodes
      .filter((node) => node.type === "n8n-nodes-base.httpRequest")
      .map((node) => node.name));
  const oldCloneNames = new Set(integration.nodes
      .filter((node) => node.id.startsWith(CLONE_NODE_PREFIX))
      .map((node) => node.name));
  const removedNames = new Set([...callbacks, ...oldCloneNames]);
  const connections = {};
  for (const [sourceName, outputs] of Object.entries(integration.connections || {})) {
    if (removedNames.has(sourceName)) continue;
    connections[sourceName] = {};
    for (const [outputType, branches] of Object.entries(outputs)) {
      connections[sourceName][outputType] = withoutTargets(branches, removedNames);
    }
  }
  const added = candidateNodes(bundle);
  for (let index = 0; index < added.length - 1; index++) {
    connections[added[index].name] = {main: [[{
      node: added[index + 1].name, type: "main", index: 0,
    }]]};
  }
  connections[added[added.length - 1].name] = {main: [[{
    node: "Ajan Görev Zarfını Hazırla", type: "main", index: 0,
  }]]};
  return {
    name: WORKFLOW_NAME,
    nodes: [...baseNodes, ...added],
    connections,
    settings: {executionOrder: "v1"},
    pinData: {},
    active: false,
  };
}

function main() {
  const integrationPath = process.argv[2] || path.join(ROOT, "workflows",
      "MarkaKalkan Dijital Dedektif 12 Ajan - Contract Integration Clone - V1.json");
  const livePath = process.argv[3];
  if (!livePath) throw new Error("LIVE_SOURCE_EXPORT_PATH_REQUIRED");
  const outputPath = process.argv[4] || path.join(ROOT, "workflows", OUTPUT_NAME);
  const candidate = createCandidate(fs.readFileSync(path.resolve(integrationPath)),
      fs.readFileSync(path.resolve(livePath)), fs.readFileSync(path.join(ROOT,
          "generated", "n8n_contract_runtime.js"), "utf8"));
  fs.writeFileSync(path.resolve(outputPath),
      `${JSON.stringify(candidate, null, 2)}\n`, "utf8");
}

if (require.main === module) main();

module.exports = {INTEGRATION_SOURCE_SHA256, LIVE_AGENT_PROMPTS_SHA256,
  LIVE_SOURCE_SHA256, OUTPUT_NAME, SAFE_WEBHOOK_PATH, WORKFLOW_NAME,
  createCandidate, promptHash};
