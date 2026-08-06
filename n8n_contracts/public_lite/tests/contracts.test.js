"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  CHANNEL_CODES,
  DISPATCH_ENVELOPE_VERSION,
  DISPATCH_RECEIPT_VERSION,
  PROVIDER_CODE,
  PROVIDER_RESULT_VERSION,
  RESULT_ENVELOPE_VERSION,
  PublicLiteWorkflowContractError,
  assertSafeJson,
  buildDispatchReceipt,
  buildResultEnvelope,
  canonicalJson,
  normalizeChannelResult,
  normalizeDispatchEnvelope,
  normalizeProviderResult,
  sha256Hex,
} = require("../src/contracts");

const validDispatch = require("../fixtures/valid_dispatch_envelope.json");

const {
  ACQUISITION_COMMAND_VERSION,
  ACQUISITION_RECEIPT_VERSION,
  DISPATCH_RECEIPT_VERSION_V2,
  HANDOFF_RECEIPT_VERSION,
  HANDOFF_REQUEST_VERSION,
  buildAcquisitionWorkflow,
  buildWorkflow,
} = require("../src/workflow_factory");

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function emptyChannel(channelCode, status = "completed") {
  return {
    channelCode,
    status,
    startedAt: "2026-08-04T12:01:00.000Z",
    completedAt: "2026-08-04T12:02:00.000Z",
    observations: [],
    diagnostics: {
      acquisitionAttempted: true,
      sourceCount: 0,
    },
  };
}

function validProviderResult() {
  return {
    contractVersion: PROVIDER_RESULT_VERSION,
    executionStatus: "completed",
    channels: CHANNEL_CODES.map((channelCode) =>
      emptyChannel(channelCode)),
    summary: {
      completedChannelCount: 3,
      dataUnavailableChannelCount: 0,
      failedChannelCount: 0,
      observationCount: 0,
    },
    engine: {
      engineCode: "public_lite_test_engine",
      engineVersion: "1.0.0",
    },
  };
}

test("dispatch constants are stable", () => {
  assert.equal(
    DISPATCH_ENVELOPE_VERSION,
    "risk-scan-public-lite-dispatch-envelope-v1",
  );
  assert.equal(
    DISPATCH_RECEIPT_VERSION,
    "risk-scan-public-lite-dispatch-receipt-v1",
  );
  assert.equal(
    RESULT_ENVELOPE_VERSION,
    "risk-scan-public-lite-result-envelope-v1",
  );
  assert.equal(PROVIDER_CODE, "n8n_public_lite");
});

test("canonical channel order is stable", () => {
  assert.deepEqual(
    CHANNEL_CODES,
    ["similarDomains", "openWeb", "marketplaceLimited"],
  );
});

test("valid anonymous dispatch envelope normalizes", () => {
  const result = normalizeDispatchEnvelope(validDispatch);
  assert.equal(result.executionId, "a".repeat(64));
  assert.equal(result.target.officialHost, "trendyol.com");
  assert.deepEqual(result.channelCodes, CHANNEL_CODES);
  assert.ok(Object.isFrozen(result));
});

test("dispatch rejects extra top-level keys", () => {
  const input = clone(validDispatch);
  input.tenantId = "forbidden";
  assert.throws(
    () => normalizeDispatchEnvelope(input),
    PublicLiteWorkflowContractError,
  );
});

test("dispatch rejects tenant identity mode", () => {
  const input = clone(validDispatch);
  input.identityMode = "tenant";
  assert.throws(
    () => normalizeDispatchEnvelope(input),
    /dispatch envelope mode is unsupported/,
  );
});

test("dispatch rejects non-canonical channel order", () => {
  const input = clone(validDispatch);
  input.channelCodes = [
    "openWeb",
    "similarDomains",
    "marketplaceLimited",
  ];
  assert.throws(
    () => normalizeDispatchEnvelope(input),
    /canonical channel set/,
  );
});

test("dispatch rejects missing channel", () => {
  const input = clone(validDispatch);
  input.channelCodes.pop();
  assert.throws(
    () => normalizeDispatchEnvelope(input),
    /canonical channel set/,
  );
});

