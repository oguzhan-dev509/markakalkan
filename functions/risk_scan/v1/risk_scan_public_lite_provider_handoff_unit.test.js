"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const executionContract = require("./public_lite_execution_contract");
const handoffContract = require("./public_lite_provider_handoff_contract");
const handoffService = require("./public_lite_provider_handoff_service");
const handoffTrigger = require("./public_lite_provider_handoff_trigger");

const now = "2026-08-04T10:00:00.000Z";
const later = "2026-08-04T10:01:00.000Z";
const executionId = "a".repeat(64);
const scanRunId = "scan-run-1";

function validEnvelope(overrides = {}) {
  return {
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
    requestedAt: now,
    expiresAt: "2026-08-05T10:00:00.000Z",
    trace: {
      sourceEventId: "event-1",
      requestId: "request-1",
      requestFingerprintSha256: "c".repeat(64),
    },
    ...overrides,
  };
}

function validRequest(overrides = {}) {
  return {
    contractVersion:
      handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1,
    providerCode: "n8n_public_lite",
    executionId,
    scanRunId,
    gatewayExecutionId: "gateway-execution-1",
    dispatchEnvelope: validEnvelope(),
    ...overrides,
  };
}

function record(overrides = {}) {
  const value = handoffContract.buildPublicLiteProviderHandoffRecord({
    request: validRequest(),
    acceptedAt: now,
    purgeAtTimestamp: new Date("2026-09-03T10:00:00.000Z"),
  });
  return handoffContract.withProviderHandoffStorageFingerprint({
    ...value,
    ...overrides,
  });
}

function acquisitionReceipt(inputRecord = record(), overrides = {}) {
  return {
    contractVersion:
      handoffContract
          .PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V2,
    providerCode: "n8n_public_lite",
    handoffId: inputRecord.handoffId,
    executionId: inputRecord.executionId,
    externalExecutionId:
      handoffContract.derivePublicLiteAcquisitionExternalExecutionId(
          inputRecord.handoffId),
    acceptedAt: later,
    ...overrides,
  };
}

class FakePort {
  constructor(overrides = {}) {
    this.calls = [];
    this.overrides = overrides;
  }

  async acceptHandoff(input) {
    this.calls.push(["acceptHandoff", input]);
    return this.overrides.accept || {
      outcome: "created",
      replayed: false,
      record: record(),
    };
  }

  async claimChildDispatch(input) {
    this.calls.push(["claimChildDispatch", input]);
    const value = record({
      state: "child_dispatching",
      childDispatchAttemptCount: 1,
      childDispatchLeaseOwner: input.ownerId,
      childDispatchLeaseToken: "e".repeat(64),
      childDispatchLeaseUntil: "2026-08-04T10:06:00.000Z",
    });
    return this.overrides.claim || {
      outcome: "claimed",
      attemptCount: 1,
      leaseToken: "e".repeat(64),
      record: value,
      command: handoffContract.buildPublicLiteAcquisitionCommand({
        record: value,
        dispatchEnvelope: validEnvelope(),
        attemptCount: 1,
        leaseToken: "e".repeat(64),
      }),
    };
  }

  async markChildDispatchSucceeded(input) {
    this.calls.push(["markChildDispatchSucceeded", input]);
    return this.overrides.success || {outcome: "child_dispatched"};
  }

  async markChildDispatchFailed(input) {
    this.calls.push(["markChildDispatchFailed", input]);
    return this.overrides.failure || {
      outcome: input.retryable ?
        "retryable_failure" : "terminal_failure",
    };
  }
}

function clock(values = [now]) {
  let index = 0;
  return {
    now: () => new Date(values[Math.min(index++, values.length - 1)]),
  };
}

function makeLogger() {
  return {info() {}, warn() {}, error() {}};
}

test("provider handoff contract versions are fixed", () => {
  assert.equal(
      handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_REQUEST_VERSION_V1,
      "risk-scan-public-lite-provider-handoff-request-v1");
  assert.equal(
      handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_RECORD_VERSION_V2,
      "risk-scan-public-lite-provider-handoff-record-v2");
  assert.equal(
      handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_RECEIPT_VERSION_V1,
      "risk-scan-public-lite-provider-handoff-receipt-v1");
  assert.equal(
      handoffContract.PUBLIC_LITE_ACQUISITION_COMMAND_VERSION_V1,
      "risk-scan-public-lite-acquisition-command-v1");
  assert.equal(
      handoffContract.PUBLIC_LITE_ACQUISITION_DISPATCH_RECEIPT_VERSION_V2,
      "risk-scan-public-lite-acquisition-dispatch-receipt-v2");
});

test("handoff request binds the exact dispatch envelope", () => {
  const normalized =
    handoffContract.normalizePublicLiteProviderHandoffRequest(
        validRequest());
  assert.equal(normalized.executionId, executionId);
  assert.equal(normalized.scanRunId, scanRunId);
  assert.match(normalized.dispatchEnvelopeHash, /^[a-f0-9]{64}$/);
  assert.equal(normalized.dispatchEnvelope.executionId, executionId);
});

