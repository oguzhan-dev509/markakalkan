"use strict";

const fs = require("node:fs");
const path = require("node:path");

const {
  CHANNEL_CODES,
  DISPATCH_ENVELOPE_VERSION,
  PROVIDER_CODE,
  PROVIDER_RESULT_VERSION,
  RESULT_ENVELOPE_VERSION,
} = require("./contracts");
const {
  ADAPTER_CODE,
  CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
  CHANNEL_CODE: MARKETPLACE_CHANNEL_CODE,
} = require(
  "./acquisition/marketplace_limited_contract",
);

const WORKFLOW_NAME =
  "MarkaKalkan Public Lite Risk Scan Gateway - V1";
const WEBHOOK_PATH =
  "markakalkan/public-lite-risk-scan/run-created";
const CALLBACK_URL =
  "https://europe-west3-markakalkan-app.cloudfunctions.net/" +
  "receivePublicLiteRiskScanResult";
const WEBHOOK_HEADER = "X-MarkaKalkan-Token";
const RESULT_HEADER =
  "X-MarkaKalkan-Public-Lite-Result-Token";

const NODE_IDS = Object.freeze({
  note: "bb432ce7-90ff-5d1d-af35-341997c07219",
  webhook: "c7728da0-2240-5ca5-a4dc-b69bb8a2f839",
  validate: "5e8b7957-73a4-53e6-995b-7b5f61f129ca",
  receipt: "2410b42e-4c74-50e7-a8d4-04344bf4b2aa",
  respond: "90b2d358-0a64-56af-9a0f-fd1f4695e4f5",
  resultTemplateNote: "67ca64b2-90fc-57e6-bb69-b70dfdd92ff0",
  resultTemplate: "f8f88e33-e7cb-5d14-b53b-3df26402053f",
  acquisitionNote: "f28e745c-5ada-5797-be75-3485888e58be",
  acquisitionPlan: "992ddc46-ca2f-538d-92c7-f80f165ea71a",
  acquisitionGuard: "bca187f7-53d2-5029-876f-5e8c1391c7a7",
  acquisitionHttp: "1e0a46dd-1f4b-565d-9328-983104d683b0",
  normalizeMarketplace: "64b52842-44d8-544b-8535-7b1affcbe1a6",
  assembleProvider: "1730e571-1bc1-5c67-8ad9-d613853dd841",
});
const WORKFLOW_VERSION_ID =
  "7fe6860d-8f63-5c16-94e1-ef7a8245b7cb";
const WEBHOOK_ID =
  "9996c454-a741-5af2-9467-7ec6754e7bee";

