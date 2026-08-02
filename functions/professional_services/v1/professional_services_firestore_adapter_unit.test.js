/* eslint-disable max-len */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  ProfessionalServicesContractError,
} = require("./contracts");
const {
  assertStoragePort,
} = require("./storage_contracts");
const {
  COMMAND_RECEIPT_RECORD_TYPE,
  DOMAIN_EVENT_RECORD_TYPE,
  FIRESTORE_COLLECTIONS,
  SOURCE_REFERENCE_COLLECTIONS,
  assertDb,
  buildCommandReceiptId,
  buildConflictCheckId,
  createProfessionalServicesFirestoreAdapter,
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

function serviceRequest(version = 1, overrides = {}) {
  return {
    serviceRequestId: "psr-1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    serviceFamily: "legal",
    serviceCode: "legal_preliminary_assessment",
    status: version === 1 ? "requested" : "scoping",
    version,
    eventCount: version,
    createdAt: "2026-08-02T10:00:00.000Z",
    updatedAt: "2026-08-02T10:00:00.000Z",
    ...overrides,
  };
}

function eventDocument(id, aggregateType = "service_request",
    aggregateId = "psr-1") {
  return {
    eventId: id,
    contractVersion: "test-command-v1",
    aggregateType,
    aggregateId,
    eventType: `event_${id}`,
    requestId: `request_${id}`,
    idempotencyKey: `idem_${id}`,
    actorUid: "user-1",
    executedByAgentId: null,
    eventData: {status: "test"},
    recordedAt: "2026-08-02T10:00:00.000Z",
    appendOnly: true,
    immutable: true,
  };
}

function receipt(id, overrides = {}) {
  return {
    contractVersion: "test-command-v1",
    requestId: `request_${id}`,
    idempotencyKey: `idem_${id}`,
    payloadFingerprint: "a".repeat(64),
    resultType: "professional_service_request",
    resultId: "psr-1",
    actorUid: "user-1",
    recordedAt: "2026-08-02T10:00:00.000Z",
    immutable: true,
    ...overrides,
  };
}

function agentTask(version = 1, overrides = {}) {
  return {
    contractVersion: "professional-agent-task-v1",
    agentTaskId: "pat-1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    serviceRequestId: "psr-1",
    serviceAssignmentId: null,
    agentCode: "legal_intake_triage",
    status: "running",
    version,
    runCount: version,
    eventCount: version,
    currentAgentRunId: "par-1",
    createdAt: "2026-08-02T10:00:00.000Z",
    updatedAt: "2026-08-02T10:00:00.000Z",
    createdByUid: "user-1",
    updatedByUid: "user-1",
    ...overrides,
  };
}

function assertCode(code) {
  return (error) =>
    error instanceof ProfessionalServicesContractError &&
    error.code === code;
}

test("adapter exposes the complete professional services storage port", () => {
  const adapter = createProfessionalServicesFirestoreAdapter(
      new FakeFirestore(),
  );
  assert.equal(assertStoragePort(adapter), adapter);
});

test("database validation rejects an incomplete Firestore implementation", () => {
  assert.throws(() => assertDb(null), TypeError);
  assert.throws(
      () => createProfessionalServicesFirestoreAdapter({
        collection() {},
      }),
      TypeError,
  );
});

test("deterministic receipt and conflict identifiers are scope-sensitive", () => {
  const first = buildCommandReceiptId({
    scopeType: "service_request",
    scopeId: "psr-1",
    idempotencyKey: "idem-1",
  });
  assert.equal(first, buildCommandReceiptId({
    scopeType: "service_request",
    scopeId: "psr-1",
    idempotencyKey: "idem-1",
  }));
  assert.notEqual(first, buildCommandReceiptId({
    scopeType: "service_request",
    scopeId: "psr-2",
    idempotencyKey: "idem-1",
  }));
  assert.notEqual(
      buildConflictCheckId({
        serviceRequestId: "psr-1",
        providerId: "provider-1",
      }),
      buildConflictCheckId({
        serviceRequestId: "psr-1",
        providerId: "provider-2",
      }),
  );
});

test("source scope resolves canonical tenant and brand aliases", async () => {
  const db = new FakeFirestore();
  db.seed(SOURCE_REFERENCE_COLLECTIONS.caseId, "case-1", {
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    status: "active",
  });
  db.seed(SOURCE_REFERENCE_COLLECTIONS.counterfeitTwinId, "twin-1", {
    tenantId: "tenant-1",
    brandId: "brand-1",
    status: "archived",
  });
  const adapter = createProfessionalServicesFirestoreAdapter(db);
  const scope = await adapter.resolveSourceScope({
    sourceReferences: {
      caseId: "case-1",
      counterfeitTwinId: "twin-1",
      legalMatterId: "missing-1",
    },
  });
  assert.equal(scope.tenantId, "tenant-1");
  assert.equal(scope.canonicalBrandId, "brand-1");
  assert.equal(scope.archived, true);
  assert.deepEqual(
      scope.unresolvedReferences,
      ["legalMatterId:missing-1"],
  );
});

test("source scope rejects references from different tenants", async () => {
  const db = new FakeFirestore();
  db.seed(SOURCE_REFERENCE_COLLECTIONS.caseId, "case-1", {
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
  });
  db.seed(SOURCE_REFERENCE_COLLECTIONS.legalMatterId, "matter-1", {
    tenantId: "tenant-2",
    canonicalBrandId: "brand-1",
  });
  const adapter = createProfessionalServicesFirestoreAdapter(db);
  await assert.rejects(
      () => adapter.resolveSourceScope({
        sourceReferences: {
          caseId: "case-1",
          legalMatterId: "matter-1",
        },
      }),
      assertCode("failed-precondition"),
  );
});

test("source collection overrides are explicit and bounded", async () => {
  const db = new FakeFirestore();
  db.seed("custom_case_registry", "case-1", {
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
  });
  const adapter = createProfessionalServicesFirestoreAdapter(db, {
    sourceReferenceCollections: {
      caseId: "custom_case_registry",
    },
  });
  const scope = await adapter.resolveSourceScope({
    sourceReferences: {caseId: "case-1"},
  });
  assert.equal(scope.tenantId, "tenant-1");
  assert.throws(
      () => createProfessionalServicesFirestoreAdapter(db, {
        sourceReferenceCollections: {unknownField: "bad"},
      }),
      assertCode("invalid-argument"),
  );
});

test("tenant owner authority does not imply publication permission", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS, "membership-1", {
    tenantId: "tenant-1",
    uid: "owner-1",
    status: "active",
    role: "owner",
  });
  const authority = await createProfessionalServicesFirestoreAdapter(db)
      .resolveProfessionalServiceAuthority({
        uid: "owner-1",
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        serviceFamily: "legal",
        operationCode: "create_service_request",
      });
  assert.equal(authority.authorized, true);
  assert.equal(authority.authoritySource, "tenant_owner");
  assert.equal(authority.professionalClass, "tenant_owner");
  assert.equal(authority.canPublish, false);
});

