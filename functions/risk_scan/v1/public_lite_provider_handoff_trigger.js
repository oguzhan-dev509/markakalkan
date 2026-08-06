"use strict";

const {defineSecret} = require("firebase-functions/params");
const {
  cleanString,
  retryableHttpStatus,
  safeResponseText,
} = require("./public_lite_execution_boundary");
const {
  PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V1,
  PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION,
  assertPublicLiteProviderHandoffRecord,
  normalizePublicLiteAcquisitionDispatchReceipt,
} = require("./public_lite_provider_handoff_contract");
const {
  createPublicLiteProviderHandoffFirestorePort,
} = require("./public_lite_provider_handoff_firestore_port");
const {
  dispatchAcceptedPublicLiteProviderHandoff,
  productionClock,
} = require("./public_lite_provider_handoff_service");

const N8N_PUBLIC_LITE_RISK_SCAN_ACQUISITION_TOKEN = defineSecret(
    "N8N_PUBLIC_LITE_RISK_SCAN_ACQUISITION_TOKEN");
const PUBLIC_LITE_ACQUISITION_TOKEN_HEADER =
  "X-MarkaKalkan-Public-Lite-Acquisition-Token";
const PUBLIC_LITE_ACQUISITION_WEBHOOK_URL =
  "https://sofrasofra-n8n.app.n8n.cloud/webhook/" +
  "markakalkan/public-lite-risk-scan/acquisition";
const PUBLIC_LITE_HANDOFF_DOCUMENT =
  `${PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION}/{executionId}`;
const PUBLIC_LITE_ACQUISITION_TIMEOUT_MS = 45000;
const PUBLIC_LITE_ACQUISITION_RESPONSE_MAX_BYTES = 65536;

class PublicLiteAcquisitionDispatchHttpError extends Error {
  constructor(code, message, {statusCode = 0, retryable = false} = {}) {
    super(message);
    this.name = "PublicLiteAcquisitionDispatchHttpError";
    this.code = code;
    this.statusCode = statusCode;
    this.retryable = retryable;
  }
}

function parseAcquisitionReceiptText(text, command) {
  const normalized = safeResponseText(text);
  if (!normalized) {
    throw new PublicLiteAcquisitionDispatchHttpError(
        "invalid_acquisition_response",
        "Acquisition provider returned an empty response.");
  }
  let parsed;
  try {
    parsed = JSON.parse(normalized);
  } catch {
    throw new PublicLiteAcquisitionDispatchHttpError(
        "invalid_acquisition_response",
        "Acquisition provider returned invalid JSON.");
  }
  return normalizePublicLiteAcquisitionDispatchReceipt(parsed, {
    expectedHandoffId: command.handoffId,
    expectedExecutionId: command.executionId,
  });
}

function createPublicLiteAcquisitionDispatcher({
  fetchImpl,
  acquisitionToken,
  webhookUrl = PUBLIC_LITE_ACQUISITION_WEBHOOK_URL,
  timeoutMs = PUBLIC_LITE_ACQUISITION_TIMEOUT_MS,
}) {
  const requestFetch = fetchImpl || global.fetch;
  if (typeof requestFetch !== "function") {
    throw new TypeError("fetch implementation is required");
  }
  if (!acquisitionToken ||
      typeof acquisitionToken.value !== "function") {
    throw new TypeError("acquisitionToken.value is required");
  }

  return Object.freeze({
    async dispatch(command) {
      const token = cleanString(acquisitionToken.value(), 10000);
      if (!token) {
        throw new PublicLiteAcquisitionDispatchHttpError(
            "missing_acquisition_token",
            "Public Lite acquisition token is not configured.",
            {retryable: false});
      }
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const response = await requestFetch(webhookUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            [PUBLIC_LITE_ACQUISITION_TOKEN_HEADER]: token,
          },
          body: JSON.stringify(command),
          signal: controller.signal,
        });
        const text = await response.text();
        if (Buffer.byteLength(text, "utf8") >
            PUBLIC_LITE_ACQUISITION_RESPONSE_MAX_BYTES) {
          throw new PublicLiteAcquisitionDispatchHttpError(
              "acquisition_response_too_large",
              "Acquisition response exceeded its size limit.",
              {statusCode: response.status, retryable: false});
        }
        if (!response.ok) {
          throw new PublicLiteAcquisitionDispatchHttpError(
              "acquisition_http_error",
              `Acquisition provider returned HTTP ${response.status}.`,
              {
                statusCode: response.status,
                retryable: retryableHttpStatus(response.status),
              });
        }
        if (response.status !== 202) {
          throw new PublicLiteAcquisitionDispatchHttpError(
              "unexpected_acquisition_status",
              `Acquisition provider must return HTTP 202; received ${
                response.status
              }.`,
              {statusCode: response.status, retryable: false});
        }
        return parseAcquisitionReceiptText(text, command);
      } catch (error) {
        if (error instanceof PublicLiteAcquisitionDispatchHttpError) {
          throw error;
        }
        if (error && error.name === "AbortError") {
          throw new PublicLiteAcquisitionDispatchHttpError(
              "acquisition_timeout",
              "Acquisition provider request timed out.",
              {statusCode: 408, retryable: true});
        }
        throw new PublicLiteAcquisitionDispatchHttpError(
            "acquisition_network_error",
            "Acquisition provider request failed before acceptance.",
            {statusCode: 0, retryable: true});
      } finally {
        clearTimeout(timer);
      }
    },
  });
}

