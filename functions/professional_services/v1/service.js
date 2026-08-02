/* eslint-disable max-len */
"use strict";

const {
  CLIENT_AUTHORIZATION_CONTRACT_VERSION,
  ProfessionalServicesContractError,
  SERVICE_ASSIGNMENT_CONTRACT_VERSION,
  SERVICE_ENGAGEMENT_CONTRACT_VERSION,
  SERVICE_PROVIDER_CONTRACT_VERSION,
  parseClientAuthorization,
  parseServiceAssignment,
  parseServiceEngagement,
  parseServiceProvider,
  parseServiceRequest,
  requiredCode,
  requiredSha256,
  requiredString,
  requiredUid,
  requiredUuid,
} = require("./contracts");
const {
  AGENT_HUMAN_REVIEW_CONTRACT_VERSION,
  AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
  AGENT_RUN_REQUEST_CONTRACT_VERSION,
  assertAgentOutputPublishable,
  parseAgentHumanReview,
  parseAgentOutputDraft,
  parseAgentRunRequest,
} = require("./agent_contracts");
const {
  canonicalDigestSha256,
  immutableSnapshot,
} = require("./canonical");
const {
  buildAgentHumanReviewId,
  buildAgentOutputDraftId,
  buildAgentRunId,
  buildAgentTaskId,
  buildServiceAssignmentId,
  buildServiceEngagementId,
  buildServiceRequestId,
  fingerprintCommand,
  prefixedId,
} = require("./identifiers");
const {
  assertAgentTaskTransition,
  assertServiceRequestTransition,
  isServiceRequestTerminal,
} = require("./lifecycle");
const {
  assertClock,
  assertReceiptShape,
  assertStoragePort,
} = require("./storage_contracts");

const SERVICE_REQUEST_CREATE_COMMAND_VERSION =
  "professional-service-request-create-command-v1";
const SERVICE_REQUEST_TRANSITION_COMMAND_VERSION =
  "professional-service-request-transition-command-v1";
const SERVICE_ENGAGEMENT_CREATE_COMMAND_VERSION =
  "professional-service-engagement-create-command-v1";
const SERVICE_ASSIGNMENT_CREATE_COMMAND_VERSION =
  "professional-service-assignment-create-command-v1";
const AGENT_RUN_START_COMMAND_VERSION =
  "professional-agent-run-start-command-v1";
const AGENT_OUTPUT_RECORD_COMMAND_VERSION =
  "professional-agent-output-record-command-v1";
const AGENT_REVIEW_RECORD_COMMAND_VERSION =
  "professional-agent-review-record-command-v1";
const AGENT_OUTPUT_PUBLISH_COMMAND_VERSION =
  "professional-agent-output-publish-command-v1";

const PROFESSIONAL_SERVICE_OPERATION_CODES = Object.freeze([
  "create_service_request",
  "transition_service_request",
  "create_service_engagement",
  "create_service_assignment",
  "start_agent_run",
  "supervise_agent_run",
  "record_agent_output",
  "review_agent_output",
  "publish_agent_output",
]);

const LEGAL_REVIEW_OUTPUT_TYPES = Object.freeze([
  "legal_document_draft",
  "compliance_checklist",
  "multilingual_document_draft",
]);

const PRE_ASSIGNMENT_AGENT_CODES = Object.freeze([
  "legal_intake_triage",
  "evidence_timeline_preparer",
]);

const ENGAGEMENT_SOURCE_STATUSES = Object.freeze([
  "scoping",
  "awaiting_client_authorization",
  "awaiting_budget_approval",
]);

const AGENT_SERVICE_STATUSES = Object.freeze([
  "assigned",
  "in_progress",
  "waiting_external",
  "blocked",
  "revision_requested",
]);

const AGENT_PRE_ASSIGNMENT_STATUSES = Object.freeze([
  "requested",
  "scoping",
  "awaiting_client_authorization",
  "awaiting_budget_approval",
  "ready_for_assignment",
]);

const ASSIGNMENT_CONFLICT_OUTCOMES = Object.freeze([
  "cleared",
  "waived",
  "not_required",
]);

function fail(code, message) {
  throw new ProfessionalServicesContractError(code, message);
}

function objectRequired(value, field = "request") {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    fail("invalid-argument", `${field} invalid`);
  }
  return value;
}

function strict(raw, contractVersion, fields) {
  objectRequired(raw);
  const allowed = new Set(["contractVersion", ...fields]);
  if (raw.contractVersion !== contractVersion ||
      Object.keys(raw).some((key) => !allowed.has(key))) {
    fail("invalid-argument", "command contract invalid");
  }
}

function positiveInteger(value, field, maximum = 1000000,
    allowZero = false) {
  const minimum = allowZero ? 0 : 1;
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    fail("invalid-argument", `${field} invalid`);
  }
  return value;
}

function optionalInteger(value, field, maximum = 1000000) {
  if (value === null || value === undefined) {
    return null;
  }
  return positiveInteger(value, field, maximum, true);
}

function optionalString(value, field, maximum = 3000) {
  if (value === null || value === undefined) {
    return null;
  }
  return requiredString(value, field, 1, maximum);
}

function isoInstant(value, field) {
  const clean = requiredString(value, field, 1, 80);
  if (Number.isNaN(Date.parse(clean))) {
    fail("invalid-argument", `${field} invalid`);
  }
  return new Date(clean).toISOString();
}

function parseEnvelope(raw, contractVersion, fields) {
  strict(raw, contractVersion, [
    "requestId",
    "idempotencyKey",
    "actorUid",
    ...fields,
  ]);
  return {
    contractVersion,
    requestId: requiredUuid(raw.requestId, "requestId"),
    idempotencyKey: requiredString(raw.idempotencyKey,
        "idempotencyKey", 1, 256),
    actorUid: requiredUid(raw.actorUid, "actorUid"),
  };
}

function parseCreateServiceRequestCommand(raw) {
  const envelope = parseEnvelope(raw,
      SERVICE_REQUEST_CREATE_COMMAND_VERSION, ["serviceRequest"]);
  const serviceRequest = parseServiceRequest(raw.serviceRequest);
  if (serviceRequest.requestId !== envelope.requestId) {
    fail("invalid-argument", "requestId mismatch");
  }
  if (serviceRequest.requestedByUid !== envelope.actorUid) {
    fail("permission-denied", "requestedByUid must match actorUid");
  }
  return immutableSnapshot({...envelope, serviceRequest});
}

function parseTransitionServiceRequestCommand(raw) {
  const envelope = parseEnvelope(raw,
      SERVICE_REQUEST_TRANSITION_COMMAND_VERSION, [
        "serviceRequestId",
        "expectedVersion",
        "nextStatus",
        "reasonCode",
        "note",
      ]);
  return immutableSnapshot({
    ...envelope,
    serviceRequestId: requiredString(raw.serviceRequestId,
        "serviceRequestId", 1, 128),
    expectedVersion: positiveInteger(raw.expectedVersion,
        "expectedVersion"),
    nextStatus: requiredCode(raw.nextStatus, "nextStatus"),
    reasonCode: requiredCode(raw.reasonCode, "reasonCode"),
    note: optionalString(raw.note, "note", 3000),
  });
}

function parseCreateServiceEngagementCommand(raw) {
  const envelope = parseEnvelope(raw,
      SERVICE_ENGAGEMENT_CREATE_COMMAND_VERSION, [
        "expectedServiceRequestVersion",
        "serviceEngagement",
      ]);
  const serviceEngagement = parseServiceEngagement(raw.serviceEngagement);
  if (serviceEngagement.createdByUid !== envelope.actorUid) {
    fail("permission-denied", "createdByUid must match actorUid");
  }
  return immutableSnapshot({
    ...envelope,
    expectedServiceRequestVersion: positiveInteger(
        raw.expectedServiceRequestVersion,
        "expectedServiceRequestVersion",
    ),
    serviceEngagement,
  });
}

