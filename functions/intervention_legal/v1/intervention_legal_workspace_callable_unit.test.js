"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  WORKSPACE_CONTRACT_VERSION,
  WORKSPACE_CALLABLE_NAME,
  READ_OPERATION_CODE,
  DEFAULT_LIMIT,
  MAX_LIMIT,
  parseWorkspaceQuery,
  resolveAuthorityScopes,
  buildInterventionLegalWorkspaceService,
  buildGetInterventionLegalWorkspaceCallable,
} = require("./workspace_callable");

function row(documentId, data) {
  return {documentId, data};
}

function baseMatter(overrides = {}) {
  return {
    legalMatterId: "lm-1",
    caseId: "case-1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    jurisdictionCode: "tr.istanbul",
    countryCode: "TR",
    matterScopeCode: "platform_takedown",
    priorityCode: "high",
    title: "Canlı hukuki dosya",
    status: "legal_review",
    version: 2,
    sourceSystemCode: "case_evidence_center",
    sourceRecordId: "case-1",
    createdAt: "2026-08-01T10:00:00.000Z",
    updatedAt: "2026-08-01T11:00:00.000Z",
    createdByUid: "user-1",
    updatedByUid: "user-1",
    statusChangedByUid: "user-1",
    ...overrides,
  };
}

function baseRequest(overrides = {}) {
  return {
    approvalRequestId: "lar-1",
    legalMatterId: "lm-1",
    approvalType: "client_action_authorization",
    status: "approved",
    version: 2,
    requestSequence: 2,
    requestReasonCode: "legal_action_authorization_required",
    requestNote: "Hukuki işlem yetkilendirme talebi.",
    preparedByUid: "user-1",
    decisionId: "lad-1",
    decidedByUid: "user-1",
    createdAt: "2026-08-01T10:30:00.000Z",
    updatedAt: "2026-08-01T11:30:00.000Z",
    decidedAt: "2026-08-01T11:30:00.000Z",
    ...overrides,
  };
}

function baseDecision(overrides = {}) {
  return {
    decisionId: "lad-1",
    approvalRequestId: "lar-1",
    legalMatterId: "lm-1",
    approvalType: "client_action_authorization",
    decision: "approved",
    decisionReasonCode: "client_action_authorized",
    decisionNote: null,
    decidedByUid: "user-1",
    decidedAt: "2026-08-01T11:30:00.000Z",
    immutable: true,
    ...overrides,
  };
}

function readerFixture(overrides = {}) {
  return {
    async listMembershipsByUid() {
      return [
        row("membership-1", {
          uid: "user-1",
          tenantId: "tenant-1",
          role: "owner",
          status: "active",
        }),
      ];
    },
    async listMattersByTenant() {
      return [row("lm-1", baseMatter())];
    },
    async listApprovalRequestsByMatter() {
      return [row("lar-1", baseRequest())];
    },
    async listApprovalDecisionsByMatter() {
      return [row("lad-1", baseDecision())];
    },
    ...overrides,
  };
}

function callableRequest(data = {}, overrides = {}) {
  return {
    auth: {uid: "user-1"},
    app: {appId: "verified-app"},
    data,
    ...overrides,
  };
}

function createLog() {
  return {
    errors: [],
    error(message, payload) {
      this.errors.push({message, payload});
    },
  };
}

test("workspace callable constants are stable", () => {
  assert.equal(
      WORKSPACE_CONTRACT_VERSION,
      "intervention-legal-workspace-v1",
  );
  assert.equal(
      WORKSPACE_CALLABLE_NAME,
      "getInterventionLegalWorkspace",
  );
  assert.equal(
      READ_OPERATION_CODE,
      "read_legal_matter_workspace",
  );
  assert.equal(DEFAULT_LIMIT, 20);
  assert.equal(MAX_LIMIT, 50);
});

