/* eslint-disable max-len */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  InterventionLegalContractError,
} = require("./contracts");
const {
  CALLABLE_NAMES,
  CALLABLE_OPTIONS,
  assertCallableRequest,
  buildCreateInterventionLegalApprovalRequestCallable,
  buildCreateInterventionLegalMatterCallable,
  buildRecordInterventionLegalApprovalDecisionCallable,
  buildTransitionInterventionLegalMatterCallable,
  createInterventionLegalCallableHandlers,
  createInterventionLegalServiceBundle,
  injectAuthenticatedActor,
  mapInterventionLegalError,
} = require("./callable");

function createLog() {
  const records = [];
  return {
    records,
    info(message, fields) {
      records.push({level: "info", message, ...fields});
    },
    error(message, fields) {
      records.push({level: "error", message, ...fields});
    },
  };
}

function createServices(overrides = {}) {
  const calls = {
    create: [],
    transition: [],
    requestApproval: [],
    approval: [],
  };
  return {
    calls,
    services: {
      async createLegalMatter(command) {
        calls.create.push(command);
        return {
          resultType: "legal_matter",
          resultId: "lm-1",
          idempotentReplay: false,
        };
      },
      async transitionLegalMatter(command) {
        calls.transition.push(command);
        return {
          resultType: "legal_matter",
          resultId: "lm-1",
          idempotentReplay: false,
        };
      },
      async createApprovalRequest(command) {
        calls.requestApproval.push(command);
        return {
          resultType: "legal_approval_request",
          resultId: "lar-1",
          idempotentReplay: false,
        };
      },
      async recordApprovalDecision(command) {
        calls.approval.push(command);
        return {
          resultType: "legal_approval_decision",
          resultId: "lad-1",
          idempotentReplay: false,
        };
      },
      ...overrides,
    },
  };
}

function request(data = {}) {
  return {
    auth: {uid: "authenticated-user"},
    app: {appId: "verified-app"},
    data,
  };
}

test("callable names and hardened options are stable", () => {
  assert.deepEqual(CALLABLE_NAMES, {
    CREATE_LEGAL_MATTER: "createInterventionLegalMatter",
    TRANSITION_LEGAL_MATTER: "transitionInterventionLegalMatter",
    CREATE_APPROVAL_REQUEST: "createInterventionLegalApprovalRequest",
    RECORD_APPROVAL_DECISION:
      "recordInterventionLegalApprovalDecision",
  });
  assert.deepEqual(CALLABLE_OPTIONS, {
    region: "europe-west3",
    enforceAppCheck: true,
    maxInstances: 1,
  });
});

test("four builders pass identical hardened options to onCall", () => {
  const captures = [];
  const onCallImpl = (options, handler) => {
    captures.push({options, handler});
    return {options, handler};
  };
  const {services} = createServices();
  const dependencies = {
    services,
    onCallImpl,
    log: createLog(),
  };

  buildCreateInterventionLegalMatterCallable(dependencies);
  buildTransitionInterventionLegalMatterCallable(dependencies);
  buildCreateInterventionLegalApprovalRequestCallable(dependencies);
  buildRecordInterventionLegalApprovalDecisionCallable(dependencies);

  assert.equal(captures.length, 4);
  assert.equal(
      captures.every((item) => item.options === CALLABLE_OPTIONS),
      true,
  );
  assert.equal(
      captures.every((item) => typeof item.handler === "function"),
      true,
  );
});

test("production service bundle binds adapter and four services", () => {
  const db = {
    collection() {
      return {};
    },
    runTransaction() {},
  };
  const bundle = createInterventionLegalServiceBundle({
    db,
    clock: () => "2026-07-31T14:00:00.000Z",
  });
  assert.equal(typeof bundle.createLegalMatter, "function");
  assert.equal(typeof bundle.transitionLegalMatter, "function");
  assert.equal(typeof bundle.createApprovalRequest, "function");
  assert.equal(typeof bundle.recordApprovalDecision, "function");
});

test("missing authentication is rejected before service execution", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await assert.rejects(
      () => handlers.createLegalMatter({
        app: {appId: "verified-app"},
        data: {},
      }),
      (error) =>
        error instanceof HttpsError &&
      error.code === "unauthenticated",
  );
  assert.equal(harness.calls.create.length, 0);
});

test("missing App Check is rejected before service execution", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await assert.rejects(
      () => handlers.createLegalMatter({
        auth: {uid: "authenticated-user"},
        data: {},
      }),
      (error) =>
        error instanceof HttpsError &&
      error.code === "failed-precondition",
  );
  assert.equal(harness.calls.create.length, 0);
});

test("create handler injects authenticated uid as actorUid", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await handlers.createLegalMatter(request({
    requestId: "req-create",
  }));

  assert.deepEqual(harness.calls.create[0], {
    requestId: "req-create",
    actorUid: "authenticated-user",
  });
});

