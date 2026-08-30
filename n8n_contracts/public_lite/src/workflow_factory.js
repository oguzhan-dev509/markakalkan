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
const ACQUISITION_WORKFLOW_NAME =
  "MarkaKalkan Public Lite Risk Scan Acquisition Worker - V1";
const WEBHOOK_PATH =
  "markakalkan/public-lite-risk-scan/run-created";
const ACQUISITION_WEBHOOK_PATH =
  "markakalkan/public-lite-risk-scan/acquisition";
const HANDOFF_URL =
  "https://europe-west3-markakalkan-app.cloudfunctions.net/" +
  "acceptPublicLiteRiskScanHandoff";
const CALLBACK_URL =
  "https://europe-west3-markakalkan-app.cloudfunctions.net/" +
  "receivePublicLiteRiskScanResult";
const WEBHOOK_HEADER = "X-MarkaKalkan-Token";
const HANDOFF_HEADER =
  "X-MarkaKalkan-Public-Lite-Handoff-Token";
const ACQUISITION_HEADER =
  "X-MarkaKalkan-Public-Lite-Acquisition-Token";
const RESULT_HEADER =
  "X-MarkaKalkan-Public-Lite-Result-Token";

const HANDOFF_REQUEST_VERSION =
  "risk-scan-public-lite-provider-handoff-request-v1";
const HANDOFF_RECEIPT_VERSION =
  "risk-scan-public-lite-provider-handoff-receipt-v1";
const DISPATCH_RECEIPT_VERSION_V2 =
  "risk-scan-public-lite-dispatch-receipt-v2";
const ACQUISITION_COMMAND_VERSION =
  "risk-scan-public-lite-acquisition-command-v1";
const ACQUISITION_RECEIPT_VERSION =
  "risk-scan-public-lite-acquisition-dispatch-receipt-v2";

const NODE_IDS = Object.freeze({
  note: "bb432ce7-90ff-5d1d-af35-341997c07219",
  webhook: "c7728da0-2240-5ca5-a4dc-b69bb8a2f839",
  validate: "5e8b7957-73a4-53e6-995b-7b5f61f129ca",
  handoffNote: "1bbc46ba-da32-502b-b99a-c6cbf523d493",
  handoffRequest: "bd52a7a3-eb5a-5dca-9d63-f23fed191b29",
  handoffHttp: "10fcc82f-b734-5967-adc4-4a26fddd4d81",
  receipt: "11de7dd7-0d2e-5ab1-885c-53068764e03f",
  respond: "90b2d358-0a64-56af-9a0f-fd1f4695e4f5",
});

const ACQUISITION_NODE_IDS = Object.freeze({
  note: "e4d069d3-342e-506b-82e0-e87003578c23",
  webhook: "eb2b2e81-8259-5ca5-84c9-29130bb0c476",
  validate: "bd68e13f-0c8e-577e-80a7-a7e827fa2c66",
  receipt: "39d32f33-c605-5950-a3ff-ef1e950ef508",
  respond: "078a52aa-1e5d-5a75-9690-c9ab51255e60",
  acquisitionNote: "8c91b8c8-2dc6-5519-b4bf-bef8bf2691f8",
  acquisitionPlan: "0ed42462-55d9-55e8-8362-c1ef8d1d3db3",
  acquisitionGuard: "1b24eb51-8b6b-52d5-bc9d-14bd20fb949a",
  acquisitionHttp: "02a12928-7363-582c-b330-1c07df71596e",
  normalizeMarketplace: "96f75ff7-86d0-57b4-9c2f-fb1f04abe7bc",
  assembleProvider: "22d9183a-d752-52fc-967a-cf8d1062de08",
  resultTemplateNote: "f2ddd589-9d4a-5212-a5b8-bf2a14a954f2",
  resultTemplate: "bac5267f-d055-55a5-bd03-e39a1e3c2365",
});

const WORKFLOW_VERSION_ID =
  "8fcca337-2349-590e-a27b-fa9ab52e49c3";
const ACQUISITION_WORKFLOW_VERSION_ID =
  "24501e82-58b3-5cd1-8ed3-00eb5d7581a7";
const WEBHOOK_ID =
  "9996c454-a741-5af2-9467-7ec6754e7bee";
const ACQUISITION_WEBHOOK_ID =
  "6d61578c-2a87-5b1d-a203-451bcf443c0e";

