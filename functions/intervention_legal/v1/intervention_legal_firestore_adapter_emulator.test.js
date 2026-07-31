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
  CONTRACT_VERSION,
} = require("./contracts");
const {
  buildApprovalDecisionId,
  buildLegalMatterId,
  buildLegalMatterKey,
  buildMatterEventId,
} = require("./identifiers");
const {
  buildCreateLegalMatterService,
  buildRecordApprovalDecisionService,
  buildTransitionLegalMatterService,
} = require("./service");
const {
  FIRESTORE_COLLECTIONS,
  buildCommandReceiptId,
  createInterventionLegalFirestoreAdapter,
} = require("./firestore_adapter");

const PROJECT_ID = "demo-markakalkan-mhl-1b-1c";
const NOW = "2026-07-31T09:30:00.000Z";

let app;
let db;
let adapter;

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

async function countCollection(name) {
  return (await db.collection(name).get()).size;
}

async function eventCounts() {
  const snapshot = await db
      .collection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_EVENTS)
      .get();
  const records = snapshot.docs.map((doc) => doc.data());
  return {
    domainEvents: records.filter(
        (record) => record.recordType === "domain_event",
    ).length,
    receipts: records.filter(
        (record) => record.recordType === "command_receipt",
    ).length,
  };
}

async function seedCase({
  caseId = "case-1",
  tenantId = "tenant-1",
  canonicalBrandId = "brand-1",
  status = "open",
} = {}) {
  await db
      .collection(FIRESTORE_COLLECTIONS.CASE_FILES)
      .doc(caseId)
      .set({
        caseId,
        tenantId,
        canonicalBrandId,
        status,
      });
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

function buildServices() {
  return {
    createMatter: buildCreateLegalMatterService({
      store: adapter,
      clock: () => NOW,
    }),
    transitionMatter: buildTransitionLegalMatterService({
      store: adapter,
      clock: () => NOW,
    }),
    decideApproval: buildRecordApprovalDecisionService({
      store: adapter,
      clock: () => NOW,
    }),
  };
}

async function createMatter(overrides = {}) {
  await seedCase({
    caseId: overrides.caseId || "case-1",
    tenantId: overrides.tenantId || "tenant-1",
    canonicalBrandId:
      overrides.canonicalBrandId || "brand-1",
  });
  return buildServices().createMatter(createCommand(overrides));
}

async function seedApprovalRequest({
  approvalRequestId = "lar-1",
  legalMatterId,
  approvalType = "client_budget_authorization",
  preparedByUid = null,
} = {}) {
  await db
      .collection(FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS)
      .doc(approvalRequestId)
      .set({
        approvalRequestId,
        legalMatterId,
        approvalType,
        preparedByUid,
        status: "pending",
        version: 1,
      });
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "mhl-1b-1c-emulator");
  db = getFirestore(app);
  adapter = createInterventionLegalFirestoreAdapter(db);
});

beforeEach(async () => {
  await clearEmulator();
});

after(async () => {
  await clearEmulator();
  await deleteApp(app);
});

test("emulator guard uses only demo project and loopback host", () => {
  assert.match(PROJECT_ID, /^demo-/);
  assert.match(
      assertEmulatorGuard(),
      /^(127\.0\.0\.1|localhost):\d+$/,
  );
});

test("create service writes one atomic matter event receipt bundle", async () => {
  const result = await createMatter();

  assert.equal(result.idempotentReplay, false);
  assert.equal(
      await countCollection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES),
      1,
  );
  assert.deepEqual(await eventCounts(), {
    domainEvents: 1,
    receipts: 1,
  });
});

test("parallel exact create collapses to one atomic winner", async () => {
  await seedCase();
  const create = buildServices().createMatter;
  const command = createCommand();

  const results = await Promise.all([
    create(command),
    create(command),
  ]);

  assert.deepEqual(
      results.map((item) => item.idempotentReplay).sort(),
      [false, true],
  );
  assert.equal(
      await countCollection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES),
      1,
  );
  assert.deepEqual(await eventCounts(), {
    domainEvents: 1,
    receipts: 1,
  });
});

