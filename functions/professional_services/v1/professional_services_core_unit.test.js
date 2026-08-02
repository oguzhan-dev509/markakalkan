/* eslint-disable max-len */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  ProfessionalServicesCanonicalError,
  canonicalDigestSha256,
  canonicalJson,
  immutableSnapshot,
} = require("./canonical");
const {
  CLIENT_AUTHORIZATION_CONTRACT_VERSION,
  CONFLICT_CHECK_CONTRACT_VERSION,
  SERVICE_ASSIGNMENT_CONTRACT_VERSION,
  SERVICE_ENGAGEMENT_CONTRACT_VERSION,
  SERVICE_PROVIDER_CONTRACT_VERSION,
  SERVICE_REQUEST_CONTRACT_VERSION,
  ProfessionalServicesContractError,
  parseClientAuthorization,
  parseConflictCheck,
  parseServiceAssignment,
  parseServiceEngagement,
  parseServiceProvider,
  parseServiceRequest,
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
  ProfessionalServicesLifecycleError,
  allowedAgentTaskTransitions,
  allowedServiceRequestTransitions,
  assertAgentTaskTransition,
  assertServiceRequestTransition,
  isAgentTaskTerminal,
  isServiceRequestTerminal,
} = require("./lifecycle");
const {
  buildAgentHumanReviewId,
  buildAgentOutputDraftId,
  buildAgentRunId,
  buildAgentTaskId,
  buildServiceAssignmentId,
  buildServiceEngagementId,
  buildServiceRequestId,
} = require("./identifiers");

const UUID = "123e4567-e89b-42d3-a456-426614174000";
const HASH_A = "a".repeat(64);
const HASH_B = "b".repeat(64);
const NOW = "2026-08-02T09:00:00.000Z";

function serviceRequestInput(overrides = {}) {
  return {
    contractVersion: SERVICE_REQUEST_CONTRACT_VERSION,
    requestId: UUID,
    tenantId: "tenant_demo",
    canonicalBrandId: "brand_demo",
    serviceCode: "legal_preliminary_assessment",
    priority: "high",
    jurisdictionCode: "TR",
    sourceReferences: {
      caseId: "case_001",
      legalMatterId: "lm_001",
    },
    title: "Ön hukuki değerlendirme",
    objective: "Mevcut delilleri inceleyip işlem seçeneklerini belirlemek.",
    scope: {
      summary: "Vaka dosyasının ön hukuki değerlendirmesi.",
      inclusions: ["Delil kronolojisinin incelenmesi"],
      exclusions: ["Mahkemeye resmî başvuru"],
    },
    requestedByUid: "uid_requester",
    requestedAt: NOW,
    ...overrides,
  };
}

function agentRunInput(overrides = {}) {
  return {
    contractVersion: AGENT_RUN_REQUEST_CONTRACT_VERSION,
    requestId: UUID,
    serviceRequestId: "psr_demo",
    serviceAssignmentId: "psa_demo",
    agentCode: "legal_intake_triage",
    agentVersion: "v1",
    modelProvider: "provider",
    modelName: "model-name",
    modelVersion: "2026-08-01",
    promptTemplateVersion: "v1",
    initiatedByUid: "uid_initiator",
    supervisingUid: "uid_supervisor",
    sourceReferences: {
      caseId: "case_001",
    },
    inputManifestHashSha256: HASH_A,
    confidentialityClass: "professional_restricted",
    privilegeClaimStatus: "none",
    startedAt: NOW,
    ...overrides,
  };
}

test("canonical JSON is stable across object key order", () => {
  const left = canonicalJson({b: 2, a: {d: 4, c: 3}});
  const right = canonicalJson({a: {c: 3, d: 4}, b: 2});
  assert.equal(left, right);
  assert.equal(canonicalDigestSha256({b: 2, a: 1}),
      canonicalDigestSha256({a: 1, b: 2}));
});