function validatorCode() {
  return String.raw`function parseHttpUrlWithoutGlobal(value, baseValue) {
  function failUrl() {
    throw new TypeError("invalid URL");
  }

  function punycodeEncode(input) {
    const base = 36;
    const tMin = 1;
    const tMax = 26;
    const skew = 38;
    const damp = 700;
    const initialBias = 72;
    const initialN = 128;
    const delimiter = "-";

    function adapt(delta, numPoints, firstTime) {
      delta = firstTime ? Math.floor(delta / damp) : (delta >> 1);
      delta += Math.floor(delta / numPoints);
      let k = 0;
      while (delta > Math.floor(((base - tMin) * tMax) / 2)) {
        delta = Math.floor(delta / (base - tMin));
        k += base;
      }
      return k + Math.floor(
        ((base - tMin + 1) * delta) / (delta + skew)
      );
    }

    function digitToBasic(digit) {
      return String.fromCharCode(
        digit + 22 + 75 * (digit < 26 ? 1 : 0)
      );
    }

    const codePoints = Array.from(input).map((character) =>
      character.codePointAt(0)
    );
    let output = "";
    let n = initialN;
    let delta = 0;
    let bias = initialBias;

    for (const point of codePoints) {
      if (point < 0x80) output += String.fromCharCode(point);
    }

    let handled = output.length;
    const basicLength = handled;
    if (basicLength > 0) output += delimiter;

    while (handled < codePoints.length) {
      let m = Number.MAX_SAFE_INTEGER;
      for (const point of codePoints) {
        if (point >= n && point < m) m = point;
      }
      if (!Number.isFinite(m) || m === Number.MAX_SAFE_INTEGER) failUrl();

      const step = (m - n) * (handled + 1);
      if (!Number.isSafeInteger(step) ||
          !Number.isSafeInteger(delta + step)) failUrl();

      delta += step;
      n = m;

      for (const point of codePoints) {
        if (point < n) {
          delta += 1;
          if (!Number.isSafeInteger(delta)) failUrl();
        }
        if (point === n) {
          let q = delta;
          for (let k = base; ; k += base) {
            let t;
            if (k <= bias) t = tMin;
            else if (k >= bias + tMax) t = tMax;
            else t = k - bias;

            if (q < t) break;
            const code = t + ((q - t) % (base - t));
            output += digitToBasic(code);
            q = Math.floor((q - t) / (base - t));
          }
          output += digitToBasic(q);
          bias = adapt(delta, handled + 1, handled === basicLength);
          delta = 0;
          handled += 1;
        }
      }
      delta += 1;
      n += 1;
    }

    return output;
  }

  function canonicalizeIpv4IfApplicable(hostname) {
    const labels = hostname.split(".");
    const numericLike = labels.every((label) =>
      /^[0-9]+$/u.test(label) || /^0x[0-9a-f]+$/iu.test(label)
    );
    if (!numericLike) return null;

    if (labels.length !== 4) failUrl();
    const canonical = [];
    for (const label of labels) {
      if (!/^[0-9]+$/u.test(label)) failUrl();
      if (label.length > 1 && label.startsWith("0")) failUrl();
      const value = Number(label);
      if (!Number.isInteger(value) || value < 0 || value > 255) failUrl();
      canonical.push(String(value));
    }
    return canonical.join(".");
  }

  function canonicalizeHostname(rawHostname) {
    let hostname = String(rawHostname || "").trim();
    if (!hostname) failUrl();

    if (hostname.startsWith("[") && hostname.endsWith("]")) {
      const inner = hostname.slice(1, -1);
      if (!inner || /[^0-9a-fA-F:.]/u.test(inner)) failUrl();
      return "[" + inner.toLowerCase() + "]";
    }

    if (/%/u.test(hostname)) {
      try {
        hostname = decodeURIComponent(hostname);
      } catch {
        failUrl();
      }
    }

    hostname = hostname.toLowerCase();
    if (/[\s\\/?#@:]/u.test(hostname)) failUrl();

    const trailingDot = hostname.endsWith(".");
    const core = trailingDot ? hostname.slice(0, -1) : hostname;
    if (!core) failUrl();

    const ipv4 = canonicalizeIpv4IfApplicable(core);
    if (ipv4 !== null) return ipv4 + (trailingDot ? "." : "");

    const labels = core.split(".");
    const canonicalLabels = [];
    for (const label of labels) {
      if (!label) failUrl();
      let next = label;
      if (/[^\x00-\x7F]/u.test(next)) {
        next = "xn--" + punycodeEncode(next);
      }
      if (!/^[a-z0-9-]+$/u.test(next)) failUrl();
      if (next.startsWith("-") || next.endsWith("-")) failUrl();
      if (next.length > 63) failUrl();
      canonicalLabels.push(next);
    }

    const canonical = canonicalLabels.join(".") + (trailingDot ? "." : "");
    if (canonical.length > 254) failUrl();
    return canonical;
  }

  function canonicalizePort(rawPort, scheme) {
    let port = String(rawPort || "").trim();
    if (!port) return "";
    if (!/^[0-9]{1,5}$/u.test(port)) failUrl();

    const numeric = Number(port);
    if (!Number.isInteger(numeric) || numeric < 0 || numeric > 65535) failUrl();

    port = String(numeric);
    if ((scheme === "https" && numeric === 443) ||
        (scheme === "http" && numeric === 80)) return "";
    return port;
  }

  function normalizedDotToken(segment) {
    return segment.toLowerCase().replace(/%2e/gu, ".");
  }

  function normalizePathname(rawPathname) {
    let pathname = String(rawPathname || "");
    if (!pathname) pathname = "/";
    if (!pathname.startsWith("/")) failUrl();

    // Intentional fail-closed restriction.
    if (pathname.includes("\\")) failUrl();

    const sourceSegments = pathname.split("/");
    const outputSegments = [];
    for (let index = 0; index < sourceSegments.length; index += 1) {
      const segment = sourceSegments[index];
      if (index === 0) {
        outputSegments.push("");
        continue;
      }

      const token = normalizedDotToken(segment);
      if (token === ".") continue;
      if (token === "..") {
        if (outputSegments.length > 1) outputSegments.pop();
        continue;
      }
      outputSegments.push(segment);
    }

    if (pathname.endsWith("/.") ||
        pathname.endsWith("/..") ||
        /\/(?:%2e|\.%2e|%2e\.|%2e%2e)$/iu.test(pathname)) {
      if (outputSegments[outputSegments.length - 1] !== "") {
        outputSegments.push("");
      }
    }

    let normalized = outputSegments.join("/");
    if (!normalized.startsWith("/")) normalized = "/" + normalized;
    return normalized || "/";
  }

  function splitAbsolute(rawValue) {
    const raw = String(rawValue || "").trim();

    // Intentional fail-closed restriction.
    if (raw.includes("\\")) failUrl();

    const match = /^(https?):\/\/([\s\S]*)$/iu.exec(raw);
    if (!match) failUrl();

    const scheme = match[1].toLowerCase();
    const remainder = match[2];

    let boundary = remainder.length;
    for (const marker of ["/", "?", "#"]) {
      const index = remainder.indexOf(marker);
      if (index >= 0 && index < boundary) boundary = index;
    }

    const authority = remainder.slice(0, boundary);
    let suffix = remainder.slice(boundary);
    if (!authority || authority.includes("@")) failUrl();

    let hostnameRaw = "";
    let portRaw = "";
    if (authority.startsWith("[")) {
      const close = authority.indexOf("]");
      if (close <= 1) failUrl();
      hostnameRaw = authority.slice(0, close + 1);
      const tail = authority.slice(close + 1);
      if (tail) {
        if (!tail.startsWith(":")) failUrl();
        portRaw = tail.slice(1);
      }
    } else {
      const colon = authority.lastIndexOf(":");
      if (colon >= 0) {
        if (authority.slice(0, colon).includes(":")) failUrl();
        hostnameRaw = authority.slice(0, colon);
        portRaw = authority.slice(colon + 1);
      } else {
        hostnameRaw = authority;
      }
    }

    const hostname = canonicalizeHostname(hostnameRaw);
    const port = canonicalizePort(portRaw, scheme);

    let hash = "";
    const hashIndex = suffix.indexOf("#");
    if (hashIndex >= 0) {
      hash = suffix.slice(hashIndex);
      suffix = suffix.slice(0, hashIndex);
    }

    let search = "";
    const searchIndex = suffix.indexOf("?");
    if (searchIndex >= 0) {
      search = suffix.slice(searchIndex);
      suffix = suffix.slice(0, searchIndex);
    }

    const pathname = normalizePathname(suffix || "/");
    return {scheme, hostname, port, pathname, search, hash};
  }

  function originOf(state) {
    return state.scheme + "://" + state.hostname +
      (state.port ? ":" + state.port : "");
  }

  function resolve(valueRaw, baseRaw) {
    const valueText = String(valueRaw || "").trim();

    if (/^https?:\/\//iu.test(valueText)) return valueText;
    if (valueText.includes("\\")) failUrl();
    if (baseRaw === undefined || baseRaw === null) failUrl();

    const base = splitAbsolute(baseRaw);
    const origin = originOf(base);

    if (valueText.startsWith("//")) return base.scheme + ":" + valueText;
    if (valueText.startsWith("/")) return origin + valueText;
    if (valueText.startsWith("?")) return origin + base.pathname + valueText;
    if (valueText.startsWith("#")) {
      return origin + base.pathname + base.search + valueText;
    }

    const slash = base.pathname.lastIndexOf("/");
    const directory = slash >= 0 ? base.pathname.slice(0, slash + 1) : "/";
    return origin + directory + valueText;
  }

  const state = splitAbsolute(resolve(value, baseValue));

  function href() {
    return originOf(state) + state.pathname + state.search + state.hash;
  }

  return {
    get protocol() { return state.scheme + ":"; },
    get username() { return ""; },
    get password() { return ""; },
    get hostname() { return state.hostname; },
    set hostname(valueInput) {
      state.hostname = canonicalizeHostname(valueInput);
    },
    get port() { return state.port; },
    set port(valueInput) {
      state.port = canonicalizePort(valueInput, state.scheme);
    },
    get pathname() { return state.pathname; },
    set pathname(valueInput) {
      state.pathname = normalizePathname(valueInput);
    },
    get search() { return state.search; },
    set search(valueInput) {
      const next = String(valueInput || "");
      state.search = next && !next.startsWith("?") ? "?" + next : next;
    },
    get hash() { return state.hash; },
    set hash(valueInput) {
      const next = String(valueInput || "");
      state.hash = next && !next.startsWith("#") ? "#" + next : next;
    },
    get href() { return href(); },
    toString() { return href(); },
  };
}

const EXPECTED_KEYS = [
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
  if (value === null ||
      typeof value !== "object" ||
      Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === null ||
    Object.getPrototypeOf(prototype) === null;
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

function normalizeWebhookJson(value, depth, state) {
  if (depth > 8) fail("webhook body nesting too deep");
  state.count += 1;
  if (state.count > 5000) fail("webhook body is too complex");

  if (value === null ||
      typeof value === "string" ||
      typeof value === "boolean") {
    if (typeof value === "string" &&
        Buffer.byteLength(value, "utf8") > 32768) {
      fail("webhook body string is too large");
    }
    return value;
  }

  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      fail("webhook body contains an invalid number");
    }
    return value;
  }

  if (Array.isArray(value)) {
    if (value.length > 500) {
      fail("webhook body array is too large");
    }
    return value.map(
      (item) => normalizeWebhookJson(item, depth + 1, state));
  }

  if (typeof value !== "object") {
    fail("webhook body contains an unsupported value");
  }

  const keys = Object.keys(value);
  if (keys.length > 500) {
    fail("webhook body has too many keys");
  }

  const output = Object.create(null);
  for (const key of keys) {
    if (Buffer.byteLength(key, "utf8") > 180) {
      fail("webhook body key is too long");
    }
    output[key] = normalizeWebhookJson(
      value[key], depth + 1, state);
  }
  return output;
}

function webhookBodyCandidate(value) {
  if (value === null ||
      typeof value !== "object" ||
      Array.isArray(value)) {
    return {found: false, value: undefined};
  }

  if (Object.prototype.hasOwnProperty.call(value, "body")) {
    return {found: true, value: value.body};
  }

  try {
    const body = value.body;
    if (body !== undefined) {
      let wrapperMarkerCount = 0;
      for (const key of [
        "headers",
        "params",
        "query",
        "webhookUrl",
        "executionMode",
      ]) {
        if (value[key] !== undefined) wrapperMarkerCount += 1;
      }

      if (wrapperMarkerCount >= 2) {
        return {found: true, value: body};
      }
    }
  } catch {
    // Preserve fail-closed fallback below.
  }

  if (plain(value)) {
    return {found: false, value: undefined};
  }

  return {found: false, value: undefined};
}

const incoming = $input.first().json;
const bodyCandidate = webhookBodyCandidate(incoming);
const raw = bodyCandidate.found ?
  normalizeWebhookJson(bodyCandidate.value, 0, {count: 0}) : incoming;
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
const officialUrl = parseHttpUrlWithoutGlobal(text(
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
const canonicalTarget = Object.create(null);
canonicalTarget.brandNameNormalized = text(
  raw.target.brandNameNormalized,
  "target.brandNameNormalized",
  300,
);
canonicalTarget.officialHost = officialHost;
canonicalTarget.officialWebsiteCanonicalUrl = officialUrl.toString();
canonicalTarget.targetFingerprintSha256 = sha(
  raw.target.targetFingerprintSha256,
  "target.targetFingerprintSha256",
);

const canonicalTrace = Object.create(null);
canonicalTrace.sourceEventId = text(
  raw.trace.sourceEventId, "trace.sourceEventId", 512);
canonicalTrace.requestId = text(
  raw.trace.requestId, "trace.requestId", 180);
canonicalTrace.requestFingerprintSha256 = sha(
  raw.trace.requestFingerprintSha256,
  "trace.requestFingerprintSha256",
);

const canonicalEnvelope = Object.create(null);
canonicalEnvelope.contractVersion =
  "risk-scan-public-lite-dispatch-envelope-v1";
canonicalEnvelope.executionId = executionId;
canonicalEnvelope.scanRunId = scanRunId;
canonicalEnvelope.scanMode = "quick";
canonicalEnvelope.accessTier = "publicLite";
canonicalEnvelope.identityMode = "anonymous";
canonicalEnvelope.target = canonicalTarget;
canonicalEnvelope.channelCodes = [...CHANNELS];
canonicalEnvelope.requestedAt = requestedAt;
canonicalEnvelope.expiresAt = expiresAt;
canonicalEnvelope.trace = canonicalTrace;

const envelope = safe(canonicalEnvelope, "dispatchEnvelope", 0);
return [{json: {dispatchEnvelope: envelope}}];`;
}


