"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const contracts = require("./contracts");
const canonical = require("./canonical");
const identifiers = require("./identifiers");
const lifecycle = require("./lifecycle");

const baseCreate = Object.freeze({
  contractVersion: contracts.CONTRACT_VERSION,
  requestId: "req-001",
  idempotencyKey: "idem-001",
  actorUid: "owner-1",
  tenantId: "tenant-1",
  canonicalBrandId: "brand-1",
  caseId: "case-1",
  jurisdictionCode: "tr.istanbul",
  matterScopeCode: "counterfeit_enforcement",
  countryCode: "TR",
});

test("collection contract contains all MHL-1A collections", () => {
  assert.equal(
    contracts.COLLECTIONS.LEGAL_MATTER_FILES,
    "legal_matter_files",
  );
  assert.equal(
    contracts.COLLECTIONS.LEGAL_APPROVAL_DECISIONS,
    "legal_approval_decisions",
  );
  assert.equal(
    contracts.COLLECTIONS.LEGAL_MATTER_EVENTS,
    "legal_matter_events",
  );
});

test("contract collections and status catalogs are frozen", () => {
  assert.equal(Object.isFrozen(contracts.COLLECTIONS), true);
  assert.equal(Object.isFrozen(contracts.LEGAL_MATTER_STATUSES), true);
  assert.equal(Object.isFrozen(contracts.ACTION_STATUSES), true);
});

test("legal matter command operations are locked and language independent", () => {
  assert.deepEqual(
    contracts.LEGAL_MATTER_OPERATION_CODES,
    [
      "create_legal_matter",
      "transition_legal_matter",
    ],
  );
  assert.equal(
    Object.isFrozen(contracts.LEGAL_MATTER_OPERATION_CODES),
    true,
  );
});

test("create legal matter command requires a canonical case reference", () => {
  const raw = {...baseCreate};
  delete raw.caseId;
  assert.throws(
    () => contracts.parseCreateLegalMatterCommand(raw),
    /required request fields missing/,
  );
});

test("create legal matter command requires authenticated actor", () => {
  const raw = {...baseCreate};
  delete raw.actorUid;
  assert.throws(
    () => contracts.parseCreateLegalMatterCommand(raw),
    /required request fields missing/,
  );
});

test("create legal matter command rejects unsupported fields", () => {
  assert.throws(
    () => contracts.parseCreateLegalMatterCommand({
      ...baseCreate,
      duplicatedCaseTitle: "must not be stored",
    }),
    /unsupported request fields/,
  );
});

test("create legal matter command normalizes language-independent codes", () => {
  const parsed = contracts.parseCreateLegalMatterCommand({
    ...baseCreate,
    jurisdictionCode: "TR.ISTANBUL",
    matterScopeCode: "COUNTERFEIT_ENFORCEMENT",
    countryCode: "tr",
  });
  assert.equal(parsed.jurisdictionCode, "tr.istanbul");
  assert.equal(parsed.matterScopeCode, "counterfeit_enforcement");
  assert.equal(parsed.countryCode, "TR");
  assert.equal(parsed.actorUid, "owner-1");
  assert.equal(Object.isFrozen(parsed), true);
});

test("create legal matter command rejects translated labels as codes", () => {
  assert.throws(
    () => contracts.parseCreateLegalMatterCommand({
      ...baseCreate,
      matterScopeCode: "Sahte ürün müdahalesi",
    }),
    /language-independent code/,
  );
});

test("transition command requires optimistic concurrency version", () => {
  assert.throws(
    () => contracts.parseTransitionLegalMatterCommand({
      contractVersion: contracts.CONTRACT_VERSION,
      requestId: "req-transition",
      idempotencyKey: "idem-transition",
      actorUid: "owner-1",
      legalMatterId: "lm_123",
      nextStatus: "legal_review",
      reasonCode: "intake_accepted",
    }),
    /required request fields missing/,
  );
});

test("transition command accepts a valid next status shape", () => {
  const parsed = contracts.parseTransitionLegalMatterCommand({
    contractVersion: contracts.CONTRACT_VERSION,
    requestId: "req-transition",
    idempotencyKey: "idem-transition",
    actorUid: "owner-1",
    expectedVersion: 0,
    legalMatterId: "lm_123",
    nextStatus: "legal_review",
    reasonCode: "intake_accepted",
  });
  assert.equal(parsed.expectedVersion, 0);
  assert.equal(parsed.nextStatus, "legal_review");
});

test("approval decision keeps client and lawyer approval types distinct", () => {
  const lawyer = contracts.parseApprovalDecisionCommand({
    contractVersion: contracts.CONTRACT_VERSION,
    requestId: "req-approval",
    idempotencyKey: "idem-approval",
    expectedApprovalRequestVersion: 1,
    approvalRequestId: "lar_123",
    legalMatterId: "lm_123",
    approvalType: "lawyer_legal_approval",
    decision: "approved",
    decisionReasonCode: "legally_sufficient",
    decidedByUid: "lawyer-1",
  });
  assert.equal(lawyer.approvalType, "lawyer_legal_approval");
  assert.notEqual(
    lawyer.approvalType,
    "client_action_authorization",
  );
  assert.equal(lawyer.expectedApprovalRequestVersion, 1);
});

