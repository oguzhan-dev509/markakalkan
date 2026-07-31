"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  InterventionLegalContractError,
} = require("./contracts");
const {
  buildLegalMatterId,
  buildLegalMatterKey,
  buildMatterEventId,
  buildApprovalDecisionId,
} = require("./identifiers");
const {
  FIRESTORE_COLLECTIONS,
  COMMAND_RECEIPT_RECORD_TYPE,
  buildCommandReceiptId,
  buildMatterIdFromKey,
  createInterventionLegalFirestoreAdapter,
} = require("./firestore_adapter");

function clone(value) {
  return value === undefined ? undefined :
    JSON.parse(JSON.stringify(value));
}

class FakeSnapshot {
  constructor(ref, data) {
    this.ref = ref;
    this.id = ref.id;
    this.exists = data !== undefined;
    this._data = clone(data);
  }

  data() {
    return clone(this._data);
  }
}

class FakeQuerySnapshot {
  constructor(docs) {
    this.docs = docs;
    this.empty = docs.length === 0;
    this.size = docs.length;
  }
}

class FakeDocumentRef {
  constructor(db, collectionName, id) {
    this.db = db;
    this.collectionName = collectionName;
    this.id = id;
    this.path = `${collectionName}/${id}`;
  }

  async get() {
    return new FakeSnapshot(this, this.db._docs.get(this.path));
  }
}

class FakeQuery {
  constructor(db, collectionName, filters = [], limitCount = null) {
    this.db = db;
    this.collectionName = collectionName;
    this.filters = filters;
    this.limitCount = limitCount;
  }

  where(field, operator, value) {
    if (operator !== "==") throw new Error("only == is supported");
    return new FakeQuery(
      this.db,
      this.collectionName,
      [...this.filters, {field, value}],
      this.limitCount,
    );
  }

  limit(value) {
    return new FakeQuery(
      this.db,
      this.collectionName,
      this.filters,
      value,
    );
  }

  async get() {
    return this.db._query(
      this.collectionName,
      this.filters,
      this.limitCount,
    );
  }
}

class FakeCollectionRef extends FakeQuery {
  constructor(db, collectionName) {
    super(db, collectionName);
    this.collectionName = collectionName;
  }

  doc(id) {
    return new FakeDocumentRef(this.db, this.collectionName, id);
  }
}

class FakeTransaction {
  constructor(db, workingDocs) {
    this.db = db;
    this.workingDocs = workingDocs;
  }

  async get(target) {
    if (target instanceof FakeDocumentRef) {
      return new FakeSnapshot(
        target,
        this.workingDocs.get(target.path),
      );
    }
    if (target instanceof FakeQuery) {
      return this.db._query(
        target.collectionName,
        target.filters,
        target.limitCount,
        this.workingDocs,
      );
    }
    throw new Error("unsupported transaction target");
  }

  create(ref, value) {
    if (this.workingDocs.has(ref.path)) {
      throw new Error(`already exists: ${ref.path}`);
    }
    this.workingDocs.set(ref.path, clone(value));
  }

  update(ref, value) {
    if (!this.workingDocs.has(ref.path)) {
      throw new Error(`not found: ${ref.path}`);
    }
    this.workingDocs.set(ref.path, clone(value));
  }
}

class FakeFirestore {
  constructor() {
    this._docs = new Map();
  }

  collection(name) {
    return new FakeCollectionRef(this, name);
  }

  async runTransaction(callback) {
    const working = new Map(
      [...this._docs.entries()].map(([key, value]) => [
        key,
        clone(value),
      ]),
    );
    const result = await callback(new FakeTransaction(this, working));
    this._docs = working;
    return result;
  }

  seed(collectionName, id, value) {
    this._docs.set(`${collectionName}/${id}`, clone(value));
  }

  read(collectionName, id) {
    return clone(this._docs.get(`${collectionName}/${id}`));
  }