test("immutable snapshot recursively freezes data", () => {
  const snapshot = immutableSnapshot({items: [{value: 1}]});
  assert.equal(Object.isFrozen(snapshot), true);
  assert.equal(Object.isFrozen(snapshot.items), true);
  assert.equal(Object.isFrozen(snapshot.items[0]), true);
});

test("canonical layer rejects circular references", () => {
  const value = {};
  value.self = value;
  assert.throws(() => immutableSnapshot(value),
      ProfessionalServicesCanonicalError);
});

test("service request requires a canonical source reference", () => {
  const parsed = parseServiceRequest(serviceRequestInput());
  assert.equal(parsed.serviceFamily, "legal");
  assert.equal(parsed.jurisdictionCode, "tr");
  assert.equal(parsed.sourceReferences.caseId, "case_001");
  assert.equal(Object.isFrozen(parsed), true);
  assert.throws(() => parseServiceRequest(serviceRequestInput({
    sourceReferences: {},
  })), ProfessionalServicesContractError);
});

test("service request rejects untrusted fields", () => {
  assert.throws(() => parseServiceRequest(serviceRequestInput({
    unexpected: true,
  })), /request contract invalid/);
});

test("provider contract preserves qualifications and jurisdictions", () => {
  const provider = parseServiceProvider({
    contractVersion: SERVICE_PROVIDER_CONTRACT_VERSION,
    providerId: "provider_001",
    providerType: "lawyer",
    displayName: "Yetkili Avukat",
    organizationName: "Örnek Hukuk",
    status: "active",
    expertiseCodes: ["trademark_enforcement"],
    jurisdictionCodes: ["TR"],
    languageCodes: ["tr", "en"],
    qualifications: [{
      qualificationCode: "bar_registration",
      issuingAuthority: "Baro",
      jurisdictionCode: "TR",
      credentialReference: "credential-001",
      validFrom: "2025-01-01T00:00:00Z",
      validUntil: "2027-01-01T00:00:00Z",
      status: "verified_active",
    }],
    professionalInsuranceStatus: "verified_active",
    conflictCheckRequired: true,
    verifiedAt: NOW,
    verifiedByUid: "uid_verifier",
  });
  assert.deepEqual(provider.jurisdictionCodes, ["tr"]);
  assert.equal(provider.qualifications[0].status, "verified_active");
});


test("engagement contract binds authorizations to an accepted scope", () => {
  const engagement = parseServiceEngagement({
    contractVersion: SERVICE_ENGAGEMENT_CONTRACT_VERSION,
    serviceRequestId: "psr_demo",
    engagementMode: "matter_based",
    scopeFingerprintSha256: HASH_A,
    clientAuthorizationId: "pca_demo",
    budgetAuthorizationId: "pba_demo",
    createdByUid: "uid_creator",
    createdAt: NOW,
  });
  assert.equal(engagement.engagementMode, "matter_based");
  assert.equal(engagement.scopeFingerprintSha256, HASH_A);
});

test("assignment contract keeps human supervision explicit", () => {
  const assignment = parseServiceAssignment({
    contractVersion: SERVICE_ASSIGNMENT_CONTRACT_VERSION,
    serviceRequestId: "psr_demo",
    serviceEngagementId: "pse_demo",
    providerId: "provider_001",
    assignmentMode: "agent_assisted_human",
    assignedByUid: "uid_assigner",
    supervisingUid: "uid_supervisor",
    jurisdictionCode: "TR",
    scope: {
      summary: "Hukuki taslak hazırlanması ve insan incelemesi.",
      inclusions: ["Ajan taslağının avukat tarafından incelenmesi"],
      exclusions: ["Otomatik dış gönderim"],
    },
    billingModel: "fixed_fee",
    currencyCode: "try",
    estimatedAmountMinorUnits: 500000,
    slaFirstResponseMinutes: 240,
    slaCompletionMinutes: 2880,
    dueAt: "2026-08-05T09:00:00Z",
    assignedAt: NOW,
  });
  assert.equal(assignment.currencyCode, "TRY");
  assert.equal(assignment.assignmentMode, "agent_assisted_human");
  assert.equal(assignment.supervisingUid, "uid_supervisor");
});

