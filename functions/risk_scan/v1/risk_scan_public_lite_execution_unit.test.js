"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const contract = require("./public_lite_execution_contract");
const service = require("./public_lite_execution_service");

const now = "2026-08-04T09:00:00.000Z";
const later = "2026-08-04T09:01:00.000Z";
const expires = "2026-08-05T09:00:00.000Z";
const digestA = "a".repeat(64);
const digestB = "b".repeat(64);
const digestC = "c".repeat(64);

function run(overrides = {}) {
  return {
    contractVersion: "risk-scan-run-v1",
    scanRunId: digestA,
    scanMode: "quick",
    accessTier: "publicLite",
    identityMode: "anonymous",
    status: "created",
    coverageStatus: "insufficient",
    target: {
      brandNameNormalized: "beauty of joseon",
      officialHost: "beautyofjoseon.com",
      officialWebsiteCanonicalUrl: "https://beautyofjoseon.com/",
      targetFingerprintSha256: digestB,
    },
    requestId: "request-1",
    requestFingerprintSha256: digestB,
    deduplicationFingerprintSha256: digestC,
    tenantId: null,
    canonicalBrandId: null,
    createdByUid: null,
    createdAt: now,
    updatedAt: now,
    expiresAt: expires,
    ...overrides,
  };
}

function channels(scanRunId = digestA, overrides = {}) {
  return [
    "similarDomains",
    "openWeb",
    "marketplaceLimited",
  ].map((channelCode) => ({
    scanRunId,
    channelCode,
    status: "queued",
    coverageStatus: "insufficient",
    ...overrides,
  }));
}

function event(overrides = {}) {
  const {run: runOverrides = {}, ...eventOverrides} = overrides;
  const value = run(runOverrides);
  return {
    eventId: "event-1",
    eventTime: later,
    run: value,
    channels: channels(value.scanRunId),
    ...eventOverrides,
  };
}

function command() {
  return contract.buildPublicLiteExecutionCommand(event());
}

class FakePort {
  constructor(overrides = {}) {
    this.calls = [];
    this.overrides = overrides;
  }

  async prepareExecution(input) {
    this.calls.push(["prepareExecution", input]);
    return this.overrides.prepare || {outcome: "created"};
  }

  async queueExecution(input) {
    this.calls.push(["queueExecution", input]);
    return this.overrides.queue || {outcome: "queued"};
  }

  async claimDispatch(input) {
    this.calls.push(["claimDispatch", input]);
    return this.overrides.claim || {
      outcome: "claimed",
      attemptCount: 1,
    };
  }

  async markDispatchSucceeded(input) {
    this.calls.push(["markDispatchSucceeded", input]);
    return this.overrides.success || {outcome: "dispatched"};
  }

  async markDispatchFailed(input) {
    this.calls.push(["markDispatchFailed", input]);
    return this.overrides.failure || {
      outcome: input.retryable ?
        "retryable_failure" : "terminal_failure",
    };
  }
}

function clock(values = [later]) {
  let index = 0;
  return {
    now: () => values[Math.min(index++, values.length - 1)],
  };
}

// Contract and deterministic identity.
test("execution contract versions are fixed", () => {
  assert.equal(
      contract.PUBLIC_LITE_EXECUTION_COMMAND_VERSION_V1,
      "risk-scan-public-lite-execution-command-v1");
  assert.equal(
      contract.PUBLIC_LITE_DISPATCH_MAX_ATTEMPTS,
      5);
});

test("execution id is deterministic", () => {
  assert.equal(command().executionId, command().executionId);
  assert.match(command().executionId, /^[a-f0-9]{64}$/);
});

test("execution id changes with request fingerprint", () => {
  const first = command();
  const second = contract.buildPublicLiteExecutionCommand(event({
    run: {requestFingerprintSha256: digestC},
  }));
  assert.notEqual(first.executionId, second.executionId);
});

test("command normalizes canonical channel order", () => {
  const input = event();
  input.channels.reverse();
  assert.deepEqual(
      contract.buildPublicLiteExecutionCommand(input).channelCodes,
      ["similarDomains", "openWeb", "marketplaceLimited"]);
});

test("resolved identity is rejected", () => {
  assert.throws(() => contract.buildPublicLiteExecutionCommand(event({
    run: {
      identityMode: "resolved",
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      createdByUid: "user-1",
    },
  })));
});

test("non-created run is rejected", () => {
  assert.throws(() => contract.buildPublicLiteExecutionCommand(event({
    run: {status: "queued"},
  })));
});

test("wrong scan mode is rejected", () => {
  assert.throws(() => contract.buildPublicLiteExecutionCommand(event({
    run: {scanMode: "deep"},
  })));
});