test("approval decision requires approval request version", () => {
  assert.throws(
    () => contracts.parseApprovalDecisionCommand({
      contractVersion: contracts.CONTRACT_VERSION,
      requestId: "req-approval-missing-version",
      idempotencyKey: "idem-approval-missing-version",
      approvalRequestId: "lar_123",
      legalMatterId: "lm_123",
      approvalType: "client_budget_authorization",
      decision: "approved",
      decisionReasonCode: "budget_confirmed",
      decidedByUid: "client-1",
    }),
    (error) =>
      error instanceof contracts.InterventionLegalContractError &&
      error.code === "invalid-argument",
  );
});

test("segregation of duties rejects sole self-approval", () => {
  assert.throws(
    () => contracts.assertSegregationOfDuties({
      preparedByUid: "user-1",
      approvedByUid: "user-1",
    }),
    /sole final legal approver/,
  );
});

test("segregation of duties accepts different users", () => {
  assert.equal(
    contracts.assertSegregationOfDuties({
      preparedByUid: "user-1",
      approvedByUid: "lawyer-2",
    }),
    true,
  );
});

test("active responsible lawyer can approve covered jurisdiction", () => {
  assert.equal(
    contracts.assertLegalProfessionalCanApprove({
      status: "active",
      roleCodes: ["responsible_lawyer"],
      jurisdictionCodes: ["tr.istanbul"],
    }, "tr.istanbul"),
    true,
  );
});

test("inactive lawyer cannot approve", () => {
  assert.throws(
    () => contracts.assertLegalProfessionalCanApprove({
      status: "inactive",
      roleCodes: ["responsible_lawyer"],
      jurisdictionCodes: ["tr.istanbul"],
    }, "tr.istanbul"),
    /not active/,
  );
});

test("field investigator cannot issue lawyer approval", () => {
  assert.throws(
    () => contracts.assertLegalProfessionalCanApprove({
      status: "active",
      roleCodes: ["field_investigator"],
      jurisdictionCodes: ["tr.istanbul"],
    }, "tr.istanbul"),
    /no lawyer approval role/,
  );
});

test("lawyer approval is jurisdiction scoped", () => {
  assert.throws(
    () => contracts.assertLegalProfessionalCanApprove({
      status: "active",
      roleCodes: ["senior_legal_reviewer"],
      jurisdictionCodes: ["tr.ankara"],
    }, "tr.istanbul"),
    /does not cover/,
  );
});

test("external dispatch gate passes only when every invariant is met", () => {
  assert.equal(
    contracts.assertExternalDispatchReadiness({
      documentStatus: "approved",
      immutableApprovedSnapshotExists: true,
      lawyerApprovalDecisionExists: true,
      clientAuthorizationRequired: true,
      clientAuthorizationExists: true,
      dataMinimizationConfirmed: true,
      artifactIntegrityHash: "a".repeat(64),
    }),
    true,
  );
});

test("external dispatch gate blocks missing lawyer approval", () => {
  assert.throws(
    () => contracts.assertExternalDispatchReadiness({
      documentStatus: "approved",
      immutableApprovedSnapshotExists: true,
      lawyerApprovalDecisionExists: false,
      clientAuthorizationRequired: false,
      clientAuthorizationExists: false,
      dataMinimizationConfirmed: true,
      artifactIntegrityHash: "a".repeat(64),
    }),
    (error) => error.details.failures.includes("lawyer_approval_missing"),
  );
});

test("external dispatch gate blocks required client authorization", () => {
  assert.throws(
    () => contracts.assertExternalDispatchReadiness({
      documentStatus: "approved",
      immutableApprovedSnapshotExists: true,
      lawyerApprovalDecisionExists: true,
      clientAuthorizationRequired: true,
      clientAuthorizationExists: false,
      dataMinimizationConfirmed: true,
      artifactIntegrityHash: "a".repeat(64),
    }),
    (error) => error.details.failures.includes("client_authorization_missing"),
  );
});

test("stable stringify is independent of object key order", () => {
  assert.equal(
    canonical.stableStringify({b: 2, a: {d: 4, c: 3}}),
    canonical.stableStringify({a: {c: 3, d: 4}, b: 2}),
  );
});

test("canonical payload fingerprint is stable", () => {
  assert.equal(
    canonical.canonicalPayloadFingerprint({b: 2, a: 1}),
    canonical.canonicalPayloadFingerprint({a: 1, b: 2}),
  );
});

test("canonical legal matter identity normalizes scope", () => {
  const result = canonical.canonicalizeLegalMatterIdentity({
    ...baseCreate,
    jurisdictionCode: "TR.ISTANBUL",
    matterScopeCode: "COUNTERFEIT_ENFORCEMENT",
    countryCode: "tr",
  });
  assert.equal(result.jurisdictionCode, "tr.istanbul");
  assert.equal(result.matterScopeCode, "counterfeit_enforcement");
  assert.equal(result.countryCode, "TR");
});