function parseCreateServiceAssignmentCommand(raw) {
  const envelope = parseEnvelope(raw,
      SERVICE_ASSIGNMENT_CREATE_COMMAND_VERSION, [
        "expectedServiceRequestVersion",
        "assignmentSequence",
        "serviceAssignment",
      ]);
  const serviceAssignment = parseServiceAssignment(raw.serviceAssignment);
  if (serviceAssignment.assignedByUid !== envelope.actorUid) {
    fail("permission-denied", "assignedByUid must match actorUid");
  }
  return immutableSnapshot({
    ...envelope,
    expectedServiceRequestVersion: positiveInteger(
        raw.expectedServiceRequestVersion,
        "expectedServiceRequestVersion",
    ),
    assignmentSequence: positiveInteger(raw.assignmentSequence,
        "assignmentSequence"),
    serviceAssignment,
  });
}

function parseStartAgentRunCommand(raw) {
  const envelope = parseEnvelope(raw,
      AGENT_RUN_START_COMMAND_VERSION, [
        "expectedAgentTaskVersion",
        "runSequence",
        "agentRunRequest",
      ]);
  const agentRunRequest = parseAgentRunRequest(raw.agentRunRequest);
  if (agentRunRequest.requestId !== envelope.requestId) {
    fail("invalid-argument", "requestId mismatch");
  }
  if (agentRunRequest.initiatedByUid !== envelope.actorUid) {
    fail("permission-denied", "initiatedByUid must match actorUid");
  }
  return immutableSnapshot({
    ...envelope,
    expectedAgentTaskVersion: optionalInteger(
        raw.expectedAgentTaskVersion,
        "expectedAgentTaskVersion",
    ),
    runSequence: positiveInteger(raw.runSequence, "runSequence"),
    agentRunRequest,
  });
}

function parseRecordAgentOutputCommand(raw) {
  const envelope = parseEnvelope(raw,
      AGENT_OUTPUT_RECORD_COMMAND_VERSION, [
        "agentTaskId",
        "expectedAgentTaskVersion",
        "agentOutputDraft",
      ]);
  return immutableSnapshot({
    ...envelope,
    agentTaskId: requiredString(raw.agentTaskId,
        "agentTaskId", 1, 128),
    expectedAgentTaskVersion: positiveInteger(
        raw.expectedAgentTaskVersion,
        "expectedAgentTaskVersion",
    ),
    agentOutputDraft: parseAgentOutputDraft(raw.agentOutputDraft),
  });
}

function parseRecordAgentReviewCommand(raw) {
  const envelope = parseEnvelope(raw,
      AGENT_REVIEW_RECORD_COMMAND_VERSION, [
        "agentTaskId",
        "expectedAgentTaskVersion",
        "agentHumanReview",
      ]);
  const agentHumanReview = parseAgentHumanReview(raw.agentHumanReview);
  if (agentHumanReview.reviewedByUid !== envelope.actorUid) {
    fail("permission-denied", "reviewedByUid must match actorUid");
  }
  return immutableSnapshot({
    ...envelope,
    agentTaskId: requiredString(raw.agentTaskId,
        "agentTaskId", 1, 128),
    expectedAgentTaskVersion: positiveInteger(
        raw.expectedAgentTaskVersion,
        "expectedAgentTaskVersion",
    ),
    agentHumanReview,
  });
}

function parsePublishAgentOutputCommand(raw) {
  const envelope = parseEnvelope(raw,
      AGENT_OUTPUT_PUBLISH_COMMAND_VERSION, [
        "agentTaskId",
        "expectedAgentTaskVersion",
        "outputDraftId",
        "humanReviewId",
        "publishedArtifactId",
        "publishedArtifactHashSha256",
        "publishedAt",
      ]);
  return immutableSnapshot({
    ...envelope,
    agentTaskId: requiredString(raw.agentTaskId,
        "agentTaskId", 1, 128),
    expectedAgentTaskVersion: positiveInteger(
        raw.expectedAgentTaskVersion,
        "expectedAgentTaskVersion",
    ),
    outputDraftId: requiredString(raw.outputDraftId,
        "outputDraftId", 1, 128),
    humanReviewId: requiredString(raw.humanReviewId,
        "humanReviewId", 1, 128),
    publishedArtifactId: requiredString(raw.publishedArtifactId,
        "publishedArtifactId", 1, 128),
    publishedArtifactHashSha256: requiredSha256(
        raw.publishedArtifactHashSha256,
        "publishedArtifactHashSha256",
    ),
    publishedAt: isoInstant(raw.publishedAt, "publishedAt"),
  });
}

function serviceRequestContractView(record) {
  objectRequired(record, "serviceRequest");
  return parseServiceRequest({
    contractVersion: record.contractVersion,
    requestId: record.requestId,
    tenantId: record.tenantId,
    canonicalBrandId: record.canonicalBrandId,
    serviceCode: record.serviceCode,
    priority: record.priority,
    jurisdictionCode: record.jurisdictionCode,
    sourceReferences: record.sourceReferences,
    title: record.title,
    objective: record.objective,
    scope: record.scope,
    requestedByUid: record.requestedByUid,
    requestedAt: record.requestedAt,
  });
}

function serviceProviderContractView(record) {
  objectRequired(record, "serviceProvider");
  return parseServiceProvider({
    contractVersion: record.contractVersion ||
      SERVICE_PROVIDER_CONTRACT_VERSION,
    providerId: record.providerId,
    providerType: record.providerType,
    displayName: record.displayName,
    organizationName: record.organizationName,
    status: record.status,
    expertiseCodes: record.expertiseCodes,
    jurisdictionCodes: record.jurisdictionCodes,
    languageCodes: record.languageCodes,
    qualifications: record.qualifications,
    professionalInsuranceStatus: record.professionalInsuranceStatus,
    conflictCheckRequired: record.conflictCheckRequired,
    verifiedAt: record.verifiedAt,
    verifiedByUid: record.verifiedByUid,
  });
}

function clientAuthorizationContractView(record) {
  objectRequired(record, "clientAuthorization");
  return parseClientAuthorization({
    contractVersion: record.contractVersion ||
      CLIENT_AUTHORIZATION_CONTRACT_VERSION,
    serviceRequestId: record.serviceRequestId,
    authorizationType: record.authorizationType,
    decision: record.decision,
    scopeFingerprintSha256: record.scopeFingerprintSha256,
    amountMinorUnits: record.amountMinorUnits,
    currencyCode: record.currencyCode,
    decidedByUid: record.decidedByUid,
    decisionNote: record.decisionNote,
    decidedAt: record.decidedAt,
  });
}

function serviceEngagementContractView(record) {
  objectRequired(record, "serviceEngagement");
  return parseServiceEngagement({
    contractVersion: record.contractVersion ||
      SERVICE_ENGAGEMENT_CONTRACT_VERSION,
    serviceRequestId: record.serviceRequestId,
    engagementMode: record.engagementMode,
    scopeFingerprintSha256: record.scopeFingerprintSha256,
    clientAuthorizationId: record.clientAuthorizationId,
    budgetAuthorizationId: record.budgetAuthorizationId,
    createdByUid: record.createdByUid,
    createdAt: record.createdAt,
  });
}