test("create handler rejects client actor identity", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await assert.rejects(
      () => handlers.createLegalMatter(request({
        actorUid: "spoofed-user",
      })),
      (error) =>
        error instanceof HttpsError &&
      error.code === "invalid-argument",
  );
  assert.equal(harness.calls.create.length, 0);
});

test("transition handler injects authenticated uid as actorUid", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await handlers.transitionLegalMatter(request({
    legalMatterId: "lm-1",
  }));

  assert.deepEqual(harness.calls.transition[0], {
    legalMatterId: "lm-1",
    actorUid: "authenticated-user",
  });
});

test("transition handler rejects client actor identity", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await assert.rejects(
      () => handlers.transitionLegalMatter(request({
        decidedByUid: "spoofed-user",
      })),
      (error) =>
        error instanceof HttpsError &&
      error.code === "invalid-argument",
  );
  assert.equal(harness.calls.transition.length, 0);
});

test("approval handler injects authenticated uid as decidedByUid", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await handlers.recordApprovalDecision(request({
    approvalRequestId: "lar-1",
  }));

  assert.deepEqual(harness.calls.approval[0], {
    approvalRequestId: "lar-1",
    decidedByUid: "authenticated-user",
  });
});

test("approval handler rejects client actor identity", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await assert.rejects(
      () => handlers.recordApprovalDecision(request({
        decidedByUid: "spoofed-user",
      })),
      (error) =>
        error instanceof HttpsError &&
      error.code === "invalid-argument",
  );
  assert.equal(harness.calls.approval.length, 0);
});

test("contract error codes map to controlled HttpsError codes", () => {
  const codes = [
    "invalid-argument",
    "failed-precondition",
    "not-found",
    "permission-denied",
    "already-exists",
    "aborted",
    "out-of-range",
    "resource-exhausted",
    "unavailable",
    "deadline-exceeded",
  ];
  for (const code of codes) {
    const mapped = mapInterventionLegalError(
        new InterventionLegalContractError(
            code,
            `message-${code}`,
            {code},
        ),
    );
    assert.equal(mapped instanceof HttpsError, true);
    assert.equal(mapped.code, code);
    assert.equal(mapped.message, `message-${code}`);
    assert.deepEqual(mapped.details, {code});
  }
});

test("unknown errors map to generic internal HttpsError", () => {
  const mapped = mapInterventionLegalError(
      new Error("sensitive implementation detail"),
  );
  assert.equal(mapped instanceof HttpsError, true);
  assert.equal(mapped.code, "internal");
  assert.equal(
      mapped.message,
      "Müdahale ve Hukuk işlemi tamamlanamadı.",
  );
  assert.equal(
      mapped.message.includes("sensitive implementation detail"),
      false,
  );
});

test("existing HttpsError is preserved", () => {
  const source = new HttpsError(
      "permission-denied",
      "already mapped",
  );
  assert.equal(mapInterventionLegalError(source), source);
});

test("logging records outcomes without uid or raw command payload", async () => {
  const log = createLog();
  const harness = createServices({
    async transitionLegalMatter() {
      throw new InterventionLegalContractError(
          "permission-denied",
          "not allowed",
      );
    },
  });
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log,
  });

  await handlers.createLegalMatter(request({requestId: "req-1"}));
  await assert.rejects(
      () => handlers.transitionLegalMatter(
          request({legalMatterId: "lm-1"}),
      ),
      (error) => error.code === "permission-denied",
  );

  assert.equal(log.records.length, 2);
  assert.equal(log.records[0].outcome, "completed");
  assert.equal(log.records[1].outcome, "failed");
  const serialized = JSON.stringify(log.records);
  assert.equal(serialized.includes("authenticated-user"), false);
  assert.equal(serialized.includes("req-1"), false);
});

test("standalone guards enforce request and actor rules", () => {
  assert.equal(assertCallableRequest(request()), "authenticated-user");
  assert.deepEqual(
      injectAuthenticatedActor(
          {value: 1},
          "actorUid",
          "authenticated-user",
      ),
      {value: 1, actorUid: "authenticated-user"},
  );
  assert.throws(
      () => injectAuthenticatedActor(
          {actorUid: "spoofed"},
          "actorUid",
          "authenticated-user",
      ),
      (error) =>
        error instanceof HttpsError &&
      error.code === "invalid-argument",
  );
});


test("approval request handler injects authenticated uid as preparedByUid", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await handlers.createApprovalRequest(request({
    legalMatterId: "lm-1",
  }));

  assert.deepEqual(harness.calls.requestApproval[0], {
    legalMatterId: "lm-1",
    preparedByUid: "authenticated-user",
  });
});

test("approval request handler rejects client preparer identity", async () => {
  const harness = createServices();
  const handlers = createInterventionLegalCallableHandlers({
    services: harness.services,
    log: createLog(),
  });

  await assert.rejects(
      () => handlers.createApprovalRequest(request({
        preparedByUid: "spoofed-user",
      })),
      (error) =>
        error instanceof HttpsError &&
        error.code === "invalid-argument",
  );
  assert.equal(harness.calls.requestApproval.length, 0);
});
