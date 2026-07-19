"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const Ajv2020 = require("ajv/dist/2020");
const addFormats = require("ajv-formats");
const standaloneCode = require("ajv/dist/standalone").default;
const esbuild = require("esbuild");

const ROOT = path.resolve(__dirname, "..");
const OUTPUT_NAME =
  "MarkaKalkan Dijital Dedektif - Open Web Acquisition Pilot - V1.json";
const WORKFLOW_NAME =
  "MarkaKalkan Dijital Dedektif — OPEN WEB ACQUISITION PILOT — V1";
const SCHEMAS = ["acquisition_result", "candidate_source",
  "structured_evidence"];

function standaloneAdapter(directory) {
  const ajv = new Ajv2020({allErrors: true, strict: true, code: {source: true}});
  addFormats(ajv);
  for (const name of SCHEMAS) {
    ajv.addSchema(JSON.parse(fs.readFileSync(path.join(ROOT, "schemas",
        `${name}.schema.json`), "utf8")));
  }
  const exportsMap = Object.fromEntries(SCHEMAS.map((name) =>
    [name, `${name}.schema.json`]));
  fs.writeFileSync(path.join(directory, "standalone_validators.js"),
      standaloneCode(ajv, exportsMap));
  const adapter = `"use strict";
const validators = require("./standalone_validators");
const {issue, result} = require(${JSON.stringify(path.join(ROOT,
      "validators", "validator_result.js"))});
function safePath(error) {
  const base = String(error.instancePath || "").replace(/^\\//, "").replace(/\\//g, ".");
  if (error.keyword === "required") return [base, error.params && error.params.missingProperty].filter(Boolean).join(".");
  if (error.keyword === "additionalProperties") return [base, error.params && error.params.additionalProperty].filter(Boolean).join(".");
  return base || "$";
}
function validateSchema(name, value) {
  const validate = validators[name];
  try {
    if (typeof validate !== "function") return result({errors:[issue("SCHEMA_NAME_UNSUPPORTED","$","Schema unsupported.")]});
    if (validate(value)) return result();
    return result({errors:(validate.errors || []).map((error) => issue("SCHEMA_" + String(error.keyword).toUpperCase(), safePath(error), "Schema validation failed."))});
  } catch (_) { return result({errors:[issue("SCHEMA_VALIDATION_EXCEPTION","$","Schema validation failed safely.")]}); }
}
module.exports = {validateSchema};
`;
  fs.writeFileSync(path.join(directory, "schema_engine.js"), adapter);
}

async function pilotBundle() {
  const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(),
      "ddt-open-web-pilot-"));
  try {
    standaloneAdapter(tempDirectory);
    const schemaSource = path.resolve(ROOT, "validators", "schema_engine.js");
    const result = await esbuild.build({
      absWorkingDir: path.resolve(ROOT, "../.."),
      entryPoints: [path.join(ROOT, "open_web", "pilot_runtime_entry.js")],
      bundle: true, write: false, format: "iife",
      globalName: "MarkaKalkanOpenWebPilot", platform: "neutral",
      target: "es2022", minify: false, sourcemap: false,
      legalComments: "none", charset: "utf8",
      plugins: [{name: "open-web-pilot-aliases", setup(build) {
        build.onResolve({filter: /^node:crypto$/}, () =>
          ({path: path.join(ROOT, "build", "crypto_shim.js")}));
        build.onResolve({filter: /schema_engine$/}, (args) => {
          const resolved = path.resolve(args.resolveDir,
              args.path + (path.extname(args.path) ? "" : ".js"));
          return resolved === schemaSource ?
            {path: path.join(tempDirectory, "schema_engine.js")} : null;
        });
        build.onResolve({filter: /^ajv\/dist\/runtime\/ucs2length$/}, () =>
          ({path: require.resolve("ajv/dist/runtime/ucs2length", {paths: [ROOT]})}));
        build.onResolve({filter: /^ajv-formats\/dist\/formats$/}, () =>
          ({path: require.resolve("ajv-formats/dist/formats", {paths: [ROOT]})}));
      }}],
    });
    const relativeTemp = path.relative(ROOT, tempDirectory).replace(/\\/g, "/");
    return result.outputFiles[0].text.replace(/\r\n/g, "\n")
        .split(tempDirectory.replace(/\\/g, "/")).join(".pilot-build-tmp")
        .split(tempDirectory).join(".pilot-build-tmp")
        .split(relativeTemp).join(".pilot-build-tmp")
        .replace(/ddt-open-web-pilot-[A-Za-z0-9]+/g, ".pilot-build-tmp")
        .replace(/module\.exports/g, 'module["exports"]')
        .replace(/__require/g, "__loadBundledModule")
        .replace(/require\(/g, "bundledModule(");
  } finally {
    fs.rmSync(tempDirectory, {recursive: true, force: true});
  }
}