function serviceAssignmentContractView(record) {
  objectRequired(record, "serviceAssignment");
  return parseServiceAssignment({
    contractVersion: record.contractVersion ||
      SERVICE_ASSIGNMENT_CONTRACT_VERSION,
    serviceRequestId: record.serviceRequestId,
    serviceEngagementId: record.serviceEngagementId,
    providerId: record.providerId,
    assignmentMode: record.assignmentMode,
    assignedByUid: record.assignedByUid,
    supervisingUid: record.supervisingUid,
    jurisdictionCode: record.jurisdictionCode,
    scope: record.scope,
    billingModel: record.billingModel,
    currencyCode: record.currencyCode,
    estimatedAmountMinorUnits: record.estimatedAmountMinorUnits,
    slaFirstResponseMinutes: record.slaFirstResponseMinutes,
    slaCompletionMinutes: record.slaCompletionMinutes,
    dueAt: record.dueAt,
    assignedAt: record.assignedAt,
  });
}

function agentRunContractView(record) {
  objectRequired(record, "agentRun");
  return parseAgentRunRequest({
    contractVersion: record.contractVersion ||
      AGENT_RUN_REQUEST_CONTRACT_VERSION,
    requestId: record.requestId,
    serviceRequestId: record.serviceRequestId,
    serviceAssignmentId: record.serviceAssignmentId,
    agentCode: record.agentCode,
    agentVersion: record.agentVersion,
    modelProvider: record.modelProvider,
    modelName: record.modelName,
    modelVersion: record.modelVersion,
    promptTemplateVersion: record.promptTemplateVersion,
    initiatedByUid: record.initiatedByUid,
    supervisingUid: record.supervisingUid,
    sourceReferences: record.sourceReferences,
    inputManifestHashSha256: record.inputManifestHashSha256,
    confidentialityClass: record.confidentialityClass,
    privilegeClaimStatus: record.privilegeClaimStatus,
    startedAt: record.startedAt,
  });
}

function agentOutputContractView(record) {
  objectRequired(record, "agentOutputDraft");
  return parseAgentOutputDraft({
    contractVersion: record.contractVersion ||
      AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
    agentRunId: record.agentRunId,
    outputType: record.outputType,
    outputHashSha256: record.outputHashSha256,
    outputBytes: record.outputBytes,
    sourceReferenceCount: record.sourceReferenceCount,
    confidenceLevel: record.confidenceLevel,
    warningCodes: record.warningCodes,
    generatedAt: record.generatedAt,
  });
}

function agentReviewContractView(record) {
  objectRequired(record, "agentHumanReview");
  return parseAgentHumanReview({
    contractVersion: record.contractVersion ||
      AGENT_HUMAN_REVIEW_CONTRACT_VERSION,
    agentRunId: record.agentRunId,
    outputDraftId: record.outputDraftId,
    expectedDraftHashSha256: record.expectedDraftHashSha256,
    decision: record.decision,
    reviewedByUid: record.reviewedByUid,
    reviewNote: record.reviewNote,
    reviewedAt: record.reviewedAt,
  });
}

function createServiceDependencies({store, clock}) {
  return Object.freeze({
    store: assertStoragePort(store),
    clock: assertClock(clock),
  });
}

function resolveIdempotentReceipt(receipt, payloadFingerprint) {
  const checked = assertReceiptShape(receipt);
  if (!checked) {
    return null;
  }
  if (checked.payloadFingerprint !== payloadFingerprint) {
    fail("already-exists",
        "idempotency key is already used with a different payload");
  }
  return immutableSnapshot({
    idempotentReplay: true,
    resultType: checked.resultType,
    resultId: checked.resultId,
  });
}

function createReceipt({
  command,
  payloadFingerprint,
  resultType,
  resultId,
  recordedAt,
}) {
  return immutableSnapshot({
    contractVersion: command.contractVersion,
    requestId: command.requestId,
    idempotencyKey: command.idempotencyKey,
    payloadFingerprint,
    resultType,
    resultId,
    actorUid: command.actorUid,
    recordedAt,
    immutable: true,
  });
}

function buildEvent({
  aggregateType,
  aggregateId,
  command,
  eventType,
  eventData,
  recordedAt,
  executedByAgentId = null,
}) {
  return immutableSnapshot({
    eventId: prefixedId("psev", {
      aggregateType,
      aggregateId,
      requestId: command.requestId,
      eventType,
    }),
    contractVersion: command.contractVersion,
    aggregateType,
    aggregateId,
    eventType,
    requestId: command.requestId,
    idempotencyKey: command.idempotencyKey,
    actorUid: command.actorUid,
    executedByAgentId,
    eventData,
    recordedAt,
    appendOnly: true,
    immutable: true,
  });
}

function assertRecordVersion(record, expectedVersion, field) {
  if (!Number.isSafeInteger(record.version) || record.version < 1) {
    fail("internal", `${field}.version invalid`);
  }
  if (record.version !== expectedVersion) {
    fail("aborted", `${field} version conflict`);
  }
}

function assertSourceScope(request, sourceScope) {
  objectRequired(sourceScope, "sourceScope");
  if (sourceScope.tenantId !== request.tenantId) {
    fail("permission-denied", "source tenant scope mismatch");
  }
  if (sourceScope.canonicalBrandId !== request.canonicalBrandId) {
    fail("failed-precondition", "source brand scope mismatch");
  }
  if (sourceScope.archived === true) {
    fail("failed-precondition", "archived source cannot request service");
  }
  if (Array.isArray(sourceScope.unresolvedReferences) &&
      sourceScope.unresolvedReferences.length > 0) {
    fail("not-found", "canonical source reference was not resolved");
  }
  return true;
}

async function assertAuthority({
  store,
  actorUid,
  request,
  operationCode,
}) {
  if (!PROFESSIONAL_SERVICE_OPERATION_CODES.includes(operationCode)) {
    fail("invalid-argument", "operationCode unsupported");
  }
  const authority = await store.resolveProfessionalServiceAuthority({
    uid: actorUid,
    tenantId: request.tenantId,
    canonicalBrandId: request.canonicalBrandId,
    serviceFamily: request.serviceFamily,
    operationCode,
  });
  if (!authority || authority.authorized !== true) {
    fail("permission-denied",
        "professional service authority is not sufficient");
  }
  return authority;
}

function assertAuthorization({
  authorization,
  authorizationId,
  request,
  authorizationType,
  scopeFingerprintSha256,
}) {
  if (!authorization) {
    fail("not-found", `${authorizationType} authorization was not found`);
  }
  const parsed = clientAuthorizationContractView(authorization);
  if ((authorization.authorizationId || authorization.id) !==
      authorizationId) {
    fail("failed-precondition", "authorization identity mismatch");
  }
  if (parsed.serviceRequestId !== request.serviceRequestId ||
      parsed.authorizationType !== authorizationType ||
      parsed.decision !== "granted" ||
      parsed.scopeFingerprintSha256 !== scopeFingerprintSha256) {
    fail("failed-precondition", `${authorizationType} authorization invalid`);
  }
  return parsed;
}