test("handoff request rejects an extra nested target key", () => {
  const request = validRequest();
  request.dispatchEnvelope.target.unexpected = true;
  assert.throws(
      () => handoffContract.normalizePublicLiteProviderHandoffRequest(
          request),
      TypeError);
});

test("handoff identity is deterministic", () => {
  const first = handoffContract.derivePublicLiteProviderHandoffId(
      executionId);
  const second = handoffContract.derivePublicLiteProviderHandoffId(
      executionId);
  assert.equal(first, second);
  assert.match(first, /^[a-f0-9]{64}$/);
});

test("handoff record begins durably accepted", () => {
  const value = record();
  assert.equal(value.executionId, executionId);
  assert.equal(value.state, "accepted");
  assert.equal(value.childDispatchAttemptCount, 0);
  assert.equal(value.purgeAtTimestamp instanceof Date, true);
  handoffContract.assertPublicLiteProviderHandoffRecord(value);
});

test("exact replay may use a later gateway execution id", () => {
  const existing = record();
  const replay = validRequest({gatewayExecutionId: "gateway-execution-2"});
  assert.equal(
      handoffContract.assertPublicLiteProviderHandoffReplay(
          existing, replay),
      existing);
});

test("conflicting dispatch envelope replay is rejected", () => {
  const existing = record();
  const changed = validRequest({
    dispatchEnvelope: validEnvelope({
      requestedAt: "2026-08-04T10:00:01.000Z",
    }),
  });
  assert.throws(
      () => handoffContract.assertPublicLiteProviderHandoffReplay(
          existing, changed),
      (error) => error.code === "conflict");
});

test("handoff receipt uses server record identity", () => {
  const receipt = handoffContract.buildPublicLiteProviderHandoffReceipt({
    record: record(),
    replayed: false,
  });
  assert.equal(receipt.executionId, executionId);
  assert.equal(receipt.acceptedAt, now);
  assert.equal(receipt.replayed, false);
  assert.match(receipt.handoffId, /^[a-f0-9]{64}$/);
});

test("child command binds attempt, lease, and envelope", () => {
  const claimed = record({
    state: "child_dispatching",
    childDispatchAttemptCount: 1,
    childDispatchLeaseOwner: "worker-1",
    childDispatchLeaseToken: "e".repeat(64),
    childDispatchLeaseUntil: "2026-08-04T10:06:00.000Z",
  });
  const command = handoffContract.buildPublicLiteAcquisitionCommand({
    record: claimed,
    dispatchEnvelope: validEnvelope(),
    attemptCount: 1,
    leaseToken: "e".repeat(64),
  });
  assert.equal(command.executionId, executionId);
  assert.equal(command.attempt, 1);
  assert.equal(command.leaseToken, "e".repeat(64));
});

test("child receipt rejects another handoff", () => {
  assert.throws(
      () => handoffContract.normalizePublicLiteAcquisitionDispatchReceipt(
          acquisitionReceipt(record(), {handoffId: "f".repeat(64)}),
          {
            expectedHandoffId: record().handoffId,
            expectedExecutionId: executionId,
          }),
      (error) => error.code === "failed-precondition");
});

test("completion accepts a result during child dispatch race", () => {
  const active = record({
    state: "child_dispatching",
    childDispatchAttemptCount: 1,
    childDispatchLeaseOwner: "worker-1",
    childDispatchLeaseToken: "e".repeat(64),
    childDispatchLeaseUntil: "2026-08-04T10:06:00.000Z",
  });
  const externalExecutionId =
    handoffContract.derivePublicLiteAcquisitionExternalExecutionId(
        active.handoffId);
  const completed =
    handoffContract.completePublicLiteProviderHandoffRecord(active, {
      externalExecutionId,
      completedAt: later,
      updatedAt: later,
    });
  assert.equal(completed.state, "completed");
  assert.equal(completed.childExternalExecutionId, externalExecutionId);
  assert.equal(completed.childDispatchDueAtTimestamp, null);
});

test("accept service derives acceptedAt from the server clock", async () => {
  const port = new FakePort();
  const result = await handoffService.acceptPublicLiteProviderHandoff({
    request: validRequest(),
    port,
    clock: clock(),
  });
  assert.equal(result.outcome, "created");
  assert.equal(result.receipt.acceptedAt, now);
  assert.equal(port.calls[0][0], "acceptHandoff");
  assert.equal(
      port.calls[0][1].purgeAtTimestamp instanceof Date,
      true);
});