test("legal matter key follows locked four-part identity", () => {
  const result = identifiers.buildLegalMatterKey(baseCreate);
  assert.match(result, /^[a-f0-9]{64}$/);
  const same = identifiers.buildLegalMatterKey({
    ...baseCreate,
    canonicalBrandId: "another-brand",
    countryCode: "US",
  });
  assert.equal(result, same);
});

test("legal matter key changes with jurisdiction", () => {
  assert.notEqual(
    identifiers.buildLegalMatterKey(baseCreate),
    identifiers.buildLegalMatterKey({
      ...baseCreate,
      jurisdictionCode: "tr.ankara",
    }),
  );
});

test("legal matter key changes with matter scope", () => {
  assert.notEqual(
    identifiers.buildLegalMatterKey(baseCreate),
    identifiers.buildLegalMatterKey({
      ...baseCreate,
      matterScopeCode: "domain_enforcement",
    }),
  );
});

test("legal matter id is deterministic and prefixed", () => {
  const one = identifiers.buildLegalMatterId(baseCreate);
  const two = identifiers.buildLegalMatterId({...baseCreate});
  assert.equal(one, two);
  assert.match(one, /^lm_[a-f0-9]{24}$/);
});

test("link id supports many-to-many external references", () => {
  const one = identifiers.buildLinkId({
    legalMatterId: "lm_123",
    referenceType: "counterfeit_twin_record",
    referenceId: "ctr_1",
  });
  const two = identifiers.buildLinkId({
    legalMatterId: "lm_123",
    referenceType: "counterfeit_twin_record",
    referenceId: "ctr_2",
  });
  assert.notEqual(one, two);
  assert.match(one, /^lml_[a-f0-9]{24}$/);
});

test("assessment ids are version-specific", () => {
  assert.notEqual(
    identifiers.buildAssessmentId({legalMatterId: "lm_1", version: 1}),
    identifiers.buildAssessmentId({legalMatterId: "lm_1", version: 2}),
  );
});

test("matter event id is idempotent for the same request", () => {
  const input = {
    legalMatterId: "lm_1",
    requestId: "req-1",
    eventType: "legal_matter_created",
  };
  assert.equal(
    identifiers.buildMatterEventId(input),
    identifiers.buildMatterEventId({...input}),
  );
});

test("legal matter intake can enter legal review", () => {
  assert.equal(
    lifecycle.canTransition(
      "legalMatter",
      "intake_pending",
      "legal_review",
    ),
    true,
  );
});

test("legal matter cannot skip from intake to submitted", () => {
  assert.equal(
    lifecycle.canTransition(
      "legalMatter",
      "intake_pending",
      "submitted",
    ),
    false,
  );
});

test("closed legal matter can be reopened for a renewed violation", () => {
  assert.equal(
    lifecycle.canTransition("legalMatter", "closed", "in_progress"),
    true,
  );
});

test("archived legal matter is terminal", () => {
  assert.equal(lifecycle.isTerminal("legalMatter", "archived"), true);
});

test("cancelled legal matter can only be archived", () => {
  assert.deepEqual(
    lifecycle.allowedTransitions("legalMatter", "cancelled"),
    ["archived"],
  );
});

test("assessment requires lawyer review before approval", () => {
  assert.equal(
    lifecycle.canTransition("assessment", "draft", "approved"),
    false,
  );
  assert.equal(
    lifecycle.canTransition(
      "assessment",
      "awaiting_lawyer_review",
      "approved",
    ),
    true,
  );
});

test("plan may require client authorization before approval", () => {
  assert.equal(
    lifecycle.canTransition(
      "plan",
      "awaiting_lawyer_review",
      "awaiting_client_authorization",
    ),
    true,
  );
});

test("action must be prepared before execution", () => {
  assert.equal(
    lifecycle.canTransition("action", "approved", "executed"),
    false,
  );
  assert.equal(
    lifecycle.canTransition(
      "action",
      "ready_for_execution",
      "executed",
    ),
    true,
  );
});

test("approval request decision is terminal", () => {
  assert.equal(
    lifecycle.canTransition("approvalRequest", "pending", "approved"),
    true,
  );
  assert.equal(lifecycle.isTerminal("approvalRequest", "approved"), true);
});

test("suspended professional can be restored to active", () => {
  assert.equal(
    lifecycle.canTransition("professional", "suspended", "active"),
    true,
  );
});

test("archived professional is terminal", () => {
  assert.equal(lifecycle.isTerminal("professional", "archived"), true);
});

test("assertTransition returns a structured contract error", () => {
  assert.throws(
    () => lifecycle.assertTransition(
      "legalMatter",
      "intake_pending",
      "resolved",
    ),
    (error) =>
      error instanceof contracts.InterventionLegalContractError &&
      error.code === "failed-precondition" &&
      error.details.currentStatus === "intake_pending",
  );
});

test("unknown lifecycle is rejected", () => {
  assert.throws(
    () => lifecycle.allowedTransitions("unknown", "draft"),
    /unknown lifecycle/,
  );
});
