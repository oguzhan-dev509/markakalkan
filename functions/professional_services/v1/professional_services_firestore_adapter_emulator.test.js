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
  SERVICE_REQUEST_CONTRACT_VERSION,
} = require("./contracts");
const {
  AGENT_HUMAN_REVIEW_CONTRACT_VERSION,
  AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
  AGENT_RUN_REQUEST_CONTRACT_VERSION,
} = require("./agent_contracts");
const {
  AGENT_OUTPUT_PUBLISH_COMMAND_VERSION,
  AGENT_OUTPUT_RECORD_COMMAND_VERSION,
  AGENT_REVIEW_RECORD_COMMAND_VERSION,
  AGENT_RUN_START_COMMAND_VERSION,
  SERVICE_REQUEST_CREATE_COMMAND_VERSION,
  SERVICE_REQUEST_TRANSITION_COMMAND_VERSION,
  buildCreateServiceRequestService,
  buildPublishAgentOutputService,
  buildRecordAgentOutputService,
  buildRecordAgentReviewService,
  buildStartAgentRunService,
  buildTransitionServiceRequestService,
} = require("./service");
const {
  FIRESTORE_COLLECTIONS,
  SOURCE_REFERENCE_COLLECTIONS,
  buildCommandReceiptId,
  createProfessionalServicesFirestoreAdapter,
} = require("./firestore_adapter");

const PROJECT_ID = "demo-markakalkan-pho-1c-2";
const NOW = "2026-08-02T10:00:00.000Z";
const UUIDS = Object.freeze({
  create: "11111111-1111-4111-8111-111111111111",
  transitionA: "22222222-2222-4222-8222-222222222222",
  transitionB: "33333333-3333-4333-8333-333333333333",
  agent: "44444444-4444-4444-8444-444444444444",
  output: "55555555-5555-4555-8555-555555555555",
  review: "66666666-6666-4666-8666-666666666666",
  publish: "77777777-7777-4777-8777-777777777777",
});

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

async function eventRecords() {
  const snapshot = await db
      .collection(FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_EVENTS)
      .get();
  return snapshot.docs.map((doc) => doc.data());
}

async function seedCanonicalScopeAndAuthorities() {
  await db
      .collection(SOURCE_REFERENCE_COLLECTIONS.caseId)
      .doc("case-1")
      .set({
        caseId: "case-1",
        tenantId: "tenant-1",
        canonicalBrandId: "brand-1",
        status: "open",
      });
  await db
      .collection(FIRESTORE_COLLECTIONS.TENANT_MEMBERSHIPS)
      .doc("membership-owner-1")
      .set({
        tenantId: "tenant-1",
        uid: "user-1",
        role: "owner",
        status: "active",
      });
  await db
      .collection(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_AUTHORITIES,
      )
      .doc("authority-reviewer-1")
      .set({
        tenantId: "tenant-1",
        uid: "reviewer-1",
        status: "active",
        delegatedProfessionalServiceOperations: [
          "review_agent_output",
        ],
        delegatedCanonicalBrandIds: ["brand-1"],
        delegatedProfessionalServiceFamilies: ["legal"],
        professionalClass: "legal_professional",
        canPublishProfessionalServiceOutputs: false,
      });
  await db
      .collection(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_AUTHORITIES,
      )
      .doc("authority-publisher-1")
      .set({
        tenantId: "tenant-1",
        uid: "publisher-1",
        status: "active",
        delegatedProfessionalServiceOperations: [
          "publish_agent_output",
        ],
        delegatedCanonicalBrandIds: ["brand-1"],
        delegatedProfessionalServiceFamilies: ["legal"],
        professionalClass: "legal_professional",
        canPublishProfessionalServiceOutputs: true,
      });
}

function requestInput() {
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
      inclusions: [
        "Delil zaman çizelgesi",
        "Yetki alanı değerlendirmesi",
      ],
      exclusions: ["Mahkemeye otomatik başvuru"],
    },
    requestedByUid: "user-1",
    requestedAt: NOW,
  };
}

function createRequestCommand() {
  const serviceRequest = requestInput();
  return {
    contractVersion: SERVICE_REQUEST_CREATE_COMMAND_VERSION,
    requestId: serviceRequest.requestId,
    idempotencyKey: "idem-create",
    actorUid: "user-1",
    serviceRequest,
  };
}

