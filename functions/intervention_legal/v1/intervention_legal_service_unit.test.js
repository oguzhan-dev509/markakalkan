"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  CONTRACT_VERSION,
  InterventionLegalContractError,
} = require("./contracts");
const {
  REQUIRED_STORAGE_METHODS,
  assertStoragePort,
} = require("./storage_contracts");
const {
  buildCreateLegalMatterService,
  buildRecordApprovalDecisionService,
  buildTransitionLegalMatterService,
} = require("./service");

const NOW = "2026-07-31T08:30:00.000Z";

function createFakeStore(overrides = {}) {
  const receipts = new Map();
  const matters = new Map();
  const mattersByKey = new Map();
  const approvals = new Map();
  const profiles = new Map();
  const receiptKey = ({scopeType, scopeId, idempotencyKey}) =>
    `${scopeType}|${scopeId}|${idempotencyKey}`;

  const store = {
    async getCommandReceipt(input) {
      return receipts.get(receiptKey(input)) || null;
    },
    async resolveCaseScope({caseId}) {
      return caseId === "case-1"
        ? {
          caseId,
          tenantId: "tenant-1",
          canonicalBrandId: "brand-1",
          status: "open",
        }
        : null;
    },
    async findLegalMatterByKey({legalMatterKey}) {
      return mattersByKey.get(legalMatterKey) || null;
    },
    async getLegalMatterById({legalMatterId}) {
      return matters.get(legalMatterId) || null;
    },
    async createLegalMatterAtomic({matter, receipt}) {
      if (matters.has(matter.legalMatterId)) {
        throw new Error("duplicate matter");
      }
      matters.set(matter.legalMatterId, matter);
      mattersByKey.set(matter.legalMatterKey, matter);
      receipts.set(receiptKey({
        scopeType: "create_legal_matter",
        scopeId: matter.tenantId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {matter, idempotentReplay: false};
    },
    async transitionLegalMatterAtomic({nextMatter, receipt}) {
      matters.set(nextMatter.legalMatterId, nextMatter);
      mattersByKey.set(nextMatter.legalMatterKey, nextMatter);
      receipts.set(receiptKey({
        scopeType: "legal_matter",
        scopeId: nextMatter.legalMatterId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {matter: nextMatter, idempotentReplay: false};
    },
    async getApprovalRequestById({approvalRequestId}) {
      return approvals.get(approvalRequestId) || null;
    },
    async getLegalTeamProfileByUid({uid}) {
      return profiles.get(uid) || null;
    },
    async resolveClientAuthority({uid}) {
      return {authorized: uid === "client-1"};
    },
    async recordApprovalDecisionAtomic({
      approvalRequest,
      expectedApprovalRequestVersion,
      decision,
      receipt,
    }) {
      if (approvalRequest.version !== expectedApprovalRequestVersion) {
        throw new InterventionLegalContractError(
          "aborted",
          "approval request version conflict",
        );
      }
      approvals.set(
        approvalRequest.approvalRequestId,
        {
          ...approvalRequest,
          status: decision.decision,
          version: expectedApprovalRequestVersion + 1,
        },
      );
      receipts.set(receiptKey({
        scopeType: "legal_approval_decision",
        scopeId: approvalRequest.approvalRequestId,
        idempotencyKey: receipt.idempotencyKey,
      }), receipt);
      return {decision, idempotentReplay: false};
    },
    __seedMatter(matter) {
      matters.set(matter.legalMatterId, matter);
      mattersByKey.set(matter.legalMatterKey, matter);
    },
    __seedApproval(request) {
      approvals.set(request.approvalRequestId, request);
    },
    __seedProfile(uid, profile) {
      profiles.set(uid, profile);
    },
    __seedReceipt(scope, receipt) {
      receipts.set(receiptKey(scope), receipt);
    },
  };

  return Object.assign(store, overrides);
}

function createCommand(overrides = {}) {
  return {
    contractVersion: CONTRACT_VERSION,
    requestId: "req-create-1",
    idempotencyKey: "idem-create-1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    caseId: "case-1",
    jurisdictionCode: "tr.istanbul",
    matterScopeCode: "counterfeit_enforcement",
    countryCode: "TR",
    ...overrides,
  };
}

test("storage port lists all required methods", () => {
  assert.equal(REQUIRED_STORAGE_METHODS.length, 10);
  assert.equal(REQUIRED_STORAGE_METHODS.includes("resolveCaseScope"), true);
  assert.equal(
    REQUIRED_STORAGE_METHODS.includes("recordApprovalDecisionAtomic"),
    true,
  );
});

test("storage port rejects an incomplete adapter", () => {
  assert.throws(
    () => assertStoragePort({getCommandReceipt() {}}),
    (error) =>
      error instanceof InterventionLegalContractError &&
      error.code === "failed-precondition" &&
      error.details.missing.includes("resolveCaseScope"),
  );
});

test("create service writes an intake-pending legal matter", async () => {
  const store = createFakeStore();
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });

  const result = await createMatter(createCommand());

  assert.equal(result.idempotentReplay, false);
  assert.equal(result.matter.status, "intake_pending");
  assert.equal(result.matter.caseId, "case-1");
  assert.equal(result.matter.version, 1);
  assert.equal(result.matter.createdAt, NOW);
});

test("create service rejects a missing canonical case", async () => {
  const createMatter = buildCreateLegalMatterService({
    store: createFakeStore(),
    clock: () => NOW,
  });

  await assert.rejects(
    () => createMatter(createCommand({caseId: "missing"})),
    (error) => error.code === "not-found",
  );
});

test("create service rejects tenant scope mismatch", async () => {
  const store = createFakeStore({
    async resolveCaseScope() {
      return {
        caseId: "case-1",
        tenantId: "another-tenant",
        canonicalBrandId: "brand-1",
        status: "open",
      };
    },
  });
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });

  await assert.rejects(
    () => createMatter(createCommand()),
    (error) => error.code === "permission-denied",
  );
});

test("create service rejects brand scope mismatch", async () => {
  const store = createFakeStore({
    async resolveCaseScope() {
      return {
        caseId: "case-1",
        tenantId: "tenant-1",
        canonicalBrandId: "another-brand",
        status: "open",
      };
    },
  });
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });

  await assert.rejects(
    () => createMatter(createCommand()),
    (error) => error.code === "failed-precondition",
  );
});

