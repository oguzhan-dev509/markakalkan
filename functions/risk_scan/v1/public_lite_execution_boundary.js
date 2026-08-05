"use strict";

const crypto = require("node:crypto");
const {defineSecret} = require("firebase-functions/params");
const {channelCodes} = require("./contracts");
const {
  normalizeDispatchReceipt,
} = require("./public_lite_execution_contract");
const {
  orchestratePublicLiteExecution,
} = require("./public_lite_execution_service");
const {
  createPublicLiteExecutionFirestorePort,
} = require("./public_lite_execution_firestore_port");
const {
  PublicLiteResultReceiptError,
  normalizePublicLiteResultEnvelope,
  persistPublicLiteResultReceipt,
} = require("./public_lite_result_receipt_firestore_port");

const N8N_PUBLIC_LITE_RISK_SCAN_WEBHOOK_TOKEN = defineSecret(
    "N8N_PUBLIC_LITE_RISK_SCAN_WEBHOOK_TOKEN");
const N8N_PUBLIC_LITE_RISK_SCAN_RESULT_TOKEN = defineSecret(
    "N8N_PUBLIC_LITE_RISK_SCAN_RESULT_TOKEN");

const PUBLIC_LITE_RUN_DOCUMENT = "risk_scan_runs/{scanRunId}";
const PUBLIC_LITE_WEBHOOK_URL =
  "https://sofrasofra-n8n.app.n8n.cloud/webhook/" +
  "markakalkan/public-lite-risk-scan/run-created";
const PUBLIC_LITE_WEBHOOK_TOKEN_HEADER = "X-MarkaKalkan-Token";
const PUBLIC_LITE_RESULT_TOKEN_HEADER =
  "X-MarkaKalkan-Public-Lite-Result-Token";
const PUBLIC_LITE_DISPATCH_RESPONSE_MAX_BYTES = 65536;
const PUBLIC_LITE_DISPATCH_TIMEOUT_MS = 45000;

class PublicLiteDispatchHttpError extends Error {
  constructor(code, message, {statusCode = 0, retryable = false} = {}) {
    super(message);
    this.name = "PublicLiteDispatchHttpError";
    this.code = code;
    this.statusCode = statusCode;
    this.retryable = retryable;
  }
}

function cleanString(value, maximum = 1000) {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maximum);
}

function productionClock() {
  return {now: () => new Date()};
}

function constantTimeEqual(expected, supplied) {
  const left = Buffer.from(String(expected || ""), "utf8");
  const right = Buffer.from(String(supplied || ""), "utf8");
  if (left.length === 0 || left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function getRequestHeader(request, headerName) {
  if (!request || !request.headers) return "";
  const direct = request.headers[headerName.toLowerCase()];
  if (Array.isArray(direct)) return cleanString(direct[0], 10000);
  if (typeof direct === "string") return cleanString(direct, 10000);
  if (typeof request.get === "function") {
    return cleanString(request.get(headerName), 10000);
  }
  return "";
}

function parseRequestBody(request) {
  const body = request && request.body;
  if (body && typeof body === "object" && !Buffer.isBuffer(body) &&
      !Array.isArray(body)) {
    return body;
  }
  const raw = Buffer.isBuffer(body) ?
    body.toString("utf8") : cleanString(body, 1000000);
  if (!raw) throw new TypeError("request body is required");
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new TypeError("request body must be valid JSON");
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new TypeError("request body must be a JSON object");
  }
  return parsed;
}

function safeResponseText(value) {
  return cleanString(value, PUBLIC_LITE_DISPATCH_RESPONSE_MAX_BYTES)
      .replace(/\s+/g, " ");
}

function retryableHttpStatus(statusCode) {
  return statusCode === 408 || statusCode === 425 ||
    statusCode === 429 || statusCode >= 500;
}

function parseDispatchReceiptText(text) {
  const normalized = safeResponseText(text);
  if (!normalized) {
    throw new PublicLiteDispatchHttpError(
        "invalid_dispatch_response",
        "Dispatch provider returned an empty response.");
  }
  let parsed;
  try {
    parsed = JSON.parse(normalized);
  } catch {
    throw new PublicLiteDispatchHttpError(
        "invalid_dispatch_response",
        "Dispatch provider returned invalid JSON.");
  }
  return normalizeDispatchReceipt(parsed);
}

function createPublicLiteN8nDispatcher({
  fetchImpl,
  webhookToken,
  webhookUrl = PUBLIC_LITE_WEBHOOK_URL,
  timeoutMs = PUBLIC_LITE_DISPATCH_TIMEOUT_MS,
}) {
  const requestFetch = fetchImpl || global.fetch;
  if (typeof requestFetch !== "function") {
    throw new TypeError("fetch implementation is required");
  }
  if (!webhookToken || typeof webhookToken.value !== "function") {
    throw new TypeError("webhookToken.value is required");
  }

  return Object.freeze({
    async dispatch(envelope) {
      const token = cleanString(webhookToken.value(), 10000);
      if (!token) {
        throw new PublicLiteDispatchHttpError(
            "missing_webhook_token",
            "Public Lite webhook token is not configured.",
            {retryable: false});
      }
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const response = await requestFetch(webhookUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            [PUBLIC_LITE_WEBHOOK_TOKEN_HEADER]: token,
          },
          body: JSON.stringify(envelope),
          signal: controller.signal,
        });
        const text = await response.text();
        if (Buffer.byteLength(text, "utf8") >
            PUBLIC_LITE_DISPATCH_RESPONSE_MAX_BYTES) {
          throw new PublicLiteDispatchHttpError(
              "dispatch_response_too_large",
              "Dispatch provider response exceeded its size limit.",
              {statusCode: response.status, retryable: false});
        }
        if (!response.ok) {
          throw new PublicLiteDispatchHttpError(
              "dispatch_http_error",
              `Dispatch provider returned HTTP ${response.status}.`,
              {
                statusCode: response.status,
                retryable: retryableHttpStatus(response.status),
              });
        }
        return parseDispatchReceiptText(text);
      } catch (error) {
        if (error instanceof PublicLiteDispatchHttpError) throw error;
        if (error && error.name === "AbortError") {
          throw new PublicLiteDispatchHttpError(
              "dispatch_timeout",
              "Dispatch provider request timed out.",
              {statusCode: 408, retryable: true});
        }
        throw new PublicLiteDispatchHttpError(
            "dispatch_network_error",
            "Dispatch provider request failed before acceptance.",
            {statusCode: 0, retryable: true});
      } finally {
        clearTimeout(timer);
      }
    },
  });
}

