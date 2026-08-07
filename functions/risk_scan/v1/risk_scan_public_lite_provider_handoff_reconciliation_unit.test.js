"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const reconciliation = require(
    "./public_lite_provider_handoff_reconciliation");
const {
  PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_VERSION_V1,
} = require("./public_lite_provider_handoff_contract");

const now = new Date("2026-08-06T12:00:00.000Z");

function record(index) {
  const digit = String(index).slice(-1);
  return {
    executionId: digit.repeat(64),
    handoffId: String((index + 1) % 10).repeat(64),
  };
}

function logger() {
  return {
    infos: [],
    warns: [],
    errors: [],
    info(message, data) {
      this.infos.push({message, data});
    },
    warn(message, data) {
      this.warns.push({message, data});
    },
    error(message, data) {
      this.errors.push({message, data});
    },
  };
}

function fixture({
  records = [record(1)],
  outcomes = ["child_dispatched"],
  scanLimit = 100,
  processLimit = 25,
  queryError = null,
} = {}) {
  const calls = [];
  const port = {
    claimChildDispatch() {},
    markChildDispatchSucceeded() {},
    markChildDispatchFailed() {},
    async listDueHandoffs(input) {
      calls.push(["listDueHandoffs", input]);
      if (queryError) throw queryError;
      return records;
    },
  };
  let index = 0;
  const dispatchCalls = [];
  const handler =
    reconciliation.createPublicLiteProviderHandoffReconciliationHandler({
      port,
      dispatcher: {dispatch() {}},
      clock: {now: () => now},
      logger: logger(),
      scanLimit,
      processLimit,
      async dispatchHandoff(input) {
        dispatchCalls.push(input);
        const outcome = outcomes[Math.min(index, outcomes.length - 1)];
        index += 1;
        if (outcome instanceof Error) throw outcome;
        return {
          outcome,
          attemptCount: outcome === "child_dispatched" ? index : undefined,
        };
      },
    });
  return {calls, dispatchCalls, handler, port};
}

test("reconciliation contract and function names are stable", () => {
  assert.equal(
      PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_VERSION_V1,
      "risk-scan-public-lite-provider-handoff-reconciliation-v1");
  assert.equal(
      reconciliation
          .PUBLIC_LITE_PROVIDER_HANDOFF_RECONCILIATION_FUNCTION_NAME,
      "reconcilePublicLiteRiskScanProviderHandoffs");
});

test("schedule options are fixed and bind acquisition secret", () => {
  const secret = {name: "acquisition-secret"};
  const options = reconciliation.scheduledReconciliationOptions({
    acquisitionToken: secret,
  });
  assert.equal(options.schedule, "every 5 minutes");
  assert.equal(options.timeZone, "Etc/UTC");
  assert.equal(options.region, "europe-west3");
  assert.equal(options.maxInstances, 1);
  assert.equal(options.concurrency, 1);
  assert.equal(options.timeoutSeconds, 540);
  assert.equal(options.memory, "256MiB");
  assert.deepEqual(options.secrets, [secret]);
});

test("handler queries due records with bounded scan limit", async () => {
  const value = fixture({scanLimit: 7});
  const result = await value.handler({scheduleTime: now.toISOString()});
  assert.equal(value.calls.length, 1);
  assert.equal(value.calls[0][0], "listDueHandoffs");
  assert.equal(value.calls[0][1].limit, 7);
  assert.equal(value.calls[0][1].now.toISOString(), now.toISOString());
  assert.equal(result.scannedCount, 1);
});

test("handler records deterministic outcome counts", async () => {
  const records = Array.from({length: 8}, (_, index) => record(index + 1));
  const outcomes = [
    "child_dispatched",
    "retryable_failure",
    "terminal_failure",
    "lease_held",
    "not_due",
    "already_dispatched",
    "completed",
    "terminal",
  ];
  const value = fixture({records, outcomes});
  const result = await value.handler({id: "schedule-event-1"});
  assert.equal(result.attemptedCount, 8);
  assert.equal(result.childDispatchedCount, 1);
  assert.equal(result.retryableFailureCount, 1);
  assert.equal(result.terminalFailureCount, 1);
  assert.equal(result.leaseHeldCount, 1);
  assert.equal(result.notDueCount, 1);
  assert.equal(result.alreadyDispatchedCount, 1);
  assert.equal(result.completedCount, 1);
  assert.equal(result.terminalCount, 1);
  assert.match(value.dispatchCalls[0].ownerId, /^reconcile:/u);
});

test("handler enforces process limit without dispatching extras", async () => {
  const value = fixture({
    records: [record(1), record(2), record(3)],
    processLimit: 2,
  });
  const result = await value.handler();
  assert.equal(result.attemptedCount, 2);
  assert.equal(result.skippedProcessLimitCount, 1);
  assert.equal(value.dispatchCalls.length, 2);
});

test("handler contains one candidate failure and continues", async () => {
  const error = new Error("failure");
  error.code = "aborted";
  const value = fixture({
    records: [record(1), record(2)],
    outcomes: [error, "child_dispatched"],
  });
  const result = await value.handler();
  assert.equal(result.failedCount, 1);
  assert.equal(result.childDispatchedCount, 1);
  assert.equal(result.handoffResults[0].errorCode, "aborted");
});

test("handler rethrows a due query failure", async () => {
  const error = new Error("query failed");
  error.code = "unavailable";
  const value = fixture({queryError: error});
  await assert.rejects(() => value.handler(), error);
});

test("handler returns deeply frozen reconciliation results", async () => {
  const value = fixture();
  const result = await value.handler();
  assert.equal(Object.isFrozen(result), true);
  assert.equal(Object.isFrozen(result.handoffResults), true);
  assert.equal(Object.isFrozen(result.handoffResults[0]), true);
});

test("builder passes exact options and handler to onSchedule", () => {
  const secret = {name: "secret", value: () => "value"};
  let captured;
  const marker = () => {};
  const built = reconciliation
      .buildReconcilePublicLiteRiskScanProviderHandoffs({
        db: {},
        logger: logger(),
        acquisitionToken: secret,
        portFactory: () => ({
          listDueHandoffs() {},
          claimChildDispatch() {},
          markChildDispatchSucceeded() {},
          markChildDispatchFailed() {},
        }),
        dispatcherFactory: () => ({dispatch() {}}),
        onScheduleImpl(options, handler) {
          captured = {options, handler};
          return marker;
        },
      });
  assert.equal(built, marker);
  assert.deepEqual(
      captured.options,
      reconciliation.scheduledReconciliationOptions({
        acquisitionToken: secret,
      }));
  assert.equal(typeof captured.handler, "function");
});

test("positive integer and safe error helpers are bounded", () => {
  assert.equal(reconciliation.assertPositiveInteger(1, "value", 2), 1);
  assert.throws(() =>
    reconciliation.assertPositiveInteger(3, "value", 2));
  assert.equal(reconciliation.safeErrorCode({code: "aborted"}), "aborted");
  assert.equal(reconciliation.safeErrorCode(new Error("secret")), "internal");
});
