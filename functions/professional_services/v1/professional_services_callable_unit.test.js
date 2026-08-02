/* eslint-disable max-len */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  ProfessionalServicesCanonicalError,
} = require("./canonical");
const {
  ProfessionalServicesContractError,
} = require("./contracts");
const {
  ProfessionalServicesIdentifierError,
} = require("./identifiers");
const {
  ProfessionalServicesLifecycleError,
} = require("./lifecycle");
const {
  CALLABLE_NAMES,
  CALLABLE_OPTIONS,
  assertCallableRequest,
  buildCreateProfessionalServiceAssignmentCallable,
  buildCreateProfessionalServiceEngagementCallable,
  buildCreateProfessionalServiceRequestCallable,
  buildPublishProfessionalAgentOutputCallable,
  buildRecordProfessionalAgentOutputCallable,
  buildRecordProfessionalAgentReviewCallable,
  buildStartProfessionalAgentRunCallable,
  buildTransitionProfessionalServiceRequestCallable,
  collectClientActorFields,
  createProfessionalServicesCallableHandlers,
  createProfessionalServicesServiceBundle,
  injectAuthenticatedActor,
  mapProfessionalServicesError,
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
    createRequest: [],
    transitionRequest: [],
    createEngagement: [],
    createAssignment: [],
    startRun: [],
    recordOutput: [],
    recordReview: [],
    publishOutput: [],
  };
  const result = (resultType, resultId) => ({
    resultType,
    resultId,
    idempotentReplay: false,
  });
  return {
    calls,
    services: {
      async createServiceRequest(command) {
        calls.createRequest.push(command);
        return result("professional_service_request", "psr-1");
      },
      async transitionServiceRequest(command) {
        calls.transitionRequest.push(command);
        return result("professional_service_request", "psr-1");
      },
      async createServiceEngagement(command) {
        calls.createEngagement.push(command);
        return result("professional_service_engagement", "pse-1");
      },
      async createServiceAssignment(command) {
        calls.createAssignment.push(command);
        return result("professional_service_assignment", "psa-1");
      },
      async startAgentRun(command) {
        calls.startRun.push(command);
        return result("professional_agent_run", "par-1");
      },
      async recordAgentOutput(command) {
        calls.recordOutput.push(command);
        return result("professional_agent_output", "pout-1");
      },
      async recordAgentReview(command) {
        calls.recordReview.push(command);
        return result("professional_agent_review", "prev-1");
      },
      async publishAgentOutput(command) {
        calls.publishOutput.push(command);
        return result("professional_agent_output_publication", "ppub-1");
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

function handlers(harness, log = createLog()) {
  return createProfessionalServicesCallableHandlers({
    services: harness.services,
    log,
  });
}

test("callable names and hardened options are stable", () => {
  assert.deepEqual(CALLABLE_NAMES, {
    CREATE_SERVICE_REQUEST: "createProfessionalServiceRequest",
    TRANSITION_SERVICE_REQUEST: "transitionProfessionalServiceRequest",
    CREATE_SERVICE_ENGAGEMENT: "createProfessionalServiceEngagement",
    CREATE_SERVICE_ASSIGNMENT: "createProfessionalServiceAssignment",
    START_AGENT_RUN: "startProfessionalAgentRun",
    RECORD_AGENT_OUTPUT: "recordProfessionalAgentOutput",
    RECORD_AGENT_REVIEW: "recordProfessionalAgentReview",
    PUBLISH_AGENT_OUTPUT: "publishProfessionalAgentOutput",
  });
  assert.deepEqual(CALLABLE_OPTIONS, {
    region: "europe-west3",
    enforceAppCheck: true,
    maxInstances: 1,
  });
});

test("eight builders pass identical hardened options to onCall", () => {
  const captures = [];
  const onCallImpl = (options, handler) => {
    captures.push({options, handler});
    return {options, handler};
  };
  const harness = createServices();
  const dependencies = {
    services: harness.services,
    onCallImpl,
    log: createLog(),
  };
  const builders = [
    buildCreateProfessionalServiceRequestCallable,
    buildTransitionProfessionalServiceRequestCallable,
    buildCreateProfessionalServiceEngagementCallable,
    buildCreateProfessionalServiceAssignmentCallable,
    buildStartProfessionalAgentRunCallable,
    buildRecordProfessionalAgentOutputCallable,
    buildRecordProfessionalAgentReviewCallable,
    buildPublishProfessionalAgentOutputCallable,
  ];
  builders.forEach((builder) => builder(dependencies));
  assert.equal(captures.length, 8);
  assert.equal(
      captures.every((item) => item.options === CALLABLE_OPTIONS),
      true,
  );
  assert.equal(
      captures.every((item) => typeof item.handler === "function"),
      true,
  );
});

test("production service bundle binds adapter and eight services", () => {
  const db = {
    collection() {
      return {};
    },
    runTransaction() {},
  };
  const bundle = createProfessionalServicesServiceBundle({
    db,
    clock: () => "2026-08-02T12:00:00.000Z",
  });
  assert.deepEqual(
      Object.keys(bundle).sort(),
      [
        "createServiceAssignment",
        "createServiceEngagement",
        "createServiceRequest",
        "publishAgentOutput",
        "recordAgentOutput",
        "recordAgentReview",
        "startAgentRun",
        "transitionServiceRequest",
      ],
  );
  assert.equal(
      Object.values(bundle).every((value) => typeof value === "function"),
      true,
  );
});

test("handler factory rejects an incomplete service bundle", () => {
  assert.throws(
      () => createProfessionalServicesCallableHandlers({services: {}}),
      /createServiceRequest service must be a function/,
  );
});

test("missing authentication is rejected before service execution", async () => {
  const harness = createServices();
  const callableHandlers = handlers(harness);
  await assert.rejects(
      () => callableHandlers.createServiceRequest({
        app: {appId: "verified-app"},
        data: {},
      }),
      (error) => error instanceof HttpsError &&
        error.code === "unauthenticated",
  );
  assert.equal(harness.calls.createRequest.length, 0);
});

test("missing App Check is rejected before service execution", async () => {
  const harness = createServices();
  const callableHandlers = handlers(harness);
  await assert.rejects(
      () => callableHandlers.createServiceRequest({
        auth: {uid: "authenticated-user"},
        data: {},
      }),
      (error) => error instanceof HttpsError &&
        error.code === "failed-precondition",
  );
  assert.equal(harness.calls.createRequest.length, 0);
});

test("service request handler injects actor and requestedByUid", async () => {
  const harness = createServices();
  await handlers(harness).createServiceRequest(request({
    requestId: "request-1",
    serviceRequest: {title: "Request"},
  }));
  assert.deepEqual(harness.calls.createRequest[0], {
    requestId: "request-1",
    actorUid: "authenticated-user",
    serviceRequest: {
      title: "Request",
      requestedByUid: "authenticated-user",
    },
  });
});

test("engagement handler injects actor and createdByUid", async () => {
  const harness = createServices();
  await handlers(harness).createServiceEngagement(request({
    serviceEngagement: {serviceRequestId: "psr-1"},
  }));
  assert.deepEqual(harness.calls.createEngagement[0], {
    actorUid: "authenticated-user",
    serviceEngagement: {
      serviceRequestId: "psr-1",
      createdByUid: "authenticated-user",
    },
  });
});

test("assignment handler injects actor and assignedByUid", async () => {
  const harness = createServices();
  await handlers(harness).createServiceAssignment(request({
    serviceAssignment: {providerId: "provider-1"},
  }));
  assert.deepEqual(harness.calls.createAssignment[0], {
    actorUid: "authenticated-user",
    serviceAssignment: {
      providerId: "provider-1",
      assignedByUid: "authenticated-user",
    },
  });
});

test("agent run handler injects initiator and preserves supervisor", async () => {
  const harness = createServices();
  await handlers(harness).startAgentRun(request({
    agentRunRequest: {
      agentCode: "legal_intake_triage",
      supervisingUid: "supervisor-1",
    },
  }));
  assert.deepEqual(harness.calls.startRun[0], {
    actorUid: "authenticated-user",
    agentRunRequest: {
      agentCode: "legal_intake_triage",
      supervisingUid: "supervisor-1",
      initiatedByUid: "authenticated-user",
    },
  });
});

test("review handler injects actor and reviewedByUid", async () => {
  const harness = createServices();
  await handlers(harness).recordAgentReview(request({
    agentHumanReview: {decision: "approved"},
  }));
  assert.deepEqual(harness.calls.recordReview[0], {
    actorUid: "authenticated-user",
    agentHumanReview: {
      decision: "approved",
      reviewedByUid: "authenticated-user",
    },
  });
});

test("transition output and publication handlers inject top-level actor", async () => {
  const harness = createServices();
  const callableHandlers = handlers(harness);
  await callableHandlers.transitionServiceRequest(
      request({serviceRequestId: "psr-1"}),
  );
  await callableHandlers.recordAgentOutput(
      request({agentTaskId: "pat-1"}),
  );
  await callableHandlers.publishAgentOutput(
      request({outputDraftId: "pout-1"}),
  );
  assert.equal(
      harness.calls.transitionRequest[0].actorUid,
      "authenticated-user",
  );
  assert.equal(
      harness.calls.recordOutput[0].actorUid,
      "authenticated-user",
  );
  assert.equal(
      harness.calls.publishOutput[0].actorUid,
      "authenticated-user",
  );
});

test("client top-level actor identity is rejected", async () => {
  const harness = createServices();
  await assert.rejects(
      () => handlers(harness).transitionServiceRequest(request({
        actorUid: "spoofed-user",
      })),
      (error) => error instanceof HttpsError &&
        error.code === "invalid-argument",
  );
  assert.equal(harness.calls.transitionRequest.length, 0);
});

test("client nested actor identity is rejected", async () => {
  const harness = createServices();
  await assert.rejects(
      () => handlers(harness).createServiceRequest(request({
        serviceRequest: {requestedByUid: "spoofed-user"},
      })),
      (error) => error instanceof HttpsError &&
        error.code === "invalid-argument" &&
        error.details.unsupported.includes(
            "$.serviceRequest.requestedByUid",
        ),
  );
  assert.equal(harness.calls.createRequest.length, 0);
});

test("recursive actor scan reports paths without identity values", () => {
  const hits = collectClientActorFields({
    actorUid: "secret-1",
    nested: [{reviewedByUid: "secret-2"}],
  });
  assert.deepEqual(hits, [
    "$.actorUid",
    "$.nested[0].reviewedByUid",
  ]);
  assert.equal(JSON.stringify(hits).includes("secret-1"), false);
  assert.equal(JSON.stringify(hits).includes("secret-2"), false);
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
    const source = new ProfessionalServicesContractError(
        code,
        `message-${code}`,
    );
    source.details = {code};
    const mapped = mapProfessionalServicesError(source);
    assert.equal(mapped instanceof HttpsError, true);
    assert.equal(mapped.code, code);
    assert.equal(mapped.message, `message-${code}`);
    assert.deepEqual(mapped.details, {code});
  }
});

test("canonical failures map to invalid-argument", () => {
  const mapped = mapProfessionalServicesError(
      new ProfessionalServicesCanonicalError(
          "canonical.invalid",
          "canonical payload invalid",
      ),
  );
  assert.equal(mapped instanceof HttpsError, true);
  assert.equal(mapped.code, "invalid-argument");
  assert.equal(mapped.message, "canonical payload invalid");
});

test("identifier and lifecycle failures preserve supported codes", () => {
  const identifier = mapProfessionalServicesError(
      new ProfessionalServicesIdentifierError(
          "invalid-argument",
          "identifier invalid",
      ),
  );
  const lifecycle = mapProfessionalServicesError(
      new ProfessionalServicesLifecycleError(
          "failed-precondition",
          "transition denied",
      ),
  );
  assert.equal(identifier.code, "invalid-argument");
  assert.equal(lifecycle.code, "failed-precondition");
});

test("unknown errors map to generic internal HttpsError", () => {
  const mapped = mapProfessionalServicesError(
      new Error("sensitive implementation detail"),
  );
  assert.equal(mapped instanceof HttpsError, true);
  assert.equal(mapped.code, "internal");
  assert.equal(
      mapped.message,
      "Profesyonel Hizmetler işlemi tamamlanamadı.",
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
  assert.equal(mapProfessionalServicesError(source), source);
});

test("logging records outcomes without uid or raw command payload", async () => {
  const log = createLog();
  const harness = createServices({
    async transitionServiceRequest() {
      throw new ProfessionalServicesContractError(
          "permission-denied",
          "not allowed",
      );
    },
  });
  const callableHandlers = handlers(harness, log);
  await callableHandlers.createServiceRequest(request({
    requestId: "sensitive-request-id",
    serviceRequest: {title: "Sensitive title"},
  }));
  await assert.rejects(
      () => callableHandlers.transitionServiceRequest(
          request({serviceRequestId: "sensitive-service-id"}),
      ),
      (error) => error.code === "permission-denied",
  );
  assert.equal(log.records.length, 2);
  assert.equal(log.records[0].outcome, "completed");
  assert.equal(log.records[1].outcome, "failed");
  const serialized = JSON.stringify(log.records);
  assert.equal(serialized.includes("authenticated-user"), false);
  assert.equal(serialized.includes("sensitive-request-id"), false);
  assert.equal(serialized.includes("Sensitive title"), false);
  assert.equal(serialized.includes("sensitive-service-id"), false);
});

test("standalone guards enforce request and nested actor rules", () => {
  assert.equal(assertCallableRequest(request()), "authenticated-user");
  assert.deepEqual(
      injectAuthenticatedActor(
          {serviceRequest: {title: "Request"}},
          ["serviceRequest", "requestedByUid"],
          "authenticated-user",
      ),
      {
        actorUid: "authenticated-user",
        serviceRequest: {
          title: "Request",
          requestedByUid: "authenticated-user",
        },
      },
  );
  assert.throws(
      () => injectAuthenticatedActor(
          {agentHumanReview: {reviewedByUid: "spoofed"}},
          ["agentHumanReview", "reviewedByUid"],
          "authenticated-user",
      ),
      (error) => error instanceof HttpsError &&
        error.code === "invalid-argument",
  );
});

test("handler maps service errors and does not return partial output", async () => {
  const harness = createServices({
    async publishAgentOutput() {
      throw new ProfessionalServicesLifecycleError(
          "failed-precondition",
          "publication transition denied",
      );
    },
  });
  await assert.rejects(
      () => handlers(harness).publishAgentOutput(
          request({outputDraftId: "pout-1"}),
      ),
      (error) => error instanceof HttpsError &&
        error.code === "failed-precondition" &&
        error.message === "publication transition denied",
  );
  assert.equal(harness.calls.publishOutput.length, 0);
});
