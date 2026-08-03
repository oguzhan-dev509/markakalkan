/* eslint-disable max-len */
"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  CREATE_SUBSCRIPTION_REQUEST_COMMAND_VERSION,
  SUBSCRIPTION_CALLABLE_CONTRACT_VERSION,
  SubscriptionRequestContractError,
  parseCreateSubscriptionRequestCommand,
} = require("./contracts");
const {
  CALLABLE_OPTIONS,
  buildCreateSubscriptionServiceRequestCallable,
  collectClientActorFields,
  createSubscriptionRequestHandler,
} = require("./callable");
const {
  buildCreateSubscriptionRequestService,
  buildSubscriptionRequestId,
} = require("./service");

function command(overrides = {}) {
  return {
    contractVersion: CREATE_SUBSCRIPTION_REQUEST_COMMAND_VERSION,
    requestId: "123e4567-e89b-42d3-a456-426614174000",
    productCode: "broad_digital_scan_subscription",
    source: {
      sourceType: "public_lite_risk_scan",
      scanRunId: "risk-scan-run-001",
      reportId: "risk-report-001",
      brandName: "MarkaKalkan",
      officialWebsiteUrl: "https://markakalkan.com",
    },
    actorUid: "user-001",
    actorEmail: "owner@example.com",
    ...overrides,
  };
}

test("contract accepts the initial broad scan subscription product", () => {
  const parsed = parseCreateSubscriptionRequestCommand(command());
  assert.equal(parsed.productCode, "broad_digital_scan_subscription");
  assert.equal(parsed.source.sourceType, "public_lite_risk_scan");
  assert.equal(parsed.source.brandName, "MarkaKalkan");
});

test("contract rejects unsupported products", () => {
  assert.throws(
      () => parseCreateSubscriptionRequestCommand(
          command({productCode: "invented_plan"}),
      ),
      SubscriptionRequestContractError,
  );
});

test("contract rejects unknown client fields", () => {
  assert.throws(
      () => parseCreateSubscriptionRequestCommand(
          command({price: "100"}),
      ),
      SubscriptionRequestContractError,
  );
});

test("request identifier is stable per actor and request", () => {
  const first = buildSubscriptionRequestId({
    actorUid: "user-001",
    requestId: "123e4567-e89b-42d3-a456-426614174000",
  });
  const second = buildSubscriptionRequestId({
    actorUid: "user-001",
    requestId: "123e4567-e89b-42d3-a456-426614174000",
  });
  assert.equal(first, second);
  assert.match(first, /^subreq_[0-9a-f]{40}$/);
});

test("service creates an immutable requested record", async () => {
  let captured;
  const service = buildCreateSubscriptionRequestService({
    clock: () => "2026-08-03T18:00:00.000Z",
    store: {
      async createSubscriptionRequestAtomic(input) {
        captured = input.subscriptionRequest;
        return {
          subscriptionRequest: input.subscriptionRequest,
          idempotentReplay: false,
        };
      },
    },
  });

  const result = await service(command());
  assert.equal(result.contractVersion, SUBSCRIPTION_CALLABLE_CONTRACT_VERSION);
  assert.equal(result.resultType, "subscription_service_request");
  assert.equal(result.status, "requested");
  assert.equal(result.idempotentReplay, false);
  assert.equal(captured.requestedByUid, "user-001");
  assert.equal(captured.status, "requested");
  assert.equal(captured.productCode, "broad_digital_scan_subscription");
  assert.equal(captured.version, 1);
});

test("service accepts a matching idempotent replay", async () => {
  let firstRecord;
  const service = buildCreateSubscriptionRequestService({
    clock: () => "2026-08-03T18:00:00.000Z",
    store: {
      async createSubscriptionRequestAtomic(input) {
        firstRecord ??= input.subscriptionRequest;
        return {
          subscriptionRequest: firstRecord,
          idempotentReplay: true,
        };
      },
    },
  });

  const result = await service(command());
  assert.equal(result.idempotentReplay, true);
});

test("service rejects a conflicting idempotent replay", async () => {
  const service = buildCreateSubscriptionRequestService({
    clock: () => "2026-08-03T18:00:00.000Z",
    store: {
      async createSubscriptionRequestAtomic(input) {
        return {
          subscriptionRequest: {
            ...input.subscriptionRequest,
            brandName: "Başka Marka",
          },
          idempotentReplay: true,
        };
      },
    },
  });

  await assert.rejects(
      () => service(command()),
      (error) => error?.code === "aborted",
  );
});

test("actor fields are discovered recursively", () => {
  assert.deepEqual(
      collectClientActorFields({
        nested: {requestedByUid: "spoof"},
        list: [{actorEmail: "spoof@example.com"}],
      }),
      ["$.nested.requestedByUid", "$.list[0].actorEmail"],
  );
});

test("callable requires authentication", async () => {
  const handler = createSubscriptionRequestHandler({
    service: async () => ({}),
    log: {info() {}, error() {}},
  });

  await assert.rejects(
      () => handler({
        data: {},
        app: {appId: "app"},
      }),
      (error) => error?.code === "unauthenticated",
  );
});

test("callable requires App Check", async () => {
  const handler = createSubscriptionRequestHandler({
    service: async () => ({}),
    log: {info() {}, error() {}},
  });

  await assert.rejects(
      () => handler({
        data: {},
        auth: {uid: "user-001", token: {}},
      }),
      (error) => error?.code === "failed-precondition",
  );
});

test("callable rejects client actor spoofing", async () => {
  const handler = createSubscriptionRequestHandler({
    service: async () => ({}),
    log: {info() {}, error() {}},
  });

  await assert.rejects(
      () => handler({
        data: {actorUid: "spoof"},
        auth: {uid: "user-001", token: {}},
        app: {appId: "app"},
      }),
      (error) => error?.code === "invalid-argument",
  );
});

test("callable injects authenticated actor and email", async () => {
  let captured;
  const handler = createSubscriptionRequestHandler({
    service: async (value) => {
      captured = value;
      return {
        resultType: "subscription_service_request",
        resultId: "subreq_001",
      };
    },
    log: {info() {}, error() {}},
  });

  await handler({
    data: {
      contractVersion: CREATE_SUBSCRIPTION_REQUEST_COMMAND_VERSION,
      requestId: "123e4567-e89b-42d3-a456-426614174000",
      productCode: "broad_digital_scan_subscription",
      source: {
        sourceType: "public_lite_risk_scan",
        scanRunId: "run-001",
        reportId: null,
        brandName: "MarkaKalkan",
        officialWebsiteUrl: "https://markakalkan.com",
      },
    },
    auth: {
      uid: "user-001",
      token: {email: "owner@example.com"},
    },
    app: {appId: "app"},
  });

  assert.equal(captured.actorUid, "user-001");
  assert.equal(captured.actorEmail, "owner@example.com");
});

test("builder exports protected europe-west3 callable options", () => {
  let capturedOptions;
  let capturedHandler;
  const callable = buildCreateSubscriptionServiceRequestCallable({
    services: {
      createSubscriptionRequest: async () => ({}),
    },
    log: {info() {}, error() {}},
    onCallImpl(options, handler) {
      capturedOptions = options;
      capturedHandler = handler;
      return {options, handler};
    },
  });

  assert.equal(callable.handler, capturedHandler);
  assert.equal(capturedOptions, CALLABLE_OPTIONS);
  assert.equal(capturedOptions.region, "europe-west3");
  assert.equal(capturedOptions.enforceAppCheck, true);
  assert.equal(capturedOptions.maxInstances, 1);
});