  async _query(collectionName, filters, limitCount, source = this._docs) {
    const prefix = `${collectionName}/`;
    const docs = [];
    for (const [path, value] of source.entries()) {
      if (!path.startsWith(prefix)) continue;
      const id = path.slice(prefix.length);
      const matches = filters.every(
        ({field, value: expected}) => value[field] === expected,
      );
      if (!matches) continue;
      docs.push(
        new FakeSnapshot(
          new FakeDocumentRef(this, collectionName, id),
          value,
        ),
      );
      if (limitCount !== null && docs.length >= limitCount) break;
    }
    return new FakeQuerySnapshot(docs);
  }
}

function matterIdentity() {
  return {
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    caseId: "case-1",
    jurisdictionCode: "tr.istanbul",
    matterScopeCode: "counterfeit_enforcement",
    countryCode: "TR",
  };
}

function matterDocument(overrides = {}) {
  const identity = matterIdentity();
  const legalMatterKey = buildLegalMatterKey(identity);
  return {
    contractVersion: "intervention-legal-core-v1",
    legalMatterId: buildLegalMatterId(identity),
    legalMatterKey,
    ...identity,
    status: "intake_pending",
    version: 1,
    createdAt: "2026-07-31T09:00:00.000Z",
    updatedAt: "2026-07-31T09:00:00.000Z",
    ...overrides,
  };
}

function eventDocument({
  legalMatterId,
  requestId,
  eventType = "legal_matter_created",
} = {}) {
  const matter = matterDocument();
  const resolvedMatterId = legalMatterId || matter.legalMatterId;
  const resolvedRequestId = requestId || "req-1";
  return {
    eventId: buildMatterEventId({
      legalMatterId: resolvedMatterId,
      requestId: resolvedRequestId,
      eventType,
    }),
    contractVersion: "intervention-legal-core-v1",
    legalMatterId: resolvedMatterId,
    eventType,
    requestId: resolvedRequestId,
    idempotencyKey: "idem-1",
    actorUid: "owner-1",
    eventData: {status: "intake_pending"},
    recordedAt: "2026-07-31T09:00:00.000Z",
  };
}

function receiptDocument(overrides = {}) {
  return {
    contractVersion: "intervention-legal-core-v1",
    requestId: "req-1",
    idempotencyKey: "idem-1",
    payloadFingerprint: "a".repeat(64),
    resultType: "legal_matter",
    resultId: matterDocument().legalMatterId,
    actorUid: "owner-1",
    recordedAt: "2026-07-31T09:00:00.000Z",
    ...overrides,
  };
}

test("adapter exports the locked collection names", () => {
  assert.equal(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    "legal_matter_files",
  );
  assert.equal(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_EVENTS,
    "legal_matter_events",
  );
  assert.equal(
    FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_DECISIONS,
    "legal_approval_decisions",
  );
});

test("adapter rejects a non-Firestore dependency", () => {
  assert.throws(
    () => createInterventionLegalFirestoreAdapter({}),
    /Firestore-compatible/,
  );
});

test("receipt id is deterministic and isolated by scope", () => {
  const one = buildCommandReceiptId({
    scopeType: "legal_matter",
    scopeId: "lm_1",
    idempotencyKey: "idem",
  });
  const two = buildCommandReceiptId({
    scopeType: "legal_approval_decision",
    scopeId: "lm_1",
    idempotencyKey: "idem",
  });
  assert.match(one, /^lmr_[a-f0-9]{24}$/);
  assert.notEqual(one, two);
});

test("matter id derived from key matches locked identifier algorithm", () => {
  const matter = matterDocument();
  assert.equal(
    buildMatterIdFromKey(matter.legalMatterKey),
    matter.legalMatterId,
  );
});

test("resolveCaseScope returns canonical tenant and brand scope", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.CASE_FILES, "case-1", {
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    status: "open",
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);
  assert.deepEqual(
    await adapter.resolveCaseScope({caseId: "case-1"}),
    {
      caseId: "case-1",
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      status: "open",
      archived: false,
    },
  );
});

