/* eslint-disable max-len */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  CLIENT_AUTHORIZATION_CONTRACT_VERSION,
  CONFLICT_CHECK_CONTRACT_VERSION,
  SERVICE_ASSIGNMENT_CONTRACT_VERSION,
  SERVICE_ENGAGEMENT_CONTRACT_VERSION,
  SERVICE_PROVIDER_CONTRACT_VERSION,
  SERVICE_REQUEST_CONTRACT_VERSION,
  ProfessionalServicesContractError,
} = require("./contracts");
const {
  AGENT_HUMAN_REVIEW_CONTRACT_VERSION,
  AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
  AGENT_RUN_REQUEST_CONTRACT_VERSION,
} = require("./agent_contracts");
const {
  canonicalDigestSha256,
} = require("./canonical");
const {
  buildAgentHumanReviewId,
  buildAgentOutputDraftId,
  buildAgentTaskId,
  buildServiceAssignmentId,
  buildServiceEngagementId,
  buildServiceRequestId,
} = require("./identifiers");
const {
  AGENT_OUTPUT_PUBLISH_COMMAND_VERSION,
  AGENT_OUTPUT_RECORD_COMMAND_VERSION,
  AGENT_REVIEW_RECORD_COMMAND_VERSION,
  AGENT_RUN_START_COMMAND_VERSION,
  SERVICE_ASSIGNMENT_CREATE_COMMAND_VERSION,
  SERVICE_ENGAGEMENT_CREATE_COMMAND_VERSION,
  SERVICE_REQUEST_CREATE_COMMAND_VERSION,
  SERVICE_REQUEST_TRANSITION_COMMAND_VERSION,
  buildCreateServiceAssignmentService,
  buildCreateServiceEngagementService,
  buildCreateServiceRequestService,
  buildPublishAgentOutputService,
  buildRecordAgentOutputService,
  buildRecordAgentReviewService,
  buildStartAgentRunService,
  buildTransitionServiceRequestService,
  createServiceDependencies,
} = require("./service");

const NOW = "2026-08-02T10:00:00.000Z";
const LATER = "2026-08-03T10:00:00.000Z";
const UUIDS = Object.freeze({
  create: "11111111-1111-4111-8111-111111111111",
  transition: "22222222-2222-4222-8222-222222222222",
  engagement: "33333333-3333-4333-8333-333333333333",
  assignment: "44444444-4444-4444-8444-444444444444",
  agent: "55555555-5555-4555-8555-555555555555",
  output: "66666666-6666-4666-8666-666666666666",
  review: "77777777-7777-4777-8777-777777777777",
  publish: "88888888-8888-4888-8888-888888888888",
});

function receiptKey({scopeType, scopeId, idempotencyKey}) {
  return `${scopeType}|${scopeId}|${idempotencyKey}`;
}