function validatorCode() {
  return String.raw`const EXPECTED_KEYS = [
  "accessTier",
  "channelCodes",
  "contractVersion",
  "executionId",
  "expiresAt",
  "identityMode",
  "requestedAt",
  "scanMode",
  "scanRunId",
  "target",
  "trace",
].sort();
const TARGET_KEYS = [
  "brandNameNormalized",
  "officialHost",
  "officialWebsiteCanonicalUrl",
  "targetFingerprintSha256",
].sort();
const TRACE_KEYS = [
  "requestFingerprintSha256",
  "requestId",
  "sourceEventId",
].sort();
const CHANNELS = [
  "similarDomains",
  "openWeb",
  "marketplaceLimited",
];
const FORBIDDEN = new Set([
  "__proto__",
  "prototype",
  "constructor",
  "authorization",
  "cookie",
  "set-cookie",
  "accesskey",
  "access_key",
  "access-key",
  "accesstoken",
  "access_token",
  "access-token",
  "secret",
  "token",
  "password",
  "passwd",
]);

function fail(message) {
  throw new Error("PUBLIC_LITE_DISPATCH_REJECTED: " + message);
}

function plain(value) {
  if (value === null || typeof value !== "object") return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function exactKeys(value, expected, label) {
  if (!plain(value)) fail(label + " must be an object");
  const actual = Object.keys(value).sort();
  if (actual.length !== expected.length ||
      actual.some((key, index) => key !== expected[index])) {
    fail(label + " keys are invalid");
  }
}

function text(value, label, maximum) {
  if (typeof value !== "string") fail(label + " must be a string");
  const normalized = value.trim();
  if (!normalized ||
      Buffer.byteLength(normalized, "utf8") > maximum) {
    fail(label + " is empty or too long");
  }
  return normalized;
}

function sha(value, label) {
  const normalized = text(value, label, 64).toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(normalized)) {
    fail(label + " must be SHA-256 hex");
  }
  return normalized;
}

function iso(value, label) {
  const normalized = text(value, label, 64);
  const timestamp = Date.parse(normalized);
  if (!Number.isFinite(timestamp) ||
      new Date(timestamp).toISOString() !== normalized) {
    fail(label + " must be canonical ISO-8601");
  }
  return normalized;
}

function safe(value, label, depth) {
  if (depth > 8) fail(label + " is too deeply nested");
  if (value === null || typeof value === "boolean") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) fail(label + " has non-finite number");
    return value;
  }
  if (typeof value === "string") {
    if (Buffer.byteLength(value, "utf8") > 32768) {
      fail(label + " has oversized string");
    }
    return value;
  }
  if (Array.isArray(value)) {
    if (value.length > 500) fail(label + " has oversized array");
    return value.map((item, index) =>
      safe(item, label + "[" + index + "]", depth + 1));
  }
  if (!plain(value)) fail(label + " has unsafe value");
  const keys = Object.keys(value);
  if (keys.length > 500) fail(label + " has too many keys");
  const output = {};
  for (const key of keys.sort()) {
    const normalizedKey = text(key, label + ".key", 180);
    if (FORBIDDEN.has(normalizedKey.toLowerCase())) {
      fail(label + " contains forbidden key");
    }
    output[normalizedKey] =
      safe(value[key], label + "." + normalizedKey, depth + 1);
  }
  return output;
}

const incoming = $input.first().json;
const raw = incoming && plain(incoming.body) ?
  incoming.body : incoming;
exactKeys(raw, EXPECTED_KEYS, "dispatchEnvelope");
if (raw.contractVersion !==
    "risk-scan-public-lite-dispatch-envelope-v1" ||
    raw.scanMode !== "quick" ||
    raw.accessTier !== "publicLite" ||
    raw.identityMode !== "anonymous") {
  fail("unsupported dispatch mode");
}
exactKeys(raw.target, TARGET_KEYS, "target");
exactKeys(raw.trace, TRACE_KEYS, "trace");
const executionId = sha(raw.executionId, "executionId");
const scanRunId = text(raw.scanRunId, "scanRunId", 180);
if (scanRunId.includes("/") ||
    scanRunId === "." || scanRunId === "..") {
  fail("scanRunId is invalid");
}
const officialHost = text(
  raw.target.officialHost, "target.officialHost", 512)
  .toLowerCase()
  .replace(/\.$/, "");
const officialUrl = new URL(text(
  raw.target.officialWebsiteCanonicalUrl,
  "target.officialWebsiteCanonicalUrl",
  4096,
));
if (!["http:", "https:"].includes(officialUrl.protocol) ||
    officialUrl.username || officialUrl.password ||
    officialUrl.pathname !== "/" ||
    officialUrl.search || officialUrl.hash ||
    officialUrl.hostname.toLowerCase().replace(/\.$/, "") !==
      officialHost) {
  fail("target official URL is invalid");
}
if (!Array.isArray(raw.channelCodes) ||
    raw.channelCodes.length !== CHANNELS.length ||
    raw.channelCodes.some(
      (value, index) => value !== CHANNELS[index])) {
  fail("canonical channel set is required");
}
const requestedAt = iso(raw.requestedAt, "requestedAt");
const expiresAt = iso(raw.expiresAt, "expiresAt");
if (Date.parse(expiresAt) <= Date.parse(requestedAt)) {
  fail("dispatch is expired");
}
const envelope = safe({
  contractVersion:
    "risk-scan-public-lite-dispatch-envelope-v1",
  executionId,
  scanRunId,
  scanMode: "quick",
  accessTier: "publicLite",
  identityMode: "anonymous",
  target: {
    brandNameNormalized: text(
      raw.target.brandNameNormalized,
      "target.brandNameNormalized",
      300,
    ),
    officialHost,
    officialWebsiteCanonicalUrl: officialUrl.toString(),
    targetFingerprintSha256: sha(
      raw.target.targetFingerprintSha256,
      "target.targetFingerprintSha256",
    ),
  },
  channelCodes: [...CHANNELS],
  requestedAt,
  expiresAt,
  trace: {
    sourceEventId: text(
      raw.trace.sourceEventId, "trace.sourceEventId", 512),
    requestId: text(raw.trace.requestId, "trace.requestId", 180),
    requestFingerprintSha256: sha(
      raw.trace.requestFingerprintSha256,
      "trace.requestFingerprintSha256",
    ),
  },
}, "dispatchEnvelope", 0);
return [{json: {dispatchEnvelope: envelope}}];`;
}

