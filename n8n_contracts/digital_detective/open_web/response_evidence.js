"use strict";

const crypto = require("node:crypto");
const {utf8ByteLength} = require("../runtime/portable_primitives");
const {buildContentHash, buildSnapshotId, buildSourceId} =
  require("../validators/deterministic_ids");
const {validateAcquisitionResult} =
  require("../validators/validate_acquisition_result");
const {validateCandidateSource} =
  require("../validators/validate_candidate_source");
const {validateEvidenceBatch} =
  require("../validators/validate_evidence_batch");
const {validateOpenWebUrl} = require("./url_policy");

const MAX_RAW_BODY_BYTES = 262144;

function ownData(value, key) {
  try {
    if (value === null || typeof value !== "object" || Array.isArray(value) ||
        !Object.prototype.hasOwnProperty.call(value, key)) return null;
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor,
        "value")) return null;
    return {value: descriptor.value};
  } catch (_) {
    return null;
  }
}

function headerValue(headers, wanted) {
  try {
    if (headers === null || typeof headers !== "object" ||
        Array.isArray(headers)) return null;
    for (const key of Object.getOwnPropertyNames(headers)) {
      const descriptor = Object.getOwnPropertyDescriptor(headers, key);
      if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor,
          "value")) return null;
      if (key.toLowerCase() === wanted) return descriptor.value;
    }
    return undefined;
  } catch (_) {
    return null;
  }
}

function headerScalar(value) {
  if (typeof value === "string" || typeof value === "number") return value;
  if (Array.isArray(value) && value.length === 1 &&
      (typeof value[0] === "string" || typeof value[0] === "number")) {
    return value[0];
  }
  return null;
}