test("resolveCaseScope returns null for missing case", async () => {
  const adapter = createInterventionLegalFirestoreAdapter(
    new FakeFirestore(),
  );
  assert.equal(
    await adapter.resolveCaseScope({caseId: "missing"}),
    null,
  );
});

test("resolveCaseScope marks archived dispositions", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.CASE_FILES, "case-1", {
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    dispositionStatus: "archived",
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);
  assert.equal(
    (await adapter.resolveCaseScope({caseId: "case-1"})).archived,
    true,
  );
});

test("findLegalMatterByKey uses deterministic direct lookup", async () => {
  const db = new FakeFirestore();
  const matter = matterDocument();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    matter.legalMatterId,
    matter,
  );
  const adapter = createInterventionLegalFirestoreAdapter(db);
  assert.deepEqual(
    await adapter.findLegalMatterByKey({
      tenantId: matter.tenantId,
      legalMatterKey: matter.legalMatterKey,
    }),
    matter,
  );
});

test("findLegalMatterByKey rejects a corrupted deterministic scope", async () => {
  const db = new FakeFirestore();
  const matter = matterDocument();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    matter.legalMatterId,
    {...matter, tenantId: "other-tenant"},
  );
  const adapter = createInterventionLegalFirestoreAdapter(db);
  await assert.rejects(
    () => adapter.findLegalMatterByKey({
      tenantId: matter.tenantId,
      legalMatterKey: matter.legalMatterKey,
    }),
    (error) => error.code === "internal",
  );
});

test("getLegalMatterById returns null when absent", async () => {
  const adapter = createInterventionLegalFirestoreAdapter(
    new FakeFirestore(),
  );
  assert.equal(
    await adapter.getLegalMatterById({legalMatterId: "lm_missing"}),
    null,
  );
});

test("createLegalMatterAtomic creates matter event and receipt", async () => {
  const db = new FakeFirestore();
  const adapter = createInterventionLegalFirestoreAdapter(db);
  const matter = matterDocument();
  const event = eventDocument();
  const receipt = receiptDocument();

  const result = await adapter.createLegalMatterAtomic({
    matter,
    event,
    receipt,
  });

  assert.equal(result.idempotentReplay, false);
  assert.deepEqual(
    db.read(
      FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
      matter.legalMatterId,
    ),
    matter,
  );
  const storedEvent = db.read(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_EVENTS,
    event.eventId,
  );
  assert.equal(storedEvent.recordType, "domain_event");
  assert.equal(storedEvent.tenantId, matter.tenantId);
  assert.equal(storedEvent.actorUid, "owner-1");
  const receiptId = buildCommandReceiptId({
    scopeType: "create_legal_matter",
    scopeId: matter.tenantId,
    idempotencyKey: receipt.idempotencyKey,
  });
  const storedReceipt = db.read(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_EVENTS,
    receiptId,
  );
  assert.equal(
    storedReceipt.recordType,
    COMMAND_RECEIPT_RECORD_TYPE,
  );
  assert.equal(storedReceipt.projectionEligible, false);
  assert.equal(storedReceipt.actorUid, "owner-1");
});

test("getCommandReceipt reads the immutable receipt record", async () => {
  const db = new FakeFirestore();
  const adapter = createInterventionLegalFirestoreAdapter(db);
  const matter = matterDocument();
  const event = eventDocument();
  const receipt = receiptDocument();
  await adapter.createLegalMatterAtomic({matter, event, receipt});

  const stored = await adapter.getCommandReceipt({
    scopeType: "create_legal_matter",
    scopeId: matter.tenantId,
    idempotencyKey: receipt.idempotencyKey,
  });
  assert.equal(stored.payloadFingerprint, receipt.payloadFingerprint);
  assert.equal(stored.resultId, matter.legalMatterId);
});