function handoffRequestCode() {
  return String.raw`const item = $input.first().json;
const dispatch = item && item.dispatchEnvelope;
if (!dispatch || typeof dispatch !== "object") {
  throw new Error(
    "PUBLIC_LITE_HANDOFF_REQUEST_REJECTED: dispatchEnvelope missing",
  );
}
const n8nExecutionId = String($execution.id || "").trim();
if (!n8nExecutionId) {
  throw new Error(
    "PUBLIC_LITE_HANDOFF_REQUEST_REJECTED: n8n execution id missing",
  );
}
const gatewayExecutionId =
  ("n8n:" + n8nExecutionId).slice(0, 256);
return [{
  json: {
    dispatchEnvelope: dispatch,
    handoffRequest: {
      contractVersion:
        "risk-scan-public-lite-provider-handoff-request-v1",
      providerCode: "n8n_public_lite",
      executionId: dispatch.executionId,
      scanRunId: dispatch.scanRunId,
      gatewayExecutionId,
      dispatchEnvelope: dispatch,
    },
  },
}];`;
}

function receiptCode() {
  return String.raw`const RESPONSE_KEYS = [
  "acceptedAt",
  "contractVersion",
  "executionId",
  "gatewayExecutionId",
  "handoffId",
  "providerCode",
  "replayed",
  "scanRunId",
  "state",
].sort();

function fail(message) {
  throw new Error(
    "PUBLIC_LITE_DURABLE_RECEIPT_REJECTED: " + message,
  );
}

function plain(value) {
  if (value === null ||
      typeof value !== "object" ||
      Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === null ||
    Object.getPrototypeOf(prototype) === null;
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
  if (typeof value !== "string") {
    fail(label + " must be a string");
  }
  const normalized = value.trim();
  if (!normalized ||
      Buffer.byteLength(normalized, "utf8") > maximum) {
    fail(label + " is empty or too long");
  }
  return normalized;
}

function sha(value, label) {
  const normalized = text(value, label, 64).toLowerCase();
  if (!/^[a-f0-9]{64}$/u.test(normalized)) {
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

function parseBody(value) {
  if (plain(value)) return value;
  if (typeof value !== "string") {
    fail("handoff response body is invalid");
  }
  try {
    const parsed = JSON.parse(value);
    if (!plain(parsed)) fail("handoff response body is invalid");
    return parsed;
  } catch {
    fail("handoff response body is invalid JSON");
  }
}

const response = $input.first().json;
const statusCode = Number(
  response && (response.statusCode ?? response.status),
);
if (!Number.isInteger(statusCode) || statusCode !== 200) {
  fail("handoff persistence did not return HTTP 200");
}
const rawReceipt = parseBody(
  response && response.body !== undefined ?
    response.body :
    response && response.data !== undefined ?
      response.data :
      null,
);
exactKeys(rawReceipt, RESPONSE_KEYS, "handoffReceipt");
if (rawReceipt.contractVersion !==
    "risk-scan-public-lite-provider-handoff-receipt-v1" ||
    rawReceipt.providerCode !== "n8n_public_lite" ||
    rawReceipt.state !== "accepted" ||
    typeof rawReceipt.replayed !== "boolean") {
  fail("handoff receipt contract is unsupported");
}
const context =
  $("Build Durable Provider Handoff Request").first().json;
const request = context && context.handoffRequest;
const dispatch = context && context.dispatchEnvelope;
if (!request || !dispatch) {
  fail("handoff request context is missing");
}
const executionId = sha(rawReceipt.executionId, "executionId");
const handoffId = sha(rawReceipt.handoffId, "handoffId");
const scanRunId = text(rawReceipt.scanRunId, "scanRunId", 180);
const gatewayExecutionId = text(
  rawReceipt.gatewayExecutionId,
  "gatewayExecutionId",
  256,
);
const acceptedAt = iso(rawReceipt.acceptedAt, "acceptedAt");
if (executionId !== request.executionId ||
    scanRunId !== request.scanRunId ||
    gatewayExecutionId !== request.gatewayExecutionId) {
  fail("handoff receipt scope does not match the request");
}
return [{
  json: {
    dispatchEnvelope: dispatch,
    handoffRequest: request,
    handoffReceipt: {
      contractVersion: rawReceipt.contractVersion,
      providerCode: rawReceipt.providerCode,
      handoffId,
      executionId,
      scanRunId,
      gatewayExecutionId,
      acceptedAt,
      state: "accepted",
      replayed: rawReceipt.replayed,
    },
    receipt: {
      contractVersion:
        "risk-scan-public-lite-dispatch-receipt-v2",
      providerCode: "n8n_public_lite",
      executionId,
      externalExecutionId: gatewayExecutionId,
      handoffId,
      acceptedAt,
    },
    gatewayState: {
      contractVersion:
        "risk-scan-public-lite-dispatch-receipt-v2",
      durableProviderHandoffAccepted: true,
      handoffReplayed: rawReceipt.replayed,
      outboundAcquisition: false,
      resultCallback: false,
      activationAllowed: false,
    },
  },
}];`;
}