test("create service rejects archived canonical case", async () => {
  const store = createFakeStore({
    async resolveCaseScope() {
      return {
        caseId: "case-1",
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        status: "archived",
      };
    },
  });
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });

  await assert.rejects(
    () => createMatter(createCommand()),
    /archived case/,
  );
});

test("create service is idempotent for the same command", async () => {
  const store = createFakeStore();
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });

  const first = await createMatter(createCommand());
  const second = await createMatter(createCommand());

  assert.equal(first.resultId, second.resultId);
  assert.equal(second.idempotentReplay, true);
});

test("idempotency key conflict is rejected", async () => {
  const store = createFakeStore();
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });

  await createMatter(createCommand());
  await assert.rejects(
    () => createMatter(createCommand({
      matterScopeCode: "domain_enforcement",
    })),
    (error) => error.code === "already-exists",
  );
});

test("canonical legal matter key prevents duplicate active scope", async () => {
  const store = createFakeStore();
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });

  const first = await createMatter(createCommand());
  const replayWithNewRequest = await createMatter(createCommand({
    requestId: "req-create-2",
    idempotencyKey: "idem-create-2",
  }));

  assert.equal(replayWithNewRequest.idempotentReplay, true);
  assert.equal(replayWithNewRequest.resultId, first.resultId);
});