test("membership delegation is operation, brand and family scoped", async () => {
  const db = new FakeFirestore();
  db.seed(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS, "membership-1", {
    tenantId: "tenant-1",
    uid: "delegate-1",
    status: "active",
    role: "member",
    delegatedProfessionalServiceOperations: ["start_agent_run"],
    delegatedCanonicalBrandIds: ["brand-1"],
    delegatedProfessionalServiceFamilies: ["legal"],
    professionalClass: "legal_professional",
    canPublishProfessionalServiceOutputs: false,
  });
  const adapter = createProfessionalServicesFirestoreAdapter(db);
  const allowed = await adapter.resolveProfessionalServiceAuthority({
    uid: "delegate-1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    serviceFamily: "legal",
    operationCode: "start_agent_run",
  });
  assert.equal(allowed.authorized, true);
  assert.equal(allowed.professionalClass, "legal_professional");
  const denied = await adapter.resolveProfessionalServiceAuthority({
    uid: "delegate-1",
    tenantId: "tenant-1",
    canonicalBrandId: "brand-2",
    serviceFamily: "legal",
    operationCode: "start_agent_run",
  });
  assert.equal(denied.authorized, false);
});

test("specialized authority supports separate review and publication gates",
    async () => {
      const db = new FakeFirestore();
      db.seed(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_AUTHORITIES,
          "authority-1",
          {
            tenantId: "tenant-1",
            uid: "lawyer-1",
            status: "active",
            delegatedProfessionalServiceOperations: [
              "review_agent_output",
              "publish_agent_output",
            ],
            delegatedCanonicalBrandIds: ["brand-1"],
            delegatedProfessionalServiceFamilies: ["legal"],
            professionalClass: "legal_professional",
            canPublishProfessionalServiceOutputs: true,
          },
      );
      const authority = await createProfessionalServicesFirestoreAdapter(db)
          .resolveProfessionalServiceAuthority({
            uid: "lawyer-1",
            tenantId: "tenant-1",
            canonicalBrandId: "brand-1",
            serviceFamily: "legal",
            operationCode: "publish_agent_output",
          });
      assert.equal(authority.authorized, true);
      assert.equal(authority.professionalClass, "legal_professional");
      assert.equal(authority.canPublish, true);
    });