function assertProviderForRequest(providerRecord, request, effectiveAt) {
  const provider = serviceProviderContractView(providerRecord);
  if (provider.status !== "active") {
    fail("failed-precondition", "service provider is not active");
  }
  if (!provider.jurisdictionCodes.includes("*") &&
      !provider.jurisdictionCodes.includes(request.jurisdictionCode)) {
    fail("failed-precondition",
        "service provider jurisdiction is not covered");
  }
  if (!provider.expertiseCodes.includes(request.serviceCode) &&
      !provider.expertiseCodes.includes(request.serviceFamily)) {
    fail("failed-precondition",
        "service provider expertise is not sufficient");
  }
  if (!["not_required", "verified_active"].includes(
      provider.professionalInsuranceStatus)) {
    fail("failed-precondition",
        "service provider insurance is not active");
  }
  const effectiveMilliseconds = Date.parse(effectiveAt);
  const qualified = provider.qualifications.some((qualification) =>
    qualification.status === "verified_active" &&
    (qualification.jurisdictionCode === "*" ||
      qualification.jurisdictionCode === request.jurisdictionCode) &&
    Date.parse(qualification.validFrom) <= effectiveMilliseconds &&
    (qualification.validUntil === null ||
      Date.parse(qualification.validUntil) > effectiveMilliseconds));
  if (!qualified) {
    fail("failed-precondition",
        "service provider qualification is not active");
  }
  return provider;
}

function requiresLegalReviewer(output, run) {
  return LEGAL_REVIEW_OUTPUT_TYPES.includes(output.outputType) ||
    run.confidentialityClass === "legal_privilege_asserted";
}

function assertReviewerAuthority(authority, output, run) {
  if (!authority || authority.authorized !== true) {
    fail("permission-denied", "agent reviewer authority is not sufficient");
  }
  if (requiresLegalReviewer(output, run) &&
      authority.professionalClass !== "legal_professional") {
    fail("permission-denied",
        "legal professional review is required");
  }
  return authority;
}

function buildCreateServiceRequestService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);
  return async function createServiceRequest(raw) {
    const command = parseCreateServiceRequestCommand(raw);
    const request = command.serviceRequest;
    const serviceRequestId = buildServiceRequestId({
      tenantId: request.tenantId,
      requestId: request.requestId,
    });
    const payloadFingerprint = fingerprintCommand(command);
    const receipt = await store.getCommandReceipt({
      scopeType: "create_service_request",
      scopeId: request.tenantId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) {
      return replay;
    }
    const sourceScope = await store.resolveSourceScope({
      sourceReferences: request.sourceReferences,
    });
    assertSourceScope(request, sourceScope);
    await assertAuthority({
      store,
      actorUid: command.actorUid,
      request,
      operationCode: "create_service_request",
    });
    const existing = await store.getServiceRequestById({serviceRequestId});
    if (existing) {
      fail("already-exists", "service request already exists");
    }
    const now = clock();
    const serviceRequest = immutableSnapshot({
      ...request,
      serviceRequestId,
      status: "requested",
      version: 1,
      createdAt: now,
      createdByRequestId: command.requestId,
      createdByUid: command.actorUid,
      updatedAt: now,
      updatedByRequestId: command.requestId,
      updatedByUid: command.actorUid,
      eventCount: 1,
    });
    const event = buildEvent({
      aggregateType: "service_request",
      aggregateId: serviceRequestId,
      command,
      eventType: "professional_service_requested",
      eventData: {
        serviceCode: request.serviceCode,
        serviceFamily: request.serviceFamily,
        status: "requested",
      },
      recordedAt: now,
    });
    const result = await store.createServiceRequestAtomic({
      serviceRequest,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "professional_service_request",
        resultId: serviceRequestId,
        recordedAt: now,
      }),
    });
    return immutableSnapshot({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "professional_service_request",
      resultId: serviceRequestId,
      serviceRequest: result && result.serviceRequest ?
        result.serviceRequest :
        serviceRequest,
    });
  };
}

function buildTransitionServiceRequestService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);
  return async function transitionServiceRequest(raw) {
    const command = parseTransitionServiceRequestCommand(raw);
    const payloadFingerprint = fingerprintCommand(command);
    const receipt = await store.getCommandReceipt({
      scopeType: "service_request",
      scopeId: command.serviceRequestId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) {
      return replay;
    }
    const current = await store.getServiceRequestById({
      serviceRequestId: command.serviceRequestId,
    });
    if (!current) {
      fail("not-found", "service request was not found");
    }
    const request = serviceRequestContractView(current);
    assertRecordVersion(current, command.expectedVersion, "serviceRequest");
    await assertAuthority({
      store,
      actorUid: command.actorUid,
      request,
      operationCode: "transition_service_request",
    });
    if (["ready_for_assignment", "assigned"].includes(command.nextStatus)) {
      fail("failed-precondition",
          "engagement or assignment command is required");
    }
    assertServiceRequestTransition(current.status, command.nextStatus);
    const now = clock();
    const nextServiceRequest = immutableSnapshot({
      ...current,
      status: command.nextStatus,
      version: current.version + 1,
      statusReasonCode: command.reasonCode,
      statusNote: command.note,
      statusChangedAt: now,
      statusChangedByUid: command.actorUid,
      updatedAt: now,
      updatedByRequestId: command.requestId,
      updatedByUid: command.actorUid,
      eventCount: Number(current.eventCount || 0) + 1,
    });
    const event = buildEvent({
      aggregateType: "service_request",
      aggregateId: command.serviceRequestId,
      command,
      eventType: "professional_service_status_changed",
      eventData: {
        previousStatus: current.status,
        nextStatus: command.nextStatus,
        reasonCode: command.reasonCode,
      },
      recordedAt: now,
    });
    const result = await store.transitionServiceRequestAtomic({
      currentServiceRequest: current,
      nextServiceRequest,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "professional_service_request",
        resultId: command.serviceRequestId,
        recordedAt: now,
      }),
    });
    return immutableSnapshot({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "professional_service_request",
      resultId: command.serviceRequestId,
      serviceRequest: result && result.serviceRequest ?
        result.serviceRequest :
        nextServiceRequest,
    });
  };
}