function agentRunRequest(serviceRequestId) {
  return {
    contractVersion: AGENT_RUN_REQUEST_CONTRACT_VERSION,
    requestId: UUIDS.agent,
    serviceRequestId,
    serviceAssignmentId: null,
    agentCode: "legal_intake_triage",
    agentVersion: "v1",
    modelProvider: "openai",
    modelName: "reasoning-model",
    modelVersion: "2026-08",
    promptTemplateVersion: "v1",
    initiatedByUid: "user-1",
    supervisingUid: "user-1",
    sourceReferences: {caseId: "case-1"},
    inputManifestHashSha256: "a".repeat(64),
    confidentialityClass: "client_confidential",
    privilegeClaimStatus: "none",
    startedAt: NOW,
  };
}

function buildServices() {
  const dependencies = {store: adapter, clock: () => NOW};
  return {
    createRequest: buildCreateServiceRequestService(dependencies),
    transitionRequest: buildTransitionServiceRequestService(dependencies),
    startAgentRun: buildStartAgentRunService(dependencies),
    recordOutput: buildRecordAgentOutputService(dependencies),
    recordReview: buildRecordAgentReviewService(dependencies),
    publishOutput: buildPublishAgentOutputService(dependencies),
  };
}

async function createRequest() {
  await seedCanonicalScopeAndAuthorities();
  return buildServices().createRequest(createRequestCommand());
}