function receiptCode() {
  return String.raw`const item = $input.first().json;
const n8nExecutionId = String($execution.id || "").trim();
if (!n8nExecutionId) {
  throw new Error("PUBLIC_LITE_RECEIPT_REJECTED: n8n execution id missing");
}
const dispatch = item && item.dispatchEnvelope;
const dispatchExecutionId = String(
  dispatch && dispatch.executionId || "",
).trim().toLowerCase();
if (!/^[0-9a-f]{64}$/u.test(dispatchExecutionId)) {
  throw new Error(
    "PUBLIC_LITE_RECEIPT_REJECTED: dispatch execution id invalid",
  );
}
const acceptedAt = new Date().toISOString();
const externalExecutionId =
  ("n8n:" + n8nExecutionId).slice(0, 256);
return [{
  json: {
    dispatchEnvelope: dispatch,
    receipt: {
      contractVersion:
        "risk-scan-public-lite-dispatch-receipt-v1",
      providerCode: "n8n_public_lite",
      executionId: dispatchExecutionId,
      externalExecutionId,
      acceptedAt,
    },
    gatewayState: {
      contractVersion:
        "risk-scan-public-lite-dispatch-receipt-v1",
      acquisitionEngineInstalled: true,
      acquisitionEngineEnabled: false,
      activationAllowed: false,
    },
  },
}];`;
}

function acquisitionPlanCode({
  executionEnabled = false,
} = {}) {
  if (typeof executionEnabled !== "boolean") {
    throw new TypeError(
      "executionEnabled must be a boolean");
  }
  return String.raw`const item = $input.first().json;
const dispatch = item && item.dispatchEnvelope;
if (!dispatch || typeof dispatch !== "object") {
  throw new Error(
    "PUBLIC_LITE_ACQUISITION_PLAN_REJECTED: dispatchEnvelope missing",
  );
}
const queryText = String(
  dispatch.target && dispatch.target.brandNameNormalized || "",
).replace(/\s+/gu, " ").trim();
if (!queryText || queryText.length > 240) {
  throw new Error(
    "PUBLIC_LITE_ACQUISITION_PLAN_REJECTED: queryText invalid",
  );
}
const encodedQuery = encodeURIComponent(queryText)
  .replace(/[!'()~]/gu, (character) =>
    "%" + character.charCodeAt(0).toString(16).toUpperCase(),
  )
  .replace(/%20/gu, "+");
const requestUrl =
  "https://www.trendyol.com/sr?q=" + encodedQuery;
return [{
  json: {
    ...item,
    acquisitionPlan: {
      contractVersion:
        "risk-scan-public-lite-marketplace-acquisition-plan-v1",
      channelAdapterResultContractVersion:
        "risk-scan-public-lite-channel-adapter-result-v1",
      channelCode: "marketplaceLimited",
      adapterCode: "trendyol_public_listing_v1",
      executionEnabled: ${JSON.stringify(executionEnabled)},
      request: {
        method: "GET",
        url: requestUrl,
        headers: {
          Accept: "text/html,application/xhtml+xml",
          "User-Agent": "MarkaKalkan-Public-Lite/1.0",
        },
        credentials: "omit",
        timeoutMs: 15000,
        maxResponseBytes: 1048576,
        maxVisibleTextCharacters: 120000,
        maxCandidates: 20,
      },
    },
  },
}];`;
}

function acquisitionGuardCode() {
  return String.raw`const item = $input.first().json;
if (!item || !item.acquisitionPlan) {
  throw new Error(
    "PUBLIC_LITE_ACQUISITION_GATE_REJECTED: acquisitionPlan missing",
  );
}
if (item.acquisitionPlan.executionEnabled !== true) {
  throw new Error(
    "PUBLIC_LITE_ACQUISITION_DISABLED: " +
    "HRT-MKT-TR-1B integration is installed but execution is disabled",
  );
}
return [{json: item}];`;
}