test("workspace query uses a bounded default limit", () => {
  assert.deepEqual(
      parseWorkspaceQuery({
        contractVersion: WORKSPACE_CONTRACT_VERSION,
      }),
      {
        contractVersion: WORKSPACE_CONTRACT_VERSION,
        limit: 20,
      },
  );
});

test("workspace query rejects unsupported fields and invalid limits", () => {
  assert.throws(
      () => parseWorkspaceQuery({
        contractVersion: WORKSPACE_CONTRACT_VERSION,
        tenantId: "client-controlled",
      }),
      (error) =>
        error.code === "invalid-argument" &&
        error.message === "unsupported request fields",
  );

  for (const limit of [0, 51, 1.5, "20"]) {
    assert.throws(
        () => parseWorkspaceQuery({
          contractVersion: WORKSPACE_CONTRACT_VERSION,
          limit,
        }),
        (error) =>
          error.code === "invalid-argument" &&
          error.message.includes("limit must be an integer"),
    );
  }
});

test("authority scopes prefer tenant owner and merge delegations", () => {
  const scopes = resolveAuthorityScopes([
    row("delegated-1", {
      tenantId: "tenant-1",
      status: "active",
      role: "member",
      delegatedLegalMatterOperations: [READ_OPERATION_CODE],
      delegatedCanonicalBrandIds: ["brand-1"],
    }),
    row("delegated-2", {
      tenantId: "tenant-1",
      status: "active",
      role: "member",
      delegatedLegalMatterOperations: [READ_OPERATION_CODE],
      delegatedCanonicalBrandIds: ["brand-2"],
    }),
    row("owner", {
      tenantId: "tenant-1",
      status: "active",
      role: "owner",
    }),
    row("inactive", {
      tenantId: "tenant-2",
      status: "inactive",
      role: "owner",
    }),
  ]);

  assert.deepEqual(scopes, [
    {
      tenantId: "tenant-1",
      allBrands: true,
      allowedBrandIds: [],
      authoritySource: "tenant_owner",
    },
  ]);
});

// eslint-disable-next-line max-len
test("service returns projected matter, approval, decision and counts", async () => {
  const service = buildInterventionLegalWorkspaceService({
    reader: readerFixture(),
    clock: () => "2026-08-01T12:00:00.000Z",
  });

  const result = await service({
    uid: "user-1",
    raw: {
      contractVersion: WORKSPACE_CONTRACT_VERSION,
      limit: 10,
    },
  });

  assert.equal(result.contractVersion, WORKSPACE_CONTRACT_VERSION);
  assert.equal(result.generatedAt, "2026-08-01T12:00:00.000Z");
  assert.equal(result.limit, 10);
  assert.equal(result.authorityScopeCount, 1);
  assert.deepEqual(result.counts, {
    legalMatterCount: 1,
    activeLegalMatterCount: 1,
    pendingApprovalCount: 0,
    approvedApprovalCount: 1,
    rejectedApprovalCount: 0,
  });
  assert.equal(result.matters.length, 1);
  assert.equal(result.matters[0].legalMatterId, "lm-1");
  assert.equal(result.matters[0].approvalRequests.length, 1);
  assert.equal(
      result.matters[0].approvalRequests[0].status,
      "approved",
  );
  assert.equal(result.matters[0].approvalDecisions.length, 1);
  assert.equal(
      result.matters[0].approvalDecisions[0].decisionReasonCode,
      "client_action_authorized",
  );
  assert.equal(
      Object.prototype.hasOwnProperty.call(
          result.matters[0],
          "internalOnly",
      ),
      false,
  );
});

