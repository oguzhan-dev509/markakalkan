"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const {validateOpenWebUrl} = require("../open_web/url_policy");
const {MAX_RAW_BODY_BYTES, buildOpenWebArtifacts, guardOpenWebResponse,
  sha256, validateOpenWebArtifacts, visibleTextFromHtml} =
  require("../open_web/response_evidence");
const {OUTPUT_NAME, WORKFLOW_NAME, serializeWorkflow} =
  require("../tools/create_open_web_acquisition_pilot");
const {runCodeNodeInIsolatedContext} =
  require("./helpers/isolated_n8n_vm");

const ROOT = path.resolve(__dirname, "..");
const WORKFLOW_PATH = path.join(ROOT, "workflows", OUTPUT_NAME);
const HTML = "<!doctype html><html><head><title>Example Domain</title>" +
  "<style>hidden style</style><script>hidden script</script></head>" +
  "<body><h1>Example&nbsp;Domain</h1><p>Safe &amp; public.</p>" +
  "<noscript>hidden noscript</noscript></body></html>";
const TASK = {taskId: "open-web-acquisition-pilot-v1",
  tenantId: "tenant-open-web-pilot", brandId: "brand-open-web-pilot",
  taskType: "open_web_acquisition_pilot", target: "https://example.com/",
  priority: "normal", createdAt: "2026-07-19T00:00:00.000Z"};
const response = (overrides = {}) => ({statusCode: 200,
  headers: {"content-type": "text/html; charset=UTF-8",
    "content-length": String(Buffer.byteLength(HTML, "utf8"))},
  body: HTML, finalUrl: "https://example.com/", ...overrides});
const workflow = () => JSON.parse(fs.readFileSync(WORKFLOW_PATH, "utf8"));
const node = (name) => workflow().nodes.find((entry) => entry.name === name);

test("URL policy accepts and normalizes only example.com HTTPS", () => {
  assert.deepEqual(validateOpenWebUrl({url: "https://example.com:443/a/../"}),
      {valid: true, reason: "URL_POLICY_READY",
        normalizedUrl: "https://example.com/"});
});

for (const [name, url] of [
  ["HTTP", "http://example.com/"],
  ["other host", "https://example.org/"],
  ["subdomain", "https://www.example.com/"],
  ["localhost", "https://localhost/"],
  ["IPv4", "https://127.0.0.1/"],
  ["IPv6", "https://[::1]/"],
  ["userinfo", "https://user:pass@example.com/"],
  ["custom port", "https://example.com:444/"],
  ["fragment", "https://example.com/#x"],
  ["protocol relative", "//example.com/"],
  ["trailing dot", "https://example.com./"],
  ["encoded host", "https://%65xample.com/"],
]) {
  test(`URL policy rejects ${name}`, () => {
    assert.equal(validateOpenWebUrl({url}).valid, false);
  });
}

test("URL policy rejects inherited and accessor values without getter", () => {
  assert.equal(validateOpenWebUrl(Object.create({url: TASK.target})).valid,
      false);
  let calls = 0;
  const accessor = {};
  Object.defineProperty(accessor, "url", {get() { calls++; return TASK.target; }});
  assert.equal(validateOpenWebUrl(accessor).valid, false);
  assert.equal(calls, 0);
});

test("URL policy descriptor proxy exception fails closed", () => {
  const proxy = new Proxy({url: TASK.target}, {getOwnPropertyDescriptor() {
    throw new Error("PRIVATE_DESCRIPTOR");
  }});
  assert.doesNotThrow(() => validateOpenWebUrl(proxy));
  assert.equal(validateOpenWebUrl(proxy).valid, false);
});

test("URL policy accepts a foreign-realm own data property", () => {
  const realm = vm.createContext({serialized: JSON.stringify({url: TASK.target})});
  const foreign = new vm.Script("JSON.parse(serialized)").runInContext(realm);
  assert.equal(validateOpenWebUrl(foreign).valid, true);
});

test("response guard accepts a complete real-shaped response", () => {
  const output = guardOpenWebResponse(response());
  assert.equal(output.valid, true);
  assert.equal(output.statusCode, 200);
  assert.equal(output.pageTitle, "Example Domain");
  assert.equal(output.rawBodyBytes, Buffer.byteLength(HTML));
  assert.equal(output.contentSha256, sha256(HTML));
});