function acquisitionCommandValidatorCode() {
  return String.raw`function parseHttpUrlWithoutGlobal(value, baseValue) {
  function failUrl() {
    throw new TypeError("invalid URL");
  }

  function punycodeEncode(input) {
    const base = 36;
    const tMin = 1;
    const tMax = 26;
    const skew = 38;
    const damp = 700;
    const initialBias = 72;
    const initialN = 128;
    const delimiter = "-";

    function adapt(delta, numPoints, firstTime) {
      delta = firstTime ? Math.floor(delta / damp) : (delta >> 1);
      delta += Math.floor(delta / numPoints);
      let k = 0;
      while (delta > Math.floor(((base - tMin) * tMax) / 2)) {
        delta = Math.floor(delta / (base - tMin));
        k += base;
      }
      return k + Math.floor(
        ((base - tMin + 1) * delta) / (delta + skew)
      );
    }

    function digitToBasic(digit) {
      return String.fromCharCode(
        digit + 22 + 75 * (digit < 26 ? 1 : 0)
      );
    }

    const codePoints = Array.from(input).map((character) =>
      character.codePointAt(0)
    );
    let output = "";
    let n = initialN;
    let delta = 0;
    let bias = initialBias;

    for (const point of codePoints) {
      if (point < 0x80) output += String.fromCharCode(point);
    }

    let handled = output.length;
    const basicLength = handled;
    if (basicLength > 0) output += delimiter;

    while (handled < codePoints.length) {
      let m = Number.MAX_SAFE_INTEGER;
      for (const point of codePoints) {
        if (point >= n && point < m) m = point;
      }
      if (!Number.isFinite(m) || m === Number.MAX_SAFE_INTEGER) failUrl();

      const step = (m - n) * (handled + 1);
      if (!Number.isSafeInteger(step) ||
          !Number.isSafeInteger(delta + step)) failUrl();

      delta += step;
      n = m;

      for (const point of codePoints) {
        if (point < n) {
          delta += 1;
          if (!Number.isSafeInteger(delta)) failUrl();
        }
        if (point === n) {
          let q = delta;
          for (let k = base; ; k += base) {
            let t;
            if (k <= bias) t = tMin;
            else if (k >= bias + tMax) t = tMax;
            else t = k - bias;

            if (q < t) break;
            const code = t + ((q - t) % (base - t));
            output += digitToBasic(code);
            q = Math.floor((q - t) / (base - t));
          }
          output += digitToBasic(q);
          bias = adapt(delta, handled + 1, handled === basicLength);
          delta = 0;
          handled += 1;
        }
      }
      delta += 1;
      n += 1;
    }

    return output;
  }

  function canonicalizeIpv4IfApplicable(hostname) {
    const labels = hostname.split(".");
    const numericLike = labels.every((label) =>
      /^[0-9]+$/u.test(label) || /^0x[0-9a-f]+$/iu.test(label)
    );
    if (!numericLike) return null;

    if (labels.length !== 4) failUrl();
    const canonical = [];
    for (const label of labels) {
      if (!/^[0-9]+$/u.test(label)) failUrl();
      if (label.length > 1 && label.startsWith("0")) failUrl();
      const value = Number(label);
      if (!Number.isInteger(value) || value < 0 || value > 255) failUrl();
      canonical.push(String(value));
    }
    return canonical.join(".");
  }

  function canonicalizeHostname(rawHostname) {
    let hostname = String(rawHostname || "").trim();
    if (!hostname) failUrl();

    if (hostname.startsWith("[") && hostname.endsWith("]")) {
      const inner = hostname.slice(1, -1);
      if (!inner || /[^0-9a-fA-F:.]/u.test(inner)) failUrl();
      return "[" + inner.toLowerCase() + "]";
    }

    if (/%/u.test(hostname)) {
      try {
        hostname = decodeURIComponent(hostname);
      } catch {
        failUrl();
      }
    }

    hostname = hostname.toLowerCase();
    if (/[\s\\/?#@:]/u.test(hostname)) failUrl();

    const trailingDot = hostname.endsWith(".");
    const core = trailingDot ? hostname.slice(0, -1) : hostname;
    if (!core) failUrl();

    const ipv4 = canonicalizeIpv4IfApplicable(core);
    if (ipv4 !== null) return ipv4 + (trailingDot ? "." : "");

    const labels = core.split(".");
    const canonicalLabels = [];
    for (const label of labels) {
      if (!label) failUrl();
      let next = label;
      if (/[^\x00-\x7F]/u.test(next)) {
        next = "xn--" + punycodeEncode(next);
      }
      if (!/^[a-z0-9-]+$/u.test(next)) failUrl();
      if (next.startsWith("-") || next.endsWith("-")) failUrl();
      if (next.length > 63) failUrl();
      canonicalLabels.push(next);
    }

    const canonical = canonicalLabels.join(".") + (trailingDot ? "." : "");
    if (canonical.length > 254) failUrl();
    return canonical;
  }

  function canonicalizePort(rawPort, scheme) {
    let port = String(rawPort || "").trim();
    if (!port) return "";
    if (!/^[0-9]{1,5}$/u.test(port)) failUrl();

    const numeric = Number(port);
    if (!Number.isInteger(numeric) || numeric < 0 || numeric > 65535) failUrl();

    port = String(numeric);
    if ((scheme === "https" && numeric === 443) ||
        (scheme === "http" && numeric === 80)) return "";
    return port;
  }

  function normalizedDotToken(segment) {
    return segment.toLowerCase().replace(/%2e/gu, ".");
  }

  function normalizePathname(rawPathname) {
    let pathname = String(rawPathname || "");
    if (!pathname) pathname = "/";
    if (!pathname.startsWith("/")) failUrl();

    // Intentional fail-closed restriction.
    if (pathname.includes("\\")) failUrl();

    const sourceSegments = pathname.split("/");
    const outputSegments = [];
    for (let index = 0; index < sourceSegments.length; index += 1) {
      const segment = sourceSegments[index];
      if (index === 0) {
        outputSegments.push("");
        continue;
      }

      const token = normalizedDotToken(segment);
      if (token === ".") continue;
      if (token === "..") {
        if (outputSegments.length > 1) outputSegments.pop();
        continue;
      }
      outputSegments.push(segment);
    }

    if (pathname.endsWith("/.") ||
        pathname.endsWith("/..") ||
        /\/(?:%2e|\.%2e|%2e\.|%2e%2e)$/iu.test(pathname)) {
      if (outputSegments[outputSegments.length - 1] !== "") {
        outputSegments.push("");
      }
    }

    let normalized = outputSegments.join("/");
    if (!normalized.startsWith("/")) normalized = "/" + normalized;
    return normalized || "/";
  }

  function splitAbsolute(rawValue) {
    const raw = String(rawValue || "").trim();

    // Intentional fail-closed restriction.
    if (raw.includes("\\")) failUrl();

    const match = /^(https?):\/\/([\s\S]*)$/iu.exec(raw);
    if (!match) failUrl();

    const scheme = match[1].toLowerCase();
    const remainder = match[2];

    let boundary = remainder.length;
    for (const marker of ["/", "?", "#"]) {
      const index = remainder.indexOf(marker);
      if (index >= 0 && index < boundary) boundary = index;
    }

    const authority = remainder.slice(0, boundary);
    let suffix = remainder.slice(boundary);
    if (!authority || authority.includes("@")) failUrl();

    let hostnameRaw = "";
    let portRaw = "";
    if (authority.startsWith("[")) {
      const close = authority.indexOf("]");
      if (close <= 1) failUrl();
      hostnameRaw = authority.slice(0, close + 1);
      const tail = authority.slice(close + 1);
      if (tail) {
        if (!tail.startsWith(":")) failUrl();
        portRaw = tail.slice(1);
      }
    } else {
      const colon = authority.lastIndexOf(":");
      if (colon >= 0) {
        if (authority.slice(0, colon).includes(":")) failUrl();
        hostnameRaw = authority.slice(0, colon);
        portRaw = authority.slice(colon + 1);
      } else {
        hostnameRaw = authority;
      }
    }

    const hostname = canonicalizeHostname(hostnameRaw);
    const port = canonicalizePort(portRaw, scheme);

    let hash = "";
    const hashIndex = suffix.indexOf("#");
    if (hashIndex >= 0) {
      hash = suffix.slice(hashIndex);
      suffix = suffix.slice(0, hashIndex);
    }

    let search = "";
    const searchIndex = suffix.indexOf("?");
    if (searchIndex >= 0) {
      search = suffix.slice(searchIndex);
      suffix = suffix.slice(0, searchIndex);
    }

    const pathname = normalizePathname(suffix || "/");
    return {scheme, hostname, port, pathname, search, hash};
  }

  function originOf(state) {
    return state.scheme + "://" + state.hostname +
      (state.port ? ":" + state.port : "");
  }

  function resolve(valueRaw, baseRaw) {
    const valueText = String(valueRaw || "").trim();

    if (/^https?:\/\//iu.test(valueText)) return valueText;
    if (valueText.includes("\\")) failUrl();
    if (baseRaw === undefined || baseRaw === null) failUrl();

    const base = splitAbsolute(baseRaw);
    const origin = originOf(base);

    if (valueText.startsWith("//")) return base.scheme + ":" + valueText;
    if (valueText.startsWith("/")) return origin + valueText;
    if (valueText.startsWith("?")) return origin + base.pathname + valueText;
    if (valueText.startsWith("#")) {
      return origin + base.pathname + base.search + valueText;
    }

    const slash = base.pathname.lastIndexOf("/");
    const directory = slash >= 0 ? base.pathname.slice(0, slash + 1) : "/";
    return origin + directory + valueText;
  }

  const state = splitAbsolute(resolve(value, baseValue));

  function href() {
    return originOf(state) + state.pathname + state.search + state.hash;
  }

  return {
    get protocol() { return state.scheme + ":"; },
    get username() { return ""; },
    get password() { return ""; },
    get hostname() { return state.hostname; },
    set hostname(valueInput) {
      state.hostname = canonicalizeHostname(valueInput);
    },
    get port() { return state.port; },
    set port(valueInput) {
      state.port = canonicalizePort(valueInput, state.scheme);
    },
    get pathname() { return state.pathname; },
    set pathname(valueInput) {
      state.pathname = normalizePathname(valueInput);
    },
    get search() { return state.search; },
    set search(valueInput) {
      const next = String(valueInput || "");
      state.search = next && !next.startsWith("?") ? "?" + next : next;
    },
    get hash() { return state.hash; },
    set hash(valueInput) {
      const next = String(valueInput || "");
      state.hash = next && !next.startsWith("#") ? "#" + next : next;
    },
    get href() { return href(); },
    toString() { return href(); },
  };
}

const COMMAND_KEYS = [
  "attempt",
  "contractVersion",
  "dispatchEnvelope",
  "executionId",
  "handoffId",
  "leaseToken",
  "scanRunId",
].sort();
const DISPATCH_KEYS = [
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
  throw new Error(
    "PUBLIC_LITE_ACQUISITION_COMMAND_REJECTED: " + message,
  );
}

function plain(value) {
  if (value === null ||
      typeof value !== "object" ||
      Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === null ||
    Object.getPrototypeOf(prototype) === null;
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
  if (!/^[a-f0-9]{64}$/u.test(normalized)) {
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

function normalizeWebhookJson(value, depth, state) {
  if (depth > 8) fail("webhook body nesting too deep");
  state.count += 1;
  if (state.count > 5000) fail("webhook body is too complex");

  if (value === null ||
      typeof value === "string" ||
      typeof value === "boolean") {
    if (typeof value === "string" &&
        Buffer.byteLength(value, "utf8") > 32768) {
      fail("webhook body string is too large");
    }
    return value;
  }

  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      fail("webhook body contains an invalid number");
    }
    return value;
  }

  if (Array.isArray(value)) {
    if (value.length > 500) {
      fail("webhook body array is too large");
    }
    return value.map(
      (item) => normalizeWebhookJson(item, depth + 1, state));
  }

  if (typeof value !== "object") {
    fail("webhook body contains an unsupported value");
  }

  const keys = Object.keys(value);
  if (keys.length > 500) {
    fail("webhook body has too many keys");
  }

  const output = Object.create(null);
  for (const key of keys) {
    if (Buffer.byteLength(key, "utf8") > 180) {
      fail("webhook body key is too long");
    }
    output[key] = normalizeWebhookJson(
      value[key], depth + 1, state);
  }
  return output;
}

const incoming = $input.first().json;
const raw = incoming &&
    Object.prototype.hasOwnProperty.call(incoming, "body") ?
  normalizeWebhookJson(incoming.body, 0, {count: 0}) : incoming;
exactKeys(raw, COMMAND_KEYS, "acquisitionCommand");
if (raw.contractVersion !==
    "risk-scan-public-lite-acquisition-command-v1") {
  fail("unsupported acquisition command");
}
const handoffId = sha(raw.handoffId, "handoffId");
const executionId = sha(raw.executionId, "executionId");
const scanRunId = text(raw.scanRunId, "scanRunId", 180);
if (scanRunId.includes("/") ||
    scanRunId === "." || scanRunId === "..") {
  fail("scanRunId is invalid");
}
if (!Number.isInteger(raw.attempt) ||
    raw.attempt < 1 || raw.attempt > 5) {
  fail("attempt is outside child dispatch policy");
}
const leaseToken = sha(raw.leaseToken, "leaseToken");
const dispatchRaw = raw.dispatchEnvelope;
exactKeys(dispatchRaw, DISPATCH_KEYS, "dispatchEnvelope");
if (dispatchRaw.contractVersion !==
    "risk-scan-public-lite-dispatch-envelope-v1" ||
    dispatchRaw.scanMode !== "quick" ||
    dispatchRaw.accessTier !== "publicLite" ||
    dispatchRaw.identityMode !== "anonymous") {
  fail("unsupported dispatch mode");
}
exactKeys(dispatchRaw.target, TARGET_KEYS, "target");
exactKeys(dispatchRaw.trace, TRACE_KEYS, "trace");
const dispatchExecutionId = sha(
  dispatchRaw.executionId,
  "dispatchEnvelope.executionId",
);
const dispatchScanRunId = text(
  dispatchRaw.scanRunId,
  "dispatchEnvelope.scanRunId",
  180,
);
if (dispatchExecutionId !== executionId ||
    dispatchScanRunId !== scanRunId) {
  fail("dispatch scope does not match acquisition command");
}
const officialHost = text(
  dispatchRaw.target.officialHost,
  "target.officialHost",
  512,
).toLowerCase().replace(/\.$/u, "");
const officialUrl = parseHttpUrlWithoutGlobal(text(
  dispatchRaw.target.officialWebsiteCanonicalUrl,
  "target.officialWebsiteCanonicalUrl",
  4096,
));
if (!["http:", "https:"].includes(officialUrl.protocol) ||
    officialUrl.username || officialUrl.password ||
    officialUrl.pathname !== "/" ||
    officialUrl.search || officialUrl.hash ||
    officialUrl.hostname.toLowerCase().replace(/\.$/u, "") !==
      officialHost) {
  fail("target official URL is invalid");
}
if (!Array.isArray(dispatchRaw.channelCodes) ||
    dispatchRaw.channelCodes.length !== CHANNELS.length ||
    dispatchRaw.channelCodes.some(
      (value, index) => value !== CHANNELS[index])) {
  fail("canonical channel set is required");
}
const requestedAt = iso(dispatchRaw.requestedAt, "requestedAt");
const expiresAt = iso(dispatchRaw.expiresAt, "expiresAt");
if (Date.parse(expiresAt) <= Date.parse(requestedAt)) {
  fail("dispatch is expired");
}
const dispatchEnvelope = safe({
  contractVersion:
    "risk-scan-public-lite-dispatch-envelope-v1",
  executionId,
  scanRunId,
  scanMode: "quick",
  accessTier: "publicLite",
  identityMode: "anonymous",
  target: {
    brandNameNormalized: text(
      dispatchRaw.target.brandNameNormalized,
      "target.brandNameNormalized",
      300,
    ),
    officialHost,
    officialWebsiteCanonicalUrl: officialUrl.toString(),
    targetFingerprintSha256: sha(
      dispatchRaw.target.targetFingerprintSha256,
      "target.targetFingerprintSha256",
    ),
  },
  channelCodes: [...CHANNELS],
  requestedAt,
  expiresAt,
  trace: {
    sourceEventId: text(
      dispatchRaw.trace.sourceEventId,
      "trace.sourceEventId",
      512,
    ),
    requestId: text(
      dispatchRaw.trace.requestId,
      "trace.requestId",
      180,
    ),
    requestFingerprintSha256: sha(
      dispatchRaw.trace.requestFingerprintSha256,
      "trace.requestFingerprintSha256",
    ),
  },
}, "dispatchEnvelope", 0);
return [{
  json: {
    acquisitionCommand: {
      contractVersion:
        "risk-scan-public-lite-acquisition-command-v1",
      handoffId,
      executionId,
      scanRunId,
      dispatchEnvelope,
      attempt: raw.attempt,
      leaseToken,
    },
    dispatchEnvelope,
  },
}];`;
}