async function readPublicLiteChannels(runDocumentRef) {
  const snapshots = await Promise.all(channelCodes.map((channelCode) =>
    runDocumentRef.collection("channels").doc(channelCode).get()));
  return snapshots.map((snapshot, index) => {
    if (!snapshot.exists) {
      throw new Error(`Public Lite channel is missing: ${channelCodes[index]}`);
    }
    return snapshot.data();
  });
}

function isPublicLiteRun(run) {
  return Boolean(run && run.scanMode === "quick" &&
    run.accessTier === "publicLite" &&
    run.identityMode === "anonymous");
}

function buildDispatchPublicLiteRiskScan({
  db,
  onDocumentCreated,
  logger,
  fetchImpl,
  webhookToken = N8N_PUBLIC_LITE_RISK_SCAN_WEBHOOK_TOKEN,
  webhookUrl = PUBLIC_LITE_WEBHOOK_URL,
  clock = productionClock(),
  orchestrate = orchestratePublicLiteExecution,
  portFactory = createPublicLiteExecutionFirestorePort,
} = {}) {
  if (!db) throw new TypeError("db is required");
  if (typeof onDocumentCreated !== "function") {
    throw new TypeError("onDocumentCreated is required");
  }
  if (!logger) throw new TypeError("logger is required");
  if (!clock || typeof clock.now !== "function") {
    throw new TypeError("clock.now is required");
  }
  const port = portFactory(db);
  const dispatcher = createPublicLiteN8nDispatcher({
    fetchImpl,
    webhookToken,
    webhookUrl,
  });

  return onDocumentCreated(
      {
        document: PUBLIC_LITE_RUN_DOCUMENT,
        secrets: [webhookToken],
        retry: true,
        timeoutSeconds: 60,
        maxInstances: 5,
      },
      async (event) => {
        const snapshot = event && event.data;
        if (!snapshot) {
          logger.warn("Public Lite run event has no snapshot", {
            eventId: cleanString(event && event.id, 512) || null,
          });
          return;
        }
        const run = snapshot.data() || {};
        if (!isPublicLiteRun(run)) {
          logger.info("Non-Public-Lite risk run skipped", {
            scanRunId: cleanString(event.params?.scanRunId, 180) || null,
          });
          return;
        }
        const scanRunId = cleanString(event.params?.scanRunId, 180);
        const eventId = cleanString(event.id, 512);
        if (!scanRunId || scanRunId !== run.scanRunId || !eventId) {
          throw new Error("Public Lite run event scope is invalid");
        }
        const channels = await readPublicLiteChannels(snapshot.ref);
        const eventTime = cleanString(event.time, 64) || run.createdAt;
        const result = await orchestrate({
          event: {
            eventId,
            eventTime,
            run,
            channels,
          },
          ownerId: eventId.slice(0, 256),
          port,
          dispatcher,
          clock,
        });
        logger.info("Public Lite execution dispatch processed", {
          eventId,
          scanRunId,
          executionId: result.executionId || null,
          outcome: result.outcome,
          attemptCount: result.attemptCount || null,
        });
        if (result.outcome === "retryable_failure") {
          const error = new Error("Public Lite dispatch will be retried");
          error.code = result.failure?.code || "dispatch_retryable_failure";
          throw error;
        }
      });
}