function marketplaceNormalizerCode() {
  return String.raw`const response = $input.first().json;
const context = $("Build Marketplace Limited Acquisition Plan")
  .first().json;
const plan = context && context.acquisitionPlan;
const dispatch = context && context.dispatchEnvelope;
if (!plan || !dispatch) {
  throw new Error(
    "PUBLIC_LITE_MARKETPLACE_RESULT_REJECTED: context missing",
  );
}
if (plan.executionEnabled !== true) {
  throw new Error(
    "PUBLIC_LITE_MARKETPLACE_RESULT_REJECTED: acquisition disabled",
  );
}
const bodyValue = typeof response.data === "string" ?
  response.data :
  (typeof response.body === "string" ? response.body : "");
const bodyBytes = Buffer.byteLength(bodyValue, "utf8");
if (bodyBytes > plan.request.maxResponseBytes) {
  throw new Error(
    "PUBLIC_LITE_MARKETPLACE_RESULT_REJECTED: response too large",
  );
}
const statusCode = Number.isInteger(response.statusCode) ?
  response.statusCode :
  (Number.isInteger(response.status) ? response.status : null);
const acquiredAt = new Date().toISOString();
const finalUrl = String(
  response.url ||
  (response.request && response.request.res &&
    response.request.res.responseUrl) ||
  plan.request.url,
);
async function sha256Hex(value) {
  const bytes = new TextEncoder().encode(String(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((part) => part.toString(16).padStart(2, "0"))
    .join("");
}
function stripTags(value) {
  return String(value || "")
    .replace(/<[^>]+>/gu, " ")
    .replace(/&nbsp;/giu, " ")
    .replace(/&amp;/giu, "&")
    .replace(/&quot;/giu, "\\\"")
    .replace(/&#39;/giu, "'")
    .replace(/\s+/gu, " ")
    .trim();
}
function normalizeUrl(value) {
  let parsed;
  try {
    parsed = new URL(value, finalUrl);
  } catch {
    return null;
  }
  const host = parsed.hostname.toLowerCase();
  if (parsed.protocol !== "https:" ||
      !(host === "trendyol.com" || host.endsWith(".trendyol.com")) ||
      parsed.username || parsed.password) {
    return null;
  }
  const path = parsed.pathname.toLowerCase();
  if (path === "/" || path.startsWith("/sr") ||
      path.startsWith("/login") || path.startsWith("/hesabim") ||
      path.startsWith("/sepet") || path.startsWith("/yardim") ||
      !(path.includes("-p-") || /\/p-\d+(?:\/|$)/u.test(path))) {
    return null;
  }
  parsed.hash = "";
  parsed.hostname = host;
  if (parsed.port === "443") parsed.port = "";
  return parsed.toString();
}
function classification(status, body) {
  const normalized = String(body || "").toLocaleLowerCase("tr-TR");
  const blocked = [
    "access denied",
    "captcha",
    "robot olmadığınızı doğrulayın",
    "güvenlik kontrolü",
    "too many requests",
    "erişim engellendi",
  ].some((marker) => normalized.includes(marker));
  if (status === 401 || status === 403 || blocked) {
    return {status: "dataUnavailable", outcomeCode: "access_policy_blocked", retryable: false};
  }
  if (status === 429) {
    return {status: "dataUnavailable", outcomeCode: "rate_limited", retryable: true};
  }
  if (status === null || status >= 500) {
    return {status: "failed", outcomeCode: "upstream_unavailable", retryable: true};
  }
  if (status < 200 || status >= 400) {
    return {status: "dataUnavailable", outcomeCode: "http_status_unavailable", retryable: false};
  }
  return {status: "completed", outcomeCode: "public_search_completed", retryable: false};
}
const evidenceSha256 = await sha256Hex(bodyValue);
const classed = classification(statusCode, bodyValue);
const observations = [];
if (classed.status === "completed") {
  const seen = new Set();
  const anchorPattern =
    /<a\b([^>]*?)href\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))([^>]*)>([\s\S]*?)<\/a\s*>/giu;
  let match;
  while (observations.length < plan.request.maxCandidates &&
      (match = anchorPattern.exec(bodyValue)) !== null) {
    const canonicalUrl = normalizeUrl(match[2] || match[3] || match[4]);
    if (!canonicalUrl || seen.has(canonicalUrl)) continue;
    const attributes = String(match[1] || "") + " " + String(match[5] || "");
    const titleMatch = attributes.match(
      /\b(?:title|aria-label)\s*=\s*(?:"([^"]+)"|'([^']+)')/iu,
    );
    const parsed = new URL(canonicalUrl);
    const title = stripTags(
      titleMatch && (titleMatch[1] || titleMatch[2]) ||
      match[6] || parsed.pathname,
    );
    if (!title) continue;
    seen.add(canonicalUrl);
    const observationId = await sha256Hex([
      dispatch.executionId,
      dispatch.scanRunId,
      dispatch.target.targetFingerprintSha256,
      canonicalUrl,
    ].join("\\u001f"));
    observations.push({
      observationId,
      observedAt: acquiredAt,
      sourceUrl: canonicalUrl,
      sourceHost: parsed.hostname.toLowerCase(),
      sourceType: "marketplace_public_listing",
      title: title.slice(0, 500),
      snippet: title.slice(0, 500),
      imageUrls: [],
      signals: {
        adapterCode: plan.adapterCode,
        rank: observations.length + 1,
        targetFingerprintSha256:
          dispatch.target.targetFingerprintSha256,
      },
      evidence: {
        sha256: evidenceSha256,
        acquisitionOutcomeCode: observations.length === 0 &&
          bodyValue.length === 0 ?
          "public_search_completed_no_candidates" :
          classed.outcomeCode,
        responseBytes: bodyBytes,
      },
    });
  }
}
const completedAt = new Date().toISOString();
const outcomeCode = classed.status === "completed" && observations.length === 0 ?
  "public_search_completed_no_candidates" : classed.outcomeCode;
return [{
  json: {
    ...context,
    marketplaceLimitedAdapterResult: {
      contractVersion:
        "risk-scan-public-lite-channel-adapter-result-v1",
      channelCode: "marketplaceLimited",
      adapterCode: plan.adapterCode,
      executionId: dispatch.executionId,
      scanRunId: dispatch.scanRunId,
      targetFingerprintSha256:
        dispatch.target.targetFingerprintSha256,
      idempotencyKey: await sha256Hex([
        dispatch.executionId,
        dispatch.scanRunId,
        dispatch.target.targetFingerprintSha256,
        plan.adapterCode,
      ].join("\\u001f")),
      status: classed.status,
      acquisition: {
        attemptedUrl: plan.request.url,
        finalUrl,
        httpStatus: statusCode,
        acquiredAt,
        outcomeCode,
        evidenceSha256,
        responseBytes: bodyBytes,
        retryable: classed.retryable,
      },
      observations: observations.map((item, index) => ({
        observationId: item.observationId,
        rank: index + 1,
        title: item.title,
        canonicalUrl: item.sourceUrl,
        sourceHost: item.sourceHost,
        evidenceSha256,
      })),
      summary: {
        candidateCount: observations.length,
        errorCount: classed.status === "failed" ? 1 : 0,
      },
      errors: classed.status === "failed" ? [{
        code: outcomeCode,
        message: outcomeCode,
        retryable: classed.retryable,
      }] : [],
    },
    marketplaceLimitedChannel: {
      channelCode: "marketplaceLimited",
      status: classed.status,
      startedAt: acquiredAt,
      completedAt,
      observations,
      diagnostics: {
        channelAdapterContractVersion:
          "risk-scan-public-lite-channel-adapter-result-v1",
        adapterCode: plan.adapterCode,
        executionId: dispatch.executionId,
        scanRunId: dispatch.scanRunId,
        targetFingerprintSha256:
          dispatch.target.targetFingerprintSha256,
        attemptedUrl: plan.request.url,
        finalUrl,
        httpStatus: statusCode,
        acquisitionOutcomeCode: outcomeCode,
        acquisitionEvidenceSha256: evidenceSha256,
        responseBytes: bodyBytes,
        retryable: classed.retryable,
        candidateCount: observations.length,
      },
    },
  },
}];`;
}