function acquisitionReceiptCode() {
  return String.raw`const item = $input.first().json;
const command = item && item.acquisitionCommand;
if (!command || typeof command !== "object") {
  throw new Error(
    "PUBLIC_LITE_ACQUISITION_RECEIPT_REJECTED: command missing",
  );
}
const handoffId = String(command.handoffId || "").trim().toLowerCase();
if (!/^[a-f0-9]{64}$/.test(handoffId)) {
  throw new Error(
    "PUBLIC_LITE_ACQUISITION_RECEIPT_REJECTED: handoffId invalid",
  );
}
const externalExecutionId = "n8n-handoff:" + handoffId;
const acceptedAt = new Date().toISOString();
return [{
  json: {
    acquisitionCommand: command,
    dispatchEnvelope: command.dispatchEnvelope,
    receipt: {
      contractVersion:
        "risk-scan-public-lite-acquisition-dispatch-receipt-v2",
      providerCode: "n8n_public_lite",
      handoffId: command.handoffId,
      executionId: command.executionId,
      externalExecutionId,
      acceptedAt,
    },
    workerState: {
      contractVersion:
        "risk-scan-public-lite-acquisition-dispatch-receipt-v2",
      acquisitionInstalled: true,
      acquisitionExecutionEnabled: false,
      resultCallbackEnabled: false,
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
  return String.raw`function parseHttpUrlWithoutGlobal(value, baseValue) {
  function failUrl() {
    throw new TypeError("invalid URL");
  }

  function punycodeEncode(input) {
    const base = 36;
    const tMin = 1;
    const tMax = 26;
    const skew = 38;
    const damp = 700;
    const initialBias = 72;
    const initialN = 128;
    const delimiter = "-";

    function adapt(delta, numPoints, firstTime) {
      delta = firstTime ? Math.floor(delta / damp) : (delta >> 1);
      delta += Math.floor(delta / numPoints);
      let k = 0;
      while (delta > Math.floor(((base - tMin) * tMax) / 2)) {
        delta = Math.floor(delta / (base - tMin));
        k += base;
      }
      return k + Math.floor(
        ((base - tMin + 1) * delta) / (delta + skew)
      );
    }

    function digitToBasic(digit) {
      return String.fromCharCode(
        digit + 22 + 75 * (digit < 26 ? 1 : 0)
      );
    }

    const codePoints = Array.from(input).map((character) =>
      character.codePointAt(0)
    );
    let output = "";
    let n = initialN;
    let delta = 0;
    let bias = initialBias;

    for (const point of codePoints) {
      if (point < 0x80) output += String.fromCharCode(point);
    }

    let handled = output.length;
    const basicLength = handled;
    if (basicLength > 0) output += delimiter;

    while (handled < codePoints.length) {
      let m = Number.MAX_SAFE_INTEGER;
      for (const point of codePoints) {
        if (point >= n && point < m) m = point;
      }
      if (!Number.isFinite(m) || m === Number.MAX_SAFE_INTEGER) failUrl();

      const step = (m - n) * (handled + 1);
      if (!Number.isSafeInteger(step) ||
          !Number.isSafeInteger(delta + step)) failUrl();

      delta += step;
      n = m;

      for (const point of codePoints) {
        if (point < n) {
          delta += 1;
          if (!Number.isSafeInteger(delta)) failUrl();
        }
        if (point === n) {
          let q = delta;
          for (let k = base; ; k += base) {
            let t;
            if (k <= bias) t = tMin;
            else if (k >= bias + tMax) t = tMax;
            else t = k - bias;

            if (q < t) break;
            const code = t + ((q - t) % (base - t));
            output += digitToBasic(code);
            q = Math.floor((q - t) / (base - t));
          }
          output += digitToBasic(q);
          bias = adapt(delta, handled + 1, handled === basicLength);
          delta = 0;
          handled += 1;
        }
      }
      delta += 1;
      n += 1;
    }

    return output;
  }

  function canonicalizeIpv4IfApplicable(hostname) {
    const labels = hostname.split(".");
    const numericLike = labels.every((label) =>
      /^[0-9]+$/u.test(label) || /^0x[0-9a-f]+$/iu.test(label)
    );
    if (!numericLike) return null;

    if (labels.length !== 4) failUrl();
    const canonical = [];
    for (const label of labels) {
      if (!/^[0-9]+$/u.test(label)) failUrl();
      if (label.length > 1 && label.startsWith("0")) failUrl();
      const value = Number(label);
      if (!Number.isInteger(value) || value < 0 || value > 255) failUrl();
      canonical.push(String(value));
    }
    return canonical.join(".");
  }

  function canonicalizeHostname(rawHostname) {
    let hostname = String(rawHostname || "").trim();
    if (!hostname) failUrl();

    if (hostname.startsWith("[") && hostname.endsWith("]")) {
      const inner = hostname.slice(1, -1);
      if (!inner || /[^0-9a-fA-F:.]/u.test(inner)) failUrl();
      return "[" + inner.toLowerCase() + "]";
    }

    if (/%/u.test(hostname)) {
      try {
        hostname = decodeURIComponent(hostname);
      } catch {
        failUrl();
      }
    }

    hostname = hostname.toLowerCase();
    if (/[\s\\/?#@:]/u.test(hostname)) failUrl();

    const trailingDot = hostname.endsWith(".");
    const core = trailingDot ? hostname.slice(0, -1) : hostname;
    if (!core) failUrl();

    const ipv4 = canonicalizeIpv4IfApplicable(core);
    if (ipv4 !== null) return ipv4 + (trailingDot ? "." : "");

    const labels = core.split(".");
    const canonicalLabels = [];
    for (const label of labels) {
      if (!label) failUrl();
      let next = label;
      if (/[^\x00-\x7F]/u.test(next)) {
        next = "xn--" + punycodeEncode(next);
      }
      if (!/^[a-z0-9-]+$/u.test(next)) failUrl();
      if (next.startsWith("-") || next.endsWith("-")) failUrl();
      if (next.length > 63) failUrl();
      canonicalLabels.push(next);
    }

    const canonical = canonicalLabels.join(".") + (trailingDot ? "." : "");
    if (canonical.length > 254) failUrl();
    return canonical;
  }

  function canonicalizePort(rawPort, scheme) {
    let port = String(rawPort || "").trim();
    if (!port) return "";
    if (!/^[0-9]{1,5}$/u.test(port)) failUrl();

    const numeric = Number(port);
    if (!Number.isInteger(numeric) || numeric < 0 || numeric > 65535) failUrl();

    port = String(numeric);
    if ((scheme === "https" && numeric === 443) ||
        (scheme === "http" && numeric === 80)) return "";
    return port;
  }

  function normalizedDotToken(segment) {
    return segment.toLowerCase().replace(/%2e/gu, ".");
  }

  function normalizePathname(rawPathname) {
    let pathname = String(rawPathname || "");
    if (!pathname) pathname = "/";
    if (!pathname.startsWith("/")) failUrl();

    // Intentional fail-closed restriction.
    if (pathname.includes("\\")) failUrl();

    const sourceSegments = pathname.split("/");
    const outputSegments = [];
    for (let index = 0; index < sourceSegments.length; index += 1) {
      const segment = sourceSegments[index];
      if (index === 0) {
        outputSegments.push("");
        continue;
      }

      const token = normalizedDotToken(segment);
      if (token === ".") continue;
      if (token === "..") {
        if (outputSegments.length > 1) outputSegments.pop();
        continue;
      }
      outputSegments.push(segment);
    }

    if (pathname.endsWith("/.") ||
        pathname.endsWith("/..") ||
        /\/(?:%2e|\.%2e|%2e\.|%2e%2e)$/iu.test(pathname)) {
      if (outputSegments[outputSegments.length - 1] !== "") {
        outputSegments.push("");
      }
    }

    let normalized = outputSegments.join("/");
    if (!normalized.startsWith("/")) normalized = "/" + normalized;
    return normalized || "/";
  }

  function splitAbsolute(rawValue) {
    const raw = String(rawValue || "").trim();

    // Intentional fail-closed restriction.
    if (raw.includes("\\")) failUrl();

    const match = /^(https?):\/\/([\s\S]*)$/iu.exec(raw);
    if (!match) failUrl();

    const scheme = match[1].toLowerCase();
    const remainder = match[2];

    let boundary = remainder.length;
    for (const marker of ["/", "?", "#"]) {
      const index = remainder.indexOf(marker);
      if (index >= 0 && index < boundary) boundary = index;
    }

    const authority = remainder.slice(0, boundary);
    let suffix = remainder.slice(boundary);
    if (!authority || authority.includes("@")) failUrl();

    let hostnameRaw = "";
    let portRaw = "";
    if (authority.startsWith("[")) {
      const close = authority.indexOf("]");
      if (close <= 1) failUrl();
      hostnameRaw = authority.slice(0, close + 1);
      const tail = authority.slice(close + 1);
      if (tail) {
        if (!tail.startsWith(":")) failUrl();
        portRaw = tail.slice(1);
      }
    } else {
      const colon = authority.lastIndexOf(":");
      if (colon >= 0) {
        if (authority.slice(0, colon).includes(":")) failUrl();
        hostnameRaw = authority.slice(0, colon);
        portRaw = authority.slice(colon + 1);
      } else {
        hostnameRaw = authority;
      }
    }

    const hostname = canonicalizeHostname(hostnameRaw);
    const port = canonicalizePort(portRaw, scheme);

    let hash = "";
    const hashIndex = suffix.indexOf("#");
    if (hashIndex >= 0) {
      hash = suffix.slice(hashIndex);
      suffix = suffix.slice(0, hashIndex);
    }

    let search = "";
    const searchIndex = suffix.indexOf("?");
    if (searchIndex >= 0) {
      search = suffix.slice(searchIndex);
      suffix = suffix.slice(0, searchIndex);
    }

    const pathname = normalizePathname(suffix || "/");
    return {scheme, hostname, port, pathname, search, hash};
  }

  function originOf(state) {
    return state.scheme + "://" + state.hostname +
      (state.port ? ":" + state.port : "");
  }

  function resolve(valueRaw, baseRaw) {
    const valueText = String(valueRaw || "").trim();

    if (/^https?:\/\//iu.test(valueText)) return valueText;
    if (valueText.includes("\\")) failUrl();
    if (baseRaw === undefined || baseRaw === null) failUrl();

    const base = splitAbsolute(baseRaw);
    const origin = originOf(base);

    if (valueText.startsWith("//")) return base.scheme + ":" + valueText;
    if (valueText.startsWith("/")) return origin + valueText;
    if (valueText.startsWith("?")) return origin + base.pathname + valueText;
    if (valueText.startsWith("#")) {
      return origin + base.pathname + base.search + valueText;
    }

    const slash = base.pathname.lastIndexOf("/");
    const directory = slash >= 0 ? base.pathname.slice(0, slash + 1) : "/";
    return origin + directory + valueText;
  }

  const state = splitAbsolute(resolve(value, baseValue));

  function href() {
    return originOf(state) + state.pathname + state.search + state.hash;
  }

  return {
    get protocol() { return state.scheme + ":"; },
    get username() { return ""; },
    get password() { return ""; },
    get hostname() { return state.hostname; },
    set hostname(valueInput) {
      state.hostname = canonicalizeHostname(valueInput);
    },
    get port() { return state.port; },
    set port(valueInput) {
      state.port = canonicalizePort(valueInput, state.scheme);
    },
    get pathname() { return state.pathname; },
    set pathname(valueInput) {
      state.pathname = normalizePathname(valueInput);
    },
    get search() { return state.search; },
    set search(valueInput) {
      const next = String(valueInput || "");
      state.search = next && !next.startsWith("?") ? "?" + next : next;
    },
    get hash() { return state.hash; },
    set hash(valueInput) {
      const next = String(valueInput || "");
      state.hash = next && !next.startsWith("#") ? "#" + next : next;
    },
    get href() { return href(); },
    toString() { return href(); },
  };
}

const response = $input.first().json;
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
    parsed = parseHttpUrlWithoutGlobal(value, finalUrl);
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
    const parsed = parseHttpUrlWithoutGlobal(canonicalUrl);
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


function assertCredentialPair(id, name, label) {
  if (Boolean(id) !== Boolean(name)) {
    throw new TypeError(
      `${label} credential id and name must be supplied together`,
    );
  }
}

function headerAuthNode({
  node,
  credentialId,
  credentialName,
}) {
  if (!credentialId || !credentialName) return node;
  return {
    ...node,
    parameters: {
      ...node.parameters,
      authentication: "genericCredentialType",
      genericAuthType: "httpHeaderAuth",
    },
    credentials: {
      httpHeaderAuth: {
        id: credentialId,
        name: credentialName,
      },
    },
  };
}

function webhookWithCredential({
  node,
  credentialId,
  credentialName,
}) {
  if (!credentialId || !credentialName) return node;
  return {
    ...node,
    parameters: {
      ...node.parameters,
      authentication: "headerAuth",
    },
    credentials: {
      httpHeaderAuth: {
        id: credentialId,
        name: credentialName,
      },
    },
  };
}

function buildWorkflow({
  webhookCredentialId = "",
  webhookCredentialName = "",
  handoffCredentialId = "",
  handoffCredentialName = "",
} = {}) {
  assertCredentialPair(
    webhookCredentialId,
    webhookCredentialName,
    "webhook",
  );
  assertCredentialPair(
    handoffCredentialId,
    handoffCredentialName,
    "handoff",
  );

  const webhookBound = Boolean(
    webhookCredentialId && webhookCredentialName);
  const handoffBound = Boolean(
    handoffCredentialId && handoffCredentialName);

  const webhookNode = webhookWithCredential({
    credentialId: webhookCredentialId,
    credentialName: webhookCredentialName,
    node: {
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
    },
  });

  const handoffNode = headerAuthNode({
    credentialId: handoffCredentialId,
    credentialName: handoffCredentialName,
    node: {
      parameters: {
        method: "POST",
        url: HANDOFF_URL,
        authentication: "none",
        sendBody: true,
        contentType: "raw",
        rawContentType: "application/json",
        body:
          "={{ JSON.stringify($json.handoffRequest) }}",
        options: {
          timeout: 15000,
          response: {
            response: {
              fullResponse: true,
              neverError: true,
              responseFormat: "json",
            },
          },
        },
      },
      id: NODE_IDS.handoffHttp,
      name: "Persist Durable Provider Handoff",
      type: "n8n-nodes-base.httpRequest",
      typeVersion: 4.2,
      position: [160, 20],
      disabled: !handoffBound,
    },
  });

  return {
    name: WORKFLOW_NAME,
    nodes: [
      {
        parameters: {
          content:
            "## HRT-MKT-TR-1D-3D-B4-B5 — INACTIVE GATEWAY V2\n\n" +
            "This parent workflow returns HTTP 202 only after the " +
            "provider handoff is durably accepted by Firestore through " +
            "acceptPublicLiteRiskScanHandoff. It contains no marketplace " +
            "acquisition and no result callback. Do not activate until " +
            "credential binding, inactive import, backend deployment, " +
            "index/TTL operationalization, reconciliation/redrive, and " +
            "controlled live validation are complete.",
          height: 340,
          width: 560,
          color: 5,
        },
        id: NODE_IDS.note,
        name: "Gateway V2 Deployment Safety Gate",
        type: "n8n-nodes-base.stickyNote",
        typeVersion: 1,
        position: [-760, -360],
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
          content:
            "## Durable provider handoff\n\n" +
            `Request: ${HANDOFF_REQUEST_VERSION}\n\n` +
            `Receipt: ${HANDOFF_RECEIPT_VERSION}\n\n` +
            `Endpoint: ${HANDOFF_URL}\n\n` +
            `Header: ${HANDOFF_HEADER}\n\n` +
            "The dedicated header credential is metadata-only in the " +
            "workflow JSON; no token value may be embedded.",
          height: 300,
          width: 520,
          color: 3,
        },
        id: NODE_IDS.handoffNote,
        name: "Durable Handoff Contract Note",
        type: "n8n-nodes-base.stickyNote",
        typeVersion: 1,
        position: [-120, -360],
      },
      {
        parameters: {
          jsCode: handoffRequestCode(),
        },
        id: NODE_IDS.handoffRequest,
        name: "Build Durable Provider Handoff Request",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [-120, 20],
      },
      handoffNode,
      {
        parameters: {
          jsCode: receiptCode(),
        },
        id: NODE_IDS.receipt,
        name: "Build Durable Dispatch Receipt",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [440, 20],
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
        name: "Return 202 Durable Dispatch Receipt",
        type: "n8n-nodes-base.respondToWebhook",
        typeVersion: 1.4,
        position: [720, 20],
      },
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
          node: "Build Durable Provider Handoff Request",
          type: "main",
          index: 0,
        }]],
      },
      "Build Durable Provider Handoff Request": {
        main: [[{
          node: "Persist Durable Provider Handoff",
          type: "main",
          index: 0,
        }]],
      },
      "Persist Durable Provider Handoff": {
        main: [[{
          node: "Build Durable Dispatch Receipt",
          type: "main",
          index: 0,
        }]],
      },
      "Build Durable Dispatch Receipt": {
        main: [[{
          node: "Return 202 Durable Dispatch Receipt",
          type: "main",
          index: 0,
        }]],
      },
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
        webhookBound && handoffBound,
      hrtPhase: "HRT-MKT-TR-1D-3D-B4-B5",
      gatewayContractVersion: DISPATCH_ENVELOPE_VERSION,
      dispatchReceiptContractVersion:
        DISPATCH_RECEIPT_VERSION_V2,
      providerCode: PROVIDER_CODE,
      durableProviderHandoffInstalled: true,
      durableProviderHandoffEnabled: handoffBound,
      outboundAcquisition: false,
      resultCallback: false,
      webhookHeader: WEBHOOK_HEADER,
      handoffHeader: HANDOFF_HEADER,
      activationAllowed: false,
    },
    tags: [],
  };
}