for (const [name, value, reason] of [
  ["404", response({statusCode: 404}), "HTTP_STATUS_INVALID"],
  ["500", response({statusCode: 500}), "HTTP_STATUS_INVALID"],
  ["wrong content type", response({headers: {"content-type": "image/png"}}),
    "CONTENT_TYPE_INVALID"],
  ["empty body", response({body: "", headers: {"content-type": "text/html"}}),
    "EMPTY_BODY"],
  ["oversized body", response({body: "a".repeat(MAX_RAW_BODY_BYTES + 1),
    headers: {"content-type": "text/plain"}}), "BODY_TOO_LARGE"],
  ["redirect host", response({finalUrl: "https://example.org/"}),
    "FINAL_URL_INVALID"],
  ["length mismatch", response({headers: {"content-type": "text/html",
    "content-length": "1"}}), "CONTENT_LENGTH_MISMATCH"],
]) {
  test(`response guard rejects ${name}`, () => {
    const output = guardOpenWebResponse(value);
    assert.equal(output.reason, "HTTP_RESPONSE_INVALID");
    assert.equal(output.errorCode, reason);
  });
}

test("response guard rejects inherited/accessor/proxy response fields", () => {
  const inherited = Object.assign(Object.create({statusCode: 200}), response());
  delete inherited.statusCode;
  assert.equal(guardOpenWebResponse(inherited).valid, false);
  let calls = 0;
  const accessor = response();
  delete accessor.body;
  Object.defineProperty(accessor, "body", {get() { calls++; return HTML; }});
  assert.equal(guardOpenWebResponse(accessor).valid, false);
  assert.equal(calls, 0);
  const proxy = new Proxy(response(), {getOwnPropertyDescriptor() {
    throw new Error("PRIVATE_RESPONSE");
  }});
  assert.equal(guardOpenWebResponse(proxy).valid, false);
});

test("visible text removes active content and normalizes entities", () => {
  assert.equal(visibleTextFromHtml(HTML),
      "Example Domain Example Domain Safe & public.");
  assert.doesNotMatch(visibleTextFromHtml(HTML), /hidden|<[^>]+>/);
});