function buildCreateServiceEngagementService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);
  return async function createServiceEngagement(raw) {
    const command = parseCreateServiceEngagementCommand(raw);
    const engagementInput = command.serviceEngagement;
    const payloadFingerprint = fingerprintCommand(command);
    const receipt = await store.getCommandReceipt({
      scopeType: "service_engagement",
      scopeId: engagementInput.serviceRequestId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) {
      return replay;
    }
    const current = await store.getServiceRequestById({
      serviceRequestId: engagementInput.serviceRequestId,
    });
    if (!current) {
      fail("not-found", "service request was not found");
    }
    const request = serviceRequestContractView(current);
    assertRecordVersion(current, command.expectedServiceRequestVersion,
        "serviceRequest");
    if (!ENGAGEMENT_SOURCE_STATUSES.includes(current.status)) {
      fail("failed-precondition",
          "service request cannot create an engagement");
    }
    await assertAuthority({
      store,
      actorUid: command.actorUid,
      request,
      operationCode: "create_service_engagement",
    });
    const scopeFingerprint = canonicalDigestSha256(request.scope);
    if (engagementInput.scopeFingerprintSha256 !== scopeFingerprint) {
      fail("failed-precondition", "engagement scope fingerprint mismatch");
    }
    const clientAuthorizationRecord =
      await store.getClientAuthorizationById({
        authorizationId: engagementInput.clientAuthorizationId,
      });
    assertAuthorization({
      authorization: clientAuthorizationRecord,
      authorizationId: engagementInput.clientAuthorizationId,
      request: current,
      authorizationType: "service_scope",
      scopeFingerprintSha256: scopeFingerprint,
    });
    if (engagementInput.budgetAuthorizationId) {
      const budgetAuthorizationRecord =
        await store.getClientAuthorizationById({
          authorizationId: engagementInput.budgetAuthorizationId,
        });
      assertAuthorization({
        authorization: budgetAuthorizationRecord,
        authorizationId: engagementInput.budgetAuthorizationId,
        request: current,
        authorizationType: "budget",
        scopeFingerprintSha256: scopeFingerprint,
      });
    }
    const serviceEngagementId = buildServiceEngagementId({
      serviceRequestId: engagementInput.serviceRequestId,
    });
    const existing = await store.getServiceEngagementById({
      serviceEngagementId,
    });
    if (existing) {
      fail("already-exists", "service engagement already exists");
    }
    assertServiceRequestTransition(current.status, "ready_for_assignment");
    const now = clock();
    const serviceEngagement = immutableSnapshot({
      ...engagementInput,
      serviceEngagementId,
      tenantId: current.tenantId,
      canonicalBrandId: current.canonicalBrandId,
      jurisdictionCode: current.jurisdictionCode,
      version: 1,
      immutable: true,
    });
    const nextServiceRequest = immutableSnapshot({
      ...current,
      status: "ready_for_assignment",
      version: current.version + 1,
      serviceEngagementId,
      statusReasonCode: "engagement_authorized",
      statusChangedAt: now,
      statusChangedByUid: command.actorUid,
      updatedAt: now,
      updatedByRequestId: command.requestId,
      updatedByUid: command.actorUid,
      eventCount: Number(current.eventCount || 0) + 1,
    });
    const event = buildEvent({
      aggregateType: "service_request",
      aggregateId: current.serviceRequestId,
      command,
      eventType: "professional_service_engagement_created",
      eventData: {
        serviceEngagementId,
        engagementMode: serviceEngagement.engagementMode,
        status: "ready_for_assignment",
      },
      recordedAt: now,
    });
    const result = await store.createServiceEngagementAtomic({
      currentServiceRequest: current,
      nextServiceRequest,
      serviceEngagement,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "professional_service_engagement",
        resultId: serviceEngagementId,
        recordedAt: now,
      }),
    });
    return immutableSnapshot({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "professional_service_engagement",
      resultId: serviceEngagementId,
      serviceEngagement: result && result.serviceEngagement ?
        result.serviceEngagement :
        serviceEngagement,
      serviceRequest: result && result.serviceRequest ?
        result.serviceRequest :
        nextServiceRequest,
    });
  };
}

function buildCreateServiceAssignmentService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);
  return async function createServiceAssignment(raw) {
    const command = parseCreateServiceAssignmentCommand(raw);
    const assignmentInput = command.serviceAssignment;
    const payloadFingerprint = fingerprintCommand(command);
    const receipt = await store.getCommandReceipt({
      scopeType: "service_assignment",
      scopeId: assignmentInput.serviceRequestId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) {
      return replay;
    }
    const current = await store.getServiceRequestById({
      serviceRequestId: assignmentInput.serviceRequestId,
    });
    if (!current) {
      fail("not-found", "service request was not found");
    }
    const request = serviceRequestContractView(current);
    assertRecordVersion(current, command.expectedServiceRequestVersion,
        "serviceRequest");
    if (current.status !== "ready_for_assignment") {
      fail("failed-precondition",
          "service request is not ready for assignment");
    }
    await assertAuthority({
      store,
      actorUid: command.actorUid,
      request,
      operationCode: "create_service_assignment",
    });
    if (!assignmentInput.serviceEngagementId) {
      fail("failed-precondition", "service engagement is required");
    }
    const engagementRecord = await store.getServiceEngagementById({
      serviceEngagementId: assignmentInput.serviceEngagementId,
    });
    if (!engagementRecord) {
      fail("not-found", "service engagement was not found");
    }
    const engagement = serviceEngagementContractView(engagementRecord);
    if (engagement.serviceRequestId !== current.serviceRequestId ||
        engagementRecord.serviceEngagementId !==
          assignmentInput.serviceEngagementId) {
      fail("failed-precondition", "service engagement scope mismatch");
    }
    const providerRecord = await store.getServiceProviderById({
      providerId: assignmentInput.providerId,
    });
    if (!providerRecord) {
      fail("not-found", "service provider was not found");
    }
    const provider = assertProviderForRequest(
        providerRecord,
        request,
        assignmentInput.assignedAt,
    );
    if (assignmentInput.jurisdictionCode !== request.jurisdictionCode) {
      fail("failed-precondition", "assignment jurisdiction mismatch");
    }
    const assignmentScopeFingerprint =
      canonicalDigestSha256(assignmentInput.scope);
    if (assignmentScopeFingerprint !==
        engagement.scopeFingerprintSha256) {
      fail("failed-precondition", "assignment scope mismatch");
    }
    if (provider.conflictCheckRequired) {
      const conflictCheck = await store.resolveConflictCheck({
        serviceRequestId: current.serviceRequestId,
        providerId: provider.providerId,
      });
      if (!conflictCheck ||
          conflictCheck.serviceRequestId !== current.serviceRequestId ||
          conflictCheck.providerId !== provider.providerId ||
          !ASSIGNMENT_CONFLICT_OUTCOMES.includes(conflictCheck.outcome)) {
        fail("failed-precondition", "conflict check is not cleared");
      }
    }
    if (assignmentInput.billingModel !== "included_in_plan" ||
        assignmentInput.estimatedAmountMinorUnits > 0) {
      if (!engagement.budgetAuthorizationId) {
        fail("failed-precondition", "budget authorization is required");
      }
      const budgetAuthorizationRecord =
        await store.getClientAuthorizationById({
          authorizationId: engagement.budgetAuthorizationId,
        });
      const budgetAuthorization = assertAuthorization({
        authorization: budgetAuthorizationRecord,
        authorizationId: engagement.budgetAuthorizationId,
        request: current,
        authorizationType: "budget",
        scopeFingerprintSha256: engagement.scopeFingerprintSha256,
      });
      if (budgetAuthorization.currencyCode !==
          assignmentInput.currencyCode ||
          budgetAuthorization.amountMinorUnits <
            assignmentInput.estimatedAmountMinorUnits) {
        fail("failed-precondition",
            "budget authorization is insufficient");
      }
    }
    if (Date.parse(assignmentInput.dueAt) <=
        Date.parse(assignmentInput.assignedAt)) {
      fail("failed-precondition", "assignment dueAt invalid");
    }
    const serviceAssignmentId = buildServiceAssignmentId({
      serviceRequestId: current.serviceRequestId,
      providerId: provider.providerId,
      assignmentSequence: command.assignmentSequence,
    });
    const existing = await store.getServiceAssignmentById({
      serviceAssignmentId,
    });
    if (existing) {
      fail("already-exists", "service assignment already exists");
    }
    assertServiceRequestTransition(current.status, "assigned");
    const now = clock();
    const serviceAssignment = immutableSnapshot({
      ...assignmentInput,
      serviceAssignmentId,
      assignmentSequence: command.assignmentSequence,
      tenantId: current.tenantId,
      canonicalBrandId: current.canonicalBrandId,
      serviceCode: current.serviceCode,
      serviceFamily: current.serviceFamily,
      version: 1,
      status: "assigned",
      immutable: true,
    });
    const nextServiceRequest = immutableSnapshot({
      ...current,
      status: "assigned",
      version: current.version + 1,
      activeServiceAssignmentId: serviceAssignmentId,
      statusReasonCode: "provider_assigned",
      statusChangedAt: now,
      statusChangedByUid: command.actorUid,
      updatedAt: now,
      updatedByRequestId: command.requestId,
      updatedByUid: command.actorUid,
      eventCount: Number(current.eventCount || 0) + 1,
    });
    const event = buildEvent({
      aggregateType: "service_request",
      aggregateId: current.serviceRequestId,
      command,
      eventType: "professional_service_assignment_created",
      eventData: {
        serviceAssignmentId,
        providerId: provider.providerId,
        assignmentMode: assignmentInput.assignmentMode,
        status: "assigned",
      },
      recordedAt: now,
    });
    const result = await store.createServiceAssignmentAtomic({
      currentServiceRequest: current,
      nextServiceRequest,
      serviceAssignment,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "professional_service_assignment",
        resultId: serviceAssignmentId,
        recordedAt: now,
      }),
    });
    return immutableSnapshot({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "professional_service_assignment",
      resultId: serviceAssignmentId,
      serviceAssignment: result && result.serviceAssignment ?
        result.serviceAssignment :
        serviceAssignment,
      serviceRequest: result && result.serviceRequest ?
        result.serviceRequest :
        nextServiceRequest,
    });
  };
}