test("createLegalMatterAtomic replays an identical receipt", async () => {
  const db = new FakeFirestore();
  const adapter = createInterventionLegalFirestoreAdapter(db);
  const matter = matterDocument();
  const event = eventDocument();
  const receipt = receiptDocument();
  await adapter.createLegalMatterAtomic({matter, event, receipt});

  const replay = await adapter.createLegalMatterAtomic({
    matter,
    event,
    receipt,
  });
  assert.equal(replay.idempotentReplay, true);
  assert.deepEqual(replay.matter, matter);
});

test("createLegalMatterAtomic rejects conflicting receipt payload", async () => {
  const db = new FakeFirestore();
  const adapter = createInterventionLegalFirestoreAdapter(db);
  const matter = matterDocument();
  const event = eventDocument();
  const receipt = receiptDocument();
  await adapter.createLegalMatterAtomic({matter, event, receipt});

  await assert.rejects(
    () => adapter.createLegalMatterAtomic({
      matter,
      event,
      receipt: receiptDocument({
        payloadFingerprint: "b".repeat(64),
      }),
    }),
    (error) => error.code === "already-exists",
  );
});

test("createLegalMatterAtomic rejects partial matter bundle", async () => {
  const db = new FakeFirestore();
  const matter = matterDocument();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    matter.legalMatterId,
    matter,
  );
  const adapter = createInterventionLegalFirestoreAdapter(db);
  await assert.rejects(
    () => adapter.createLegalMatterAtomic({
      matter,
      event: eventDocument(),
      receipt: receiptDocument(),
    }),
    /partial or duplicate/,
  );
});

test("transitionLegalMatterAtomic updates matter and records event", async () => {
  const db = new FakeFirestore();
  const current = matterDocument();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    current.legalMatterId,
    current,
  );
  const adapter = createInterventionLegalFirestoreAdapter(db);
  const next = {
    ...current,
    status: "legal_review",
    version: 2,
    updatedAt: "2026-07-31T09:01:00.000Z",
  };
  const event = eventDocument({
    legalMatterId: current.legalMatterId,
    requestId: "req-transition",
    eventType: "legal_matter_status_changed",
  });
  const receipt = receiptDocument({
    requestId: "req-transition",
    idempotencyKey: "idem-transition",
  });

  const result = await adapter.transitionLegalMatterAtomic({
    currentMatter: current,
    nextMatter: next,
    event,
    receipt,
  });
  assert.equal(result.matter.status, "legal_review");
  assert.equal(
    db.read(
      FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
      current.legalMatterId,
    ).version,
    2,
  );
});

test("transitionLegalMatterAtomic rejects persisted version conflict", async () => {
  const db = new FakeFirestore();
  const current = matterDocument();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    current.legalMatterId,
    {...current, version: 2},
  );
  const adapter = createInterventionLegalFirestoreAdapter(db);
  await assert.rejects(
    () => adapter.transitionLegalMatterAtomic({
      currentMatter: current,
      nextMatter: {...current, version: 2},
      event: eventDocument({
        requestId: "req-transition",
        eventType: "legal_matter_status_changed",
      }),
      receipt: receiptDocument({
        requestId: "req-transition",
        idempotencyKey: "idem-transition",
      }),
    }),
    (error) =>
      error.code === "aborted" &&
      error.details.actualVersion === 2,
  );
});

test("getApprovalRequestById reads the request", async () => {
  const db = new FakeFirestore();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS,
    "lar_1",
    {approvalRequestId: "lar_1", status: "pending"},
  );
  const adapter = createInterventionLegalFirestoreAdapter(db);
  assert.equal(
    (await adapter.getApprovalRequestById({
      approvalRequestId: "lar_1",
    })).status,
    "pending",
  );
});

