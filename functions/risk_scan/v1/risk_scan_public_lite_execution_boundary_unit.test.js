"use strict";

const {test} = require("node:test");
const assert = require("node:assert/strict");
const boundary = require("./public_lite_execution_boundary");
const receiptPort = require(
    "./public_lite_result_receipt_firestore_port");

const executionId = "a".repeat(64);
const scanRunId = "scan-run-1";
const completedAt = "2026-08-04T10:15:00.000Z";

function validResultEnvelope(overrides = {}) {
  return {
    contractVersion:
      receiptPort.PUBLIC_LITE_RESULT_ENVELOPE_VERSION_V1,
    providerCode: "n8n_public_lite",
    externalExecutionId: "n8n-execution-1",
    providerEventId: "provider-event-1",
    executionId,
    scanRunId,
    completedAt,
    resultPayload: {
      channels: [],
      source: "pilot",
    },
    ...overrides,
  };
}

function validRun(overrides = {}) {
  return {
    scanRunId,
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    status: "created",
    createdAt: "2026-08-04T10:00:00.000Z",
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
  return {
    info() {},
    warn() {},
    error() {},
  };
}

function makeRunSnapshot(run, channels) {
  return {
    data: () => run,
    ref: {
      collection(name) {
        assert.equal(name, "channels");
        return {
          doc(channelCode) {
            return {
              async get() {
                return {
                  exists: Object.hasOwn(channels, channelCode),
                  data: () => channels[channelCode],
                };
              },
            };
          },
        };
      },
    },
  };
}

function buildResultHandler({
  tokenValue = "result-secret",
  persistReceipt,
} = {}) {
  let options;
  let handler;
  const onRequest = (value, callback) => {
    options = value;
    handler = callback;
    return callback;
  };
  const resultToken = {
    value: () => tokenValue,
  };
  const built = boundary.buildReceivePublicLiteRiskScanResult({
    db: {},
    onRequest,
    logger: makeLogger(),
    resultToken,
    clock: {
      now: () => new Date("2026-08-04T10:16:00.000Z"),
    },
    persistReceipt: persistReceipt || (async () => ({
      duplicate: false,
      receiptId: "b".repeat(64),
    })),
  });
  assert.equal(built, handler);
  return {handler, options, resultToken};
}

test("boundary declares dedicated Public Lite secrets", () => {
  assert.equal(
      boundary.N8N_PUBLIC_LITE_RISK_SCAN_WEBHOOK_TOKEN.name,
      "N8N_PUBLIC_LITE_RISK_SCAN_WEBHOOK_TOKEN");
  assert.equal(
      boundary.N8N_PUBLIC_LITE_RISK_SCAN_RESULT_TOKEN.name,
      "N8N_PUBLIC_LITE_RISK_SCAN_RESULT_TOKEN");
});

test("constantTimeEqual accepts only equal non-empty tokens", () => {
  assert.equal(boundary.constantTimeEqual("secret", "secret"), true);
  assert.equal(boundary.constantTimeEqual("secret", "other"), false);
  assert.equal(boundary.constantTimeEqual("", ""), false);
});

test("parseRequestBody accepts a JSON string object", () => {
  assert.deepEqual(
      boundary.parseRequestBody({body: "{\"ok\":true}"}),
      {ok: true});
});

test("parseRequestBody rejects a JSON array", () => {
  assert.throws(
      () => boundary.parseRequestBody({body: "[]"}),
      /JSON object/);
});

test("normalize result envelope creates a bounded payload digest", () => {
  const normalized = receiptPort.normalizePublicLiteResultEnvelope(
      validResultEnvelope());
  assert.equal(normalized.executionId, executionId);
  assert.match(normalized.resultPayloadDigestSha256, /^[a-f0-9]{64}$/);
  assert.equal(normalized.resultPayloadCanonicalBytes > 0, true);
});

test("normalize result envelope rejects unexpected top-level keys", () => {
  assert.throws(
      () => receiptPort.normalizePublicLiteResultEnvelope(
          validResultEnvelope({unexpected: true})),
      /unexpected keys/);
});

test("normalize result envelope rejects nested secret-like keys", () => {
  assert.throws(
      () => receiptPort.normalizePublicLiteResultEnvelope(
          validResultEnvelope({
            resultPayload: {nested: {token: "do-not-store"}},
          })),
      /forbidden key/);
});

test("normalize result envelope rejects excessive nesting", () => {
  let value = {leaf: true};
  for (let index = 0; index < 10; index += 1) {
    value = {next: value};
  }
  assert.throws(
      () => receiptPort.normalizePublicLiteResultEnvelope(
          validResultEnvelope({resultPayload: value})),
      /nesting depth/);
});

test("result receipt identity is deterministic", () => {
  const first = receiptPort.derivePublicLiteResultReceiptId({
    executionId,
    providerEventId: "provider-event-1",
  });
  const second = receiptPort.derivePublicLiteResultReceiptId({
    executionId,
    providerEventId: "provider-event-1",
  });
  assert.equal(first, second);
  assert.match(first, /^[a-f0-9]{64}$/);
});

test("n8n dispatcher sends the exact token and JSON envelope", async () => {
  const calls = [];
  const dispatcher = boundary.createPublicLiteN8nDispatcher({
    webhookToken: {value: () => "dispatch-secret"},
    webhookUrl: "https://example.test/webhook",
    fetchImpl: async (url, options) => {
      calls.push({url, options});
      return {
        ok: true,
        status: 200,
        text: async () => JSON.stringify({
          providerCode: "n8n_public_lite",
          externalExecutionId: "n8n-execution-1",
          acceptedAt: "2026-08-04T10:05:00.000Z",
        }),
      };
    },
  });
  const receipt = await dispatcher.dispatch({executionId});
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "https://example.test/webhook");
  assert.equal(
      calls[0].options.headers[boundary.PUBLIC_LITE_WEBHOOK_TOKEN_HEADER],
      "dispatch-secret");
  assert.deepEqual(JSON.parse(calls[0].options.body), {executionId});
  assert.equal(receipt.providerCode, "n8n_public_lite");
});