test("transition service updates status and increments version", async () => {
  const store = createFakeStore();
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });
  const transitionMatter = buildTransitionLegalMatterService({
    store,
    clock: () => "2026-07-31T08:31:00.000Z",
  });
  const created = await createMatter(createCommand());

  const result = await transitionMatter({
    contractVersion: CONTRACT_VERSION,
    requestId: "req-transition-1",
    idempotencyKey: "idem-transition-1",
    expectedVersion: 1,
    legalMatterId: created.resultId,
    nextStatus: "legal_review",
    reasonCode: "intake_accepted",
  });

  assert.equal(result.matter.status, "legal_review");
  assert.equal(result.matter.version, 2);
  assert.equal(result.matter.statusReasonCode, "intake_accepted");
});

test("transition service rejects optimistic concurrency conflict", async () => {
  const store = createFakeStore();
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });
  const transitionMatter = buildTransitionLegalMatterService({
    store,
    clock: () => NOW,
  });
  const created = await createMatter(createCommand());

  await assert.rejects(
    () => transitionMatter({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-transition",
      idempotencyKey: "idem-transition",
      expectedVersion: 0,
      legalMatterId: created.resultId,
      nextStatus: "legal_review",
      reasonCode: "intake_accepted",
    }),
    (error) =>
      error.code === "aborted" &&
      error.details.actualVersion === 1,
  );
});

test("transition service rejects forbidden lifecycle jump", async () => {
  const store = createFakeStore();
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });
  const transitionMatter = buildTransitionLegalMatterService({
    store,
    clock: () => NOW,
  });
  const created = await createMatter(createCommand());

  await assert.rejects(
    () => transitionMatter({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-transition",
      idempotencyKey: "idem-transition",
      expectedVersion: 1,
      legalMatterId: created.resultId,
      nextStatus: "submitted",
      reasonCode: "skip",
    }),
    (error) => error.code === "failed-precondition",
  );
});

test("transition service is idempotent", async () => {
  const store = createFakeStore();
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });
  const transitionMatter = buildTransitionLegalMatterService({
    store,
    clock: () => NOW,
  });
  const created = await createMatter(createCommand());
  const command = {
    contractVersion: CONTRACT_VERSION,
    requestId: "req-transition",
    idempotencyKey: "idem-transition",
    expectedVersion: 1,
    legalMatterId: created.resultId,
    nextStatus: "legal_review",
    reasonCode: "intake_accepted",
  };

  const first = await transitionMatter(command);
  const second = await transitionMatter(command);

  assert.equal(first.resultId, second.resultId);
  assert.equal(second.idempotentReplay, true);
});

test("lawyer approval requires active covered legal profile", async () => {
  const store = createFakeStore();
  store.__seedMatter({
    legalMatterId: "lm_1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
  });
  store.__seedApproval({
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "lawyer_legal_approval",
    status: "pending",
    preparedByUid: "operations-1",
    version: 1,
  });
  store.__seedProfile("lawyer-1", {
    status: "active",
    roleCodes: ["responsible_lawyer"],
    jurisdictionCodes: ["tr.istanbul"],
  });

  const decide = buildRecordApprovalDecisionService({
    store,
    clock: () => NOW,
  });
  const result = await decide({
    contractVersion: CONTRACT_VERSION,
    requestId: "req-decision",
    idempotencyKey: "idem-decision",
    expectedApprovalRequestVersion: 1,
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "lawyer_legal_approval",
    decision: "approved",
    decisionReasonCode: "legally_sufficient",
    decidedByUid: "lawyer-1",
  });

  assert.equal(result.decision.immutable, true);
  assert.equal(result.decision.decision, "approved");
});