before(async () => {
  assertEmulatorGuard();
  app = initializeApp({projectId: PROJECT_ID}, "pho-1c-2-emulator");
  db = getFirestore(app);
  adapter = createProfessionalServicesFirestoreAdapter(db);
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

test("create service writes one request event receipt bundle", async () => {
  const result = await createRequest();
  assert.equal(result.idempotentReplay, false);
  assert.equal(result.serviceRequest.status, "requested");
  assert.equal(result.serviceRequest.createdByUid, "user-1");
  assert.equal(
      await countCollection(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_REQUESTS,
      ),
      1,
  );
  const records = await eventRecords();
  assert.equal(
      records.filter((record) => record.recordType === "domain_event")
          .length,
      1,
  );
  assert.equal(
      records.filter((record) => record.recordType === "command_receipt")
          .length,
      1,
  );
  assert.equal(records.every((record) => record.actorUid === "user-1"), true);
});

test("identical create command replays without duplicate writes", async () => {
  const first = await createRequest();
  const second = await buildServices().createRequest(
      createRequestCommand(),
  );
  assert.equal(first.idempotentReplay, false);
  assert.equal(second.idempotentReplay, true);
  assert.equal(second.resultId, first.resultId);
  assert.equal(
      await countCollection(
          FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_REQUESTS,
      ),
      1,
  );
  assert.equal((await eventRecords()).length, 2);
  const receiptId = buildCommandReceiptId({
    scopeType: "create_service_request",
    scopeId: "tenant-1",
    idempotencyKey: "idem-create",
  });
  const receipt = await db
      .collection(FIRESTORE_COLLECTIONS.PROFESSIONAL_SERVICE_EVENTS)
      .doc(receiptId)
      .get();
  assert.equal(receipt.exists, true);
  assert.equal(receipt.data().immutable, true);
});

test("concurrent transitions enforce one optimistic version winner",
    async () => {
      const created = await createRequest();
      const base = {
        contractVersion: SERVICE_REQUEST_TRANSITION_COMMAND_VERSION,
        actorUid: "user-1",
        serviceRequestId: created.serviceRequest.serviceRequestId,
        expectedVersion: created.serviceRequest.version,
        nextStatus: "scoping",
        reasonCode: "scope_review_started",
        note: "Kapsam incelemesi başlatıldı.",
      };
      const results = await Promise.allSettled([
        buildServices().transitionRequest({
          ...base,
          requestId: UUIDS.transitionA,
          idempotencyKey: "idem-transition-a",
        }),
        buildServices().transitionRequest({
          ...base,
          requestId: UUIDS.transitionB,
          idempotencyKey: "idem-transition-b",
        }),
      ]);
      assert.equal(
          results.filter((item) => item.status === "fulfilled").length,
          1,
      );
      const rejected = results.find((item) => item.status === "rejected");
      assert.ok(rejected);
      const persisted = await adapter.getServiceRequestById({
        serviceRequestId: created.serviceRequest.serviceRequestId,
      });
      assert.equal(persisted.version, 2);
      assert.equal(persisted.status, "scoping");
    });

test("agent run output human review and publication remain atomic",
    async () => {
      const created = await createRequest();
      const services = buildServices();
      const runInput = agentRunRequest(
          created.serviceRequest.serviceRequestId,
      );
      const run = await services.startAgentRun({
        contractVersion: AGENT_RUN_START_COMMAND_VERSION,
        requestId: UUIDS.agent,
        idempotencyKey: "idem-agent-run",
        actorUid: "user-1",
        expectedAgentTaskVersion: null,
        runSequence: 1,
        agentRunRequest: runInput,
      });
      const output = await services.recordOutput({
        contractVersion: AGENT_OUTPUT_RECORD_COMMAND_VERSION,
        requestId: UUIDS.output,
        idempotencyKey: "idem-agent-output",
        actorUid: "user-1",
        agentTaskId: run.agentTask.agentTaskId,
        expectedAgentTaskVersion: run.agentTask.version,
        agentOutputDraft: {
          contractVersion: AGENT_OUTPUT_DRAFT_CONTRACT_VERSION,
          agentRunId: run.agentRun.agentRunId,
          outputType: "legal_intake_summary",
          outputHashSha256: "b".repeat(64),
          outputBytes: 1200,
          sourceReferenceCount: 1,
          confidenceLevel: "high",
          warningCodes: [],
          generatedAt: NOW,
        },
      });
      const review = await services.recordReview({
        contractVersion: AGENT_REVIEW_RECORD_COMMAND_VERSION,
        requestId: UUIDS.review,
        idempotencyKey: "idem-agent-review",
        actorUid: "reviewer-1",
        agentTaskId: output.agentTask.agentTaskId,
        expectedAgentTaskVersion: output.agentTask.version,
        agentHumanReview: {
          contractVersion: AGENT_HUMAN_REVIEW_CONTRACT_VERSION,
          agentRunId: run.agentRun.agentRunId,
          outputDraftId: output.agentOutputDraft.outputDraftId,
          expectedDraftHashSha256: "b".repeat(64),
          decision: "approved",
          reviewedByUid: "reviewer-1",
          reviewNote:
            "Kaynak bağlantıları ve içerik insan tarafından incelendi.",
          reviewedAt: NOW,
        },
      });
      const publication = await services.publishOutput({
        contractVersion: AGENT_OUTPUT_PUBLISH_COMMAND_VERSION,
        requestId: UUIDS.publish,
        idempotencyKey: "idem-agent-publication",
        actorUid: "publisher-1",
        agentTaskId: review.agentTask.agentTaskId,
        expectedAgentTaskVersion: review.agentTask.version,
        outputDraftId: output.agentOutputDraft.outputDraftId,
        humanReviewId: review.agentHumanReview.humanReviewId,
        publishedArtifactId: "artifact-1",
        publishedArtifactHashSha256: "c".repeat(64),
        publishedAt: NOW,
      });
      assert.equal(publication.agentTask.status, "published");
      assert.equal(publication.publication.publishedByUid, "publisher-1");
      assert.equal(
          await countCollection(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_TASKS,
          ),
          1,
      );
      assert.equal(
          await countCollection(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_RUNS,
          ),
          1,
      );
      assert.equal(
          await countCollection(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_OUTPUT_DRAFTS,
          ),
          1,
      );
      assert.equal(
          await countCollection(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_HUMAN_REVIEWS,
          ),
          1,
      );
      assert.equal(
          await countCollection(
              FIRESTORE_COLLECTIONS.PROFESSIONAL_AGENT_OUTPUT_PUBLICATIONS,
          ),
          1,
      );
      const records = await eventRecords();
      assert.equal(
          records.filter((record) => record.recordType === "domain_event")
              .length,
          5,
      );
      assert.equal(
          records.filter((record) => record.recordType === "command_receipt")
              .length,
          5,
      );
    });