test("getLegalTeamProfileByUid uses uid as profile document id", async () => {
  const db = new FakeFirestore();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_TEAM_PROFILES,
    "lawyer-1",
    {uid: "lawyer-1", status: "active"},
  );
  const adapter = createInterventionLegalFirestoreAdapter(db);
  assert.equal(
    (await adapter.getLegalTeamProfileByUid({
      uid: "lawyer-1",
    })).status,
    "active",
  );
});

test("tenant owner can create and transition legal matters", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS, "tm_owner", {
    tenantId: "tenant-1",
    uid: "owner-1",
    role: "owner",
    status: "active",
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);

  for (const operationCode of [
    "create_legal_matter",
    "transition_legal_matter",
  ]) {
    const result = await adapter.resolveLegalMatterAuthority({
      uid: "owner-1",
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      operationCode,
    });
    assert.equal(result.authorized, true);
    assert.equal(result.authoritySource, "tenant_owner");
    assert.equal(result.operationCode, operationCode);
  }
});

test("brand-scoped operation delegation grants matter authority", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS, "tm_delegate", {
    tenantId: "tenant-1",
    uid: "delegate-1",
    role: "member",
    status: "active",
    delegatedLegalMatterOperations: [
      "transition_legal_matter",
    ],
    delegatedCanonicalBrandIds: ["brand-1"],
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);
  const result = await adapter.resolveLegalMatterAuthority({
    uid: "delegate-1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    operationCode: "transition_legal_matter",
  });
  assert.equal(result.authorized, true);
  assert.equal(result.authoritySource, "explicit_delegation");
});

test("wrong operation or brand denies delegated matter authority", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS, "tm_delegate", {
    tenantId: "tenant-1",
    uid: "delegate-1",
    role: "member",
    status: "active",
    delegatedLegalMatterOperations: [
      "transition_legal_matter",
    ],
    delegatedCanonicalBrandIds: ["brand-1"],
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);

  assert.equal(
    (await adapter.resolveLegalMatterAuthority({
      uid: "delegate-1",
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      operationCode: "create_legal_matter",
    })).authorized,
    false,
  );
  assert.equal(
    (await adapter.resolveLegalMatterAuthority({
      uid: "delegate-1",
      tenantId: "tenant-1",
      canonicalBrandId: "brand-2",
      operationCode: "transition_legal_matter",
    })).authorized,
    false,
  );
});

test("tenant owner has client authority", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS, "tm_1", {
    tenantId: "tenant-1",
    uid: "client-1",
    role: "owner",
    status: "active",
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);
  const result = await adapter.resolveClientAuthority({
    uid: "client-1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    approvalType: "client_budget_authorization",
  });
  assert.equal(result.authorized, true);
  assert.equal(result.authoritySource, "tenant_owner");
});

test("inactive tenant owner has no client authority", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS, "tm_1", {
    tenantId: "tenant-1",
    uid: "client-1",
    role: "owner",
    status: "inactive",
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);
  assert.equal(
    (await adapter.resolveClientAuthority({
      uid: "client-1",
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      approvalType: "client_budget_authorization",
    })).authorized,
    false,
  );
});

test("explicit brand-scoped delegation grants client authority", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS, "tm_1", {
    tenantId: "tenant-1",
    uid: "delegate-1",
    role: "member",
    status: "active",
    delegatedLegalApprovalTypes: [
      "client_budget_authorization",
    ],
    delegatedCanonicalBrandIds: ["brand-1"],
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);
  const result = await adapter.resolveClientAuthority({
    uid: "delegate-1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    approvalType: "client_budget_authorization",
  });
  assert.equal(result.authorized, true);
  assert.equal(result.authoritySource, "explicit_delegation");
});