test("lawyer cannot be sole preparer and approver", async () => {
  const store = createFakeStore();
  store.__seedMatter({
    legalMatterId: "lm_1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
  });
  store.__seedApproval({
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "lawyer_legal_approval",
    status: "pending",
    preparedByUid: "lawyer-1",
    version: 1,
  });
  store.__seedProfile("lawyer-1", {
    status: "active",
    roleCodes: ["responsible_lawyer"],
    jurisdictionCodes: ["tr.istanbul"],
  });
  const decide = buildRecordApprovalDecisionService({
    store,
    clock: () => NOW,
  });

  await assert.rejects(
    () => decide({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-decision",
      idempotencyKey: "idem-decision",
      expectedApprovalRequestVersion: 1,
      approvalRequestId: "lar_1",
      legalMatterId: "lm_1",
      approvalType: "lawyer_legal_approval",
      decision: "approved",
      decisionReasonCode: "legally_sufficient",
      decidedByUid: "lawyer-1",
    }),
    /sole final legal approver/,
  );
});

test("client authorization requires resolved client authority", async () => {
  const store = createFakeStore();
  store.__seedMatter({
    legalMatterId: "lm_1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
  });
  store.__seedApproval({
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 1,
  });
  const decide = buildRecordApprovalDecisionService({
    store,
    clock: () => NOW,
  });

  await assert.rejects(
    () => decide({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-decision",
      idempotencyKey: "idem-decision",
      expectedApprovalRequestVersion: 1,
      approvalRequestId: "lar_1",
      legalMatterId: "lm_1",
      approvalType: "client_budget_authorization",
      decision: "approved",
      decisionReasonCode: "budget_confirmed",
      decidedByUid: "unauthorized-client",
    }),
    (error) => error.code === "permission-denied",
  );
});

test("authorized client can approve budget request", async () => {
  const store = createFakeStore();
  store.__seedMatter({
    legalMatterId: "lm_1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
  });
  store.__seedApproval({
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 1,
  });
  const decide = buildRecordApprovalDecisionService({
    store,
    clock: () => NOW,
  });

  const result = await decide({
    contractVersion: CONTRACT_VERSION,
    requestId: "req-decision",
    idempotencyKey: "idem-decision",
    expectedApprovalRequestVersion: 1,
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    decision: "approved",
    decisionReasonCode: "budget_confirmed",
    decidedByUid: "client-1",
  });

  assert.equal(result.decision.approvalType, "client_budget_authorization");
});

test("approval request type mismatch is rejected", async () => {
  const store = createFakeStore();
  store.__seedMatter({
    legalMatterId: "lm_1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
  });
  store.__seedApproval({
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 1,
  });
  const decide = buildRecordApprovalDecisionService({
    store,
    clock: () => NOW,
  });

  await assert.rejects(
    () => decide({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-decision",
      idempotencyKey: "idem-decision",
      expectedApprovalRequestVersion: 1,
      approvalRequestId: "lar_1",
      legalMatterId: "lm_1",
      approvalType: "lawyer_legal_approval",
      decision: "approved",
      decisionReasonCode: "legally_sufficient",
      decidedByUid: "lawyer-1",
    }),
    /approval type mismatch/,
  );
});

test("approval decision rejects stale approval request version", async () => {
  const store = createFakeStore();
  store.__seedMatter({
    legalMatterId: "lm_1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
  });
  store.__seedApproval({
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 2,
  });
  const decide = buildRecordApprovalDecisionService({
    store,
    clock: () => NOW,
  });

  await assert.rejects(
    () => decide({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-decision-stale",
      idempotencyKey: "idem-decision-stale",
      expectedApprovalRequestVersion: 1,
      approvalRequestId: "lar_1",
      legalMatterId: "lm_1",
      approvalType: "client_budget_authorization",
      decision: "approved",
      decisionReasonCode: "budget_confirmed",
      decidedByUid: "client-1",
    }),
    (error) =>
      error.code === "aborted" &&
      error.details.actualApprovalRequestVersion === 2,
  );
});