function buildAcquisitionWorkflow({
  acquisitionCredentialId = "",
  acquisitionCredentialName = "",
  resultCredentialId = "",
  resultCredentialName = "",
  acquisitionExecutionEnabled = false,
  resultCallbackEnabled = false,
} = {}) {
  assertCredentialPair(
    acquisitionCredentialId,
    acquisitionCredentialName,
    "acquisition webhook",
  );
  assertCredentialPair(
    resultCredentialId,
    resultCredentialName,
    "result",
  );
  if (typeof acquisitionExecutionEnabled !== "boolean") {
    throw new TypeError(
      "acquisitionExecutionEnabled must be a boolean");
  }
  if (typeof resultCallbackEnabled !== "boolean") {
    throw new TypeError(
      "resultCallbackEnabled must be a boolean");
  }

  const acquisitionBound = Boolean(
    acquisitionCredentialId && acquisitionCredentialName);
  const resultBound = Boolean(
    resultCredentialId && resultCredentialName);
  if (resultCallbackEnabled && !resultBound) {
    throw new TypeError(
      "result callback enable requires result credential binding");
  }

  const webhookNode = webhookWithCredential({
    credentialId: acquisitionCredentialId,
    credentialName: acquisitionCredentialName,
    node: {
      parameters: {
        httpMethod: "POST",
        path: ACQUISITION_WEBHOOK_PATH,
        responseMode: "responseNode",
        options: {},
      },
      id: ACQUISITION_NODE_IDS.webhook,
      name: "Acquisition Handoff Webhook",
      type: "n8n-nodes-base.webhook",
      typeVersion: 2.1,
      position: [-680, 20],
      webhookId: ACQUISITION_WEBHOOK_ID,
      disabled: !acquisitionBound,
    },
  });

  const resultTemplateNode = headerAuthNode({
    credentialId: resultCredentialId,
    credentialName: resultCredentialName,
    node: {
      parameters: {
        method: "POST",
        url: CALLBACK_URL,
        authentication: "none",
        sendBody: true,
        contentType: "raw",
        rawContentType: "application/json",
        body: resultTemplateBody(),
        options: {
          timeout: 45000,
        },
      },
      id: ACQUISITION_NODE_IDS.resultTemplate,
      name: "Result Callback Template - Disabled",
      type: "n8n-nodes-base.httpRequest",
      typeVersion: 4.2,
      position: [1280, 360],
      disabled: !resultCallbackEnabled,
    },
  });

  return {
    name: ACQUISITION_WORKFLOW_NAME,
    nodes: [
      {
        parameters: {
          content:
            "## HRT-MKT-TR-1D-3D-B4-B5 — INACTIVE ACQUISITION WORKER\n\n" +
            "This child workflow acknowledges a validated acquisition " +
            "command with HTTP 202 before the long marketplace path. " +
            "Acquisition execution and result callback remain disabled. " +
            "Do not activate until inactive import, credential binding, " +
            "backend deployment, reconciliation/redrive, index/TTL " +
            "operationalization, and controlled live validation complete. " +
            "Logical child identity is deterministic from handoffId.",
          height: 340,
          width: 560,
          color: 5,
        },
        id: ACQUISITION_NODE_IDS.note,
        name: "Acquisition Worker Deployment Safety Gate",
        type: "n8n-nodes-base.stickyNote",
        typeVersion: 1,
        position: [-760, -360],
      },
      webhookNode,
      {
        parameters: {
          jsCode: acquisitionCommandValidatorCode(),
        },
        id: ACQUISITION_NODE_IDS.validate,
        name: "Validate Acquisition Handoff Command",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [-400, 20],
      },
      {
        parameters: {
          jsCode: acquisitionReceiptCode(),
        },
        id: ACQUISITION_NODE_IDS.receipt,
        name: "Build Acquisition Dispatch Receipt",
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
        id: ACQUISITION_NODE_IDS.respond,
        name: "Return 202 Acquisition Dispatch Receipt",
        type: "n8n-nodes-base.respondToWebhook",
        typeVersion: 1.4,
        position: [160, 20],
      },
      {
        parameters: {
          content:
            "## marketplaceLimited execution — disabled\n\n" +
            `Adapter: ${ADAPTER_CODE}\n\n` +
            `Channel adapter result: ${CHANNEL_ADAPTER_RESULT_CONTRACT_VERSION}\n\n` +
            "Public pages only. No authentication, cookies, API keys, " +
            "CAPTCHA solving, or anti-bot bypass. The execution guard is " +
            "false and the HTTP Request node is disabled.",
          height: 320,
          width: 520,
          color: 5,
        },
        id: ACQUISITION_NODE_IDS.acquisitionNote,
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
        id: ACQUISITION_NODE_IDS.acquisitionPlan,
        name: "Build Marketplace Limited Acquisition Plan",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [160, -120],
      },
      {
        parameters: {
          jsCode: acquisitionGuardCode(),
        },
        id: ACQUISITION_NODE_IDS.acquisitionGuard,
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
        id: ACQUISITION_NODE_IDS.acquisitionHttp,
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
        id: ACQUISITION_NODE_IDS.normalizeMarketplace,
        name: "Normalize Marketplace Limited Result",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [1000, -120],
      },
      {
        parameters: {
          jsCode: providerAssemblerCode(),
        },
        id: ACQUISITION_NODE_IDS.assembleProvider,
        name: "Assemble Canonical Provider Result",
        type: "n8n-nodes-base.code",
        typeVersion: 2,
        position: [1280, -120],
      },
      {
        parameters: {
          content:
            "## Result callback — disabled\n\n" +
            `Contract: ${RESULT_ENVELOPE_VERSION}\n\n` +
            `Provider result: ${PROVIDER_RESULT_VERSION}\n\n` +
            `Callback: ${CALLBACK_URL}\n\n` +
            `Header: ${RESULT_HEADER}\n\n` +
            "Only the assembled resultEnvelope may be sent after " +
            "controlled live validation. No synthetic result or " +
            "placeholder evidence may be sent.",
          height: 300,
          width: 500,
          color: 3,
        },
        id: ACQUISITION_NODE_IDS.resultTemplateNote,
        name: "Result Contract Safety Note",
        type: "n8n-nodes-base.stickyNote",
        typeVersion: 1,
        position: [-180, 260],
      },
      resultTemplateNode,
    ],
    pinData: {},
    connections: {
      "Acquisition Handoff Webhook": {
        main: [[{
          node: "Validate Acquisition Handoff Command",
          type: "main",
          index: 0,
        }]],
      },
      "Validate Acquisition Handoff Command": {
        main: [[{
          node: "Build Acquisition Dispatch Receipt",
          type: "main",
          index: 0,
        }]],
      },
      "Build Acquisition Dispatch Receipt": {
        main: [[
          {
            node: "Return 202 Acquisition Dispatch Receipt",
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
    versionId: ACQUISITION_WORKFLOW_VERSION_ID,
    meta: {
      templateCredsSetupCompleted:
        acquisitionBound && resultBound,
      hrtPhase: "HRT-MKT-TR-1D-3D-B4-C",
      acquisitionCommandContractVersion:
        ACQUISITION_COMMAND_VERSION,
      acquisitionReceiptContractVersion:
        ACQUISITION_RECEIPT_VERSION,
      logicalExternalExecutionIdFormat:
        "n8n-handoff:<handoffId>",
      providerCode: PROVIDER_CODE,
      acquisitionInstalled: true,
      acquisitionExecutionEnabled,
      resultCallbackEnabled,
      acquisitionHeader: ACQUISITION_HEADER,
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

function writeAcquisitionWorkflow(outputPath, options = {}) {
  const workflow = buildAcquisitionWorkflow(options);
  const serialized = serializeWorkflow(workflow);
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.writeFileSync(outputPath, serialized, "utf8");
  return workflow;
}

module.exports = Object.freeze({
  ACQUISITION_COMMAND_VERSION,
  ACQUISITION_HEADER,
  ACQUISITION_NODE_IDS,
  ACQUISITION_RECEIPT_VERSION,
  ACQUISITION_WEBHOOK_PATH,
  ACQUISITION_WORKFLOW_NAME,
  CALLBACK_URL,
  DISPATCH_RECEIPT_VERSION_V2,
  HANDOFF_HEADER,
  HANDOFF_RECEIPT_VERSION,
  HANDOFF_REQUEST_VERSION,
  HANDOFF_URL,
  NODE_IDS,
  RESULT_HEADER,
  WEBHOOK_HEADER,
  WEBHOOK_PATH,
  WORKFLOW_NAME,
  acquisitionCommandValidatorCode,
  acquisitionGuardCode,
  acquisitionPlanCode,
  acquisitionReceiptCode,
  buildAcquisitionWorkflow,
  buildWorkflow,
  canonicalJson,
  handoffRequestCode,
  marketplaceNormalizerCode,
  providerAssemblerCode,
  receiptCode,
  resultTemplateBody,
  serializeWorkflow,
  validatorCode,
  writeAcquisitionWorkflow,
  writeWorkflow,
});