test("n8n dispatcher rejects an empty webhook token", async () => {
  const dispatcher = boundary.createPublicLiteN8nDispatcher({
    webhookToken: {value: () => ""},
    fetchImpl: async () => assert.fail("fetch must not run"),
  });
  await assert.rejects(
      dispatcher.dispatch({executionId}),
      (error) => error.code === "missing_webhook_token" &&
        error.retryable === false);
});

test("n8n dispatcher classifies HTTP 429 as retryable", async () => {
  const dispatcher = boundary.createPublicLiteN8nDispatcher({
    webhookToken: {value: () => "secret"},
    fetchImpl: async () => ({
      ok: false,
      status: 429,
      text: async () => "busy",
    }),
  });
  await assert.rejects(
      dispatcher.dispatch({executionId}),
      (error) => error.statusCode === 429 && error.retryable === true);
});

test("n8n dispatcher rejects invalid success JSON", async () => {
  const dispatcher = boundary.createPublicLiteN8nDispatcher({
    webhookToken: {value: () => "secret"},
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      text: async () => "not-json",
    }),
  });
  await assert.rejects(
      dispatcher.dispatch({executionId}),
      (error) => error.code === "invalid_dispatch_response");
});

test("dispatch trigger uses retry, secret, and run-create document", () => {
  let options;
  const onDocumentCreated = (value, callback) => {
    options = value;
    return callback;
  };
  boundary.buildDispatchPublicLiteRiskScan({
    db: {},
    onDocumentCreated,
    logger: makeLogger(),
    fetchImpl: async () => assert.fail("fetch must not run"),
    webhookToken: {value: () => "secret"},
    portFactory: () => ({}),
    orchestrate: async () => ({outcome: "already_dispatched"}),
  });
  assert.equal(options.document, boundary.PUBLIC_LITE_RUN_DOCUMENT);
  assert.equal(options.retry, true);
  assert.equal(options.timeoutSeconds, 60);
  assert.equal(options.secrets.length, 1);
});

test("dispatch trigger skips non-Public-Lite runs", async () => {
  let handler;
  let orchestrated = false;
  const onDocumentCreated = (_options, callback) => {
    handler = callback;
    return callback;
  };
  boundary.buildDispatchPublicLiteRiskScan({
    db: {},
    onDocumentCreated,
    logger: makeLogger(),
    fetchImpl: async () => assert.fail("fetch must not run"),
    webhookToken: {value: () => "secret"},
    portFactory: () => ({}),
    orchestrate: async () => {
      orchestrated = true;
    },
  });
  await handler({
    id: "event-1",
    params: {scanRunId},
    data: makeRunSnapshot(
        validRun({accessTier: "registered"}), {}),
  });
  assert.equal(orchestrated, false);
});

test("dispatch trigger loads all channels and orchestrates once", async () => {
  let handler;
  let input;
  const channels = Object.fromEntries([
    "similarDomains",
    "openWeb",
    "marketplaceLimited",
  ].map((channelCode) => [channelCode, {
    scanRunId,
    channelCode,
    status: "queued",
  }]));
  const onDocumentCreated = (_options, callback) => {
    handler = callback;
    return callback;
  };
  boundary.buildDispatchPublicLiteRiskScan({
    db: {},
    onDocumentCreated,
    logger: makeLogger(),
    fetchImpl: async () => assert.fail("fetch must not run"),
    webhookToken: {value: () => "secret"},
    portFactory: () => ({name: "port"}),
    orchestrate: async (value) => {
      input = value;
      return {outcome: "dispatched", executionId};
    },
  });
  await handler({
    id: "event-1",
    time: "2026-08-04T10:00:01.000Z",
    params: {scanRunId},
    data: makeRunSnapshot(validRun(), channels),
  });
  assert.equal(input.event.channels.length, 3);
  assert.equal(input.ownerId, "event-1");
  assert.equal(input.event.scanRunId, undefined);
});

