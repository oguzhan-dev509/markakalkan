"use strict";

const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {
  PUBLIC_LITE_CALLABLE_CONTRACT_VERSION_V1,
  RiskScanPublicLiteError,
  buildPublicLiteStartCommand,
  normalizeAccessData,
} = require("./public_lite_contract");
const {
  createPublicLiteRun,
  getPublicLiteReport,
  getPublicLiteStatus,
} = require("./public_lite_firestore_port");
const {RiskScanStorageError} = require("./firestore_storage_port");
const {buildPublicLiteProjection} = require("./public_projection");

const HRT_PUBLIC_LITE_SECRET_KEY = defineSecret(
    "HRT_PUBLIC_LITE_SECRET_KEY");
const REGION = "europe-west3";

const PUBLIC_LITE_FUNCTION_NAMES = Object.freeze({
  start: "startPublicLiteRiskScan",
  status: "getPublicLiteRiskScanStatus",
  report: "getPublicLiteRiskScanReport",
});

function callableOptions(action) {
  if (action === "start") {
    return {
      region: REGION,
      enforceAppCheck: true,
      maxInstances: 1,
      secrets: [HRT_PUBLIC_LITE_SECRET_KEY],
    };
  }
  if (["status", "report"].includes(action)) {
    return {
      region: REGION,
      enforceAppCheck: true,
      maxInstances: 3,
    };
  }
  throw new TypeError("unknown public-lite callable action");
}

function productionClock() {
  return {now: () => new Date()};
}

function extractAppId(request) {
  const appId = request && request.app && request.app.appId;
  if (typeof appId !== "string" || !appId.trim()) {
    throw new RiskScanPublicLiteError(
        "failed-precondition", "Geçerli App Check bağlamı gerekir.");
  }
  return appId.trim();
}

function extractNetworkAddress(request) {
  const rawRequest = request && request.rawRequest;
  const candidate = rawRequest && (
    rawRequest.ip ||
    (rawRequest.socket && rawRequest.socket.remoteAddress));
  if (typeof candidate !== "string" || !candidate.trim()) {
    throw new RiskScanPublicLiteError(
        "internal", "Ağ güvenlik bağlamı alınamadı.");
  }
  return candidate.trim();
}

function mapPublicLiteError(error) {
  if (error instanceof HttpsError) return error;
  const supported = new Set([
    "invalid-argument",
    "not-found",
    "failed-precondition",
    "resource-exhausted",
    "already-exists",
    "aborted",
    "unauthenticated",
    "permission-denied",
    "internal",
  ]);
  if (error instanceof RiskScanPublicLiteError ||
      error instanceof RiskScanStorageError ||
      (error && typeof error.code === "string")) {
    let code = "internal";
    if (supported.has(error.code)) {
      code = error.code;
    } else if (error.code === "conflict") {
      code = "aborted";
    }
    const safeMessage = code === "internal" ?
      "Risk taraması işlemi güvenli biçimde tamamlanamadı." :
      error.message;
    return new HttpsError(code, safeMessage);
  }
  if (error instanceof TypeError || error instanceof RangeError) {
    return new HttpsError("invalid-argument", error.message);
  }
  return new HttpsError(
      "internal", "Risk taraması işlemi güvenli biçimde tamamlanamadı.");
}

function createPublicLiteHandler(action, {
  db,
  clock = productionClock(),
  secretKeyProvider = () => HRT_PUBLIC_LITE_SECRET_KEY.value(),
  rateLimit,
} = {}) {
  if (!db) throw new TypeError("db is required");
  if (!clock || typeof clock.now !== "function") {
    throw new TypeError("clock.now is required");
  }

  return async (request) => {
    try {
      const appId = extractAppId(request);
      const now = clock.now();
      if (action === "start") {
        const command = buildPublicLiteStartCommand({
          data: request.data,
          appId,
          networkAddress: extractNetworkAddress(request),
          secretKey: secretKeyProvider(),
          now,
          rateLimit,
        });
        const result = await createPublicLiteRun(db, command);
        return {
          contractVersion: PUBLIC_LITE_CALLABLE_CONTRACT_VERSION_V1,
          outcome: result.outcome,
          accessKey: command.accessKey,
          projection: buildPublicLiteProjection({
            run: result.run,
            channels: result.channels,
            report: null,
          }),
        };
      }

      const {accessKey} = normalizeAccessData(request.data);
      const input = {
        accessKey,
        now: (now instanceof Date ? now : new Date(now)).toISOString(),
      };
      let projection;
      if (action === "status") {
        projection = await getPublicLiteStatus(db, input);
      } else if (action === "report") {
        projection = await getPublicLiteReport(db, input);
      } else {
        throw new TypeError("unknown public-lite action");
      }
      return {
        contractVersion: PUBLIC_LITE_CALLABLE_CONTRACT_VERSION_V1,
        projection,
      };
    } catch (error) {
      throw mapPublicLiteError(error);
    }
  };
}

function buildStartPublicLiteRiskScan({db, clock} = {}) {
  return onCall(
      callableOptions("start"),
      createPublicLiteHandler("start", {db, clock}));
}

function buildGetPublicLiteRiskScanStatus({db, clock} = {}) {
  return onCall(
      callableOptions("status"),
      createPublicLiteHandler("status", {db, clock}));
}

function buildGetPublicLiteRiskScanReport({db, clock} = {}) {
  return onCall(
      callableOptions("report"),
      createPublicLiteHandler("report", {db, clock}));
}

module.exports = {
  HRT_PUBLIC_LITE_SECRET_KEY,
  PUBLIC_LITE_FUNCTION_NAMES,
  REGION,
  buildGetPublicLiteRiskScanReport,
  buildGetPublicLiteRiskScanStatus,
  buildStartPublicLiteRiskScan,
  callableOptions,
  createPublicLiteHandler,
  extractAppId,
  extractNetworkAddress,
  mapPublicLiteError,
  productionClock,
};