test("delegation for another approval type is rejected", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS, "tm_1", {
    tenantId: "tenant-1",
    uid: "delegate-1",
    role: "member",
    status: "active",
    delegatedLegalApprovalTypes: [
      "client_action_authorization",
    ],
    delegatedCanonicalBrandIds: ["brand-1"],
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);
  assert.equal(
    (await adapter.resolveClientAuthority({
      uid: "delegate-1",
      tenantId: "tenant-1",
      canonicalBrandId: "brand-1",
      approvalType: "client_budget_authorization",
    })).authorized,
    false,
  );
});

test("recordApprovalDecisionAtomic commits request decision event receipt", async () => {
  const db = new FakeFirestore();
  const matter = matterDocument();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    matter.legalMatterId,
    matter,
  );
  const approvalRequest = {
    approvalRequestId: "lar_1",
    legalMatterId: matter.legalMatterId,
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 1,
  };
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS,
    approvalRequest.approvalRequestId,
    approvalRequest,
  );
  const decisionId = buildApprovalDecisionId({
    approvalRequestId: approvalRequest.approvalRequestId,
    decidedByUid: "client-1",
    decision: "approved",
  });
  const decision = {
    decisionId,
    approvalRequestId: approvalRequest.approvalRequestId,
    legalMatterId: matter.legalMatterId,
    approvalType: approvalRequest.approvalType,
    decision: "approved",
    decidedByUid: "client-1",
    decidedAt: "2026-07-31T09:02:00.000Z",
    immutable: true,
  };
  const event = eventDocument({
    legalMatterId: matter.legalMatterId,
    requestId: "req-decision",
    eventType: "legal_approval_decided",
  });
  const receipt = receiptDocument({
    requestId: "req-decision",
    idempotencyKey: "idem-decision",
    resultType: "legal_approval_decision",
    resultId: decisionId,
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);

  const result = await adapter.recordApprovalDecisionAtomic({
      expectedApprovalRequestVersion: 1,
    approvalRequest,
    decision,
    event,
    receipt,
  });

  assert.equal(result.idempotentReplay, false);
  assert.equal(
    db.read(
      FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS,
      approvalRequest.approvalRequestId,
    ).status,
    "approved",
  );
  assert.equal(
    db.read(
      FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_DECISIONS,
      decisionId,
    ).immutable,
    true,
  );
  assert.equal(
    db.read(
      FIRESTORE_COLLECTIONS.LEGAL_MATTER_EVENTS,
      event.eventId,
    ).recordType,
    "domain_event",
  );
});

test("recordApprovalDecisionAtomic replays identical decision", async () => {
  const db = new FakeFirestore();
  const matter = matterDocument();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    matter.legalMatterId,
    matter,
  );
  const approvalRequest = {
    approvalRequestId: "lar_1",
    legalMatterId: matter.legalMatterId,
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 1,
  };
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS,
    approvalRequest.approvalRequestId,
    approvalRequest,
  );
  const decisionId = buildApprovalDecisionId({
    approvalRequestId: "lar_1",
    decidedByUid: "client-1",
    decision: "approved",
  });
  const decision = {
    decisionId,
    approvalRequestId: "lar_1",
    legalMatterId: matter.legalMatterId,
    approvalType: "client_budget_authorization",
    decision: "approved",
    decidedByUid: "client-1",
    decidedAt: "2026-07-31T09:02:00.000Z",
    immutable: true,
  };
  const event = eventDocument({
    legalMatterId: matter.legalMatterId,
    requestId: "req-decision",
    eventType: "legal_approval_decided",
  });
  const receipt = receiptDocument({
    requestId: "req-decision",
    idempotencyKey: "idem-decision",
    resultType: "legal_approval_decision",
    resultId: decisionId,
  });
  const adapter = createInterventionLegalFirestoreAdapter(db);
  await adapter.recordApprovalDecisionAtomic({
      expectedApprovalRequestVersion: 1,
    approvalRequest,
    decision,
    event,
    receipt,
  });
  const replay = await adapter.recordApprovalDecisionAtomic({
      expectedApprovalRequestVersion: 1,
    approvalRequest,
    decision,
    event,
    receipt,
  });
  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.decision.decisionId, decisionId);
});