test("direct reads and deterministic conflict lookup preserve records",
    async () => {
      const db = new FakeFirestore();
      const request = serviceRequest();
      db.seed(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_REQUESTS,
          request.serviceRequestId,
          request,
      );
      db.seed(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_PROVIDERS,
          "provider-1",
          {providerId: "provider-1", status: "active"},
      );
      const conflictId = buildConflictCheckId({
        serviceRequestId: request.serviceRequestId,
        providerId: "provider-1",
      });
      db.seed(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_CONFLICT_CHECKS,
          conflictId,
          {
            serviceRequestId: request.serviceRequestId,
            providerId: "provider-1",
            outcome: "cleared",
          },
      );
      const adapter = createProfessionalServicesFirestoreAdapter(db);
      assert.deepEqual(
          await adapter.getServiceRequestById({
            serviceRequestId: request.serviceRequestId,
          }),
          request,
      );
      assert.equal(
          (await adapter.getServiceProviderById({
            providerId: "provider-1",
          })).status,
          "active",
      );
      assert.equal(
          (await adapter.resolveConflictCheck({
            serviceRequestId: request.serviceRequestId,
            providerId: "provider-1",
          })).outcome,
          "cleared",
      );
    });

test("create service request writes an immutable atomic bundle", async () => {
  const db = new FakeFirestore();
  const adapter = createProfessionalServicesFirestoreAdapter(db);
  const request = serviceRequest();
  const event = eventDocument("event-create");
  const commandReceipt = receipt("create");
  const result = await adapter.createServiceRequestAtomic({
    serviceRequest: request,
    event,
    receipt: commandReceipt,
  });
  assert.equal(result.idempotentReplay, false);
  assert.deepEqual(
      db.read(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_REQUESTS,
          request.serviceRequestId,
      ),
      request,
  );
  const storedEvent = db.read(
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_EVENTS,
      event.eventId,
  );
  assert.equal(storedEvent.recordType, DOMAIN_EVENT_RECORD_TYPE);
  assert.equal(storedEvent.actorUid, "user-1");
  const receiptId = buildCommandReceiptId({
    scopeType: "create_service_request",
    scopeId: request.tenantId,
    idempotencyKey: commandReceipt.idempotencyKey,
  });
  const storedReceipt = db.read(
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_EVENTS,
      receiptId,
  );
  assert.equal(storedReceipt.recordType, COMMAND_RECEIPT_RECORD_TYPE);
  assert.equal(storedReceipt.payloadFingerprint, "a".repeat(64));
  assert.equal(storedReceipt.actorUid, "user-1");
});

test("create service request replays only an identical receipt", async () => {
  const db = new FakeFirestore();
  const adapter = createProfessionalServicesFirestoreAdapter(db);
  const request = serviceRequest();
  const event = eventDocument("event-replay");
  const commandReceipt = receipt("replay");
  await adapter.createServiceRequestAtomic({
    serviceRequest: request,
    event,
    receipt: commandReceipt,
  });
  const replay = await adapter.createServiceRequestAtomic({
    serviceRequest: request,
    event,
    receipt: commandReceipt,
  });
  assert.equal(replay.idempotentReplay, true);
  await assert.rejects(
      () => adapter.createServiceRequestAtomic({
        serviceRequest: request,
        event,
        receipt: {
          ...commandReceipt,
          payloadFingerprint: "b".repeat(64),
        },
      }),
      assertCode("already-exists"),
  );
});

test("service request transition enforces persisted version", async () => {
  const db = new FakeFirestore();
  const current = serviceRequest(1);
  db.seed(
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_REQUESTS,
      current.serviceRequestId,
      current,
  );
  const adapter = createProfessionalServicesFirestoreAdapter(db);
  const next = serviceRequest(2);
  const result = await adapter.transitionServiceRequestAtomic({
    currentServiceRequest: current,
    nextServiceRequest: next,
    event: eventDocument("event-transition"),
    receipt: receipt("transition"),
  });
  assert.equal(result.serviceRequest.version, 2);
  await assert.rejects(
      () => adapter.transitionServiceRequestAtomic({
        currentServiceRequest: current,
        nextServiceRequest: next,
        event: eventDocument("event-transition-stale"),
        receipt: receipt("transition-stale"),
      }),
      assertCode("aborted"),
  );
});