test("missing channel is rejected", () => {
  const input = event();
  input.channels.pop();
  assert.throws(() => contract.buildPublicLiteExecutionCommand(input));
});

test("duplicate channel is rejected", () => {
  const input = event();
  input.channels[2] = {...input.channels[1]};
  assert.throws(() => contract.buildPublicLiteExecutionCommand(input));
});

test("channel from another run is rejected", () => {
  const input = event();
  input.channels[1].scanRunId = digestB;
  assert.throws(() => contract.buildPublicLiteExecutionCommand(input));
});

test("replayed channel status remains accepted", () => {
  const input = event();
  input.channels[1].status = "acquiring";
  assert.deepEqual(
      contract.buildPublicLiteExecutionCommand(input).channelCodes,
      ["similarDomains", "openWeb", "marketplaceLimited"]);
});

test("expired run is rejected", () => {
  assert.throws(() => contract.buildPublicLiteExecutionCommand(event({
    eventTime: "2026-08-05T10:00:00.000Z",
  })));
});

test("official host mismatch is rejected", () => {
  assert.throws(() => contract.buildPublicLiteExecutionCommand(event({
    run: {
      target: {
        ...run().target,
        officialHost: "example.com",
      },
    },
  })));
});

test("execution record begins prepared without a lease", () => {
  const record = contract.buildPublicLiteExecutionRecord(command());
  assert.equal(record.status, "prepared");
  assert.equal(record.attemptCount, 0);
  assert.equal(record.leaseOwner, null);
});

test("dispatch envelope excludes access secrets", () => {
  const envelope = contract.buildPublicLiteDispatchEnvelope(command());
  const serialized = JSON.stringify(envelope).toLowerCase();
  assert.equal(serialized.includes("accesssecret"), false);
  assert.equal(serialized.includes("accesskey"), false);
  assert.equal(envelope.identityMode, "anonymous");
});

test("dispatch lease has bounded expiry", () => {
  const lease = contract.buildDispatchLease({
    executionId: command().executionId,
    ownerId: "worker-1",
    attemptCount: 1,
    now: later,
  });
  assert.equal(
      Date.parse(lease.leaseExpiresAt) - Date.parse(lease.leasedAt),
      contract.PUBLIC_LITE_DISPATCH_LEASE_MS);
});

test("dispatch lease rejects attempt above policy", () => {
  assert.throws(() => contract.buildDispatchLease({
    executionId: command().executionId,
    ownerId: "worker-1",
    attemptCount: 6,
    now: later,
  }));
});

test("execution lifecycle accepts retry", () => {
  assert.equal(
      contract.assertExecutionTransition(
          "retryableFailure", "dispatching"),
      "dispatching");
});

test("execution lifecycle rejects terminal replay", () => {
  assert.throws(() => contract.assertExecutionTransition(
      "terminalFailure", "dispatching"));
});

test("receipt normalizes provider metadata", () => {
  assert.deepEqual(contract.normalizeDispatchReceipt({
    providerCode: "n8n_public_lite",
    externalExecutionId: "execution-1",
    acceptedAt: later,
  }), {
    contractVersion: "risk-scan-public-lite-dispatch-receipt-v1",
    providerCode: "n8n_public_lite",
    externalExecutionId: "execution-1",
    acceptedAt: later,
  });
});

// Orchestration core.
test("prepare creates and queues execution", async () => {
  const port = new FakePort();
  const result = await service.preparePublicLiteExecution({
    event: event(),
    port,
    clock: clock(),
  });
  assert.equal(result.outcome, "prepared");
  assert.deepEqual(
      port.calls.map(([name]) => name),
      ["prepareExecution", "queueExecution"]);
});

test("prepare replay remains idempotent", async () => {
  const port = new FakePort({
    prepare: {outcome: "idempotent_success"},
    queue: {outcome: "idempotent_success"},
  });
  const result = await service.preparePublicLiteExecution({
    event: event(),
    port,
    clock: clock(),
  });
  assert.equal(result.outcome, "idempotent_prepared");
});

test("successful dispatch is stored once", async () => {
  const port = new FakePort();
  const result = await service.dispatchPreparedPublicLiteExecution({
    command: command(),
    ownerId: "worker-1",
    port,
    dispatcher: {
      dispatch: async () => ({
        providerCode: "n8n_public_lite",
        externalExecutionId: "execution-1",
        acceptedAt: later,
      }),
    },
    clock: clock(),
  });
  assert.equal(result.outcome, "dispatched");
  assert.equal(result.attemptCount, 1);
  assert.equal(
      port.calls.at(-1)[0],
      "markDispatchSucceeded");
});