function decodeEntities(text) {
  const named = {amp: "&", apos: "'", gt: ">", lt: "<", nbsp: " ",
    quot: "\""};
  return text.replace(/&(?:#(x[0-9a-f]+|[0-9]+)|([a-z]+));/gi,
      (match, numeric, name) => {
        if (name) return Object.prototype.hasOwnProperty.call(named,
            name.toLowerCase()) ? named[name.toLowerCase()] : match;
        const value = numeric[0].toLowerCase() === "x" ?
          Number.parseInt(numeric.slice(1), 16) : Number.parseInt(numeric, 10);
        if (!Number.isSafeInteger(value) || value <= 0 || value > 0x10FFFF ||
            (value >= 0xD800 && value <= 0xDFFF)) return "�";
        return String.fromCodePoint(value);
      });
}

function visibleTextFromHtml(body) {
  return decodeEntities(body
      .replace(/<!--[^]*?-->/g, " ")
      .replace(/<(script|style|noscript)\b[^>]*>[^]*?<\/\1\s*>/gi, " ")
      .replace(/<[^>]*>/g, " "))
      .replace(/\s+/g, " ").trim().normalize("NFC");
}

function titleFromHtml(body) {
  const match = /<title\b[^>]*>([^]*?)<\/title\s*>/i.exec(body);
  if (!match) return null;
  const title = visibleTextFromHtml(match[1]).slice(0, 500);
  return title || null;
}

function sha256(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function guardOpenWebResponse(response) {
  const invalid = (errorCode = "HTTP_RESPONSE_INVALID", errorPath = "$.") =>
    ({valid: false, reason: "HTTP_RESPONSE_INVALID", errorCode, errorPath});
  try {
    const status = ownData(response, "statusCode");
    const headers = ownData(response, "headers");
    const body = ownData(response, "body");
    const finalUrl = ownData(response, "finalUrl");
    if (!status || status.value === undefined) return invalid(
        "HTTP_STATUS_MISSING", "$.statusCode");
    if (!headers || headers.value === undefined) return invalid(
        "HTTP_HEADERS_MISSING", "$.headers");
    if (!body || body.value === undefined) return invalid(
        "HTTP_BODY_MISSING", "$.body");
    if (!finalUrl || finalUrl.value === undefined) return invalid(
        "FINAL_URL_MISSING", "$.finalUrl");
    if (!Number.isInteger(status.value)) return invalid(
        "HTTP_STATUS_INVALID", "$.statusCode");
    if (typeof body.value !== "string") return invalid(
        "HTTP_BODY_INVALID", "$.body");
    if (typeof finalUrl.value !== "string") return invalid(
        "FINAL_URL_INVALID", "$.finalUrl");
    if (status.value < 200 || status.value > 299) return invalid(
        "HTTP_STATUS_INVALID", "$.statusCode");
    const finalPolicy = validateOpenWebUrl({url: finalUrl.value});
    if (!finalPolicy.valid) return invalid("FINAL_URL_INVALID", "$.finalUrl");
    const contentTypeValue = headerScalar(headerValue(headers.value,
        "content-type"));
    if (typeof contentTypeValue !== "string") return invalid(
        "CONTENT_TYPE_INVALID", "$.headers.content-type");
    const contentType = contentTypeValue.trim();
    if (!/^(?:text\/html|text\/plain)(?:;\s*charset=utf-8)?$/i.test(
        contentType)) return invalid("CONTENT_TYPE_INVALID",
        "$.headers.content-type");
    const rawBodyBytes = utf8ByteLength(body.value);
    if (!body.value || rawBodyBytes === 0) return invalid("EMPTY_BODY", "$.body");
    if (rawBodyBytes > MAX_RAW_BODY_BYTES) return invalid("BODY_TOO_LARGE",
        "$.body");
    const declared = headerScalar(headerValue(headers.value, "content-length"));
    if (declared !== undefined) {
      if ((typeof declared !== "string" && typeof declared !== "number") ||
          !/^[0-9]+$/.test(String(declared)) ||
          Number(declared) !== rawBodyBytes) return invalid(
          "CONTENT_LENGTH_MISMATCH", "$.headers.content-length");
    }
    const visibleText = /^text\/html/i.test(contentType) ?
      visibleTextFromHtml(body.value) : body.value.replace(/\s+/g, " ")
          .trim().normalize("NFC");
    if (!visibleText) return invalid("VISIBLE_TEXT_EMPTY", "$.body");
    const visibleTextBytes = utf8ByteLength(visibleText);
    if (visibleText.length > 50000 || visibleTextBytes > 131072) {
      return invalid("VISIBLE_TEXT_TOO_LARGE", "$.body");
    }
    return {valid: true, reason: "HTTP_RESPONSE_READY",
      normalizedUrl: finalPolicy.normalizedUrl, statusCode: status.value,
      contentType, rawBodyBytes, visibleTextBytes, visibleText,
      pageTitle: /^text\/html/i.test(contentType) ? titleFromHtml(body.value) : null,
      contentSha256: sha256(body.value), visibleTextSha256: sha256(visibleText)};
  } catch (_) {
    return invalid("HTTP_RESPONSE_EXCEPTION", "$.response");
  }
}

function buildOpenWebArtifacts({task, executionId, response, capturedAt}) {
  const guarded = guardOpenWebResponse(response);
  if (!guarded.valid || !task || typeof executionId !== "string" ||
      !executionId || typeof capturedAt !== "string" || !capturedAt) {
    return {valid: false, reason: "HTTP_RESPONSE_INVALID",
      errorCode: guarded.errorCode || "OPEN_WEB_ADAPTER_INVALID",
      errorPath: guarded.errorPath || "$.response"};
  }
  const sourceId = buildSourceId(task.taskId, executionId,
      guarded.normalizedUrl);
  const contractContentHash = buildContentHash(guarded.visibleText);
  const snapshotId = buildSnapshotId(task.taskId, executionId, sourceId,
      contractContentHash);
  const candidate = {contractVersion: "candidate-source-v1",
    taskId: task.taskId, executionId, sourceId,
    sourceUrl: guarded.normalizedUrl, canonicalUrl: guarded.normalizedUrl,
    sourcePlatform: "open_web", pageTitle: guarded.pageTitle,
    sellerName: null, productTitle: null, price: null, currency: null,
    country: null, city: null, searchQuery: null,
    acquisitionMethod: "manual_seed", discoveredAt: capturedAt,
    acquisitionStatus: "acquired", legalBasis: "public_source",
    robotsPolicy: "unknown", errorCode: null};
  const acquisitionResult = {contractVersion: "acquisition-result-v1",
    taskId: task.taskId, executionId, status: "completed",
    candidates: [candidate], queriesAttempted: [guarded.normalizedUrl],
    errors: [], limits: {maximumCandidates: 3,
      maximumTotalVisibleTextBytes: 393216}, fixtureMetadata: null};
  const evidence = {contractVersion: "structured-evidence-v1",
    taskId: task.taskId, executionId, sourceId, snapshotId,
    sourceUrl: guarded.normalizedUrl, retrievedAt: capturedAt,
    httpStatus: guarded.statusCode, contentType: guarded.contentType,
    visibleText: guarded.visibleText, contentHash: contractContentHash,
    snapshotReference: guarded.normalizedUrl, acquisitionStatus: "acquired",
    errorCode: null};
  return {valid: true, reason: "OPEN_WEB_ARTIFACTS_READY", candidate,
    acquisitionResult, evidences: [evidence], capture: {...guarded,
      sourceId, snapshotId, contractContentHash, capturedAt}};
}

function validateOpenWebArtifacts(artifacts) {
  try {
    if (!artifacts || artifacts.valid !== true) return {valid: false};
    const {candidate, acquisitionResult, evidences} = artifacts;
    const context = Object.assign(Object.create(null), {
      taskId: acquisitionResult.taskId, executionId: acquisitionResult.executionId,
      productionCallback: false});
    const acquisitionValidation = validateAcquisitionResult(acquisitionResult,
        context);
    const candidateValidation = validateCandidateSource(candidate, context);
    const evidenceBatchValidation = validateEvidenceBatch(evidences,
        Object.assign(Object.create(null), context, {candidates: [candidate]}));
    return {valid: acquisitionValidation.valid === true &&
      candidateValidation.valid === true && evidenceBatchValidation.valid === true,
    acquisitionValidation, candidateValidation, evidenceBatchValidation};
  } catch (_) {
    return {valid: false};
  }
}

module.exports = {MAX_RAW_BODY_BYTES, buildOpenWebArtifacts,
  guardOpenWebResponse, sha256, validateOpenWebArtifacts, visibleTextFromHtml};