test("dispatch rejects invalid execution digest", () => {
  const input = clone(validDispatch);
  input.executionId = "not-a-digest";
  assert.throws(
    () => normalizeDispatchEnvelope(input),
    /SHA-256/,
  );
});

test("dispatch rejects mismatched official host and URL", () => {
  const input = clone(validDispatch);
  input.target.officialHost = "example.com";
  assert.throws(
    () => normalizeDispatchEnvelope(input),
    /target official URL is invalid/,
  );
});

test("dispatch rejects URL credentials", () => {
  const input = clone(validDispatch);
  input.target.officialWebsiteCanonicalUrl =
    "https://user:pass@trendyol.com/";
  assert.throws(
    () => normalizeDispatchEnvelope(input),
    /target official URL is invalid/,
  );
});

test("dispatch rejects expired window", () => {
  const input = clone(validDispatch);
  input.expiresAt = input.requestedAt;
  assert.throws(
    () => normalizeDispatchEnvelope(input),
    /already expired/,
  );
});

test("dispatch rejects forbidden nested token key", () => {
  const input = clone(validDispatch);
  input.trace.token = "leak";
  assert.throws(
    () => normalizeDispatchEnvelope(input),
    /trace keys are invalid/,
  );
});

test("safe JSON rejects forbidden keys at depth", () => {
  assert.throws(
    () => assertSafeJson({
      outer: {
        authorization: "Bearer secret",
      },
    }),
    /forbidden key/,
  );
});

test("safe JSON canonicalizes object key order", () => {
  assert.deepEqual(
    assertSafeJson({z: 1, a: 2}),
    {a: 2, z: 1},
  );
});

test("dispatch receipt normalizes provider acceptance", () => {
  const receipt = buildDispatchReceipt({
    externalExecutionId: "n8n:1234",
    acceptedAt: "2026-08-04T12:00:01.000Z",
  });
  assert.deepEqual(receipt, {
    contractVersion: DISPATCH_RECEIPT_VERSION,
    providerCode: PROVIDER_CODE,
    externalExecutionId: "n8n:1234",
    acceptedAt: "2026-08-04T12:00:01.000Z",
  });
});

test("dispatch receipt rejects non-canonical time", () => {
  assert.throws(
    () => buildDispatchReceipt({
      externalExecutionId: "n8n:1234",
      acceptedAt: "2026-08-04T12:00:01Z",
    }),
    /canonical ISO-8601/,
  );
});

test("provider result with three completed channels normalizes", () => {
  const result = normalizeProviderResult(validProviderResult());
  assert.equal(result.summary.completedChannelCount, 3);
  assert.equal(result.summary.observationCount, 0);
  assert.ok(Object.isFrozen(result));
});

test("provider result rejects channel reordering", () => {
  const input = validProviderResult();
  input.channels.reverse();
  assert.throws(
    () => normalizeProviderResult(input),
    /channel set is invalid/,
  );
});

test("provider result rejects inconsistent summary", () => {
  const input = validProviderResult();
  input.summary.observationCount = 1;
  assert.throws(
    () => normalizeProviderResult(input),
    /summary.observationCount is invalid/,
  );
});

test("data unavailable channel cannot contain observations", () => {
  const input = validProviderResult();
  input.executionStatus = "partial";
  input.channels[0].status = "dataUnavailable";
  input.channels[0].observations.push({
    observationId: "obs-1",
    observedAt: "2026-08-04T12:01:30.000Z",
    sourceUrl: "https://example.com/item",
    sourceHost: "example.com",
    sourceType: "open_web_page",
    title: "Example",
    snippet: "Example snippet",
    imageUrls: [],
    signals: {},
    evidence: {},
  });
  input.summary.completedChannelCount = 2;
  input.summary.dataUnavailableChannelCount = 1;
  input.summary.observationCount = 1;
  assert.throws(
    () => normalizeProviderResult(input),
    /cannot contain observations/,
  );
});

test("observation source host must match URL", () => {
  const input = validProviderResult();
  input.channels[1].observations.push({
    observationId: "obs-1",
    observedAt: "2026-08-04T12:01:30.000Z",
    sourceUrl: "https://example.com/item",
    sourceHost: "other.example",
    sourceType: "open_web_page",
    title: "Example",
    snippet: "Example snippet",
    imageUrls: [],
    signals: {},
    evidence: {},
  });
  input.summary.observationCount = 1;
  assert.throws(
    () => normalizeProviderResult(input),
    /sourceHost does not match sourceUrl/,
  );
});