function workflowObject(bundle) {
  const mode = "runOnceForAllItems";
  const inputCode = `void $input.all();
return [{json: {task: {
  taskId: "open-web-acquisition-pilot-v1",
  tenantId: "tenant-open-web-pilot",
  brandId: "brand-open-web-pilot",
  taskType: "open_web_acquisition_pilot",
  target: "https://example.com/",
  priority: "normal",
  createdAt: "2026-07-19T00:00:00.000Z"
}, executionId: String($execution.id)}}];`;
  const taskGateCode = `${bundle}
return $input.all().flatMap((item) => {
  const result = MarkaKalkanOpenWebPilot.validateTaskEnvelope(item?.json?.task);
  if (result.valid !== true) return [];
  return [{json: {task: result.snapshot,
    executionId: String(item.json.executionId), taskEnvelopeValid: true,
    productionAllowed: false, callbackAttempted: false}}];
});`;
  const urlCode = `${bundle}
return $input.all().flatMap((item) => {
  const policy = MarkaKalkanOpenWebPilot.validateOpenWebUrl(
    {url: item?.json?.task?.target});
  if (policy.valid !== true) return [];
  return [{json: {...item.json, normalizedUrl: policy.normalizedUrl,
    urlPolicyValid: true}}];
});`;
  const responseCode = `${bundle}
return $input.all().map((item) => {
  const json = item?.json && typeof item.json === "object" ? item.json : {};
  const artifacts = MarkaKalkanOpenWebPilot.buildOpenWebArtifacts({
    task: json.task, executionId: json.executionId, response: json,
    capturedAt: new Date().toISOString()});
  if (artifacts.valid !== true) return {json: {
    task: json.task, executionId: json.executionId,
    normalizedUrl: json.normalizedUrl,
    taskEnvelopeValid: json.taskEnvelopeValid === true,
    urlPolicyValid: json.urlPolicyValid === true,
    captureValid: false, reason: "HTTP_RESPONSE_INVALID",
    errorCode: typeof artifacts.errorCode === "string"
      ? artifacts.errorCode : "HTTP_RESPONSE_INVALID",
    errorPath: typeof artifacts.errorPath === "string"
      ? artifacts.errorPath : "$.response",
    networkFetchPerformed: true, productionAllowed: false,
    callbackAttempted: false}};
  return {json: {task: json.task, executionId: json.executionId,
    normalizedUrl: json.normalizedUrl,
    taskEnvelopeValid: json.taskEnvelopeValid === true,
    urlPolicyValid: json.urlPolicyValid === true,
    captureValid: true, artifacts, networkFetchPerformed: true,
    productionAllowed: false, callbackAttempted: false}};
});`;
  const contractCode = `${bundle}
return $input.all().map((item) => {
  if (item?.json?.captureValid !== true) return {json: {...item.json,
    contractGateRun: false}};
  const validations = MarkaKalkanOpenWebPilot.validateOpenWebArtifacts(
    item?.json?.artifacts);
  if (validations.valid !== true) return {json: {
    task: item.json.task, executionId: item.json.executionId,
    normalizedUrl: item.json.normalizedUrl,
    taskEnvelopeValid: item.json.taskEnvelopeValid === true,
    urlPolicyValid: item.json.urlPolicyValid === true,
    captureValid: true, contractValid: false,
    reason: "CONTRACT_VALIDATION_INVALID",
    errorCode: "CONTRACT_VALIDATION_INVALID", errorPath: "$.artifacts",
    networkFetchPerformed: true, productionAllowed: false,
    callbackAttempted: false, contractGateRun: true}};
  return {json: {...item.json, validations, contractValid: true,
    contractGateRun: true}};
});`;
  const summaryCode = `return $input.all().map((item) => {
  const json = item.json;
  if (json.captureValid !== true || json.contractValid !== true) {
    return {json: {taskId: typeof json.task?.taskId === "string"
      ? json.task.taskId : "", executionId: typeof json.executionId === "string"
      ? json.executionId : "", normalizedUrl: typeof json.normalizedUrl === "string"
      ? json.normalizedUrl : "", taskEnvelopeValid: json.taskEnvelopeValid === true,
      urlPolicyValid: json.urlPolicyValid === true,
      captureValid: json.captureValid === true, reason: typeof json.reason === "string"
      ? json.reason : "HTTP_RESPONSE_INVALID",
      errorCode: typeof json.errorCode === "string" ? json.errorCode
        : "HTTP_RESPONSE_INVALID", errorPath: typeof json.errorPath === "string"
        ? json.errorPath : "$.response", scannerStage: "NOT_RUN", findingCount: 0,
      networkFetchPerformed: json.networkFetchPerformed === true,
      productionAllowed: false, callbackAttempted: false}};
  }
  const capture = json.artifacts.capture;
  return {json: {taskId: json.task.taskId,
    executionId: json.executionId, normalizedUrl: capture.normalizedUrl,
    taskEnvelopeValid: json.taskEnvelopeValid === true,
    urlPolicyValid: json.urlPolicyValid === true,
    captureValid: true,
    httpStatus: capture.statusCode, contentType: capture.contentType,
    rawBodyBytes: capture.rawBodyBytes,
    visibleTextBytes: capture.visibleTextBytes,
    contentSha256: capture.contentSha256,
    visibleTextSha256: capture.visibleTextSha256,
    sourceId: capture.sourceId, snapshotId: capture.snapshotId,
    acquisitionValid: json.validations.acquisitionValidation.valid === true,
    candidateValid: json.validations.candidateValidation.valid === true,
    evidenceBatchValid: json.validations.evidenceBatchValidation.valid === true,
    scannerStage: "NOT_RUN", findingCount: 0,
    networkFetchPerformed: json.networkFetchPerformed === true,
    productionAllowed: false, callbackAttempted: false}};
});`;
  const nodes = [
    {parameters: {}, id: "ddt-open-web-manual-v1", name: "Manual Trigger",
      type: "n8n-nodes-base.manualTrigger", typeVersion: 1, position: [0, 0]},
    {parameters: {mode, jsCode: inputCode}, id: "ddt-open-web-task-v1",
      name: "Pilot Task Input", type: "n8n-nodes-base.code", typeVersion: 2,
      position: [220, 0]},
    {parameters: {mode, jsCode: taskGateCode}, id: "ddt-open-web-task-gate-v1",
      name: "Task Envelope Gate", type: "n8n-nodes-base.code", typeVersion: 2,
      position: [440, 0]},
    {parameters: {mode, jsCode: urlCode}, id: "ddt-open-web-url-policy-v1",
      name: "URL Policy and Candidate Seed", type: "n8n-nodes-base.code",
      typeVersion: 2, position: [660, 0]},
    {parameters: {method: "GET", url: "={{ $json.normalizedUrl }}",
      sendHeaders: false, sendBody: false,
      options: {timeout: 15000, redirect: {redirect: {followRedirects: false,
        maxRedirects: 0}}, response: {response: {fullResponse: true,
        neverError: true, responseFormat: "text"}}}},
    id: "ddt-open-web-http-v1", name: "Open Web GET — example.com only",
    type: "n8n-nodes-base.httpRequest", typeVersion: 4.2,
    position: [880, 100]},
    {parameters: {mode: "combine", combineBy: "combineByPosition",
      options: {}}, id: "ddt-open-web-merge-v1",
    name: "Merge Policy and HTTP Response", type: "n8n-nodes-base.merge",
    typeVersion: 3.2, position: [1100, 0]},
    {parameters: {mode, jsCode: responseCode},
      id: "ddt-open-web-response-v1",
      name: "Response Guard and Evidence Capture", type: "n8n-nodes-base.code",
      typeVersion: 2, position: [1320, 0]},
    {parameters: {mode, jsCode: contractCode},
      id: "ddt-open-web-contract-v1",
      name: "Acquisition Candidate Evidence Contract Gate",
      type: "n8n-nodes-base.code", typeVersion: 2, position: [1540, 0]},
    {parameters: {mode, jsCode: summaryCode},
      id: "ddt-open-web-summary-v1", name: "Acquisition Pilot Summary",
      type: "n8n-nodes-base.code", typeVersion: 2, position: [1760, 0]},
  ];
  const link = (node, index = 0) => ({node, type: "main", index});
  const connections = {
    "Manual Trigger": {main: [[link("Pilot Task Input")]]},
    "Pilot Task Input": {main: [[link("Task Envelope Gate")]]},
    "Task Envelope Gate": {main: [[link("URL Policy and Candidate Seed")]]},
    "URL Policy and Candidate Seed": {main: [[
      link("Open Web GET — example.com only"),
      link("Merge Policy and HTTP Response", 0)]]},
    "Open Web GET — example.com only": {main: [[
      link("Merge Policy and HTTP Response", 1)]]},
    "Merge Policy and HTTP Response": {main: [[
      link("Response Guard and Evidence Capture")]]},
    "Response Guard and Evidence Capture": {main: [[
      link("Acquisition Candidate Evidence Contract Gate")]]},
    "Acquisition Candidate Evidence Contract Gate": {main: [[
      link("Acquisition Pilot Summary")]]},
  };
  return {name: WORKFLOW_NAME, nodes, connections,
    settings: {executionOrder: "v1"}, pinData: {}, active: false};
}

async function serializeWorkflow() {
  return `${JSON.stringify(workflowObject(await pilotBundle()), null, 2)}\n`;
}

async function main() {
  const outputPath = process.argv[2] || path.join(ROOT, "workflows", OUTPUT_NAME);
  fs.writeFileSync(path.resolve(outputPath), await serializeWorkflow(), "utf8");
}

if (require.main === module) main().catch((error) => {
  process.stderr.write("OPEN_WEB_PILOT_GENERATION_FAILED\n");
  process.exitCode = 1;
});

module.exports = {OUTPUT_NAME, WORKFLOW_NAME, pilotBundle, serializeWorkflow,
  workflowObject};
