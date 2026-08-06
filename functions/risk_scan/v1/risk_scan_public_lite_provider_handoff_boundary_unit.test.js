"use strict";

const {test} = require("node:test");
const assert = require("node:assert/strict");

const boundary = require("./public_lite_provider_handoff_boundary");
const contract = require("./public_lite_provider_handoff_contract");
const executionContract = require("./public_lite_execution_contract");

const executionId = "a".repeat(64);
const scanRunId = "scan-run-1";

function requestBody(overrides = {}) {
  return {
    contractVersion:
      contract.PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1,
    providerCode: "n8n_public_lite",
    executionId,
    scanRunId,
    gatewayExecutionId: "gateway-execution-1",
    dispatchEnvelope: {
      contractVersion:
        executionContract.PUBLIC_LITE_DISPATCH_ENVELOPE_VERSION_V1,
      executionId,
      scanRunId,
      scanMode: "quick",
      accessTier: "publicLite",
      identityMode: "anonymous",
      target: {
        brandNameNormalized: "beauty of joseon",
        officialHost: "beautyofjoseon.com",
        officialWebsiteCanonicalUrl: "https://beautyofjoseon.com/",
        targetFingerprintSha256: "b".repeat(64),
      },
      channelCodes: [
        "similarDomains",
        "openWeb",
        "marketplaceLimited",
      ],
      requestedAt: "2026-08-04T10:00:00.000Z",
      expiresAt: "2026-08-05T10:00:00.000Z",
      trace: {
        sourceEventId: "event-1",
        requestId: "request-1",
        requestFingerprintSha256: "c".repeat(64),
      },
    },
    ...overrides,
  };
}

function makeResponse() {
  return {
    headers: {},
    statusCode: null,
    body: null,
    set(name, value) {
      this.headers[name] = value;
      return this;
    },
    status(value) {
      this.statusCode = value;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
  };
}

function makeLogger() {
  return {info() {}, warn() {}, error() {}};
}

function buildHandler({
  tokenValue = "handoff-secret",
  acceptHandoff,
} = {}) {
  let options;
  let handler;
  const built = boundary.buildAcceptPublicLiteRiskScanHandoff({
    db: {},
    onRequest: (value, callback) => {
      options = value;
      handler = callback;
      return callback;
    },
    logger: makeLogger(),
    handoffToken: {value: () => tokenValue},
    clock: {now: () => new Date("2026-08-04T10:00:00.000Z")},
    portFactory: () => ({name: "port"}),
    acceptHandoff: acceptHandoff || (async () => ({
      outcome: "created",
      receipt: {
        contractVersion:
          contract.PUBLIC_LITE_PROVIDER_HANDOFF_RECEIPT_VERSION_V1,
        providerCode: "n8n_public_lite",
        handoffId: "d".repeat(64),
        executionId,
        scanRunId,
        gatewayExecutionId: "gateway-execution-1",
        acceptedAt: "2026-08-04T10:00:00.000Z",
        state: "accepted",
        replayed: false,
      },
    })),
  });
  assert.equal(built, handler);
  return {handler, options};
}

test("handoff boundary declares a dedicated secret", () => {
  assert.equal(
      boundary.N8N_PUBLIC_LITE_RISK_SCAN_HANDOFF_TOKEN.name,
      "N8N_PUBLIC_LITE_RISK_SCAN_HANDOFF_TOKEN");
});

test("handoff boundary requires POST", async () => {
  const {handler} = buildHandler();
  const response = makeResponse();
  await handler({method: "GET", headers: {}}, response);
  assert.equal(response.statusCode, 405);
  assert.equal(response.headers.Allow, "POST");
});

test("handoff boundary rejects an invalid token", async () => {
  const {handler} = buildHandler();
  const response = makeResponse();
  await handler({
    method: "POST",
    headers: {
      [boundary.PUBLIC_LITE_HANDOFF_TOKEN_HEADER.toLowerCase()]: "wrong",
    },
    body: requestBody(),
  }, response);
  assert.equal(response.statusCode, 403);
});

test("handoff boundary returns the durable receipt", async () => {
  let accepted;
  const {handler, options} = buildHandler({
    acceptHandoff: async (input) => {
      accepted = input;
      return {
        outcome: "created",
        receipt: {
          contractVersion:
            contract.PUBLIC_LITE_PROVIDER_HANDOFF_RECEIPT_VERSION_V1,
          providerCode: "n8n_public_lite",
          handoffId: "d".repeat(64),
          executionId,
          scanRunId,
          gatewayExecutionId: "gateway-execution-1",
          acceptedAt: "2026-08-04T10:00:00.000Z",
          state: "accepted",
          replayed: false,
        },
      };
    },
  });
  const response = makeResponse();
  await handler({
    method: "POST",
    headers: {
      [boundary.PUBLIC_LITE_HANDOFF_TOKEN_HEADER.toLowerCase()]:
        "handoff-secret",
    },
    body: requestBody(),
  }, response);
  assert.equal(options.secrets.length, 1);
  assert.equal(options.timeoutSeconds, 30);
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.handoffId, "d".repeat(64));
  assert.equal(accepted.request.executionId, executionId);
});

test("handoff boundary maps a conflicting replay to 409", async () => {
  const {handler} = buildHandler({
    acceptHandoff: async () => {
      const error = new Error("conflict");
      error.code = "conflict";
      throw error;
    },
  });
  const response = makeResponse();
  await handler({
    method: "POST",
    headers: {
      [boundary.PUBLIC_LITE_HANDOFF_TOKEN_HEADER.toLowerCase()]:
        "handoff-secret",
    },
    body: requestBody(),
  }, response);
  assert.equal(response.statusCode, 409);
  assert.equal(response.body.code, "conflict");
});

test(
    "handoff boundary maps unexpected persistence failure to 500",
    async () => {
      const {handler} = buildHandler({
        acceptHandoff: async () => {
          throw new Error("database unavailable");
        },
      });
      const response = makeResponse();
      await handler({
        method: "POST",
        headers: {
          [boundary.PUBLIC_LITE_HANDOFF_TOKEN_HEADER.toLowerCase()]:
            "handoff-secret",
        },
        body: requestBody(),
      }, response);
      assert.equal(response.statusCode, 500);
    });