test("client authorization is immutable and scope-bound", () => {
  const authorization = parseClientAuthorization({
    contractVersion: CLIENT_AUTHORIZATION_CONTRACT_VERSION,
    serviceRequestId: "psr_demo",
    authorizationType: "budget",
    decision: "granted",
    scopeFingerprintSha256: HASH_A,
    amountMinorUnits: 500000,
    currencyCode: "TRY",
    decidedByUid: "uid_client",
    decisionNote: "Belirtilen kapsam ve bütçe onaylandı.",
    decidedAt: NOW,
  });
  assert.equal(authorization.immutable, true);
  assert.equal(Object.isFrozen(authorization), true);
});

test("conflict waiver requires an authorizing user", () => {
  const base = {
    contractVersion: CONFLICT_CHECK_CONTRACT_VERSION,
    serviceRequestId: "psr_demo",
    providerId: "provider_001",
    outcome: "waived",
    checkedByUid: "uid_checker",
    authorizedByUid: null,
    note: "Potansiyel çatışma değerlendirildi.",
    checkedAt: NOW,
  };
  assert.throws(() => parseConflictCheck(base),
      /waiver authorization required/);
  const cleared = parseConflictCheck({
    ...base,
    outcome: "cleared",
  });
  assert.equal(cleared.outcome, "cleared");
});

test("agent run records model, prompt, sources and human supervisor", () => {
  const run = parseAgentRunRequest(agentRunInput());
  assert.equal(run.agentCode, "legal_intake_triage");
  assert.equal(run.humanApprovalRequired, true);
  assert.equal(run.supervisingUid, "uid_supervisor");
  assert.deepEqual(run.agentCapabilities, [
    "case_intake_summary",
    "missing_information_detection",
  ]);
});

test("privilege-marked agent work requires a privilege claim state", () => {
  assert.throws(() => parseAgentRunRequest(agentRunInput({
    confidentialityClass: "legal_privilege_asserted",
    privilegeClaimStatus: "none",
  })), /privilege claim status required/);
});

test("agent output is always a non-publishable draft", () => {
  const draft = parseAgentOutputDraft({
    contractVersion: AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
    agentRunId: "par_demo",
    outputType: "legal_document_draft",
    outputHashSha256: HASH_B,
    outputBytes: 25000,
    sourceReferenceCount: 12,
    confidenceLevel: "not_scored",
    warningCodes: ["lawyer_review_required"],
    generatedAt: NOW,
  });
  assert.equal(draft.reviewStatus, "pending_human_review");
  assert.equal(draft.publishable, false);
  assert.equal(draft.immutable, true);
});

test("matching human approval makes an agent draft publishable", () => {
  const draft = parseAgentOutputDraft({
    contractVersion: AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
    agentRunId: "par_demo",
    outputType: "legal_document_draft",
    outputHashSha256: HASH_B,
    outputBytes: 25000,
    sourceReferenceCount: 12,
    confidenceLevel: "not_scored",
    warningCodes: [],
    generatedAt: NOW,
  });
  const review = parseAgentHumanReview({
    contractVersion: AGENT_HUMAN_REVIEW_CONTRACT_VERSION,
    agentRunId: "par_demo",
    outputDraftId: "pao_demo",
    expectedDraftHashSha256: HASH_B,
    decision: "approved",
    reviewedByUid: "uid_lawyer",
    reviewNote: "Taslak insan tarafından incelendi ve onaylandı.",
    reviewedAt: NOW,
  });
  assert.equal(assertAgentOutputPublishable(draft, review), true);
});