function buildStartAgentRunService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);
  return async function startAgentRun(raw) {
    const command = parseStartAgentRunCommand(raw);
    const runInput = command.agentRunRequest;
    const payloadFingerprint = fingerprintCommand(command);
    const receipt = await store.getCommandReceipt({
      scopeType: "agent_run",
      scopeId: runInput.serviceRequestId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) {
      return replay;
    }
    const serviceRequestRecord = await store.getServiceRequestById({
      serviceRequestId: runInput.serviceRequestId,
    });
    if (!serviceRequestRecord) {
      fail("not-found", "service request was not found");
    }
    const request = serviceRequestContractView(serviceRequestRecord);
    if (isServiceRequestTerminal(serviceRequestRecord.status)) {
      fail("failed-precondition",
          "terminal service request cannot start an agent");
    }
    await assertAuthority({
      store,
      actorUid: command.actorUid,
      request,
      operationCode: "start_agent_run",
    });
    await assertAuthority({
      store,
      actorUid: runInput.supervisingUid,
      request,
      operationCode: "supervise_agent_run",
    });
    const sourceScope = await store.resolveSourceScope({
      sourceReferences: runInput.sourceReferences,
    });
    assertSourceScope(request, sourceScope);
    if (runInput.serviceAssignmentId) {
      if (!AGENT_SERVICE_STATUSES.includes(serviceRequestRecord.status)) {
        fail("failed-precondition",
            "service request status cannot start assigned agent work");
      }
      const assignmentRecord = await store.getServiceAssignmentById({
        serviceAssignmentId: runInput.serviceAssignmentId,
      });
      if (!assignmentRecord) {
        fail("not-found", "service assignment was not found");
      }
      const assignment = serviceAssignmentContractView(assignmentRecord);
      if (assignment.serviceRequestId !== serviceRequestRecord.serviceRequestId ||
          assignment.assignmentMode !== "agent_assisted_human" ||
          assignment.supervisingUid !== runInput.supervisingUid) {
        fail("failed-precondition",
            "agent-assisted assignment scope is invalid");
      }
    } else {
      if (!PRE_ASSIGNMENT_AGENT_CODES.includes(runInput.agentCode) ||
          !AGENT_PRE_ASSIGNMENT_STATUSES.includes(
              serviceRequestRecord.status)) {
        fail("failed-precondition",
            "agent run requires an agent-assisted assignment");
      }
    }
    const agentTaskId = buildAgentTaskId({
      serviceRequestId: runInput.serviceRequestId,
      agentCode: runInput.agentCode,
      requestId: command.requestId,
    });
    const currentTask = await store.getAgentTaskById({agentTaskId});
    if (!currentTask) {
      if (command.expectedAgentTaskVersion !== null ||
          command.runSequence !== 1) {
        fail("aborted", "new agent task sequence is invalid");
      }
    } else {
      assertRecordVersion(currentTask,
          command.expectedAgentTaskVersion, "agentTask");
      if (!["revision_requested", "failed"].includes(currentTask.status)) {
        fail("failed-precondition", "agent task cannot be rerun");
      }
      if (currentTask.serviceRequestId !== runInput.serviceRequestId ||
          currentTask.agentCode !== runInput.agentCode ||
          command.runSequence !== Number(currentTask.runCount || 0) + 1) {
        fail("failed-precondition", "agent task rerun scope is invalid");
      }
      assertAgentTaskTransition(currentTask.status, "running");
    }
    const agentRunId = buildAgentRunId({
      agentTaskId,
      runSequence: command.runSequence,
      inputManifestHashSha256: runInput.inputManifestHashSha256,
    });
    const existingRun = await store.getAgentRunById({agentRunId});
    if (existingRun) {
      fail("already-exists", "agent run already exists");
    }
    const now = clock();
    const agentTask = immutableSnapshot({
      ...(currentTask || {}),
      contractVersion: "professional-agent-task-v1",
      agentTaskId,
      tenantId: serviceRequestRecord.tenantId,
      canonicalBrandId: serviceRequestRecord.canonicalBrandId,
      serviceRequestId: runInput.serviceRequestId,
      serviceAssignmentId: runInput.serviceAssignmentId,
      agentCode: runInput.agentCode,
      status: "running",
      version: currentTask ? currentTask.version + 1 : 1,
      runCount: command.runSequence,
      currentAgentRunId: agentRunId,
      initiatedByUid: runInput.initiatedByUid,
      supervisingUid: runInput.supervisingUid,
      createdAt: currentTask ? currentTask.createdAt : now,
      createdByUid: currentTask ?
        currentTask.createdByUid :
        command.actorUid,
      updatedAt: now,
      updatedByUid: command.actorUid,
      eventCount: Number(currentTask && currentTask.eventCount || 0) + 1,
    });
    const agentRun = immutableSnapshot({
      ...runInput,
      agentRunId,
      agentTaskId,
      runSequence: command.runSequence,
      tenantId: serviceRequestRecord.tenantId,
      canonicalBrandId: serviceRequestRecord.canonicalBrandId,
      status: "running",
      executedByAgentId:
        `${runInput.agentCode}@${runInput.agentVersion}`,
      immutable: true,
    });
    const event = buildEvent({
      aggregateType: "agent_task",
      aggregateId: agentTaskId,
      command,
      eventType: "professional_agent_run_started",
      eventData: {
        agentRunId,
        runSequence: command.runSequence,
        agentCode: runInput.agentCode,
        status: "running",
      },
      recordedAt: now,
      executedByAgentId: agentRun.executedByAgentId,
    });
    const result = await store.createAgentRunAtomic({
      currentAgentTask: currentTask,
      nextAgentTask: agentTask,
      agentRun,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "professional_agent_run",
        resultId: agentRunId,
        recordedAt: now,
      }),
    });
    return immutableSnapshot({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "professional_agent_run",
      resultId: agentRunId,
      agentTask: result && result.agentTask ?
        result.agentTask :
        agentTask,
      agentRun: result && result.agentRun ?
        result.agentRun :
        agentRun,
    });
  };
}

