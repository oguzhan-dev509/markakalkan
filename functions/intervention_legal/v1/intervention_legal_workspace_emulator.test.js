/* eslint-disable max-len */
"use strict";

const {
  after,
  before,
  beforeEach,
  test,
} = require("node:test");
const assert = require("node:assert/strict");
const {
  deleteApp,
  initializeApp,
} = require("firebase-admin/app");
const {
  getFirestore,
} = require("firebase-admin/firestore");

const {
  WORKSPACE_CONTRACT_VERSION,
  READ_OPERATION_CODE,
  createWorkspaceReader,
  buildInterventionLegalWorkspaceService,
} = require("./workspace_callable");

const PROJECT_ID = "demo-markakalkan-mhl-1b-1c";
const NOW = "2026-08-01T18:48:17.930Z";

let app;
let db;

function assertEmulatorGuard() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "";
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
    throw new Error("FIRESTORE_EMULATOR_HOST must be loopback");
  }
  const environmentProject =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    "";
  if (environmentProject && environmentProject !== PROJECT_ID) {
    throw new Error("emulator project must be the locked demo project");
  }
  return host;
}

async function clearEmulator() {
  const host = assertEmulatorGuard();
  const url =
    `http://${host}/emulator/v1/projects/${PROJECT_ID}` +
    "/databases/(default)/documents";
  const response = await fetch(url, {method: "DELETE"});
  if (!response.ok) {
    throw new Error(`emulator clear failed: ${response.status}`);
  }
}

async function seedOwner({
  uid = "owner-1",
  tenantId = "tenant-1",
} = {}) {
  await db.collection("tenant_memberships").doc(`${tenantId}-${uid}`).set({
    uid,
    tenantId,
    role: "owner",
    status: "active",
  });
}

async function seedDelegated({
  uid = "delegate-1",
  tenantId = "tenant-1",
  brandIds = ["brand-1"],
  operations = [READ_OPERATION_CODE],
} = {}) {
  await db.collection("tenant_memberships").doc(`${tenantId}-${uid}`).set({
    uid,
    tenantId,
    role: "member",
    status: "active",
    delegatedLegalMatterOperations: operations,
    delegatedCanonicalBrandIds: brandIds,
  });
}

async function seedMatter({
  legalMatterId = "lm-1",
  tenantId = "tenant-1",
  canonicalBrandId = "brand-1",
  caseId = "case-1",
  status = "legal_review",
} = {}) {
  await db.collection("legal_matter_files").doc(legalMatterId).set({
    legalMatterId,
    tenantId,
    canonicalBrandId,
    caseId,
    jurisdictionCode: "tr.istanbul",
    countryCode: "TR",
    matterScopeCode: "platform_takedown",
    priorityCode: "high",
    title: `Hukuki dosya ${legalMatterId}`,
    status,
    version: 2,
    sourceSystemCode: "case_evidence_center",
    sourceRecordId: caseId,
    createdAt: NOW,
    updatedAt: NOW,
    createdByUid: "owner-1",
    updatedByUid: "owner-1",
    statusChangedByUid: "owner-1",
  });
}

async function seedApproval({
  legalMatterId = "lm-1",
  approvalRequestId = "lar-1",
  decisionId = "lad-1",
} = {}) {
  await db.collection("legal_approval_requests").doc(approvalRequestId).set({
    approvalRequestId,
    legalMatterId,
    approvalType: "client_action_authorization",
    status: "approved",
    version: 2,
    requestSequence: 2,
    requestReasonCode: "legal_action_authorization_required",
    requestNote: "Hukuki işlem yetkilendirme talebi.",
    preparedByUid: "owner-1",
    decisionId,
    decidedByUid: "owner-1",
    createdAt: NOW,
    updatedAt: NOW,
    decidedAt: NOW,
  });

  await db.collection("legal_approval_decisions").doc(decisionId).set({
    decisionId,
    approvalRequestId,
    legalMatterId,
    approvalType: "client_action_authorization",
    decision: "approved",
    decisionReasonCode: "client_action_authorized",
    decisionNote: null,
    decidedByUid: "owner-1",
    decidedAt: NOW,
    immutable: true,
  });
}

function service() {
  return buildInterventionLegalWorkspaceService({
    reader: createWorkspaceReader(db),
    clock: () => NOW,
  });
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "mhl-workspace-emulator");
  db = getFirestore(app);
});

beforeEach(async () => {
  await clearEmulator();
});

after(async () => {
  await clearEmulator();
  await deleteApp(app);
});

test("owner reads tenant matters with approval and decision projections", async () => {
  await seedOwner();
  await seedMatter();
  await seedApproval();

  const result = await service()({
    uid: "owner-1",
    raw: {contractVersion: WORKSPACE_CONTRACT_VERSION},
  });

  assert.deepEqual(result.counts, {
    legalMatterCount: 1,
    activeLegalMatterCount: 1,
    pendingApprovalCount: 0,
    approvedApprovalCount: 1,
    rejectedApprovalCount: 0,
  });
  assert.equal(result.matters[0].legalMatterId, "lm-1");
  assert.equal(result.matters[0].approvalRequests[0].status, "approved");
  assert.equal(
      result.matters[0].approvalDecisions[0].decisionReasonCode,
      "client_action_authorized",
  );
});

test("delegated reader receives only explicitly allowed brand matters", async () => {
  await seedDelegated();
  await seedMatter();
  await seedMatter({
    legalMatterId: "lm-2",
    canonicalBrandId: "brand-2",
    caseId: "case-2",
  });

  const result = await service()({
    uid: "delegate-1",
    raw: {contractVersion: WORKSPACE_CONTRACT_VERSION},
  });

  assert.deepEqual(
      result.matters.map((matter) => matter.legalMatterId),
      ["lm-1"],
  );
});

test("user without owner or read delegation cannot read workspace", async () => {
  await seedDelegated({
    uid: "member-1",
    operations: [],
    brandIds: [],
  });
  await seedMatter();

  await assert.rejects(
      service()({
        uid: "member-1",
        raw: {contractVersion: WORKSPACE_CONTRACT_VERSION},
      }),
      (error) => error.code === "permission-denied",
  );
});