test("engagement creation updates request and creates immutable engagement",
    async () => {
      const db = new FakeFirestore();
      const current = serviceRequest(2, {status: "scoping"});
      const next = serviceRequest(3, {status: "ready_for_assignment"});
      const engagement = {
        serviceEngagementId: "pse-1",
        serviceRequestId: current.serviceRequestId,
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        immutable: true,
      };
      db.seed(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_REQUESTS,
          current.serviceRequestId,
          current,
      );
      const result = await createProfessionalServicesFirestoreAdapter(db)
          .createServiceEngagementAtomic({
            currentServiceRequest: current,
            nextServiceRequest: next,
            serviceEngagement: engagement,
            event: eventDocument("event-engagement"),
            receipt: receipt("engagement", {
              resultType: "professional_service_engagement",
              resultId: engagement.serviceEngagementId,
            }),
          });
      assert.equal(result.serviceRequest.version, 3);
      assert.deepEqual(
          db.read(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_ENGAGEMENTS,
              engagement.serviceEngagementId,
          ),
          engagement,
      );
    });

test("assignment creation updates request and creates assignment", async () => {
  const db = new FakeFirestore();
  const current = serviceRequest(3, {status: "ready_for_assignment"});
  const next = serviceRequest(4, {status: "assigned"});
  const assignment = {
    serviceAssignmentId: "psa-1",
    serviceRequestId: current.serviceRequestId,
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    immutable: true,
  };
  db.seed(
      FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_REQUESTS,
      current.serviceRequestId,
      current,
  );
  const result = await createProfessionalServicesFirestoreAdapter(db)
      .createServiceAssignmentAtomic({
        currentServiceRequest: current,
        nextServiceRequest: next,
        serviceAssignment: assignment,
        event: eventDocument("event-assignment"),
        receipt: receipt("assignment", {
          resultType: "professional_service_assignment",
          resultId: assignment.serviceAssignmentId,
        }),
      });
  assert.equal(result.serviceRequest.status, "assigned");
  assert.deepEqual(
      db.read(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_ASSIGNMENTS,
          assignment.serviceAssignmentId,
      ),
      assignment,
  );
});

test("new and rerun agent tasks preserve optimistic concurrency", async () => {
  const db = new FakeFirestore();
  const adapter = createProfessionalServicesFirestoreAdapter(db);
  const firstTask = agentTask(1);
  const firstRun = {
    agentRunId: "par-1",
    agentTaskId: firstTask.agentTaskId,
    serviceRequestId: firstTask.serviceRequestId,
    tenantId: "tenant-1",
    canonicalBrandId: "brand-1",
    immutable: true,
  };
  await adapter.createAgentRunAtomic({
    currentAgentTask: null,
    nextAgentTask: firstTask,
    agentRun: firstRun,
    event: eventDocument(
        "event-run-1",
        "agent_task",
        firstTask.agentTaskId,
    ),
    receipt: receipt("run-1", {
      resultType: "professional_agent_run",
      resultId: firstRun.agentRunId,
    }),
  });
  const secondTask = agentTask(2, {
    status: "running",
    runCount: 2,
    currentAgentRunId: "par-2",
  });
  const secondRun = {
    ...firstRun,
    agentRunId: "par-2",
  };
  const rerun = await adapter.createAgentRunAtomic({
    currentAgentTask: firstTask,
    nextAgentTask: secondTask,
    agentRun: secondRun,
    event: eventDocument(
        "event-run-2",
        "agent_task",
        firstTask.agentTaskId,
    ),
    receipt: receipt("run-2", {
      resultType: "professional_agent_run",
      resultId: secondRun.agentRunId,
    }),
  });
  assert.equal(rerun.agentTask.version, 2);
  await assert.rejects(
      () => adapter.createAgentRunAtomic({
        currentAgentTask: firstTask,
        nextAgentTask: secondTask,
        agentRun: {...secondRun, agentRunId: "par-3"},
        event: eventDocument(
            "event-run-stale",
            "agent_task",
            firstTask.agentTaskId,
        ),
        receipt: receipt("run-stale", {
          resultType: "professional_agent_run",
          resultId: "par-3",
        }),
      }),
      assertCode("aborted"),
  );
});