function buildRecordAgentOutputService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);
  return async function recordAgentOutput(raw) {
    const command = parseRecordAgentOutputCommand(raw);
    const outputInput = command.agentOutputDraft;
    const payloadFingerprint = fingerprintCommand(command);
    const receipt = await store.getCommandReceipt({
      scopeType: "agent_output_draft",
      scopeId: outputInput.agentRunId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) {
      return replay;
    }
    const task = await store.getAgentTaskById({
      agentTaskId: command.agentTaskId,
    });
    if (!task) {
      fail("not-found", "agent task was not found");
    }
    assertRecordVersion(task, command.expectedAgentTaskVersion,
        "agentTask");
    if (task.status !== "running") {
      fail("failed-precondition", "agent task is not running");
    }
    const runRecord = await store.getAgentRunById({
      agentRunId: outputInput.agentRunId,
    });
    if (!runRecord) {
      fail("not-found", "agent run was not found");
    }
    const run = agentRunContractView(runRecord);
    if (runRecord.agentTaskId !== command.agentTaskId ||
        task.currentAgentRunId !== outputInput.agentRunId ||
        command.actorUid !== run.supervisingUid) {
      fail("failed-precondition", "agent output scope is invalid");
    }
    const requestRecord = await store.getServiceRequestById({
      serviceRequestId: run.serviceRequestId,
    });
    if (!requestRecord) {
      fail("not-found", "service request was not found");
    }
    const request = serviceRequestContractView(requestRecord);
    await assertAuthority({
      store,
      actorUid: command.actorUid,
      request,
      operationCode: "record_agent_output",
    });
    if (Date.parse(outputInput.generatedAt) <
        Date.parse(run.startedAt)) {
      fail("failed-precondition",
          "agent output predates the agent run");
    }
    if (outputInput.sourceReferenceCount !==
        Object.keys(run.sourceReferences).length) {
      fail("failed-precondition",
          "agent output source reference count mismatch");
    }
    assertAgentTaskTransition(task.status, "waiting_human_review");
    const outputDraftId = buildAgentOutputDraftId({
      agentRunId: outputInput.agentRunId,
      outputHashSha256: outputInput.outputHashSha256,
    });
    const existingOutput = await store.getAgentOutputDraftById({
      outputDraftId,
    });
    if (existingOutput) {
      fail("already-exists", "agent output draft already exists");
    }
    const now = clock();
    const agentOutputDraft = immutableSnapshot({
      ...outputInput,
      outputDraftId,
      agentTaskId: task.agentTaskId,
      serviceRequestId: task.serviceRequestId,
      serviceAssignmentId: task.serviceAssignmentId || null,
      tenantId: task.tenantId,
      canonicalBrandId: task.canonicalBrandId,
      agentCode: run.agentCode,
      agentVersion: run.agentVersion,
      modelProvider: run.modelProvider,
      modelName: run.modelName,
      modelVersion: run.modelVersion,
      promptTemplateVersion: run.promptTemplateVersion,
      confidentialityClass: run.confidentialityClass,
      privilegeClaimStatus: run.privilegeClaimStatus,
      initiatedByUid: run.initiatedByUid,
      supervisingUid: run.supervisingUid,
      executedByAgentId: runRecord.executedByAgentId ||
        `${run.agentCode}@${run.agentVersion}`,
      immutable: true,
    });
    const nextAgentTask = immutableSnapshot({
      ...task,
      status: "waiting_human_review",
      version: task.version + 1,
      latestOutputDraftId: outputDraftId,
      latestOutputHashSha256: outputInput.outputHashSha256,
      updatedAt: now,
      updatedByUid: command.actorUid,
      eventCount: Number(task.eventCount || 0) + 1,
    });
    const event = buildEvent({
      aggregateType: "agent_task",
      aggregateId: task.agentTaskId,
      command,
      eventType: "professional_agent_output_recorded",
      eventData: {
        agentRunId: outputInput.agentRunId,
        outputDraftId,
        outputType: outputInput.outputType,
        status: "waiting_human_review",
      },
      recordedAt: now,
      executedByAgentId: agentOutputDraft.executedByAgentId,
    });
    const result = await store.createAgentOutputDraftAtomic({
      currentAgentTask: task,
      nextAgentTask,
      agentOutputDraft,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "professional_agent_output_draft",
        resultId: outputDraftId,
        recordedAt: now,
      }),
    });
    return immutableSnapshot({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "professional_agent_output_draft",
      resultId: outputDraftId,
      agentTask: result && result.agentTask ?
        result.agentTask :
        nextAgentTask,
      agentOutputDraft: result && result.agentOutputDraft ?
        result.agentOutputDraft :
        agentOutputDraft,
    });
  };
}

function buildRecordAgentReviewService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);
  return async function recordAgentReview(raw) {
    const command = parseRecordAgentReviewCommand(raw);
    const reviewInput = command.agentHumanReview;
    const payloadFingerprint = fingerprintCommand(command);
    const receipt = await store.getCommandReceipt({
      scopeType: "agent_human_review",
      scopeId: reviewInput.outputDraftId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) {
      return replay;
    }
    const task = await store.getAgentTaskById({
      agentTaskId: command.agentTaskId,
    });
    if (!task) {
      fail("not-found", "agent task was not found");
    }
    assertRecordVersion(task, command.expectedAgentTaskVersion,
        "agentTask");
    if (task.status !== "waiting_human_review" ||
        task.latestOutputDraftId !== reviewInput.outputDraftId) {
      fail("failed-precondition",
          "agent task is not waiting for this review");
    }
    const outputRecord = await store.getAgentOutputDraftById({
      outputDraftId: reviewInput.outputDraftId,
    });
    if (!outputRecord) {
      fail("not-found", "agent output draft was not found");
    }
    const outputDraft = agentOutputContractView(outputRecord);
    const runRecord = await store.getAgentRunById({
      agentRunId: reviewInput.agentRunId,
    });
    if (!runRecord) {
      fail("not-found", "agent run was not found");
    }
    const run = agentRunContractView(runRecord);
    if (outputRecord.agentTaskId !== task.agentTaskId ||
        runRecord.agentTaskId !== task.agentTaskId) {
      fail("failed-precondition", "agent review scope mismatch");
    }
    const requestRecord = await store.getServiceRequestById({
      serviceRequestId: task.serviceRequestId,
    });
    if (!requestRecord) {
      fail("not-found", "service request was not found");
    }
    const request = serviceRequestContractView(requestRecord);
    if (Date.parse(reviewInput.reviewedAt) <
        Date.parse(outputDraft.generatedAt)) {
      fail("failed-precondition",
          "human review predates the agent output");
    }
    const authority = await assertAuthority({
      store,
      actorUid: command.actorUid,
      request,
      operationCode: "review_agent_output",
    });
    assertReviewerAuthority(authority, outputDraft, run);
    if (reviewInput.decision === "approved") {
      assertAgentOutputPublishable(outputDraft, reviewInput);
    } else if (outputDraft.agentRunId !== reviewInput.agentRunId ||
        outputDraft.outputHashSha256 !==
          reviewInput.expectedDraftHashSha256) {
      fail("failed-precondition",
          "human review does not match output draft");
    }
    const nextStatus = {
      approved: "approved",
      revision_requested: "revision_requested",
      rejected: "rejected",
    }[reviewInput.decision];
    assertAgentTaskTransition(task.status, nextStatus);
    const humanReviewId = buildAgentHumanReviewId({
      outputDraftId: reviewInput.outputDraftId,
      reviewedByUid: reviewInput.reviewedByUid,
      decision: reviewInput.decision,
    });
    const existingReview = await store.getAgentHumanReviewById({
      humanReviewId,
    });
    if (existingReview) {
      fail("already-exists", "agent human review already exists");
    }
    const now = clock();
    const agentHumanReview = immutableSnapshot({
      ...reviewInput,
      humanReviewId,
      agentTaskId: task.agentTaskId,
      serviceRequestId: task.serviceRequestId,
      tenantId: task.tenantId,
      canonicalBrandId: task.canonicalBrandId,
      reviewerProfessionalClass:
        authority.professionalClass || "authorized_human",
      immutable: true,
    });
    const nextAgentTask = immutableSnapshot({
      ...task,
      status: nextStatus,
      version: task.version + 1,
      latestHumanReviewId: humanReviewId,
      latestHumanReviewDecision: reviewInput.decision,
      updatedAt: now,
      updatedByUid: command.actorUid,
      eventCount: Number(task.eventCount || 0) + 1,
    });
    const event = buildEvent({
      aggregateType: "agent_task",
      aggregateId: task.agentTaskId,
      command,
      eventType: "professional_agent_output_reviewed",
      eventData: {
        outputDraftId: reviewInput.outputDraftId,
        humanReviewId,
        decision: reviewInput.decision,
        status: nextStatus,
      },
      recordedAt: now,
    });
    const result = await store.recordAgentHumanReviewAtomic({
      currentAgentTask: task,
      nextAgentTask,
      agentHumanReview,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "professional_agent_human_review",
        resultId: humanReviewId,
        recordedAt: now,
      }),
    });
    return immutableSnapshot({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "professional_agent_human_review",
      resultId: humanReviewId,
      agentTask: result && result.agentTask ?
        result.agentTask :
        nextAgentTask,
      agentHumanReview: result && result.agentHumanReview ?
        result.agentHumanReview :
        agentHumanReview,
    });
  };
}