test("valid observation is accepted", () => {
  const input = validProviderResult();
  input.channels[1].observations.push({
    observationId: "obs-1",
    observedAt: "2026-08-04T12:01:30.000Z",
    sourceUrl: "https://example.com/item",
    sourceHost: "example.com",
    sourceType: "open_web_page",
    title: "Example",
    snippet: "Example snippet",
    imageUrls: ["https://example.com/image.jpg"],
    signals: {
      brandNameMatch: 0.91,
      officialHostMismatch: true,
    },
    evidence: {
      capturedAt: "2026-08-04T12:01:31.000Z",
      contentDigestSha256: "d".repeat(64),
    },
  });
  input.summary.observationCount = 1;
  const result = normalizeProviderResult(input);
  assert.equal(result.channels[1].observations.length, 1);
});

test("result envelope binds dispatch and provider receipt scope", () => {
  const result = buildResultEnvelope({
    dispatchEnvelope: validDispatch,
    dispatchReceipt: {
      externalExecutionId: "n8n:1234",
      acceptedAt: "2026-08-04T12:00:01.000Z",
    },
    providerEventId: "provider-event-1",
    completedAt: "2026-08-04T12:03:00.000Z",
    resultPayload: validProviderResult(),
  });
  assert.equal(result.contractVersion, RESULT_ENVELOPE_VERSION);
  assert.equal(result.executionId, validDispatch.executionId);
  assert.equal(result.scanRunId, validDispatch.scanRunId);
  assert.equal(result.externalExecutionId, "n8n:1234");
});

test("canonical JSON is deterministic", () => {
  assert.equal(
    canonicalJson({z: [2, {b: 1, a: 2}], a: 3}),
    '{"a":3,"z":[2,{"a":2,"b":1}]}',
  );
});

test("sha256 helper is stable", () => {
  assert.equal(
    sha256Hex("MarkaKalkan"),
    "c4f21e57abadda9dc80a8066363ccc09910f7282d4d4fa6b47b5cbb785e63502",
  );
});


test("normalizes one canonical channel result directly", () => {
  const result = normalizeChannelResult(
    emptyChannel("marketplaceLimited"),
    0,
  );
  assert.equal(result.channelCode, "marketplaceLimited");
  assert.equal(result.status, "completed");
  assert.equal(Object.isFrozen(result), true);
});


test("gateway v2 durable handoff versions are stable", () => {
  assert.equal(
    HANDOFF_REQUEST_VERSION,
    "risk-scan-public-lite-provider-handoff-request-v1",
  );
  assert.equal(
    HANDOFF_RECEIPT_VERSION,
    "risk-scan-public-lite-provider-handoff-receipt-v1",
  );
  assert.equal(
    DISPATCH_RECEIPT_VERSION_V2,
    "risk-scan-public-lite-dispatch-receipt-v2",
  );
});

test("child acquisition command and receipt versions are stable", () => {
  assert.equal(
    ACQUISITION_COMMAND_VERSION,
    "risk-scan-public-lite-acquisition-command-v1",
  );
  assert.equal(
    ACQUISITION_RECEIPT_VERSION,
    "risk-scan-public-lite-acquisition-dispatch-receipt-v1",
  );
});

test("parent and child workflows expose separate contract surfaces", () => {
  const parent = buildWorkflow();
  const child = buildAcquisitionWorkflow();
  assert.equal(
    parent.meta.dispatchReceiptContractVersion,
    DISPATCH_RECEIPT_VERSION_V2,
  );
  assert.equal(
    child.meta.acquisitionCommandContractVersion,
    ACQUISITION_COMMAND_VERSION,
  );
  assert.equal(
    child.meta.acquisitionReceiptContractVersion,
    ACQUISITION_RECEIPT_VERSION,
  );
  assert.equal(parent.meta.outboundAcquisition, false);
  assert.equal(parent.meta.resultCallback, false);
});