function providerAssemblerCode() {
  return String.raw`const item = $input.first().json;
const dispatch = item.dispatchEnvelope;
const receipt = item.receipt;
const marketplace = item.marketplaceLimitedChannel;
if (!dispatch || !receipt || !marketplace) {
  throw new Error(
    "PUBLIC_LITE_PROVIDER_RESULT_REJECTED: required input missing",
  );
}
const now = new Date().toISOString();
function unavailable(channelCode) {
  return {
    channelCode,
    status: "dataUnavailable",
    startedAt: now,
    completedAt: now,
    observations: [],
    diagnostics: {
      reason: "channel_not_installed_in_hrt_mkt_tr_1b",
      syntheticResult: false,
    },
  };
}
const channels = [
  unavailable("similarDomains"),
  unavailable("openWeb"),
  marketplace,
];
const summary = {
  completedChannelCount:
    channels.filter((channel) => channel.status === "completed").length,
  dataUnavailableChannelCount:
    channels.filter((channel) => channel.status === "dataUnavailable").length,
  failedChannelCount:
    channels.filter((channel) => channel.status === "failed").length,
  observationCount:
    channels.reduce((total, channel) =>
      total + channel.observations.length, 0),
};
const executionStatus = summary.failedChannelCount > 0 ?
  "partial" :
  (summary.completedChannelCount === 3 ? "completed" : "partial");
async function sha256Hex(value) {
  const bytes = new TextEncoder().encode(String(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((part) => part.toString(16).padStart(2, "0"))
    .join("");
}
const providerEventId = await sha256Hex([
  dispatch.executionId,
  receipt.externalExecutionId,
  marketplace.completedAt,
  String(summary.observationCount),
].join("\\u001f"));
const resultPayload = {
  contractVersion: "risk-scan-public-lite-provider-result-v1",
  executionStatus,
  channels,
  summary,
  engine: {
    engineCode: "public_lite_marketplace_limited_v1",
    engineVersion: "1.0.0",
  },
};
return [{
  json: {
    ...item,
    resultPayload,
    resultEnvelope: {
      contractVersion: "risk-scan-public-lite-result-envelope-v1",
      providerCode: "n8n_public_lite",
      externalExecutionId: receipt.externalExecutionId,
      providerEventId,
      executionId: dispatch.executionId,
      scanRunId: dispatch.scanRunId,
      completedAt: now,
      resultPayload,
    },
  },
}];`;
}