function buildDispatchPublicLiteRiskScanAcquisition({
  db,
  onDocumentCreated,
  logger,
  fetchImpl,
  acquisitionToken = N8N_PUBLIC_LITE_RISK_SCAN_ACQUISITION_TOKEN,
  webhookUrl = PUBLIC_LITE_ACQUISITION_WEBHOOK_URL,
  clock = productionClock(),
  dispatchHandoff = dispatchAcceptedPublicLiteProviderHandoff,
  portFactory = createPublicLiteProviderHandoffFirestorePort,
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
  const dispatcher = createPublicLiteAcquisitionDispatcher({
    fetchImpl,
    acquisitionToken,
    webhookUrl,
  });

  return onDocumentCreated(
      {
        document: PUBLIC_LITE_HANDOFF_DOCUMENT,
        secrets: [acquisitionToken],
        retry: true,
        timeoutSeconds: 60,
        maxInstances: 5,
      },
      async (event) => {
        const snapshot = event && event.data;
        if (!snapshot) {
          logger.warn("Public Lite handoff event has no snapshot", {
            eventId: cleanString(event && event.id, 512) || null,
          });
          return;
        }
        const record = assertPublicLiteProviderHandoffRecord(
            snapshot.data() || {});
        const executionId = cleanString(
            event.params?.executionId, 64);
        const ownerId = cleanString(event.id, 256);
        if (!executionId || executionId !== record.executionId || !ownerId) {
          throw new Error("Public Lite handoff event scope is invalid");
        }
        const result = await dispatchHandoff({
          executionId,
          ownerId,
          port,
          dispatcher,
          clock,
        });
        logger.info("Public Lite child acquisition dispatch processed", {
          eventId: ownerId,
          executionId,
          handoffId: record.handoffId,
          outcome: result.outcome,
          attemptCount: result.attemptCount || null,
        });
        if (result.outcome === "retryable_failure") {
          const error = new Error(
              "Public Lite child acquisition dispatch will be retried");
          error.code = result.failure?.code ||
            "acquisition_retryable_failure";
          throw error;
        }
      });
}

module.exports = Object.freeze({
  N8N_PUBLIC_LITE_RISK_SCAN_ACQUISITION_TOKEN,
  PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V1,
  PUBLIC_LITE_ACQUISITION_RESPONSE_MAX_BYTES,
  PUBLIC_LITE_ACQUISITION_TIMEOUT_MS,
  PUBLIC_LITE_ACQUISITION_TOKEN_HEADER,
  PUBLIC_LITE_ACQUISITION_WEBHOOK_URL,
  PUBLIC_LITE_HANDOFF_DOCUMENT,
  PublicLiteAcquisitionDispatchHttpError,
  buildDispatchPublicLiteRiskScanAcquisition,
  createPublicLiteAcquisitionDispatcher,
  parseAcquisitionReceiptText,
});