function sendJson(response, statusCode, body) {
  response.status(statusCode).json(body);
}

function mapReceiptError(error) {
  if (error instanceof TypeError || error instanceof RangeError) {
    return {statusCode: 400, code: "invalid_argument"};
  }
  if (error instanceof PublicLiteResultReceiptError ||
      (error && typeof error.code === "string")) {
    if (error.code === "not-found") {
      return {statusCode: 404, code: "not_found"};
    }
    if (["conflict", "failed-precondition"].includes(error.code)) {
      return {statusCode: 409, code: "conflict"};
    }
  }
  return {statusCode: 500, code: "internal"};
}

function buildReceivePublicLiteRiskScanResult({
  db,
  onRequest,
  logger,
  resultToken = N8N_PUBLIC_LITE_RISK_SCAN_RESULT_TOKEN,
  clock = productionClock(),
  persistReceipt = persistPublicLiteResultReceipt,
} = {}) {
  if (!db) throw new TypeError("db is required");
  if (typeof onRequest !== "function") {
    throw new TypeError("onRequest is required");
  }
  if (!logger) throw new TypeError("logger is required");
  if (!resultToken || typeof resultToken.value !== "function") {
    throw new TypeError("resultToken.value is required");
  }
  if (!clock || typeof clock.now !== "function") {
    throw new TypeError("clock.now is required");
  }

  return onRequest(
      {
        secrets: [resultToken],
        timeoutSeconds: 60,
        maxInstances: 5,
      },
      async (request, response) => {
        response.set("Cache-Control", "no-store");
        if (request.method !== "POST") {
          response.set("Allow", "POST");
          sendJson(response, 405, {
            ok: false,
            code: "method_not_allowed",
          });
          return;
        }
        const expectedToken = cleanString(resultToken.value(), 10000);
        const suppliedToken = getRequestHeader(
            request, PUBLIC_LITE_RESULT_TOKEN_HEADER);
        if (!expectedToken ||
            !constantTimeEqual(expectedToken, suppliedToken)) {
          logger.warn("Public Lite result authorization failed");
          sendJson(response, 403, {ok: false, code: "forbidden"});
          return;
        }
        try {
          const envelope = normalizePublicLiteResultEnvelope(
              parseRequestBody(request));
          const result = await persistReceipt(db, {
            envelope,
            receivedAt: clock.now().toISOString(),
          });
          logger.info("Public Lite result receipt accepted", {
            executionId: envelope.executionId,
            scanRunId: envelope.scanRunId,
            providerEventId: envelope.providerEventId,
            duplicate: result.duplicate,
            receiptId: result.receiptId,
          });
          sendJson(response, 200, {
            ok: true,
            duplicate: result.duplicate,
            receiptId: result.receiptId,
            executionId: envelope.executionId,
            scanRunId: envelope.scanRunId,
          });
        } catch (error) {
          const mapped = mapReceiptError(error);
          if (mapped.statusCode >= 500) {
            logger.error("Public Lite result receipt failed", {
              error: error instanceof Error ? error.message : String(error),
            });
          } else {
            logger.warn("Public Lite result receipt rejected", {
              code: mapped.code,
              message: error instanceof Error ? error.message : String(error),
            });
          }
          sendJson(response, mapped.statusCode, {
            ok: false,
            code: mapped.code,
          });
        }
      });
}

module.exports = Object.freeze({
  N8N_PUBLIC_LITE_RISK_SCAN_RESULT_TOKEN,
  N8N_PUBLIC_LITE_RISK_SCAN_WEBHOOK_TOKEN,
  PUBLIC_LITE_DISPATCH_RESPONSE_MAX_BYTES,
  PUBLIC_LITE_DISPATCH_TIMEOUT_MS,
  PUBLIC_LITE_RESULT_TOKEN_HEADER,
  PUBLIC_LITE_RUN_DOCUMENT,
  PUBLIC_LITE_WEBHOOK_TOKEN_HEADER,
  PUBLIC_LITE_WEBHOOK_URL,
  PublicLiteDispatchHttpError,
  buildDispatchPublicLiteRiskScan,
  buildReceivePublicLiteRiskScanResult,
  cleanString,
  constantTimeEqual,
  createPublicLiteN8nDispatcher,
  getRequestHeader,
  isPublicLiteRun,
  mapReceiptError,
  parseDispatchReceiptText,
  parseRequestBody,
  productionClock,
  readPublicLiteChannels,
  retryableHttpStatus,
  safeResponseText,
  sendJson,
});