test("agent output atomically advances task and stores immutable draft",
    async () => {
      const db = new FakeFirestore();
      const current = agentTask(1);
      const next = agentTask(2, {
        status: "waiting_human_review",
        latestOutputDraftId: "pao-1",
      });
      const output = {
        outputDraftId: "pao-1",
        agentRunId: "par-1",
        agentTaskId: current.agentTaskId,
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        immutable: true,
      };
      db.seed(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_TASKS,
          current.agentTaskId,
          current,
      );
      const result = await createProfessionalServicesFirestoreAdapter(db)
          .createAgentOutputDraftAtomic({
            currentAgentTask: current,
            nextAgentTask: next,
            agentOutputDraft: output,
            event: eventDocument(
                "event-output",
                "agent_task",
                current.agentTaskId,
            ),
            receipt: receipt("output", {
              resultType: "professional_agent_output_draft",
              resultId: output.outputDraftId,
            }),
          });
      assert.equal(result.agentTask.status, "waiting_human_review");
      assert.deepEqual(
          db.read(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_OUTPUT_DRAFTS,
              output.outputDraftId,
          ),
          output,
      );
    });

test("human review atomically advances task and stores reviewer record",
    async () => {
      const db = new FakeFirestore();
      const current = agentTask(2, {
        status: "waiting_human_review",
        latestOutputDraftId: "pao-1",
      });
      const next = agentTask(3, {
        status: "approved",
        latestOutputDraftId: "pao-1",
        latestHumanReviewId: "phr-1",
      });
      const review = {
        humanReviewId: "phr-1",
        outputDraftId: "pao-1",
        agentTaskId: current.agentTaskId,
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        immutable: true,
      };
      db.seed(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_TASKS,
          current.agentTaskId,
          current,
      );
      const result = await createProfessionalServicesFirestoreAdapter(db)
          .recordAgentHumanReviewAtomic({
            currentAgentTask: current,
            nextAgentTask: next,
            agentHumanReview: review,
            event: eventDocument(
                "event-review",
                "agent_task",
                current.agentTaskId,
            ),
            receipt: receipt("review", {
              resultType: "professional_agent_human_review",
              resultId: review.humanReviewId,
            }),
          });
      assert.equal(result.agentTask.status, "approved");
      assert.deepEqual(
          db.read(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_HUMAN_REVIEWS,
              review.humanReviewId,
          ),
          review,
      );
    });

test("publication atomically advances task and stores artifact reference",
    async () => {
      const db = new FakeFirestore();
      const current = agentTask(3, {
        status: "approved",
        latestOutputDraftId: "pao-1",
        latestHumanReviewId: "phr-1",
      });
      const next = agentTask(4, {
        status: "published",
        publicationId: "ppub-1",
      });
      const publication = {
        publicationId: "ppub-1",
        outputDraftId: "pao-1",
        agentTaskId: current.agentTaskId,
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        immutable: true,
      };
      db.seed(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_TASKS,
          current.agentTaskId,
          current,
      );
      const result = await createProfessionalServicesFirestoreAdapter(db)
          .publishAgentOutputAtomic({
            currentAgentTask: current,
            nextAgentTask: next,
            publication,
            event: eventDocument(
                "event-publication",
                "agent_task",
                current.agentTaskId,
            ),
            receipt: receipt("publication", {
              resultType: "professional_agent_output_publication",
              resultId: publication.publicationId,
            }),
          });
      assert.equal(result.agentTask.status, "published");
      assert.deepEqual(
          db.read(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_OUTPUT_PUBLICATIONS,
              publication.publicationId,
          ),
          publication,
      );
    });

test("partial bundle collision is rejected without additional writes",
    async () => {
      const db = new FakeFirestore();
      const request = serviceRequest();
      db.seed(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_REQUESTS,
          request.serviceRequestId,
          request,
      );
      const before = db._docs.size;
      await assert.rejects(
          () => createProfessionalServicesFirestoreAdapter(db)
              .createServiceRequestAtomic({
                serviceRequest: request,
                event: eventDocument("event-partial"),
                receipt: receipt("partial"),
              }),
          assertCode("already-exists"),
      );
      assert.equal(db._docs.size, before);
    });