test("recordApprovalDecisionAtomic rejects persisted version conflict", async () => {
  const db = new FakeFirestore();
  const matter = matterDocument();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    matter.legalMatterId,
    matter,
  );
  const approvalRequest = {
    approvalRequestId: "lar_1",
    legalMatterId: matter.legalMatterId,
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 1,
  };
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS,
    "lar_1",
    {...approvalRequest, version: 2},
  );
  const adapter = createInterventionLegalFirestoreAdapter(db);

  await assert.rejects(
    () => adapter.recordApprovalDecisionAtomic({
      expectedApprovalRequestVersion: 1,
      approvalRequest,
      decision: {
        decisionId: "lad_stale",
        decision: "approved",
        decidedAt: "2026-07-31T09:02:00.000Z",
      },
      event: eventDocument({
        requestId: "req-decision-stale",
        eventType: "legal_approval_decided",
      }),
      receipt: receiptDocument({
        requestId: "req-decision-stale",
        idempotencyKey: "idem-decision-stale",
      }),
    }),
    (error) =>
      error.code === "aborted" &&
      error.details.actualApprovalRequestVersion === 2,
  );
});

test("recordApprovalDecisionAtomic rejects non-pending persisted request", async () => {
  const db = new FakeFirestore();
  const matter = matterDocument();
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
    matter.legalMatterId,
    matter,
  );
  const approvalRequest = {
    approvalRequestId: "lar_1",
    legalMatterId: matter.legalMatterId,
    approvalType: "client_budget_authorization",
    status: "pending",
    version: 1,
  };
  db.seed(
    FIRESTORE_COLLECTIONS.LEGAL_APPROVAL_REQUESTS,
    "lar_1",
    {...approvalRequest, status: "approved"},
  );
  const adapter = createInterventionLegalFirestoreAdapter(db);
  await assert.rejects(
    () => adapter.recordApprovalDecisionAtomic({
      expectedApprovalRequestVersion: 1,
      approvalRequest,
      decision: {
        decisionId: "lad_1",
        decision: "approved",
        decidedAt: "2026-07-31T09:02:00.000Z",
      },
      event: eventDocument({
        requestId: "req-decision",
        eventType: "legal_approval_decided",
      }),
      receipt: receiptDocument({
        requestId: "req-decision",
        idempotencyKey: "idem-decision",
      }),
    }),
    (error) =>
      error instanceof InterventionLegalContractError &&
      error.code === "failed-precondition",
  );
});


test("create receipt conflicts across changed matter payload in one tenant", async () => {
  const db = new FakeFirestore();
  const adapter = createInterventionLegalFirestoreAdapter(db);
  const first = matterDocument();
  const firstEvent = eventDocument();
  const receipt = receiptDocument();

  await adapter.createLegalMatterAtomic({
    matter: first,
    event: firstEvent,
    receipt,
  });

  const secondIdentity = {
    ...matterIdentity(),
    matterScopeCode: "domain_enforcement",
  };
  const second = {
    ...first,
    legalMatterKey: buildLegalMatterKey(secondIdentity),
    legalMatterId: buildLegalMatterId(secondIdentity),
    matterScopeCode: "domain_enforcement",
  };
  const secondEvent = eventDocument({
    legalMatterId: second.legalMatterId,
    requestId: receipt.requestId,
  });

  await assert.rejects(
    () => adapter.createLegalMatterAtomic({
      matter: second,
      event: secondEvent,
      receipt: {
        ...receipt,
        payloadFingerprint: "b".repeat(64),
        resultId: second.legalMatterId,
      },
    }),
    (error) => error.code === "already-exists",
  );
  assert.equal(
    db.read(
      FIRESTORE_COLLECTIONS.LEGAL_MATTER_FILES,
      second.legalMatterId,
    ),
    undefined,
  );
});