test("dispatch trigger throws after a retryable provider failure", async () => {
  let handler;
  const channels = Object.fromEntries([
    "similarDomains",
    "openWeb",
    "marketplaceLimited",
  ].map((channelCode) => [channelCode, {
    scanRunId,
    channelCode,
    status: "queued",
  }]));
  const onDocumentCreated = (_options, callback) => {
    handler = callback;
    return callback;
  };
  boundary.buildDispatchPublicLiteRiskScan({
    db: {},
    onDocumentCreated,
    logger: makeLogger(),
    fetchImpl: async () => assert.fail("fetch must not run"),
    webhookToken: {value: () => "secret"},
    portFactory: () => ({}),
    orchestrate: async () => ({
      outcome: "retryable_failure",
      executionId,
      failure: {code: "dispatch_timeout"},
    }),
  });
  await assert.rejects(handler({
    id: "event-1",
    params: {scanRunId},
    data: makeRunSnapshot(validRun(), channels),
  }), /will be retried/);
});

test("dispatch trigger returns after a terminal provider failure", async () => {
  let handler;
  const channels = Object.fromEntries([
    "similarDomains",
    "openWeb",
    "marketplaceLimited",
  ].map((channelCode) => [channelCode, {
    scanRunId,
    channelCode,
    status: "queued",
  }]));
  const onDocumentCreated = (_options, callback) => {
    handler = callback;
    return callback;
  };
  boundary.buildDispatchPublicLiteRiskScan({
    db: {},
    onDocumentCreated,
    logger: makeLogger(),
    fetchImpl: async () => assert.fail("fetch must not run"),
    webhookToken: {value: () => "secret"},
    portFactory: () => ({}),
    orchestrate: async () => ({
      outcome: "terminal_failure",
      executionId,
    }),
  });
  await handler({
    id: "event-1",
    params: {scanRunId},
    data: makeRunSnapshot(validRun(), channels),
  });
});

test("result callback rejects methods other than POST", async () => {
  const {handler} = buildResultHandler();
  const response = makeResponse();
  await handler({method: "GET", headers: {}}, response);
  assert.equal(response.statusCode, 405);
  assert.equal(response.headers.Allow, "POST");
});

test("result callback rejects an invalid token", async () => {
  const {handler} = buildResultHandler();
  const response = makeResponse();
  await handler({
    method: "POST",
    headers: {
      [boundary.PUBLIC_LITE_RESULT_TOKEN_HEADER.toLowerCase()]: "wrong",
    },
    body: validResultEnvelope(),
  }, response);
  assert.equal(response.statusCode, 403);
});

test("result callback rejects a malformed envelope", async () => {
  const {handler} = buildResultHandler();
  const response = makeResponse();
  await handler({
    method: "POST",
    headers: {
      [boundary.PUBLIC_LITE_RESULT_TOKEN_HEADER.toLowerCase()]:
        "result-secret",
    },
    body: {contractVersion: "wrong"},
  }, response);
  assert.equal(response.statusCode, 400);
  assert.equal(response.body.code, "invalid_argument");
});

test("result callback accepts a new immutable receipt", async () => {
  let received;
  const {handler, options} = buildResultHandler({
    persistReceipt: async (_db, value) => {
      received = value;
      return {duplicate: false, receiptId: "b".repeat(64)};
    },
  });
  const response = makeResponse();
  await handler({
    method: "POST",
    headers: {
      [boundary.PUBLIC_LITE_RESULT_TOKEN_HEADER.toLowerCase()]:
        "result-secret",
    },
    body: validResultEnvelope(),
  }, response);
  assert.equal(options.secrets.length, 1);
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.duplicate, false);
  assert.equal(received.envelope.executionId, executionId);
  assert.equal(received.receivedAt, "2026-08-04T10:16:00.000Z");
});

test("result callback reports an idempotent duplicate", async () => {
  const {handler} = buildResultHandler({
    persistReceipt: async () => ({
      duplicate: true,
      receiptId: "c".repeat(64),
    }),
  });
  const response = makeResponse();
  await handler({
    method: "POST",
    headers: {
      [boundary.PUBLIC_LITE_RESULT_TOKEN_HEADER.toLowerCase()]:
        "result-secret",
    },
    body: validResultEnvelope(),
  }, response);
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.duplicate, true);
});

test(
    "result callback maps an unexpected persistence error to 500",
    async () => {
      const {handler} = buildResultHandler({
        persistReceipt: async () => {
          throw new Error("database unavailable");
        },
      });
      const response = makeResponse();
      await handler({
        method: "POST",
        headers: {
          [boundary.PUBLIC_LITE_RESULT_TOKEN_HEADER.toLowerCase()]:
            "result-secret",
        },
        body: validResultEnvelope(),
      }, response);
      assert.equal(response.statusCode, 500);
      assert.equal(response.body.code, "internal");
    });