function resultTemplateBody() {
  return String.raw`={{ JSON.stringify($json.resultEnvelope) }}`;
}

function buildWorkflow({
  webhookCredentialId = "",
  webhookCredentialName = "",
  resultCredentialId = "",
  resultCredentialName = "",
  acquisitionExecutionEnabled = false,
  resultCallbackEnabled = false,
} = {}) {
  const webhookBound = Boolean(
    webhookCredentialId && webhookCredentialName);
  const resultBound = Boolean(
    resultCredentialId && resultCredentialName);

  if (typeof acquisitionExecutionEnabled !== "boolean") {
    throw new TypeError(
      "acquisitionExecutionEnabled must be a boolean");
  }
  if (typeof resultCallbackEnabled !== "boolean") {
    throw new TypeError(
      "resultCallbackEnabled must be a boolean");
  }

  if (Boolean(webhookCredentialId) !== Boolean(webhookCredentialName)) {
    throw new TypeError(
      "webhook credential id and name must be supplied together");
  }
  if (Boolean(resultCredentialId) !== Boolean(resultCredentialName)) {
    throw new TypeError(
      "result credential id and name must be supplied together");
  }
  if (resultCallbackEnabled && !resultBound) {
    throw new TypeError(
      "result callback enable requires result credential binding");
  }

  const webhookNode = {
    parameters: {
      httpMethod: "POST",
      path: WEBHOOK_PATH,
      responseMode: "responseNode",
      options: {},
    },
    id: NODE_IDS.webhook,
    name: "Public Lite Dispatch Webhook",
    type: "n8n-nodes-base.webhook",
    typeVersion: 2.1,
    position: [-680, 20],
    webhookId: WEBHOOK_ID,
    disabled: !webhookBound,
  };
  if (webhookBound) {
    webhookNode.parameters.authentication = "headerAuth";
    webhookNode.credentials = {
      httpHeaderAuth: {
        id: webhookCredentialId,
        name: webhookCredentialName,
      },
    };
  }

  const resultTemplateNode = {
    parameters: {
      method: "POST",
      url: CALLBACK_URL,
      authentication: resultBound ?
        "genericCredentialType" : "none",
      sendBody: true,
      contentType: "raw",
      rawContentType: "application/json",
      body: resultTemplateBody(),
      options: {
        timeout: 45000,
      },
    },
    id: NODE_IDS.resultTemplate,
    name: "Result Callback Template - Disabled",
    type: "n8n-nodes-base.httpRequest",
    typeVersion: 4.2,
    position: [1280, 360],
    disabled: !resultCallbackEnabled,
  };
  if (resultBound) {
    resultTemplateNode.parameters.genericAuthType = "httpHeaderAuth";
    resultTemplateNode.credentials = {
      httpHeaderAuth: {
        id: resultCredentialId,
        name: resultCredentialName,
      },
    };
  }

  return {
    name: WORKFLOW_NAME,
    nodes: [
      {
        parameters: {
          content:
            "## HRT-MKT-TR-1B — INACTIVE INTEGRATION\n\n" +
            "The real marketplaceLimited adapter chain is installed, but " +
            "its execution guard is false and its HTTP Request node is " +
            "disabled. Do not activate this workflow until controlled " +
            "inactive import, live acquisition validation, and result " +
            "materialization are complete.",
          height: 260,
          width: 520,
          color: 5,
        },
        id: NODE_IDS.note,
        name: "Deployment Safety Gate",
        type: "n8n-nodes-base.stickyNote",
        typeVersion: 1,
        position: [-760, -320],
      },
      webhookNode,
      {
        parameters: {
          jsCode: validatorCode(),
        },
        id: NODE_IDS.validate,
        name: "Validate Public Lite Dispatch",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [-400, 20],
      },
      {
        parameters: {
          jsCode: receiptCode(),
        },
        id: NODE_IDS.receipt,
        name: "Build Dispatch Receipt",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [-120, 20],
      },
      {
        parameters: {
          respondWith: "json",
          responseBody: "={{ $json.receipt }}",
          options: {
            responseCode: 202,
          },
        },
        id: NODE_IDS.respond,
        name: "Return 202 Dispatch Receipt",
        type: "n8n-nodes-base.respondToWebhook",
        typeVersion: 1.4,
        position: [160, 20],
      },
      {
        parameters: {
          content:
            "## marketplaceLimited integration — execution disabled\n\n" +
            `Adapter: ${ADAPTER_CODE}\n\n` +
            `Channel adapter result: ${CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION}\n\n` +
            "Public pages only. No authentication, cookies, API keys, " +
            "CAPTCHA solving, or anti-bot bypass. The execution guard is " +
            "false and the HTTP Request node is disabled.",
          height: 320,
          width: 520,
          color: 5,
        },
        id: NODE_IDS.acquisitionNote,
        name: "Marketplace Limited Safety Gate",
        type: "n8n-nodes-base.stickyNote",
        typeVersion: 1,
        position: [-120, -360],
      },
      {
        parameters: {
          jsCode: acquisitionPlanCode({
              executionEnabled: acquisitionExecutionEnabled,
            }),
        },
        id: NODE_IDS.acquisitionPlan,
        name: "Build Marketplace Limited Acquisition Plan",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [160, -120],
      },
      {
        parameters: {
          jsCode: acquisitionGuardCode(),
        },
        id: NODE_IDS.acquisitionGuard,
        name: "Assert Marketplace Acquisition Enabled",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [440, -120],
      },
      {
        parameters: {
          method: "GET",
          url: "={{ $json.acquisitionPlan.request.url }}",
          sendHeaders: true,
          headerParameters: {
            parameters: [
              {
                name: "Accept",
                value: "text/html,application/xhtml+xml",
              },
              {
                name: "User-Agent",
                value: "MarkaKalkan-Public-Lite/1.0",
              },
            ],
          },
          options: {
            timeout: 15000,
            response: {
              response: {
                fullResponse: true,
                neverError: true,
                responseFormat: "text",
              },
            },
          },
        },
        id: NODE_IDS.acquisitionHttp,
        name: "Trendyol Public Listing Acquisition - Disabled",
        type: "n8n-nodes-base.httpRequest",
        typeVersion: 4.2,
        position: [720, -120],
        disabled: !acquisitionExecutionEnabled,
      },
      {
        parameters: {
          jsCode: marketplaceNormalizerCode(),
        },
        id: NODE_IDS.normalizeMarketplace,
        name: "Normalize Marketplace Limited Result",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [1000, -120],
      },
      {
        parameters: {
          jsCode: providerAssemblerCode(),
        },
        id: NODE_IDS.assembleProvider,
        name: "Assemble Canonical Provider Result",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [1280, -120],
      },
      {
        parameters: {
          content:
            "## Result callback template — disabled\n\n" +
            `Contract: ${RESULT_ENVELOPE_VERSION}\n\n` +
            `Provider result: ${PROVIDER_RESULT_VERSION}\n\n` +
            `Callback: ${CALLBACK_URL}\n\n` +
            `Header: ${RESULT_HEADER}\n\n` +
            "This node is intentionally disabled and unconnected. " +
            "It accepts only the assembled resultEnvelope after controlled " +
            "live validation. No synthetic result or placeholder evidence " +
            "may be sent.",
          height: 300,
          width: 500,
          color: 3,
        },
        id: NODE_IDS.resultTemplateNote,
        name: "Result Contract Safety Note",
        type: "n8n-nodes-base.stickyNote",
        typeVersion: 1,
        position: [-180, 260],
      },
      resultTemplateNode,
    ],
    pinData: {},
    connections: {
      "Public Lite Dispatch Webhook": {
        main: [[{
          node: "Validate Public Lite Dispatch",
          type: "main",
          index: 0,
        }]],
      },
      "Validate Public Lite Dispatch": {
        main: [[{
          node: "Build Dispatch Receipt",
          type: "main",
          index: 0,
        }]],
      },
      "Build Dispatch Receipt": {
        main: [[
          {
            node: "Return 202 Dispatch Receipt",
            type: "main",
            index: 0,
          },
          {
            node: "Build Marketplace Limited Acquisition Plan",
            type: "main",
            index: 0,
          },
        ]],
      },
      "Build Marketplace Limited Acquisition Plan": {
        main: [[{
          node: "Assert Marketplace Acquisition Enabled",
          type: "main",
          index: 0,
        }]],
      },
      "Assert Marketplace Acquisition Enabled": {
        main: [[{
          node: "Trendyol Public Listing Acquisition - Disabled",
          type: "main",
          index: 0,
        }]],
      },
      "Trendyol Public Listing Acquisition - Disabled": {
        main: [[{
          node: "Normalize Marketplace Limited Result",
          type: "main",
          index: 0,
        }]],
      },
      "Normalize Marketplace Limited Result": {
        main: [[{
          node: "Assemble Canonical Provider Result",
          type: "main",
          index: 0,
        }]],
      },
      ...(resultCallbackEnabled ? {
        "Assemble Canonical Provider Result": {
          main: [[{
            node: "Result Callback Template - Disabled",
            type: "main",
            index: 0,
          }]],
        },
      } : {}),
    },
    active: false,
    settings: {
      executionOrder: "v1",
      saveManualExecutions: true,
      callerPolicy: "workflowsFromSameOwner",
    },
    versionId: WORKFLOW_VERSION_ID,
    meta: {
      templateCredsSetupCompleted:
        webhookBound && resultBound,
      hrtPhase: "HRT-MKT-TR-1B",
      gatewayContractVersion: DISPATCH_ENVELOPE_VERSION,
      providerCode: PROVIDER_CODE,
      acquisitionEngineInstalled: true,
      acquisitionEngineEnabled: false,
      acquisitionAdapterCode: ADAPTER_CODE,
      acquisitionChannelCode: MARKETPLACE_CHANNEL_CODE,
      channelAdapterResultContractVersion:
        CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION,
      webhookHeader: WEBHOOK_HEADER,
      resultHeader: RESULT_HEADER,
      activationAllowed: false,
    },
    tags: [],
  };
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJson(value[key])}`,
    ).join(",")}}`;
  }
  return JSON.stringify(value);
}

function serializeWorkflow(workflow) {
  return JSON.stringify(workflow, null, 2) + "\n";
}

function writeWorkflow(outputPath, options = {}) {
  const workflow = buildWorkflow(options);
  const serialized = serializeWorkflow(workflow);
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.writeFileSync(outputPath, serialized, "utf8");
  return workflow;
}

module.exports = Object.freeze({
  CALLBACK_URL,
  NODE_IDS,
  RESULT_HEADER,
  WEBHOOK_HEADER,
  WEBHOOK_PATH,
  WORKFLOW_NAME,
  acquisitionGuardCode,
  acquisitionPlanCode,
  buildWorkflow,
  canonicalJson,
  marketplaceNormalizerCode,
  providerAssemblerCode,
  receiptCode,
  resultTemplateBody,
  serializeWorkflow,
  validatorCode,
  writeWorkflow,
});