test("pure SHA-256 matches known vectors", () => {
  assert.equal(sha256(""),
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
  assert.equal(sha256("abc"),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
});

test("real-shaped response produces valid contract artifacts", () => {
  const artifacts = buildOpenWebArtifacts({task: TASK,
    executionId: "execution-001", response: response(),
    capturedAt: "2026-07-19T01:00:00.000Z"});
  assert.equal(artifacts.valid, true);
  const validations = validateOpenWebArtifacts(artifacts);
  assert.equal(validations.valid, true);
  assert.equal(validations.acquisitionValidation.valid, true);
  assert.equal(validations.candidateValidation.valid, true);
  assert.equal(validations.evidenceBatchValidation.valid, true);
  assert.equal(artifacts.acquisitionResult.fixtureMetadata, null);
  assert.equal("scannerResult" in artifacts, false);
  assert.equal("findings" in artifacts, false);
});

test("source and snapshot IDs are deterministic and execution scoped", () => {
  const make = (taskId, executionId) => buildOpenWebArtifacts({
    task: {...TASK, taskId}, executionId, response: response(),
    capturedAt: "2026-07-19T01:00:00.000Z"});
  const first = make("task-a", "execution-a");
  const repeat = make("task-a", "execution-a");
  const otherTask = make("task-b", "execution-a");
  const otherExecution = make("task-a", "execution-b");
  assert.equal(first.candidate.sourceId, repeat.candidate.sourceId);
  assert.equal(first.evidences[0].snapshotId, repeat.evidences[0].snapshotId);
  assert.notEqual(first.candidate.sourceId, otherTask.candidate.sourceId);
  assert.notEqual(first.candidate.sourceId, otherExecution.candidate.sourceId);
});

test("response body is never mutated", () => {
  const value = response();
  const before = JSON.stringify(value);
  buildOpenWebArtifacts({task: TASK, executionId: "execution-001",
    response: value, capturedAt: "2026-07-19T01:00:00.000Z"});
  assert.equal(JSON.stringify(value), before);
});

test("workflow is passive and import-safe", () => {
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

test("workflow has one manual entry and one constrained HTTP GET", () => {
  const value = workflow();
  assert.equal(value.nodes.filter((entry) =>
    entry.type === "n8n-nodes-base.manualTrigger" && entry.disabled !== true).length, 1);
  const requests = value.nodes.filter((entry) =>
    entry.type === "n8n-nodes-base.httpRequest" && entry.disabled !== true);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].parameters.method, "GET");
  assert.equal(requests[0].parameters.url, "={{ $json.normalizedUrl }}");
  assert.equal(requests[0].parameters.options.timeout, 15000);
  assert.equal(requests[0].parameters.options.redirect.redirect.followRedirects,
      false);
});

test("workflow has no credential, AI, callback, webhook or embedded fixture", () => {
  const value = workflow();
  assert.equal(value.nodes.some((entry) => "credentials" in entry), false);
  assert.equal(value.nodes.some((entry) =>
    entry.type.startsWith("@n8n/n8n-nodes-langchain.") ||
    entry.type === "n8n-nodes-base.webhook"), false);
  const source = fs.readFileSync(WORKFLOW_PATH, "utf8");
  assert.doesNotMatch(source,
      /example\.com\/test-fixture|evidence:\/\/TEST_FIXTURE|scannerResult|findingKey/);
  assert.doesNotMatch(source, /productionAllowed\s*[:=]\s*true/);
  assert.doesNotMatch(source, /callbackAttempted\s*[:=]\s*true/);
  assert.doesNotMatch(source, /<!doctype|<html|Example Domain/);
});

test("workflow gates precede request and contract gate follows response", () => {
  const names = workflow().nodes.map((entry) => entry.name);
  const index = (name) => names.indexOf(name);
  assert.ok(index("Task Envelope Gate") <
    index("Open Web GET — example.com only"));
  assert.ok(index("URL Policy and Candidate Seed") <
    index("Open Web GET — example.com only"));
  assert.ok(index("Acquisition Candidate Evidence Contract Gate") >
    index("Response Guard and Evidence Capture"));
  assert.match(node("Acquisition Pilot Summary").parameters.jsCode,
      /scannerStage: "NOT_RUN"/);
});

test("URL policy code runs through the n8n membrane", () => {
  const output = runCodeNodeInIsolatedContext(
      node("URL Policy and Candidate Seed").parameters.jsCode,
      [{json: {task: TASK, executionId: "execution-001",
        taskEnvelopeValid: true, productionAllowed: false,
        callbackAttempted: false}}], {n8nLikeNullPrototypeMembrane: true});
  assert.equal(output.length, 1);
  assert.equal(output[0].json.normalizedUrl, TASK.target);
  assert.equal(output[0].json.urlPolicyValid, true);
});

function mergedItem(overrides = {}) {
  return {json: {task: TASK, executionId: "execution-001",
    taskEnvelopeValid: true, normalizedUrl: TASK.target, urlPolicyValid: true,
    productionAllowed: false, callbackAttempted: false,
    statusCode: 200, headers: {"content-type": ["text/html; charset=UTF-8"],
      "content-length": [Buffer.byteLength(HTML)]}, body: HTML, ...overrides}};
}

test("real n8n flat full-response shape produces exactly one capture item", () => {
  const output = runCodeNodeInIsolatedContext(
      node("Response Guard and Evidence Capture").parameters.jsCode,
      [mergedItem()], {n8nLikeNullPrototypeMembrane: true});
  assert.equal(output.length, 1);
  assert.equal(output[0].json.captureValid, true);
  assert.equal(output[0].json.artifacts.capture.visibleText.length > 0, true);
  assert.match(output[0].json.artifacts.capture.contentSha256, /^[a-f0-9]{64}$/);
  assert.equal(output[0].json.artifacts.candidate.sourceUrl, TASK.target);
  assert.equal(output[0].json.productionAllowed, false);
  assert.equal(output[0].json.callbackAttempted, false);
});

test("old nested response assumption is not silently accepted", () => {
  const nested = mergedItem({statusCode: undefined, headers: undefined,
    body: undefined, response: response()});
  const output = runCodeNodeInIsolatedContext(
      node("Response Guard and Evidence Capture").parameters.jsCode, [nested]);
  assert.equal(output.length, 1);
  assert.equal(output[0].json.captureValid, false);
  assert.equal(output[0].json.reason, "HTTP_RESPONSE_INVALID");
  assert.equal(output[0].json.errorPath, "$.statusCode");
});

test("flat HTTP fields win despite an unrelated nested collision", () => {
  const output = runCodeNodeInIsolatedContext(
      node("Response Guard and Evidence Capture").parameters.jsCode,
      [mergedItem({response: {statusCode: 500, body: "private"}})]);
  assert.equal(output.length, 1);
  assert.equal(output[0].json.captureValid, true);
});

for (const [name, patch, errorCode] of [
  ["missing statusCode", {statusCode: undefined}, "HTTP_STATUS_MISSING"],
  ["missing body", {body: undefined}, "HTTP_BODY_MISSING"],
]) {
  test(`${name} emits one body-free diagnostic item`, () => {
    const output = runCodeNodeInIsolatedContext(
        node("Response Guard and Evidence Capture").parameters.jsCode,
        [mergedItem(patch)]);
    assert.equal(output.length, 1);
    assert.equal(output[0].json.captureValid, false);
    assert.equal(output[0].json.reason, "HTTP_RESPONSE_INVALID");
    assert.equal(output[0].json.errorCode, errorCode);
    assert.equal("body" in output[0].json, false);
    assert.equal("artifacts" in output[0].json, false);
  });
}

test("diagnostic bypasses contract validation and reaches safe summary", () => {
  let items = runCodeNodeInIsolatedContext(
      node("Response Guard and Evidence Capture").parameters.jsCode,
      [mergedItem({body: undefined})]);
  items = runCodeNodeInIsolatedContext(
      node("Acquisition Candidate Evidence Contract Gate").parameters.jsCode,
      items);
  assert.equal(items.length, 1);
  assert.equal(items[0].json.contractGateRun, false);
  items = runCodeNodeInIsolatedContext(
      node("Acquisition Pilot Summary").parameters.jsCode, items);
  assert.equal(items.length, 1);
  assert.equal(items[0].json.scannerStage, "NOT_RUN");
  assert.equal(items[0].json.productionAllowed, false);
  assert.equal(items[0].json.callbackAttempted, false);
  assert.doesNotMatch(JSON.stringify(items), /<!doctype|<html|Example Domain/);
});

test("generator is OS-independent byte-for-byte deterministic", async () => {
  const first = await serializeWorkflow();
  const second = await serializeWorkflow();
  assert.equal(first, second);
  assert.equal(first, fs.readFileSync(WORKFLOW_PATH, "utf8"));
});

test("four verified workflows remain byte-for-byte unchanged", () => {
  const expected = new Map([
    ["MarkaKalkan Dijital Dedektif - Contract Fixture Harness - V1.json",
      "c073262e6a8078264d5653ba7042b86febfda6e34757a36d8f968e9295691e1b"],
    ["MarkaKalkan Dijital Dedektif 12 Ajan - Contract Integration Clone - V1.json",
      "c64c3535e6248b3b7b97a4cb6057dfed858f8483f636e65a20f53d30d0be4d0d"],
    ["MarkaKalkan Dijital Dedektif 12 Ajan - Production Candidate Clone - V1.json",
      "69f4e1b2222f8f1d00dd4ad04a4ac4630fa33cfa01d366002c85216342dfdc6f"],
    ["MarkaKalkan Dijital Dedektif - Task Envelope Gate Fixture - V1.json",
      "d2dc3a7ad7bb655a7c410324f6893b6292f9f6adc8c4bae8c1978bd2f0653f76"],
  ]);
  for (const [name, hash] of expected) {
    const bytes = fs.readFileSync(path.join(ROOT, "workflows", name));
    assert.equal(crypto.createHash("sha256").update(bytes).digest("hex"), hash);
  }
});