test("child dispatch service stores a scoped receipt", async () => {
  const port = new FakePort();
  const result =
    await handoffService.dispatchAcceptedPublicLiteProviderHandoff({
      executionId,
      ownerId: "worker-1",
      port,
      dispatcher: {
        dispatch: async (command) => acquisitionReceipt(record(), {
          handoffId: command.handoffId,
          executionId: command.executionId,
        }),
      },
      clock: clock([now, later]),
    });
  assert.equal(result.outcome, "child_dispatched");
  assert.equal(port.calls.at(-1)[0], "markChildDispatchSucceeded");
});

test("retryable child HTTP failure is stored for retry", async () => {
  const port = new FakePort();
  const result =
    await handoffService.dispatchAcceptedPublicLiteProviderHandoff({
      executionId,
      ownerId: "worker-1",
      port,
      dispatcher: {
        dispatch: async () => {
          const error = new Error("busy");
          error.statusCode = 503;
          throw error;
        },
      },
      clock: clock([now, later]),
    });
  assert.equal(result.outcome, "retryable_failure");
  assert.equal(port.calls.at(-1)[1].retryable, true);
});

test("acquisition dispatcher sends exact token and command", async () => {
  const calls = [];
  const claimed = record({
    state: "child_dispatching",
    childDispatchAttemptCount: 1,
    childDispatchLeaseOwner: "worker-1",
    childDispatchLeaseToken: "e".repeat(64),
    childDispatchLeaseUntil: "2026-08-04T10:06:00.000Z",
  });
  const command = handoffContract.buildPublicLiteAcquisitionCommand({
    record: claimed,
    dispatchEnvelope: validEnvelope(),
    attemptCount: 1,
    leaseToken: "e".repeat(64),
  });
  const dispatcher = handoffTrigger.createPublicLiteAcquisitionDispatcher({
    acquisitionToken: {value: () => "acquisition-secret"},
    webhookUrl: "https://example.test/acquisition",
    fetchImpl: async (url, options) => {
      calls.push({url, options});
      return {
        ok: true,
        status: 202,
        text: async () => JSON.stringify(acquisitionReceipt(claimed)),
      };
    },
  });
  const receipt = await dispatcher.dispatch(command);
  assert.equal(calls.length, 1);
  assert.equal(
      calls[0].options.headers[
          handoffTrigger.PUBLIC_LITE_ACQUISITION_TOKEN_HEADER],
      "acquisition-secret");
  assert.equal(receipt.executionId, executionId);
});

test("child trigger declares retry and dedicated secret", () => {
  let options;
  handoffTrigger.buildDispatchPublicLiteRiskScanAcquisition({
    db: {},
    onDocumentCreated: (value, callback) => {
      options = value;
      return callback;
    },
    logger: makeLogger(),
    fetchImpl: async () => assert.fail("fetch must not run"),
    acquisitionToken: {value: () => "secret"},
    portFactory: () => ({}),
    dispatchHandoff: async () => ({outcome: "already_dispatched"}),
  });
  assert.equal(options.document, handoffTrigger.PUBLIC_LITE_HANDOFF_DOCUMENT);
  assert.equal(options.retry, true);
  assert.equal(options.secrets.length, 1);
});


test("handoff record v2 is immediately due and storage-bound", () => {
  const value = record();
  assert.equal(
      value.contractVersion,
      handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_RECORD_VERSION_V2);
  assert.equal(
      value.storageVersion,
      handoffContract.PUBLIC_LITE_PROVIDER_HANDOFF_STORAGE_VERSION_V2);
  assert.equal(value.childDispatchDueAtTimestamp instanceof Date, true);
  assert.equal(value.childDispatchDueAtTimestamp.toISOString(), now);
  assert.equal(value.deadLetteredAt, null);
});

test("retry backoff is deterministic and bounded", () => {
  assert.equal(
      handoffContract.publicLiteProviderHandoffRetryDelayMs(1),
      60000);
  assert.equal(
      handoffContract.publicLiteProviderHandoffRetryDelayMs(5),
      900000);
  assert.equal(
      handoffContract.publicLiteProviderHandoffRetryDueAt({
        attemptCount: 2,
        failedAt: now,
      }).toISOString(),
      "2026-08-04T10:02:00.000Z");
});

test("logical child identity is deterministic from handoffId", () => {
  const value = record();
  const first =
    handoffContract.derivePublicLiteAcquisitionExternalExecutionId(
        value.handoffId);
  const second =
    handoffContract.derivePublicLiteAcquisitionExternalExecutionId(
        value.handoffId);
  assert.equal(first, second);
  assert.equal(first, `n8n-handoff:${value.handoffId}`);
});

test("child receipt rejects another logical external identity", () => {
  const value = record();
  assert.throws(
      () => handoffContract.normalizePublicLiteAcquisitionDispatchReceipt(
          acquisitionReceipt(value, {
            externalExecutionId: "n8n-handoff:" + "f".repeat(64),
          }),
          {
            expectedHandoffId: value.handoffId,
            expectedExecutionId: value.executionId,
          }),
      (error) => error.code === "failed-precondition");
});