test("rejected or mismatched agent output cannot be published", () => {
  const draft = parseAgentOutputDraft({
    contractVersion: AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
    agentRunId: "par_demo",
    outputType: "legal_document_draft",
    outputHashSha256: HASH_B,
    outputBytes: 25000,
    sourceReferenceCount: 12,
    confidenceLevel: "not_scored",
    warningCodes: [],
    generatedAt: NOW,
  });
  const rejected = parseAgentHumanReview({
    contractVersion: AGENT_HUMAN_REVIEW_CONTRACT_VERSION,
    agentRunId: "par_demo",
    outputDraftId: "pao_demo",
    expectedDraftHashSha256: HASH_B,
    decision: "rejected",
    reviewedByUid: "uid_lawyer",
    reviewNote: "Taslak hukuki kullanım için uygun değildir.",
    reviewedAt: NOW,
  });
  assert.throws(() => assertAgentOutputPublishable(draft, rejected),
      /not approved/);
  assert.throws(() => assertAgentOutputPublishable(draft, {
    ...rejected,
    decision: "approved",
    expectedDraftHashSha256: HASH_A,
  }), /does not match/);
});

test("service lifecycle allows controlled delivery and closure", () => {
  assert.equal(assertServiceRequestTransition("draft", "requested"), true);
  assert.equal(assertServiceRequestTransition("delivered", "accepted"), true);
  assert.equal(assertServiceRequestTransition("accepted", "closed"), true);
  assert.deepEqual(allowedServiceRequestTransitions("blocked"),
      ["in_progress", "cancelled"]);
  assert.equal(isServiceRequestTerminal("closed"), true);
  assert.equal(isServiceRequestTerminal("accepted"), false);
});

test("service lifecycle rejects skipped authorization stages", () => {
  assert.throws(() =>
    assertServiceRequestTransition("requested", "assigned"),
  ProfessionalServicesLifecycleError);
});

test("agent lifecycle enforces human review before publication", () => {
  assert.equal(assertAgentTaskTransition("running",
      "waiting_human_review"), true);
  assert.equal(assertAgentTaskTransition("waiting_human_review",
      "approved"), true);
  assert.equal(assertAgentTaskTransition("approved", "published"), true);
  assert.throws(() => assertAgentTaskTransition("running", "published"),
      ProfessionalServicesLifecycleError);
  assert.deepEqual(allowedAgentTaskTransitions("failed"),
      ["queued", "cancelled"]);
  assert.equal(isAgentTaskTerminal("published"), true);
});

test("deterministic identifiers are stable and scope-sensitive", () => {
  const serviceRequestId = buildServiceRequestId({
    tenantId: "tenant_demo",
    requestId: UUID,
  });
  assert.equal(serviceRequestId, buildServiceRequestId({
    tenantId: "tenant_demo",
    requestId: UUID.toUpperCase(),
  }));
  assert.notEqual(serviceRequestId, buildServiceRequestId({
    tenantId: "tenant_other",
    requestId: UUID,
  }));
  assert.match(serviceRequestId, /^psr_[0-9a-f]{64}$/);
  assert.match(buildServiceEngagementId({serviceRequestId}),
      /^pse_[0-9a-f]{64}$/);
});

test("assignment and agent identifiers preserve causal scope", () => {
  const assignmentId = buildServiceAssignmentId({
    serviceRequestId: "psr_demo",
    providerId: "provider_001",
    assignmentSequence: 1,
  });
  const taskId = buildAgentTaskId({
    serviceRequestId: "psr_demo",
    agentCode: "legal_intake_triage",
    requestId: UUID,
  });
  const runId = buildAgentRunId({
    agentTaskId: taskId,
    runSequence: 1,
    inputManifestHashSha256: HASH_A,
  });
  const outputId = buildAgentOutputDraftId({
    agentRunId: runId,
    outputHashSha256: HASH_B,
  });
  const reviewId = buildAgentHumanReviewId({
    outputDraftId: outputId,
    reviewedByUid: "uid_lawyer",
    decision: "approved",
  });
  assert.match(assignmentId, /^psa_[0-9a-f]{64}$/);
  assert.match(taskId, /^pat_[0-9a-f]{64}$/);
  assert.match(runId, /^par_[0-9a-f]{64}$/);
  assert.match(outputId, /^pao_[0-9a-f]{64}$/);
  assert.match(reviewId, /^phr_[0-9a-f]{64}$/);
});
