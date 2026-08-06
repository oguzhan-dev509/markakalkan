"use strict";

const {defineSecret} = require("firebase-functions/params");
const {
  cleanString,
  constantTimeEqual,
  getRequestHeader,
  parseRequestBody,
  productionClock,
  sendJson,
} = require("./public_lite_execution_boundary");
const {
  PublicLiteProviderHandoffContractError,
} = require("./public_lite_provider_handoff_contract");
const {
  PublicLiteProviderHandoffFirestoreError,
  createPublicLiteProviderHandoffFirestorePort,
} = require("./public_lite_provider_handoff_firestore_port");
const {
  acceptPublicLiteProviderHandoff,
} = require("./public_lite_provider_handoff_service");

const N8N_PUBLIC_LITE_RISK_SCAN_HANDOFF_TOKEN = defineSecret(
    "N8N_PUBLIC_LITE_RISK_SCAN_HANDOFF_TOKEN");
const PUBLIC_LITE_HANDOFF_TOKEN_HEADER =
  "X-MarkaKalkan-Public-Lite-Handoff-Token";

function mapHandoffError(error) {
  if (error instanceof TypeError || error instanceof RangeError ||
      error instanceof PublicLiteProviderHandoffContractError) {
    if (error.code === "failed-precondition" || error.code === "conflict") {
      return {statusCode: 409, code: "conflict"};
    }
    return {statusCode: 400, code: "invalid_argument"};
  }
  if (error instanceof PublicLiteProviderHandoffFirestoreError ||
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

function buildAcceptPublicLiteRiskScanHandoff({
  db,
  onRequest,
  logger,
  handoffToken = N8N_PUBLIC_LITE_RISK_SCAN_HANDOFF_TOKEN,
  clock = productionClock(),
  acceptHandoff = acceptPublicLiteProviderHandoff,
  portFactory = createPublicLiteProviderHandoffFirestorePort,
} = {}) {
  if (!db) throw new TypeError("db is required");
  if (typeof onRequest !== "function") {
    throw new TypeError("onRequest is required");
  }
  if (!logger) throw new TypeError("logger is required");
  if (!handoffToken || typeof handoffToken.value !== "function") {
    throw new TypeError("handoffToken.value is required");
  }
  if (!clock || typeof clock.now !== "function") {
    throw new TypeError("clock.now is required");
  }
  const port = portFactory(db);

  return onRequest(
      {
        secrets: [handoffToken],
        timeoutSeconds: 30,
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
        const expectedToken = cleanString(handoffToken.value(), 10000);
        const suppliedToken = getRequestHeader(
            request, PUBLIC_LITE_HANDOFF_TOKEN_HEADER);
        if (!expectedToken ||
            !constantTimeEqual(expectedToken, suppliedToken)) {
          logger.warn("Public Lite provider handoff authorization failed");
          sendJson(response, 403, {ok: false, code: "forbidden"});
          return;
        }

        try {
          const result = await acceptHandoff({
            request: parseRequestBody(request),
            port,
            clock,
          });
          logger.info("Public Lite provider handoff accepted", {
            executionId: result.receipt.executionId,
            scanRunId: result.receipt.scanRunId,
            handoffId: result.receipt.handoffId,
            replayed: result.receipt.replayed,
          });
          sendJson(response, 200, result.receipt);
        } catch (error) {
          const mapped = mapHandoffError(error);
          if (mapped.statusCode >= 500) {
            logger.error("Public Lite provider handoff failed", {
              error: error instanceof Error ? error.message : String(error),
            });
          } else {
            logger.warn("Public Lite provider handoff rejected", {
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
  N8N_PUBLIC_LITE_RISK_SCAN_HANDOFF_TOKEN,
  PUBLIC_LITE_HANDOFF_TOKEN_HEADER,
  buildAcceptPublicLiteRiskScanHandoff,
  mapHandoffError,
});