function buildPublishAgentOutputService(dependencies) {
  const {store, clock} = createServiceDependencies(dependencies);
  return async function publishAgentOutput(raw) {
    const command = parsePublishAgentOutputCommand(raw);
    const payloadFingerprint = fingerprintCommand(command);
    const receipt = await store.getCommandReceipt({
      scopeType: "agent_output_publication",
      scopeId: command.outputDraftId,
      idempotencyKey: command.idempotencyKey,
    });
    const replay = resolveIdempotentReceipt(receipt, payloadFingerprint);
    if (replay) {
      return replay;
    }
    const task = await store.getAgentTaskById({
      agentTaskId: command.agentTaskId,
    });
    if (!task) {
      fail("not-found", "agent task was not found");
    }
    assertRecordVersion(task, command.expectedAgentTaskVersion,
        "agentTask");
    if (task.status !== "approved" ||
        task.latestOutputDraftId !== command.outputDraftId ||
        task.latestHumanReviewId !== command.humanReviewId) {
      fail("failed-precondition",
          "agent task is not approved for publication");
    }
    const outputRecord = await store.getAgentOutputDraftById({
      outputDraftId: command.outputDraftId,
    });
    const reviewRecord = await store.getAgentHumanReviewById({
      humanReviewId: command.humanReviewId,
    });
    if (!outputRecord || !reviewRecord) {
      fail("not-found", "approved agent output was not found");
    }
    const outputDraft = agentOutputContractView(outputRecord);
    const humanReview = agentReviewContractView(reviewRecord);
    assertAgentOutputPublishable(outputDraft, humanReview);
    const runRecord = await store.getAgentRunById({
      agentRunId: outputDraft.agentRunId,
    });
    if (!runRecord) {
      fail("not-found", "agent run was not found");
    }
    const run = agentRunContractView(runRecord);
    const requestRecord = await store.getServiceRequestById({
      serviceRequestId: task.serviceRequestId,
    });
    if (!requestRecord) {
      fail("not-found", "service request was not found");
    }
    const request = serviceRequestContractView(requestRecord);
    if (Date.parse(command.publishedAt) <
        Date.parse(humanReview.reviewedAt)) {
      fail("failed-precondition",
          "publication predates the human review");
    }
    const authority = await assertAuthority({
      store,
      actorUid: command.actorUid,
      request,
      operationCode: "publish_agent_output",
    });
    assertReviewerAuthority(authority, outputDraft, run);
    if (authority.canPublish !== true) {
      fail("permission-denied",
          "agent output publication authority is not sufficient");
    }
    assertAgentTaskTransition(task.status, "published");
    const publicationId = prefixedId("ppub", {
      outputDraftId: command.outputDraftId,
      humanReviewId: command.humanReviewId,
      publishedArtifactId: command.publishedArtifactId,
    });
    const now = clock();
    const publication = immutableSnapshot({
      contractVersion: "professional-agent-output-publication-v1",
      publicationId,
      agentTaskId: task.agentTaskId,
      agentRunId: outputDraft.agentRunId,
      outputDraftId: command.outputDraftId,
      humanReviewId: command.humanReviewId,
      serviceRequestId: task.serviceRequestId,
      tenantId: task.tenantId,
      canonicalBrandId: task.canonicalBrandId,
      sourceOutputHashSha256: outputDraft.outputHashSha256,
      publishedArtifactId: command.publishedArtifactId,
      publishedArtifactHashSha256:
        command.publishedArtifactHashSha256,
      publishedByUid: command.actorUid,
      publishedAt: command.publishedAt,
      immutable: true,
    });
    const nextAgentTask = immutableSnapshot({
      ...task,
      status: "published",
      version: task.version + 1,
      publicationId,
      publishedArtifactId: command.publishedArtifactId,
      publishedAt: command.publishedAt,
      publishedByUid: command.actorUid,
      updatedAt: now,
      updatedByUid: command.actorUid,
      eventCount: Number(task.eventCount || 0) + 1,
    });
    const event = buildEvent({
      aggregateType: "agent_task",
      aggregateId: task.agentTaskId,
      command,
      eventType: "professional_agent_output_published",
      eventData: {
        outputDraftId: command.outputDraftId,
        humanReviewId: command.humanReviewId,
        publicationId,
        publishedArtifactId: command.publishedArtifactId,
        status: "published",
      },
      recordedAt: now,
    });
    const result = await store.publishAgentOutputAtomic({
      currentAgentTask: task,
      nextAgentTask,
      publication,
      event,
      receipt: createReceipt({
        command,
        payloadFingerprint,
        resultType: "professional_agent_output_publication",
        resultId: publicationId,
        recordedAt: now,
      }),
    });
    return immutableSnapshot({
      idempotentReplay:
        Boolean(result && result.idempotentReplay === true),
      resultType: "professional_agent_output_publication",
      resultId: publicationId,
      agentTask: result && result.agentTask ?
        result.agentTask :
        nextAgentTask,
      publication: result && result.publication ?
        result.publication :
        publication,
    });
  };
}

module.exports = Object.freeze({
  AGENT_OUTPUT_PUBLISH_COMMAND_VERSION,
  AGENT_OUTPUT_RECORD_COMMAND_VERSION,
  AGENT_REVIEW_RECORD_COMMAND_VERSION,
  AGENT_RUN_START_COMMAND_VERSION,
  LEGAL_REVIEW_OUTPUT_TYPES,
  PRE_ASSIGNMENT_AGENT_CODES,
  PROFESSIONAL_SERVICE_OPERATION_CODES,
  SERVICE_ASSIGNMENT_CREATE_COMMAND_VERSION,
  SERVICE_ENGAGEMENT_CREATE_COMMAND_VERSION,
  SERVICE_REQUEST_CREATE_COMMAND_VERSION,
  SERVICE_REQUEST_TRANSITION_COMMAND_VERSION,
  assertAuthority,
  assertSourceScope,
  buildCreateServiceAssignmentService,
  buildCreateServiceEngagementService,
  buildCreateServiceRequestService,
  buildPublishAgentOutputService,
  buildRecordAgentOutputService,
  buildRecordAgentReviewService,
  buildStartAgentRunService,
  buildTransitionServiceRequestService,
  createReceipt,
  createServiceDependencies,
  parseCreateServiceAssignmentCommand,
  parseCreateServiceEngagementCommand,
  parseCreateServiceRequestCommand,
  parsePublishAgentOutputCommand,
  parseRecordAgentOutputCommand,
  parseRecordAgentReviewCommand,
  parseStartAgentRunCommand,
  parseTransitionServiceRequestCommand,
  resolveIdempotentReceipt,
});