test("non-pending approval request cannot receive a new decision", async () => {
  const store = createFakeStore();
  store.__seedMatter({
    legalMatterId: "lm_1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
  });
  store.__seedApproval({
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    status: "approved",
    version: 1,
  });
  const decide = buildRecordApprovalDecisionService({
    store,
    clock: () => NOW,
  });

  await assert.rejects(
    () => decide({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-decision",
      idempotencyKey: "idem-decision",
      expectedApprovalRequestVersion: 1,
      approvalRequestId: "lar_1",
      legalMatterId: "lm_1",
      approvalType: "client_budget_authorization",
      decision: "approved",
      decisionReasonCode: "budget_confirmed",
      decidedByUid: "client-1",
    }),
    /not pending/,
  );
});

test("approval decision service is idempotent", async () => {
  const store = createFakeStore();
  store.__seedMatter({
    legalMatterId: "lm_1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
  });
  store.__seedApproval({
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 1,
  });
  const decide = buildRecordApprovalDecisionService({
    store,
    clock: () => NOW,
  });
  const command = {
    contractVersion: CONTRACT_VERSION,
    requestId: "req-decision",
    idempotencyKey: "idem-decision",
    expectedApprovalRequestVersion: 1,
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    decision: "approved",
    decisionReasonCode: "budget_confirmed",
    decidedByUid: "client-1",
  };

  const first = await decide(command);
  const second = await decide(command);

  assert.equal(first.resultId, second.resultId);
  assert.equal(second.idempotentReplay, true);
});

test("invalid clock is rejected at service construction", () => {
  assert.throws(
    () => buildCreateLegalMatterService({
      store: createFakeStore(),
      clock: () => "not-a-time",
    }),
    /ISO-8601/,
  );
});


test("create service scopes idempotency to tenant and command type", async () => {
  const calls = [];
  const store = createFakeStore({
    async getCommandReceipt(input) {
      calls.push(input);
      return null;
    },
  });
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });

  await createMatter(createCommand());

  assert.deepEqual(calls[0], {
    scopeType: "create_legal_matter",
    scopeId: "tenant-1",
    idempotencyKey: "idem-create-1",
  });
});

test("create service propagates transaction-level replay", async () => {
  const store = createFakeStore({
    async createLegalMatterAtomic({matter}) {
      return {matter, idempotentReplay: true};
    },
  });
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });

  const result = await createMatter(createCommand());
  assert.equal(result.idempotentReplay, true);
});

test("transition service propagates transaction-level replay", async () => {
  const store = createFakeStore();
  const createMatter = buildCreateLegalMatterService({
    store,
    clock: () => NOW,
  });
  const created = await createMatter(createCommand());

  store.transitionLegalMatterAtomic = async ({nextMatter}) => ({
    matter: nextMatter,
    idempotentReplay: true,
  });
  const transitionMatter = buildTransitionLegalMatterService({
    store,
    clock: () => NOW,
  });
  const result = await transitionMatter({
    contractVersion: CONTRACT_VERSION,
    requestId: "req-transition-race",
    idempotencyKey: "idem-transition-race",
    expectedVersion: 1,
    legalMatterId: created.resultId,
    nextStatus: "legal_review",
    reasonCode: "intake_accepted",
  });

  assert.equal(result.idempotentReplay, true);
});

test("approval service propagates transaction-level replay", async () => {
  const store = createFakeStore();
  store.__seedMatter({
    legalMatterId: "lm_1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
  });
  store.__seedApproval({
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 1,
  });
  store.recordApprovalDecisionAtomic = async ({decision}) => ({
    decision,
    idempotentReplay: true,
  });
  const decide = buildRecordApprovalDecisionService({
    store,
    clock: () => NOW,
  });

  const result = await decide({
    contractVersion: CONTRACT_VERSION,
    requestId: "req-approval-race",
    idempotencyKey: "idem-approval-race",
    expectedApprovalRequestVersion: 1,
    approvalRequestId: "lar_1",
    legalMatterId: "lm_1",
    approvalType: "client_budget_authorization",
    decision: "approved",
    decisionReasonCode: "budget_confirmed",
    decidedByUid: "client-1",
  });

  assert.equal(result.idempotentReplay, true);
});