function createFakeStore() {
  const state = {
    receipts: new Map(),
    serviceRequests: new Map(),
    authorizations: new Map(),
    engagements: new Map(),
    providers: new Map(),
    conflictChecks: new Map(),
    assignments: new Map(),
    agentTasks: new Map(),
    agentRuns: new Map(),
    outputs: new Map(),
    reviews: new Map(),
    publications: new Map(),
    events: [],
    sourceScope: {
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      archived: false,
      unresolvedReferences: [],
    },
    authority: {
      authorized: true,
      professionalClass: "legal_professional",
      canPublish: true,
    },
  };
  const store = {
    state,
    async getCommandReceipt(input) {
      return state.receipts.get(receiptKey(input)) || null;
    },
    async resolveSourceScope() {
      return state.sourceScope;
    },
    async resolveProfessionalServiceAuthority() {
      return state.authority;
    },
    async getServiceRequestById({serviceRequestId}) {
      return state.serviceRequests.get(serviceRequestId) || null;
    },
    async createServiceRequestAtomic({serviceRequest, event, receipt}) {
      state.serviceRequests.set(serviceRequest.serviceRequestId,
          serviceRequest);
      state.events.push(event);
      state.receipts.set(receiptKey({
        scopeType: "create_service_request",
        scopeId: serviceRequest.tenantId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {serviceRequest, idempotentReplay: false};
    },
    async transitionServiceRequestAtomic({
      nextServiceRequest,
      event,
      receipt,
    }) {
      state.serviceRequests.set(nextServiceRequest.serviceRequestId,
          nextServiceRequest);
      state.events.push(event);
      state.receipts.set(receiptKey({
        scopeType: "service_request",
        scopeId: nextServiceRequest.serviceRequestId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {serviceRequest: nextServiceRequest, idempotentReplay: false};
    },
    async getClientAuthorizationById({authorizationId}) {
      return state.authorizations.get(authorizationId) || null;
    },
    async getServiceEngagementById({serviceEngagementId}) {
      return state.engagements.get(serviceEngagementId) || null;
    },
    async createServiceEngagementAtomic({
      nextServiceRequest,
      serviceEngagement,
      event,
      receipt,
    }) {
      state.serviceRequests.set(nextServiceRequest.serviceRequestId,
          nextServiceRequest);
      state.engagements.set(serviceEngagement.serviceEngagementId,
          serviceEngagement);
      state.events.push(event);
      state.receipts.set(receiptKey({
        scopeType: "service_engagement",
        scopeId: nextServiceRequest.serviceRequestId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {
        serviceRequest: nextServiceRequest,
        serviceEngagement,
        idempotentReplay: false,
      };
    },
    async getServiceProviderById({providerId}) {
      return state.providers.get(providerId) || null;
    },
    async resolveConflictCheck({serviceRequestId, providerId}) {
      return state.conflictChecks.get(
          `${serviceRequestId}|${providerId}`,
      ) || null;
    },
    async getServiceAssignmentById({serviceAssignmentId}) {
      return state.assignments.get(serviceAssignmentId) || null;
    },
    async createServiceAssignmentAtomic({
      nextServiceRequest,
      serviceAssignment,
      event,
      receipt,
    }) {
      state.serviceRequests.set(nextServiceRequest.serviceRequestId,
          nextServiceRequest);
      state.assignments.set(serviceAssignment.serviceAssignmentId,
          serviceAssignment);
      state.events.push(event);
      state.receipts.set(receiptKey({
        scopeType: "service_assignment",
        scopeId: nextServiceRequest.serviceRequestId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {
        serviceRequest: nextServiceRequest,
        serviceAssignment,
        idempotentReplay: false,
      };
    },
    async getAgentTaskById({agentTaskId}) {
      return state.agentTasks.get(agentTaskId) || null;
    },
    async getAgentRunById({agentRunId}) {
      return state.agentRuns.get(agentRunId) || null;
    },
    async createAgentRunAtomic({
      nextAgentTask,
      agentRun,
      event,
      receipt,
    }) {
      state.agentTasks.set(nextAgentTask.agentTaskId, nextAgentTask);
      state.agentRuns.set(agentRun.agentRunId, agentRun);
      state.events.push(event);
      state.receipts.set(receiptKey({
        scopeType: "agent_run",
        scopeId: agentRun.serviceRequestId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {
        agentTask: nextAgentTask,
        agentRun,
        idempotentReplay: false,
      };
    },
    async getAgentOutputDraftById({outputDraftId}) {
      return state.outputs.get(outputDraftId) || null;
    },
    async createAgentOutputDraftAtomic({
      nextAgentTask,
      agentOutputDraft,
      event,
      receipt,
    }) {
      state.agentTasks.set(nextAgentTask.agentTaskId, nextAgentTask);
      state.outputs.set(agentOutputDraft.outputDraftId, agentOutputDraft);
      state.events.push(event);
      state.receipts.set(receiptKey({
        scopeType: "agent_output_draft",
        scopeId: agentOutputDraft.agentRunId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {
        agentTask: nextAgentTask,
        agentOutputDraft,
        idempotentReplay: false,
      };
    },
    async getAgentHumanReviewById({humanReviewId}) {
      return state.reviews.get(humanReviewId) || null;
    },
    async recordAgentHumanReviewAtomic({
      nextAgentTask,
      agentHumanReview,
      event,
      receipt,
    }) {
      state.agentTasks.set(nextAgentTask.agentTaskId, nextAgentTask);
      state.reviews.set(agentHumanReview.humanReviewId, agentHumanReview);
      state.events.push(event);
      state.receipts.set(receiptKey({
        scopeType: "agent_human_review",
        scopeId: agentHumanReview.outputDraftId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {
        agentTask: nextAgentTask,
        agentHumanReview,
        idempotentReplay: false,
      };
    },
    async publishAgentOutputAtomic({
      nextAgentTask,
      publication,
      event,
      receipt,
    }) {
      state.agentTasks.set(nextAgentTask.agentTaskId, nextAgentTask);
      state.publications.set(publication.publicationId, publication);
      state.events.push(event);
      state.receipts.set(receiptKey({
        scopeType: "agent_output_publication",
        scopeId: publication.outputDraftId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {
        agentTask: nextAgentTask,
        publication,
        idempotentReplay: false,
      };
    },
  };
  return store;
}

function requestInput(overrides = {}) {
  return {
    contractVersion: SERVICE_REQUEST_CONTRACT_VERSION,
    requestId: UUIDS.create,
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    serviceCode: "legal_preliminary_assessment",
    priority: "high",
    jurisdictionCode: "tr",
    sourceReferences: {caseId: "case-1"},
    title: "Sahtecilik hukuki ön değerlendirmesi",
    objective: "Vaka delillerinin hukuki müdahale seçeneklerini belirlemek.",
    scope: {
      summary: "Vaka ve deliller için kontrollü hukuki ön değerlendirme.",
      inclusions: ["Delil zaman çizelgesi", "Yetki alanı değerlendirmesi"],
      exclusions: ["Mahkemeye otomatik başvuru"],
    },
    requestedByUid: "user-1",
    requestedAt: NOW,
    ...overrides,
  };
}

function createRequestCommand(overrides = {}) {
  const serviceRequest = requestInput(overrides.serviceRequest);
  return {
    contractVersion: SERVICE_REQUEST_CREATE_COMMAND_VERSION,
    requestId: serviceRequest.requestId,
    idempotencyKey: "idem-create",
    actorUid: serviceRequest.requestedByUid,
    serviceRequest,
    ...overrides,
  };
}

function persistedRequest(status = "requested", version = 1,
    overrides = {}) {
  const input = requestInput();
  return {
    ...input,
    serviceRequestId: buildServiceRequestId({
      tenantId: input.tenantId,
      requestId: input.requestId,
    }),
    serviceFamily: "legal",
    status,
    version,
    createdAt: NOW,
    createdByUid: "user-1",
    updatedAt: NOW,
    updatedByUid: "user-1",
    eventCount: version,
    ...overrides,
  };
}

function serviceScopeAuthorization(request, overrides = {}) {
  return {
    authorizationId: "auth-scope-1",
    contractVersion: CLIENT_AUTHORIZATION_CONTRACT_VERSION,
    serviceRequestId: request.serviceRequestId,
    authorizationType: "service_scope",
    decision: "granted",
    scopeFingerprintSha256: canonicalDigestSha256(request.scope),
    amountMinorUnits: null,
    currencyCode: null,
    decidedByUid: "owner-1",
    decisionNote: "Hizmet kapsamı onaylandı.",
    decidedAt: NOW,
    ...overrides,
  };
}

function budgetAuthorization(request, overrides = {}) {
  return {
    authorizationId: "auth-budget-1",
    contractVersion: CLIENT_AUTHORIZATION_CONTRACT_VERSION,
    serviceRequestId: request.serviceRequestId,
    authorizationType: "budget",
    decision: "granted",
    scopeFingerprintSha256: canonicalDigestSha256(request.scope),
    amountMinorUnits: 500000,
    currencyCode: "TRY",
    decidedByUid: "owner-1",
    decisionNote: "Bütçe onaylandı.",
    decidedAt: NOW,
    ...overrides,
  };
}

function engagementInput(request, overrides = {}) {
  return {
    contractVersion: SERVICE_ENGAGEMENT_CONTRACT_VERSION,
    serviceRequestId: request.serviceRequestId,
    engagementMode: "single_service",
    scopeFingerprintSha256: canonicalDigestSha256(request.scope),
    clientAuthorizationId: "auth-scope-1",
    budgetAuthorizationId: "auth-budget-1",
    createdByUid: "user-1",
    createdAt: NOW,
    ...overrides,
  };
}

function providerRecord(overrides = {}) {
  return {
    contractVersion: SERVICE_PROVIDER_CONTRACT_VERSION,
    providerId: "provider-1",
    providerType: "lawyer",
    displayName: "Yetkili Marka Avukatı",
    organizationName: "Örnek Hukuk",
    status: "active",
    expertiseCodes: ["legal_preliminary_assessment"],
    jurisdictionCodes: ["tr"],
    languageCodes: ["tr"],
    qualifications: [{
      qualificationCode: "bar_registration",
      issuingAuthority: "İstanbul Barosu",
      jurisdictionCode: "tr",
      credentialReference: "BAR-1001",
      validFrom: "2025-01-01T00:00:00.000Z",
      validUntil: "2027-01-01T00:00:00.000Z",
      status: "verified_active",
    }],
    professionalInsuranceStatus: "verified_active",
    conflictCheckRequired: true,
    verifiedAt: NOW,
    verifiedByUid: "admin-1",
    ...overrides,
  };
}

function assignmentInput(request, engagementId, overrides = {}) {
  return {
    contractVersion: SERVICE_ASSIGNMENT_CONTRACT_VERSION,
    serviceRequestId: request.serviceRequestId,
    serviceEngagementId: engagementId,
    providerId: "provider-1",
    assignmentMode: "agent_assisted_human",
    assignedByUid: "user-1",
    supervisingUid: "lawyer-1",
    jurisdictionCode: "tr",
    scope: request.scope,
    billingModel: "fixed_fee",
    currencyCode: "TRY",
    estimatedAmountMinorUnits: 250000,
    slaFirstResponseMinutes: 240,
    slaCompletionMinutes: 2880,
    dueAt: LATER,
    assignedAt: NOW,
    ...overrides,
  };
}

function agentRunRequest(request, assignmentId = null, overrides = {}) {
  return {
    contractVersion: AGENT_RUN_REQUEST_CONTRACT_VERSION,
    requestId: UUIDS.agent,
    serviceRequestId: request.serviceRequestId,
    serviceAssignmentId: assignmentId,
    agentCode: assignmentId ?
      "legal_document_drafter" :
      "legal_intake_triage",
    agentVersion: "v1",
    modelProvider: "openai",
    modelName: "reasoning-model",
    modelVersion: "2026-08",
    promptTemplateVersion: "v1",
    initiatedByUid: "user-1",
    supervisingUid: assignmentId ? "lawyer-1" : "user-1",
    sourceReferences: {caseId: "case-1"},
    inputManifestHashSha256: "a".repeat(64),
    confidentialityClass: assignmentId ?
      "legal_privilege_asserted" :
      "client_confidential",
    privilegeClaimStatus: assignmentId ?
      "lawyer_confirmed" :
      "none",
    startedAt: NOW,
    ...overrides,
  };
}

function outputInput(agentRunId, outputType, overrides = {}) {
  return {
    contractVersion: AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
    agentRunId,
    outputType,
    outputHashSha256: "b".repeat(64),
    outputBytes: 1200,
    sourceReferenceCount: 1,
    confidenceLevel: "high",
    warningCodes: [],
    generatedAt: NOW,
    ...overrides,
  };
}

function reviewInput(agentRunId, outputDraftId, decision = "approved",
    overrides = {}) {
  return {
    contractVersion: AGENT_HUMAN_REVIEW_CONTRACT_VERSION,
    agentRunId,
    outputDraftId,
    expectedDraftHashSha256: "b".repeat(64),
    decision,
    reviewedByUid: "reviewer-1",
    reviewNote: "Kaynak bağlantıları ve içerik insan tarafından incelendi.",
    reviewedAt: NOW,
    ...overrides,
  };
}

function services(store) {
  const dependencies = {store, clock: () => NOW};
  return {
    createRequest: buildCreateServiceRequestService(dependencies),
    transitionRequest: buildTransitionServiceRequestService(dependencies),
    createEngagement: buildCreateServiceEngagementService(dependencies),
    createAssignment: buildCreateServiceAssignmentService(dependencies),
    startAgentRun: buildStartAgentRunService(dependencies),
    recordOutput: buildRecordAgentOutputService(dependencies),
    recordReview: buildRecordAgentReviewService(dependencies),
    publishOutput: buildPublishAgentOutputService(dependencies),
  };
}

async function seedReadyForAssignment(store) {
  const request = persistedRequest("scoping", 2);
  store.state.serviceRequests.set(request.serviceRequestId, request);
  const scopeAuth = serviceScopeAuthorization(request);
  const budgetAuth = budgetAuthorization(request);
  store.state.authorizations.set(scopeAuth.authorizationId, scopeAuth);
  store.state.authorizations.set(budgetAuth.authorizationId, budgetAuth);
  const result = await services(store).createEngagement({
    contractVersion: SERVICE_ENGAGEMENT_CREATE_COMMAND_VERSION,
    requestId: UUIDS.engagement,
    idempotencyKey: "idem-engagement",
    actorUid: "user-1",
    expectedServiceRequestVersion: 2,
    serviceEngagement: engagementInput(request),
  });
  return result.serviceRequest;
}

async function seedAssignedAgentWork(store) {
  const ready = await seedReadyForAssignment(store);
  const provider = providerRecord();
  store.state.providers.set(provider.providerId, provider);
  store.state.conflictChecks.set(
      `${ready.serviceRequestId}|${provider.providerId}`,
      {
        contractVersion: CONFLICT_CHECK_CONTRACT_VERSION,
        serviceRequestId: ready.serviceRequestId,
        providerId: provider.providerId,
        outcome: "cleared",
      },
  );
  const engagementId = buildServiceEngagementId({
    serviceRequestId: ready.serviceRequestId,
  });
  const result = await services(store).createAssignment({
    contractVersion: SERVICE_ASSIGNMENT_CREATE_COMMAND_VERSION,
    requestId: UUIDS.assignment,
    idempotencyKey: "idem-assignment",
    actorUid: "user-1",
    expectedServiceRequestVersion: ready.version,
    assignmentSequence: 1,
    serviceAssignment: assignmentInput(ready, engagementId),
  });
  return result;
}

async function seedAgentOutput(store, legal = true) {
  let request;
  let assignmentId = null;
  if (legal) {
    const assigned = await seedAssignedAgentWork(store);
    request = assigned.serviceRequest;
    assignmentId = assigned.serviceAssignment.serviceAssignmentId;
  } else {
    request = persistedRequest("scoping", 2);
    store.state.serviceRequests.set(request.serviceRequestId, request);
  }
  const runRequest = agentRunRequest(request, assignmentId);
  const runResult = await services(store).startAgentRun({
    contractVersion: AGENT_RUN_START_COMMAND_VERSION,
    requestId: runRequest.requestId,
    idempotencyKey: "idem-agent-run",
    actorUid: runRequest.initiatedByUid,
    expectedAgentTaskVersion: null,
    runSequence: 1,
    agentRunRequest: runRequest,
  });
  const output = outputInput(
      runResult.agentRun.agentRunId,
      legal ? "legal_document_draft" : "legal_intake_summary",
  );
  const outputResult = await services(store).recordOutput({
    contractVersion: AGENT_OUTPUT_RECORD_COMMAND_VERSION,
    requestId: UUIDS.output,
    idempotencyKey: "idem-agent-output",
    actorUid: runRequest.supervisingUid,
    agentTaskId: runResult.agentTask.agentTaskId,
    expectedAgentTaskVersion: runResult.agentTask.version,
    agentOutputDraft: output,
  });
  return {request, runResult, outputResult};
}

test("service dependencies require the complete storage port", () => {
  assert.throws(
      () => createServiceDependencies({
        store: {getCommandReceipt() {}},
        clock: () => NOW,
      }),
      (error) => error instanceof ProfessionalServicesContractError &&
        error.code === "failed-precondition",
  );
});

test("create service request writes immutable actor-attributed bundle", async () => {
  const store = createFakeStore();
  const result = await services(store).createRequest(createRequestCommand());
  assert.equal(result.idempotentReplay, false);
  assert.equal(result.serviceRequest.status, "requested");
  assert.equal(result.serviceRequest.version, 1);
  assert.equal(result.serviceRequest.createdByUid, "user-1");
  assert.equal(result.serviceRequest.updatedByUid, "user-1");
  assert.equal(store.state.events[0].actorUid, "user-1");
  assert.equal(store.state.events[0].appendOnly, true);
});

test("create service request rejects unresolved canonical sources", async () => {
  const store = createFakeStore();
  store.state.sourceScope = {
    ...store.state.sourceScope,
    unresolvedReferences: ["caseId"],
  };
  await assert.rejects(
      () => services(store).createRequest(createRequestCommand()),
      (error) => error.code === "not-found",
  );
  assert.equal(store.state.serviceRequests.size, 0);
});

test("create service request rejects unauthorized actor", async () => {
  const store = createFakeStore();
  store.state.authority = {authorized: false};
  await assert.rejects(
      () => services(store).createRequest(createRequestCommand()),
      (error) => error.code === "permission-denied",
  );
});

test("create service request is idempotent and detects key conflict", async () => {
  const store = createFakeStore();
  const command = createRequestCommand();
  const first = await services(store).createRequest(command);
  const replay = await services(store).createRequest(command);
  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.resultId, first.resultId);
  await assert.rejects(
      () => services(store).createRequest({
        ...command,
        serviceRequest: {
          ...command.serviceRequest,
          title: "Farklı kapsamlı hukuki değerlendirme talebi",
        },
      }),
      (error) => error.code === "already-exists",
  );
});

test("service transition increments version and actor attribution", async () => {
  const store = createFakeStore();
  const request = persistedRequest("requested", 1);
  store.state.serviceRequests.set(request.serviceRequestId, request);
  const result = await services(store).transitionRequest({
    contractVersion: SERVICE_REQUEST_TRANSITION_COMMAND_VERSION,
    requestId: UUIDS.transition,
    idempotencyKey: "idem-transition",
    actorUid: "user-1",
    serviceRequestId: request.serviceRequestId,
    expectedVersion: 1,
    nextStatus: "scoping",
    reasonCode: "scope_review_started",
    note: "Hizmet kapsamı incelemeye alındı.",
  });
  assert.equal(result.serviceRequest.status, "scoping");
  assert.equal(result.serviceRequest.version, 2);
  assert.equal(result.serviceRequest.statusChangedByUid, "user-1");
});

test("generic transition cannot bypass engagement or assignment gates", async () => {
  const store = createFakeStore();
  const request = persistedRequest("scoping", 2);
  store.state.serviceRequests.set(request.serviceRequestId, request);
  await assert.rejects(
      () => services(store).transitionRequest({
        contractVersion: SERVICE_REQUEST_TRANSITION_COMMAND_VERSION,
        requestId: UUIDS.transition,
        idempotencyKey: "idem-transition",
        actorUid: "user-1",
        serviceRequestId: request.serviceRequestId,
        expectedVersion: 2,
        nextStatus: "ready_for_assignment",
        reasonCode: "bypass",
        note: "Bu geçiş engellenmelidir.",
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("service transition rejects optimistic concurrency conflict", async () => {
  const store = createFakeStore();
  const request = persistedRequest("requested", 2);
  store.state.serviceRequests.set(request.serviceRequestId, request);
  await assert.rejects(
      () => services(store).transitionRequest({
        contractVersion: SERVICE_REQUEST_TRANSITION_COMMAND_VERSION,
        requestId: UUIDS.transition,
        idempotencyKey: "idem-transition",
        actorUid: "user-1",
        serviceRequestId: request.serviceRequestId,
        expectedVersion: 1,
        nextStatus: "scoping",
        reasonCode: "stale",
        note: "Eski sürüm.",
      }),
      (error) => error.code === "aborted",
  );
});

test("engagement validates scope and client authorizations", async () => {
  const store = createFakeStore();
  const ready = await seedReadyForAssignment(store);
  assert.equal(ready.status, "ready_for_assignment");
  assert.equal(ready.version, 3);
  assert.equal(store.state.engagements.size, 1);
});

test("engagement rejects denied client authorization", async () => {
  const store = createFakeStore();
  const request = persistedRequest("scoping", 2);
  store.state.serviceRequests.set(request.serviceRequestId, request);
  const denied = serviceScopeAuthorization(request, {decision: "denied"});
  store.state.authorizations.set(denied.authorizationId, denied);
  const budget = budgetAuthorization(request);
  store.state.authorizations.set(budget.authorizationId, budget);
  await assert.rejects(
      () => services(store).createEngagement({
        contractVersion: SERVICE_ENGAGEMENT_CREATE_COMMAND_VERSION,
        requestId: UUIDS.engagement,
        idempotencyKey: "idem-engagement",
        actorUid: "user-1",
        expectedServiceRequestVersion: 2,
        serviceEngagement: engagementInput(request),
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("assignment validates provider, conflict and budget gates", async () => {
  const store = createFakeStore();
  const result = await seedAssignedAgentWork(store);
  assert.equal(result.serviceRequest.status, "assigned");
  assert.equal(result.serviceAssignment.status, "assigned");
  assert.equal(result.serviceAssignment.assignmentMode,
      "agent_assisted_human");
  assert.equal(store.state.assignments.size, 1);
});

test("assignment rejects inactive provider", async () => {
  const store = createFakeStore();
  const ready = await seedReadyForAssignment(store);
  const provider = providerRecord({status: "suspended"});
  store.state.providers.set(provider.providerId, provider);
  store.state.conflictChecks.set(
      `${ready.serviceRequestId}|${provider.providerId}`,
      {
        serviceRequestId: ready.serviceRequestId,
        providerId: provider.providerId,
        outcome: "cleared",
      },
  );
  const engagementId = buildServiceEngagementId({
    serviceRequestId: ready.serviceRequestId,
  });
  await assert.rejects(
      () => services(store).createAssignment({
        contractVersion: SERVICE_ASSIGNMENT_CREATE_COMMAND_VERSION,
        requestId: UUIDS.assignment,
        idempotencyKey: "idem-assignment",
        actorUid: "user-1",
        expectedServiceRequestVersion: ready.version,
        assignmentSequence: 1,
        serviceAssignment: assignmentInput(ready, engagementId),
      }),
      (error) => error.code === "failed-precondition",
  );
});


test("assignment rejects an expired provider qualification", async () => {
  const store = createFakeStore();
  const ready = await seedReadyForAssignment(store);
  const provider = providerRecord({
    qualifications: [{
      qualificationCode: "bar_registration",
      issuingAuthority: "İstanbul Barosu",
      jurisdictionCode: "tr",
      credentialReference: "BAR-1001",
      validFrom: "2024-01-01T00:00:00.000Z",
      validUntil: "2025-01-01T00:00:00.000Z",
      status: "verified_active",
    }],
  });
  store.state.providers.set(provider.providerId, provider);
  store.state.conflictChecks.set(
      `${ready.serviceRequestId}|${provider.providerId}`,
      {
        serviceRequestId: ready.serviceRequestId,
        providerId: provider.providerId,
        outcome: "cleared",
      },
  );
  const engagementId = buildServiceEngagementId({
    serviceRequestId: ready.serviceRequestId,
  });
  await assert.rejects(
      () => services(store).createAssignment({
        contractVersion: SERVICE_ASSIGNMENT_CREATE_COMMAND_VERSION,
        requestId: UUIDS.assignment,
        idempotencyKey: "idem-assignment",
        actorUid: "user-1",
        expectedServiceRequestVersion: ready.version,
        assignmentSequence: 1,
        serviceAssignment: assignmentInput(ready, engagementId),
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("assignment rejects uncleared conflict", async () => {
  const store = createFakeStore();
  const ready = await seedReadyForAssignment(store);
  const provider = providerRecord();
  store.state.providers.set(provider.providerId, provider);
  store.state.conflictChecks.set(
      `${ready.serviceRequestId}|${provider.providerId}`,
      {
        serviceRequestId: ready.serviceRequestId,
        providerId: provider.providerId,
        outcome: "conflict_confirmed",
      },
  );
  const engagementId = buildServiceEngagementId({
    serviceRequestId: ready.serviceRequestId,
  });
  await assert.rejects(
      () => services(store).createAssignment({
        contractVersion: SERVICE_ASSIGNMENT_CREATE_COMMAND_VERSION,
        requestId: UUIDS.assignment,
        idempotencyKey: "idem-assignment",
        actorUid: "user-1",
        expectedServiceRequestVersion: ready.version,
        assignmentSequence: 1,
        serviceAssignment: assignmentInput(ready, engagementId),
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("assignment rejects insufficient budget authorization", async () => {
  const store = createFakeStore();
  const ready = await seedReadyForAssignment(store);
  const provider = providerRecord();
  store.state.providers.set(provider.providerId, provider);
  store.state.conflictChecks.set(
      `${ready.serviceRequestId}|${provider.providerId}`,
      {
        serviceRequestId: ready.serviceRequestId,
        providerId: provider.providerId,
        outcome: "cleared",
      },
  );
  const budget = budgetAuthorization(ready, {amountMinorUnits: 100});
  store.state.authorizations.set(budget.authorizationId, budget);
  const engagementId = buildServiceEngagementId({
    serviceRequestId: ready.serviceRequestId,
  });
  await assert.rejects(
      () => services(store).createAssignment({
        contractVersion: SERVICE_ASSIGNMENT_CREATE_COMMAND_VERSION,
        requestId: UUIDS.assignment,
        idempotencyKey: "idem-assignment",
        actorUid: "user-1",
        expectedServiceRequestVersion: ready.version,
        assignmentSequence: 1,
        serviceAssignment: assignmentInput(ready, engagementId),
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("pre-assignment intake agent can start under human supervision", async () => {
  const store = createFakeStore();
  const request = persistedRequest("scoping", 2);
  store.state.serviceRequests.set(request.serviceRequestId, request);
  const runRequest = agentRunRequest(request);
  const result = await services(store).startAgentRun({
    contractVersion: AGENT_RUN_START_COMMAND_VERSION,
    requestId: runRequest.requestId,
    idempotencyKey: "idem-agent-run",
    actorUid: "user-1",
    expectedAgentTaskVersion: null,
    runSequence: 1,
    agentRunRequest: runRequest,
  });
  assert.equal(result.agentTask.status, "running");
  assert.equal(result.agentRun.executedByAgentId,
      "legal_intake_triage@v1");
  assert.equal(result.agentRun.supervisingUid, "user-1");
});

test("non-intake agent requires an agent-assisted assignment", async () => {
  const store = createFakeStore();
  const request = persistedRequest("scoping", 2);
  store.state.serviceRequests.set(request.serviceRequestId, request);
  const runRequest = agentRunRequest(request, null, {
    agentCode: "legal_document_drafter",
    supervisingUid: "lawyer-1",
    confidentialityClass: "legal_privilege_asserted",
    privilegeClaimStatus: "lawyer_confirmed",
  });
  await assert.rejects(
      () => services(store).startAgentRun({
        contractVersion: AGENT_RUN_START_COMMAND_VERSION,
        requestId: runRequest.requestId,
        idempotencyKey: "idem-agent-run",
        actorUid: "user-1",
        expectedAgentTaskVersion: null,
        runSequence: 1,
        agentRunRequest: runRequest,
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("assigned legal drafting agent preserves human and model provenance", async () => {
  const store = createFakeStore();
  const assigned = await seedAssignedAgentWork(store);
  const runRequest = agentRunRequest(
      assigned.serviceRequest,
      assigned.serviceAssignment.serviceAssignmentId,
  );
  const result = await services(store).startAgentRun({
    contractVersion: AGENT_RUN_START_COMMAND_VERSION,
    requestId: runRequest.requestId,
    idempotencyKey: "idem-agent-run",
    actorUid: "user-1",
    expectedAgentTaskVersion: null,
    runSequence: 1,
    agentRunRequest: runRequest,
  });
  assert.equal(result.agentRun.agentCode, "legal_document_drafter");
  assert.equal(result.agentRun.modelProvider, "openai");
  assert.equal(result.agentRun.supervisingUid, "lawyer-1");
  assert.equal(result.agentRun.immutable, true);
});

test("agent output remains an immutable non-publishable draft", async () => {
  const store = createFakeStore();
  const seeded = await seedAgentOutput(store, false);
  assert.equal(seeded.outputResult.agentTask.status,
      "waiting_human_review");
  assert.equal(seeded.outputResult.agentOutputDraft.publishable, false);
  assert.equal(seeded.outputResult.agentOutputDraft.reviewStatus,
      "pending_human_review");
  assert.equal(seeded.outputResult.agentOutputDraft.immutable, true);
});

test("agent output rejects source manifest count mismatch", async () => {
  const store = createFakeStore();
  const request = persistedRequest("scoping", 2);
  store.state.serviceRequests.set(request.serviceRequestId, request);
  const runRequest = agentRunRequest(request);
  const run = await services(store).startAgentRun({
    contractVersion: AGENT_RUN_START_COMMAND_VERSION,
    requestId: runRequest.requestId,
    idempotencyKey: "idem-agent-run",
    actorUid: "user-1",
    expectedAgentTaskVersion: null,
    runSequence: 1,
    agentRunRequest: runRequest,
  });
  await assert.rejects(
      () => services(store).recordOutput({
        contractVersion: AGENT_OUTPUT_RECORD_COMMAND_VERSION,
        requestId: UUIDS.output,
        idempotencyKey: "idem-agent-output",
        actorUid: "user-1",
        agentTaskId: run.agentTask.agentTaskId,
        expectedAgentTaskVersion: run.agentTask.version,
        agentOutputDraft: outputInput(
            run.agentRun.agentRunId,
            "legal_intake_summary",
            {sourceReferenceCount: 2},
        ),
      }),
      (error) => error.code === "failed-precondition",
  );
});


test("agent output cannot predate its immutable run record", async () => {
  const store = createFakeStore();
  const request = persistedRequest("scoping", 2);
  store.state.serviceRequests.set(request.serviceRequestId, request);
  const runRequest = agentRunRequest(request, null, {
    startedAt: "2026-08-02T11:00:00.000Z",
  });
  const run = await services(store).startAgentRun({
    contractVersion: AGENT_RUN_START_COMMAND_VERSION,
    requestId: runRequest.requestId,
    idempotencyKey: "idem-agent-run",
    actorUid: "user-1",
    expectedAgentTaskVersion: null,
    runSequence: 1,
    agentRunRequest: runRequest,
  });
  await assert.rejects(
      () => services(store).recordOutput({
        contractVersion: AGENT_OUTPUT_RECORD_COMMAND_VERSION,
        requestId: UUIDS.output,
        idempotencyKey: "idem-agent-output",
        actorUid: "user-1",
        agentTaskId: run.agentTask.agentTaskId,
        expectedAgentTaskVersion: run.agentTask.version,
        agentOutputDraft: outputInput(
            run.agentRun.agentRunId,
            "legal_intake_summary",
            {generatedAt: NOW},
        ),
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("authorized legal professional can approve legal agent output", async () => {
  const store = createFakeStore();
  const seeded = await seedAgentOutput(store, true);
  const output = seeded.outputResult.agentOutputDraft;
  const review = reviewInput(output.agentRunId, output.outputDraftId);
  const result = await services(store).recordReview({
    contractVersion: AGENT_REVIEW_RECORD_COMMAND_VERSION,
    requestId: UUIDS.review,
    idempotencyKey: "idem-review",
    actorUid: review.reviewedByUid,
    agentTaskId: seeded.outputResult.agentTask.agentTaskId,
    expectedAgentTaskVersion: seeded.outputResult.agentTask.version,
    agentHumanReview: review,
  });
  assert.equal(result.agentTask.status, "approved");
  assert.equal(result.agentHumanReview.reviewerProfessionalClass,
      "legal_professional");
  assert.equal(result.agentHumanReview.immutable, true);
});


test("human review cannot predate the agent output", async () => {
  const store = createFakeStore();
  const seeded = await seedAgentOutput(store, false);
  const output = seeded.outputResult.agentOutputDraft;
  const review = reviewInput(
      output.agentRunId,
      output.outputDraftId,
      "approved",
      {reviewedAt: "2026-08-02T09:00:00.000Z"},
  );
  await assert.rejects(
      () => services(store).recordReview({
        contractVersion: AGENT_REVIEW_RECORD_COMMAND_VERSION,
        requestId: UUIDS.review,
        idempotencyKey: "idem-review",
        actorUid: review.reviewedByUid,
        agentTaskId: seeded.outputResult.agentTask.agentTaskId,
        expectedAgentTaskVersion: seeded.outputResult.agentTask.version,
        agentHumanReview: review,
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("non-legal reviewer cannot approve privileged legal output", async () => {
  const store = createFakeStore();
  const seeded = await seedAgentOutput(store, true);
  store.state.authority = {
    authorized: true,
    professionalClass: "authorized_human",
    canPublish: true,
  };
  const output = seeded.outputResult.agentOutputDraft;
  const review = reviewInput(output.agentRunId, output.outputDraftId);
  await assert.rejects(
      () => services(store).recordReview({
        contractVersion: AGENT_REVIEW_RECORD_COMMAND_VERSION,
        requestId: UUIDS.review,
        idempotencyKey: "idem-review",
        actorUid: review.reviewedByUid,
        agentTaskId: seeded.outputResult.agentTask.agentTaskId,
        expectedAgentTaskVersion: seeded.outputResult.agentTask.version,
        agentHumanReview: review,
      }),
      (error) => error.code === "permission-denied",
  );
});

test("revision decision returns agent task to controlled rerun state", async () => {
  const store = createFakeStore();
  const seeded = await seedAgentOutput(store, false);
  const output = seeded.outputResult.agentOutputDraft;
  const review = reviewInput(
      output.agentRunId,
      output.outputDraftId,
      "revision_requested",
  );
  const result = await services(store).recordReview({
    contractVersion: AGENT_REVIEW_RECORD_COMMAND_VERSION,
    requestId: UUIDS.review,
    idempotencyKey: "idem-review",
    actorUid: review.reviewedByUid,
    agentTaskId: seeded.outputResult.agentTask.agentTaskId,
    expectedAgentTaskVersion: seeded.outputResult.agentTask.version,
    agentHumanReview: review,
  });
  assert.equal(result.agentTask.status, "revision_requested");
});

test("approved agent output requires separate publication authority", async () => {
  const store = createFakeStore();
  const seeded = await seedAgentOutput(store, true);
  const output = seeded.outputResult.agentOutputDraft;
  const review = reviewInput(output.agentRunId, output.outputDraftId);
  const reviewed = await services(store).recordReview({
    contractVersion: AGENT_REVIEW_RECORD_COMMAND_VERSION,
    requestId: UUIDS.review,
    idempotencyKey: "idem-review",
    actorUid: review.reviewedByUid,
    agentTaskId: seeded.outputResult.agentTask.agentTaskId,
    expectedAgentTaskVersion: seeded.outputResult.agentTask.version,
    agentHumanReview: review,
  });
  store.state.authority = {
    authorized: true,
    professionalClass: "legal_professional",
    canPublish: false,
  };
  await assert.rejects(
      () => services(store).publishOutput({
        contractVersion: AGENT_OUTPUT_PUBLISH_COMMAND_VERSION,
        requestId: UUIDS.publish,
        idempotencyKey: "idem-publish",
        actorUid: "publisher-1",
        agentTaskId: reviewed.agentTask.agentTaskId,
        expectedAgentTaskVersion: reviewed.agentTask.version,
        outputDraftId: output.outputDraftId,
        humanReviewId: reviewed.agentHumanReview.humanReviewId,
        publishedArtifactId: "artifact-1",
        publishedArtifactHashSha256: "c".repeat(64),
        publishedAt: NOW,
      }),
      (error) => error.code === "permission-denied",
  );
});

test("approved reviewed output publishes as immutable artifact reference", async () => {
  const store = createFakeStore();
  const seeded = await seedAgentOutput(store, true);
  const output = seeded.outputResult.agentOutputDraft;
  const review = reviewInput(output.agentRunId, output.outputDraftId);
  const reviewed = await services(store).recordReview({
    contractVersion: AGENT_REVIEW_RECORD_COMMAND_VERSION,
    requestId: UUIDS.review,
    idempotencyKey: "idem-review",
    actorUid: review.reviewedByUid,
    agentTaskId: seeded.outputResult.agentTask.agentTaskId,
    expectedAgentTaskVersion: seeded.outputResult.agentTask.version,
    agentHumanReview: review,
  });
  const result = await services(store).publishOutput({
    contractVersion: AGENT_OUTPUT_PUBLISH_COMMAND_VERSION,
    requestId: UUIDS.publish,
    idempotencyKey: "idem-publish",
    actorUid: "publisher-1",
    agentTaskId: reviewed.agentTask.agentTaskId,
    expectedAgentTaskVersion: reviewed.agentTask.version,
    outputDraftId: output.outputDraftId,
    humanReviewId: reviewed.agentHumanReview.humanReviewId,
    publishedArtifactId: "artifact-1",
    publishedArtifactHashSha256: "c".repeat(64),
    publishedAt: NOW,
  });
  assert.equal(result.agentTask.status, "published");
  assert.equal(result.publication.sourceOutputHashSha256,
      output.outputHashSha256);
  assert.equal(result.publication.publishedByUid, "publisher-1");
  assert.equal(result.publication.immutable, true);
});


test("publication cannot predate the approved human review", async () => {
  const store = createFakeStore();
  const seeded = await seedAgentOutput(store, true);
  const output = seeded.outputResult.agentOutputDraft;
  const review = reviewInput(
      output.agentRunId,
      output.outputDraftId,
      "approved",
      {reviewedAt: "2026-08-02T11:00:00.000Z"},
  );
  const reviewed = await services(store).recordReview({
    contractVersion: AGENT_REVIEW_RECORD_COMMAND_VERSION,
    requestId: UUIDS.review,
    idempotencyKey: "idem-review",
    actorUid: review.reviewedByUid,
    agentTaskId: seeded.outputResult.agentTask.agentTaskId,
    expectedAgentTaskVersion: seeded.outputResult.agentTask.version,
    agentHumanReview: review,
  });
  await assert.rejects(
      () => services(store).publishOutput({
        contractVersion: AGENT_OUTPUT_PUBLISH_COMMAND_VERSION,
        requestId: UUIDS.publish,
        idempotencyKey: "idem-publish",
        actorUid: "publisher-1",
        agentTaskId: reviewed.agentTask.agentTaskId,
        expectedAgentTaskVersion: reviewed.agentTask.version,
        outputDraftId: output.outputDraftId,
        humanReviewId: reviewed.agentHumanReview.humanReviewId,
        publishedArtifactId: "artifact-1",
        publishedArtifactHashSha256: "c".repeat(64),
        publishedAt: NOW,
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("publication rejects a mismatched human review", async () => {
  const store = createFakeStore();
  const seeded = await seedAgentOutput(store, false);
  const output = seeded.outputResult.agentOutputDraft;
  const fakeReviewId = buildAgentHumanReviewId({
    outputDraftId: output.outputDraftId,
    reviewedByUid: "reviewer-1",
    decision: "approved",
  });
  store.state.reviews.set(fakeReviewId, {
    ...reviewInput(output.agentRunId, output.outputDraftId),
    humanReviewId: fakeReviewId,
    expectedDraftHashSha256: "d".repeat(64),
  });
  const task = {
    ...seeded.outputResult.agentTask,
    status: "approved",
    latestHumanReviewId: fakeReviewId,
    version: seeded.outputResult.agentTask.version + 1,
  };
  store.state.agentTasks.set(task.agentTaskId, task);
  await assert.rejects(
      () => services(store).publishOutput({
        contractVersion: AGENT_OUTPUT_PUBLISH_COMMAND_VERSION,
        requestId: UUIDS.publish,
        idempotencyKey: "idem-publish",
        actorUid: "publisher-1",
        agentTaskId: task.agentTaskId,
        expectedAgentTaskVersion: task.version,
        outputDraftId: output.outputDraftId,
        humanReviewId: fakeReviewId,
        publishedArtifactId: "artifact-1",
        publishedArtifactHashSha256: "c".repeat(64),
        publishedAt: NOW,
      }),
      (error) => error.code === "invalid-argument",
  );
});

test("invalid clock is rejected before any service command", () => {
  const store = createFakeStore();
  assert.throws(
      () => buildCreateServiceRequestService({
        store,
        clock: () => "invalid",
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("deterministic assignment and output ids remain causally scoped", () => {
  const request = persistedRequest();
  const assignmentId = buildServiceAssignmentId({
    serviceRequestId: request.serviceRequestId,
    providerId: "provider-1",
    assignmentSequence: 1,
  });
  const taskId = buildAgentTaskId({
    serviceRequestId: request.serviceRequestId,
    agentCode: "legal_intake_triage",
    requestId: UUIDS.agent,
  });
  const outputId = buildAgentOutputDraftId({
    agentRunId: `par_${"a".repeat(64)}`,
    outputHashSha256: "b".repeat(64),
  });
  assert.match(assignmentId, /^psa_[0-9a-f]{64}$/);
  assert.match(taskId, /^pat_[0-9a-f]{64}$/);
  assert.match(outputId, /^pao_[0-9a-f]{64}$/);
});