test("held lease does not dispatch", async () => {
  const port = new FakePort({claim: {outcome: "lease_held"}});
  let dispatchCount = 0;
  const result = await service.dispatchPreparedPublicLiteExecution({
    command: command(),
    ownerId: "worker-2",
    port,
    dispatcher: {
      dispatch: async () => {
        dispatchCount += 1;
      },
    },
    clock: clock(),
  });
  assert.equal(result.outcome, "lease_held");
  assert.equal(dispatchCount, 0);
});

test("already dispatched execution is not dispatched again", async () => {
  const port = new FakePort({
    claim: {outcome: "already_dispatched"},
  });
  let dispatchCount = 0;
  const result = await service.dispatchPreparedPublicLiteExecution({
    command: command(),
    ownerId: "worker-2",
    port,
    dispatcher: {
      dispatch: async () => {
        dispatchCount += 1;
      },
    },
    clock: clock(),
  });
  assert.equal(result.outcome, "already_dispatched");
  assert.equal(dispatchCount, 0);
});

test("HTTP 503 is retryable", async () => {
  const port = new FakePort();
  const result = await service.dispatchPreparedPublicLiteExecution({
    command: command(),
    ownerId: "worker-1",
    port,
    dispatcher: {
      dispatch: async () => {
        const error = new Error("upstream unavailable");
        error.statusCode = 503;
        throw error;
      },
    },
    clock: clock([later, later]),
  });
  assert.equal(result.outcome, "retryable_failure");
  assert.equal(result.failure.retryable, true);
  assert.equal(port.calls.at(-1)[1].retryable, true);
});

test("HTTP 400 is terminal", async () => {
  const port = new FakePort();
  const result = await service.dispatchPreparedPublicLiteExecution({
    command: command(),
    ownerId: "worker-1",
    port,
    dispatcher: {
      dispatch: async () => {
        const error = new Error("invalid contract");
        error.statusCode = 400;
        throw error;
      },
    },
    clock: clock([later, later]),
  });
  assert.equal(result.outcome, "terminal_failure");
  assert.equal(result.failure.retryable, false);
});

test("invalid provider receipt becomes terminal", async () => {
  const port = new FakePort();
  const result = await service.dispatchPreparedPublicLiteExecution({
    command: command(),
    ownerId: "worker-1",
    port,
    dispatcher: {
      dispatch: async () => ({providerCode: "n8n_public_lite"}),
    },
    clock: clock([later, later]),
  });
  assert.equal(result.outcome, "terminal_failure");
  assert.equal(port.calls.at(-1)[0], "markDispatchFailed");
});

test("fifth failed attempt becomes terminal", async () => {
  const port = new FakePort({
    claim: {outcome: "claimed", attemptCount: 5},
  });
  const result = await service.dispatchPreparedPublicLiteExecution({
    command: command(),
    ownerId: "worker-1",
    port,
    dispatcher: {
      dispatch: async () => {
        const error = new Error("timeout");
        error.statusCode = 503;
        throw error;
      },
    },
    clock: clock([later, later]),
  });
  assert.equal(result.outcome, "terminal_failure");
  assert.equal(port.calls.at(-1)[1].retryable, false);
});

test("explicit retryable flag overrides HTTP classification", () => {
  const failure = service.normalizeDispatchFailure({
    code: "custom",
    message: "try again",
    statusCode: 400,
    retryable: true,
  });
  assert.equal(failure.retryable, true);
});

test("orchestration prepares then dispatches", async () => {
  const port = new FakePort();
  const result = await service.orchestratePublicLiteExecution({
    event: event(),
    ownerId: "worker-1",
    port,
    dispatcher: {
      dispatch: async () => ({
        providerCode: "n8n_public_lite",
        externalExecutionId: "execution-1",
        acceptedAt: later,
      }),
    },
    clock: clock([later, later]),
  });
  assert.equal(result.outcome, "dispatched");
  assert.deepEqual(
      port.calls.map(([name]) => name),
      [
        "prepareExecution",
        "queueExecution",
        "claimDispatch",
        "markDispatchSucceeded",
      ]);
});

test("invalid execution port is rejected", async () => {
  await assert.rejects(() => service.preparePublicLiteExecution({
    event: event(),
    port: {},
    clock: clock(),
  }));
});

test("invalid dispatcher is rejected", async () => {
  await assert.rejects(() =>
    service.dispatchPreparedPublicLiteExecution({
      command: command(),
      ownerId: "worker-1",
      port: new FakePort(),
      dispatcher: {},
      clock: clock(),
    }));
});