test("delegated scope only exposes explicitly allowed brands", async () => {
  const reader = readerFixture({
    async listMembershipsByUid() {
      return [
        row("membership-1", {
          uid: "user-1",
          tenantId: "tenant-1",
          role: "member",
          status: "active",
          delegatedLegalMatterOperations: [READ_OPERATION_CODE],
          delegatedCanonicalBrandIds: ["brand-1"],
        }),
      ];
    },
    async listMattersByTenant() {
      return [
        row("lm-1", baseMatter()),
        row("lm-2", baseMatter({
          legalMatterId: "lm-2",
          canonicalBrandId: "brand-2",
          caseId: "case-2",
        })),
      ];
    },
    async listApprovalRequestsByMatter({legalMatterId}) {
      return legalMatterId === "lm-1" ?
        [row("lar-1", baseRequest())] :
        [];
    },
    async listApprovalDecisionsByMatter({legalMatterId}) {
      return legalMatterId === "lm-1" ?
        [row("lad-1", baseDecision())] :
        [];
    },
  });
  const service = buildInterventionLegalWorkspaceService({
    reader,
    clock: () => "2026-08-01T12:00:00.000Z",
  });

  const result = await service({
    uid: "user-1",
    raw: {contractVersion: WORKSPACE_CONTRACT_VERSION},
  });

  assert.deepEqual(
      result.matters.map((matter) => matter.legalMatterId),
      ["lm-1"],
  );
});

// eslint-disable-next-line max-len
test("service rejects users without an active read authority scope", async () => {
  const service = buildInterventionLegalWorkspaceService({
    reader: readerFixture({
      async listMembershipsByUid() {
        return [
          row("membership-1", {
            uid: "user-1",
            tenantId: "tenant-1",
            role: "member",
            status: "active",
            delegatedLegalMatterOperations: [],
            delegatedCanonicalBrandIds: [],
          }),
        ];
      },
    }),
  });

  await assert.rejects(
      service({
        uid: "user-1",
        raw: {contractVersion: WORKSPACE_CONTRACT_VERSION},
      }),
      (error) =>
        error.code === "permission-denied" &&
        error.message.includes("yetkiniz yok"),
  );
});

// eslint-disable-next-line max-len
test("callable builder keeps App Check options and injects auth uid", async () => {
  const captures = [];
  const calls = [];
  const log = createLog();

  const callable = buildGetInterventionLegalWorkspaceCallable({
    service: async ({uid, raw}) => {
      calls.push({uid, raw});
      return {
        contractVersion: WORKSPACE_CONTRACT_VERSION,
        generatedAt: "2026-08-01T12:00:00.000Z",
        limit: 20,
        authorityScopeCount: 1,
        counts: {
          legalMatterCount: 0,
          activeLegalMatterCount: 0,
          pendingApprovalCount: 0,
          approvedApprovalCount: 0,
          rejectedApprovalCount: 0,
        },
        matters: [],
      };
    },
    db: {},
    reader: readerFixture(),
    onCallImpl(options, handler) {
      captures.push({options, handler});
      return handler;
    },
    log,
  });

  assert.deepEqual(captures[0].options, {
    region: "europe-west3",
    enforceAppCheck: true,
    maxInstances: 1,
  });

  const result = await callable(
      callableRequest({
        contractVersion: WORKSPACE_CONTRACT_VERSION,
      }),
  );

  assert.equal(result.contractVersion, WORKSPACE_CONTRACT_VERSION);
  assert.deepEqual(calls, [{
    uid: "user-1",
    raw: {contractVersion: WORKSPACE_CONTRACT_VERSION},
  }]);
  assert.equal(log.errors.length, 0);
});

// eslint-disable-next-line max-len
test("callable maps unauthenticated and missing App Check requests", async () => {
  const callable = buildGetInterventionLegalWorkspaceCallable({
    service: async () => {
      throw new Error("service must not be called");
    },
    db: {},
    reader: readerFixture(),
    onCallImpl: (_, handler) => handler,
    log: createLog(),
  });

  await assert.rejects(
      callable(callableRequest(
          {contractVersion: WORKSPACE_CONTRACT_VERSION},
          {auth: null},
      )),
      (error) => error instanceof Error && error.code === "unauthenticated",
  );

  await assert.rejects(
      callable(callableRequest(
          {contractVersion: WORKSPACE_CONTRACT_VERSION},
          {app: null},
      )),
      (error) =>
        error instanceof Error &&
        error.code === "failed-precondition",
  );
});