test("conflicting parallel create keeps one complete winner", async () => {
  await seedCase();
  const create = buildServices().createMatter;
  const first = createCommand();
  const second = createCommand({
    matterScopeCode: "domain_enforcement",
  });

  const results = await Promise.allSettled([
    create(first),
    create(second),
  ]);
  const fulfilled = results.filter(
      (item) => item.status === "fulfilled",
  );
  const rejected = results.filter(
      (item) => item.status === "rejected",
  );

  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);
  assert.equal(rejected[0].reason.code, "already-exists");
  assert.equal(
      await countCollection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES),
      1,
  );
  assert.deepEqual(await eventCounts(), {
    domainEvents: 1,
    receipts: 1,
  });
});

test("same idempotency key is isolated across tenants", async () => {
  await seedCase();
  await seedCase({
    caseId: "case-2",
    tenantId: "tenant-2",
    canonicalBrandId: "brand-2",
  });
  const create = buildServices().createMatter;

  const results = await Promise.all([
    create(createCommand()),
    create(createCommand({
      requestId: "req-create-2",
      tenantId: "tenant-2",
      canonicalBrandId: "brand-2",
      caseId: "case-2",
      jurisdictionCode: "us.federal",
      countryCode: "US",
    })),
  ]);

  assert.equal(results.every(
      (item) => item.idempotentReplay === false,
  ), true);
  assert.equal(
      await countCollection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES),
      2,
  );
  assert.deepEqual(await eventCounts(), {
    domainEvents: 2,
    receipts: 2,
  });
});

test("case scope mismatch leaves no MHL writes", async () => {
  await seedCase({
    tenantId: "tenant-other",
  });

  await assert.rejects(
      () => buildServices().createMatter(createCommand()),
      (error) => error.code === "permission-denied",
  );
  assert.equal(
      await countCollection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES),
      0,
  );
  assert.deepEqual(await eventCounts(), {
    domainEvents: 0,
    receipts: 0,
  });
});

test("transition persists matter event and receipt atomically", async () => {
  const created = await createMatter();
  const result = await buildServices().transitionMatter({
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
  assert.deepEqual(await eventCounts(), {
    domainEvents: 2,
    receipts: 2,
  });
});

test("parallel competing transitions commit only one winner", async () => {
  const created = await createMatter();
  const transition = buildServices().transitionMatter;
  const common = {
    contractVersion: CONTRACT_VERSION,
    expectedVersion: 1,
    legalMatterId: created.resultId,
  };

  const results = await Promise.allSettled([
    transition({
      ...common,
      requestId: "req-transition-a",
      idempotencyKey: "idem-transition-a",
      nextStatus: "legal_review",
      reasonCode: "intake_accepted",
    }),
    transition({
      ...common,
      requestId: "req-transition-b",
      idempotencyKey: "idem-transition-b",
      nextStatus: "cancelled",
      reasonCode: "intake_cancelled",
    }),
  ]);
  const fulfilled = results.filter(
      (item) => item.status === "fulfilled",
  );
  const rejected = results.filter(
      (item) => item.status === "rejected",
  );

  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);
  assert.equal(rejected[0].reason.code, "aborted");
  const persisted = await adapter.getLegalMatterById({
    legalMatterId: created.resultId,
  });
  assert.equal(persisted.version, 2);
  assert.deepEqual(await eventCounts(), {
    domainEvents: 2,
    receipts: 2,
  });
});

test("pre-existing event conflict rolls back matter and receipt", async () => {
  const identity = createCommand();
  const legalMatterKey = buildLegalMatterKey(identity);
  const legalMatterId = buildLegalMatterId(identity);
  const eventType = "legal_matter_created";
  const eventId = buildMatterEventId({
    legalMatterId,
    requestId: identity.requestId,
    eventType,
  });
  await db
      .collection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_EVENTS)
      .doc(eventId)
      .set({
        eventId,
        recordType: "domain_event",
        immutable: true,
      });

  const matter = {
    ...identity,
    legalMatterId,
    legalMatterKey,
    status: "intake_pending",
    version: 1,
    createdAt: NOW,
    updatedAt: NOW,
  };
  const event = {
    eventId,
    legalMatterId,
    eventType,
    requestId: identity.requestId,
    idempotencyKey: identity.idempotencyKey,
    eventData: {},
    recordedAt: NOW,
  };
  const receipt = {
    contractVersion: CONTRACT_VERSION,
    requestId: identity.requestId,
    idempotencyKey: identity.idempotencyKey,
    payloadFingerprint: "a".repeat(64),
    resultType: "legal_matter",
    resultId: legalMatterId,
    recordedAt: NOW,
  };

  await assert.rejects(
      () => adapter.createLegalMatterAtomic({
        matter,
        event,
        receipt,
      }),
      (error) => error.code === "already-exists",
  );
  assert.equal(
      await adapter.getLegalMatterById({legalMatterId}),
      null,
  );
  const receiptId = buildCommandReceiptId({
    scopeType: "create_legal_matter",
    scopeId: identity.tenantId,
    idempotencyKey: identity.idempotencyKey,
  });
  assert.equal(
      (
        await db
            .collection(FIRESTORE_COLLECTIONS.LEGAL_MATTER_EVENTS)
            .doc(receiptId)
            .get()
      ).exists,
      false,
  );
});

test("tenant owner approval commits immutable decision bundle", async () => {
  const created = await createMatter();
  await seedApprovalRequest({
    legalMatterId: created.resultId,
  });
  await db
      .collection(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS)
      .doc("membership-owner")
      .set({
        tenantId: "tenant-1",
        uid: "client-1",
        role: "owner",
        status: "active",
      });

  const result = await buildServices().decideApproval({
    contractVersion: CONTRACT_VERSION,
    requestId: "req-approval-1",
    idempotencyKey: "idem-approval-1",
    approvalRequestId: "lar-1",
    legalMatterId: created.resultId,
    approvalType: "client_budget_authorization",
    decision: "approved",
    decisionReasonCode: "budget_confirmed",
    decidedByUid: "client-1",
  });

  assert.equal(result.decision.immutable, true);
  assert.equal(
      await countCollection(
          FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_DECISIONS,
      ),
      1,
  );
  assert.equal(
      (
        await db
            .collection(FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS)
            .doc("lar-1")
            .get()
      ).data().status,
      "approved",
  );
  assert.deepEqual(await eventCounts(), {
    domainEvents: 2,
    receipts: 2,
  });
});

test("unauthorized client approval creates no decision bundle", async () => {
  const created = await createMatter();
  await seedApprovalRequest({
    legalMatterId: created.resultId,
  });

  await assert.rejects(
      () => buildServices().decideApproval({
        contractVersion: CONTRACT_VERSION,
        requestId: "req-approval-unauthorized",
        idempotencyKey: "idem-approval-unauthorized",
        approvalRequestId: "lar-1",
        legalMatterId: created.resultId,
        approvalType: "client_budget_authorization",
        decision: "approved",
        decisionReasonCode: "budget_confirmed",
        decidedByUid: "unknown-client",
      }),
      (error) => error.code === "permission-denied",
  );

  assert.equal(
      await countCollection(
          FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_DECISIONS,
      ),
      0,
  );
  assert.equal(
      (
        await db
            .collection(FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS)
            .doc("lar-1")
            .get()
      ).data().status,
      "pending",
  );
  assert.deepEqual(await eventCounts(), {
    domainEvents: 1,
    receipts: 1,
  });
});

test("active covered lawyer can commit legal approval", async () => {
  const created = await createMatter();
  await seedApprovalRequest({
    legalMatterId: created.resultId,
    approvalType: "lawyer_legal_approval",
    preparedByUid: "operations-1",
  });
  await db
      .collection(FIRESTORE_COLLECTIONS.LEGAL_TEAM_PROFILES)
      .doc("lawyer-1")
      .set({
        uid: "lawyer-1",
        status: "active",
        roleCodes: ["responsible_lawyer"],
        jurisdictionCodes: ["tr.istanbul"],
      });

  const result = await buildServices().decideApproval({
    contractVersion: CONTRACT_VERSION,
    requestId: "req-lawyer-approval",
    idempotencyKey: "idem-lawyer-approval",
    approvalRequestId: "lar-1",
    legalMatterId: created.resultId,
    approvalType: "lawyer_legal_approval",
    decision: "approved",
    decisionReasonCode: "legally_sufficient",
    decidedByUid: "lawyer-1",
  });

  const expectedDecisionId = buildApprovalDecisionId({
    approvalRequestId: "lar-1",
    decidedByUid: "lawyer-1",
    decision: "approved",
  });
  assert.equal(result.resultId, expectedDecisionId);
  assert.equal(
      await countCollection(
          FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_DECISIONS,
      ),
      1,
  );
});
