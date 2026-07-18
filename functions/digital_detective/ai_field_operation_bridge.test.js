const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  BRIDGE_VERSION,
  OPERATION_DOCUMENT,
  buildAiFieldOperationBridge,
  buildDigitalDetectiveTaskData,
  buildTaskName,
  normalizePriority,
} = require("./ai_field_operation_bridge");

class FakeDocumentReference {
  constructor(path) {
    this.path = path;
  }

  collection(name) {
    return new FakeCollectionReference(`${this.path}/${name}`);
  }

  doc(id) {
    return new FakeDocumentReference(`${this.path}/${id}`);
  }
}

class FakeCollectionReference {
  constructor(path) {
    this.path = path;
  }

  doc(id) {
    return new FakeDocumentReference(`${this.path}/${id}`);
  }
}

function makeSnapshot(reference, data) {
  return {
    exists: data !== undefined,
    ref: reference,
    data: () => data,
  };
}

function makeHarness({plannerData, existingTask} = {}) {
  const documents = new Map();
  const operationPath = "brands/brand-path/aiFieldOperations/operation-123";
  const taskPath =
    "brands/brand-path/digitalDetectiveTasks/operation-123";
  const plannerPath = `${operationPath}/agentTasks/task_planner`;

  if (plannerData !== undefined) {
    documents.set(plannerPath, plannerData);
  }

  if (existingTask !== undefined) {
    documents.set(taskPath, existingTask);
  }

  const creates = [];
  const db = {
    collection: (name) => new FakeCollectionReference(name),
    runTransaction: async (callback) => callback({
      get: async (reference) => makeSnapshot(
          reference,
          documents.get(reference.path),
      ),
      create: (reference, data) => {
        if (documents.has(reference.path)) {
          throw new Error("Document already exists");
        }
        documents.set(reference.path, data);
        creates.push({path: reference.path, data});
      },
    }),
  };
  let options;
  let handler;
  const logs = [];

  buildAiFieldOperationBridge({
    db,
    admin: {
      firestore: {
        FieldValue: {
          serverTimestamp: () => "SERVER_TIMESTAMP",
        },
      },
    },
    onDocumentCreated: (value, callback) => {
      options = value;
      handler = callback;
      return callback;
    },
    logger: {
      info: (message, data) => logs.push({message, data}),
      warn: (message, data) => logs.push({message, data}),
      error: (message, data) => logs.push({message, data}),
    },
  });

  const event = {
    id: "event-123",
    params: {
      brandUid: "brand-path",
      operationId: "operation-123",
    },
    data: makeSnapshot(new FakeDocumentReference(operationPath), {
      title: "Bosch fren balatası taraması",
      objective: "Şüpheli satış kanallarını incele.",
      priority: "normal",
      createdAt: "OPERATION_TIMESTAMP",
      tenantId: "attacker-tenant",
      brandId: "attacker-brand",
    }),
  };

  return {creates, documents, event, handler, logs, options, taskPath};
}

async function testPureMapping() {
  assert.equal(normalizePriority("low"), "low");
  assert.equal(normalizePriority("normal"), "medium");
  assert.equal(normalizePriority("high"), "high");
  assert.equal(normalizePriority("critical"), "high");
  assert.equal(buildTaskName({title: "Başlık", objective: "Amaç"}), "Başlık");
  assert.equal(buildTaskName({title: "", objective: "Amaç"}), "Amaç");
  assert.equal(buildTaskName({title: "", objective: ""}), "");

  const data = buildDigitalDetectiveTaskData({
    brandUid: "brand-path",
    operationId: "operation-123",
    operationData: {
      title: "Operasyon",
      objective: "Amaç",
      priority: "normal",
    },
    plannerInput: {
      brandName: "Bosch",
      productName: "Fren balatası",
      sellerName: "Örnek Mağaza",
      targetUrl: "https://example.test/item",
    },
    serverTimestamp: "SERVER_TIMESTAMP",
  });

  assert.equal(data.ownerUid, "brand-path");
  assert.equal(data.taskName, "Operasyon");
  assert.equal(data.brandName, "Bosch");
  assert.equal(data.productName, "Fren balatası");
  assert.equal(data.targetSeller, "Örnek Mağaza");
  assert.equal(data.initialUrl, "https://example.test/item");
  assert.equal(data.frequency, "once");
  assert.equal(data.riskLevel, "medium");
  assert.equal(data.sourceType, "ai_field_operation");
  assert.equal(data.sourceOperationId, "operation-123");
  assert.equal(data.bridgeVersion, BRIDGE_VERSION);
  assert.equal(data.endDate, null);
  assert.equal(data.createdAt, "SERVER_TIMESTAMP");
  assert.equal(data.startDate, "SERVER_TIMESTAMP");
  assert.equal("categoryId" in data, false);
  assert.equal("violationIds" in data, false);
  assert.equal("sources" in data, false);
  assert.equal("countries" in data, false);
  assert.equal("currency" in data, false);
}

async function testBridgeContractHasNoExternalDispatch() {
  // This is a limited source guard, not a substitute for behavioral tests.
  const source = fs.readFileSync(
      path.join(__dirname, "ai_field_operation_bridge.js"),
      "utf8",
  );

  assert.equal(OPERATION_DOCUMENT.includes("agentTasks"), false);
  assert.equal(source.includes("fetch("), false);
  assert.equal(source.includes("axios"), false);
  assert.equal(source.includes("http.request"), false);
  assert.equal(source.includes("https.request"), false);
  assert.equal(source.includes("defineSecret"), false);
  assert.equal(source.includes("secret.value"), false);
  assert.equal(source.includes("webhook"), false);
  assert.equal(source.includes("X-MarkaKalkan-Token"), false);
  assert.equal(source.includes("plannerRef.set"), false);
  assert.equal(source.includes("plannerRef.create"), false);
  assert.equal(source.includes("plannerRef.update"), false);
  assert.equal(source.includes("plannerRef.delete"), false);
}

async function testCreateAndDuplicate() {
  const harness = makeHarness({
    plannerData: {
      input: {
        brandName: "Bosch",
        productName: "Fren balatası",
        sellerName: "Hedef Satıcı",
        targetUrl: "https://example.test/bosch",
        tenantId: "attacker-tenant",
      },
    },
  });

  assert.equal(harness.options.document, OPERATION_DOCUMENT);
  assert.equal(harness.options.retry, true);
  assert.equal(harness.options.timeoutSeconds, 60);

  await harness.handler(harness.event);
  await harness.handler({...harness.event, id: "event-duplicate"});

  assert.equal(harness.creates.length, 1);
  assert.equal(harness.creates[0].path, harness.taskPath);
  assert.equal(harness.creates[0].data.ownerUid, "brand-path");
  assert.equal(harness.creates[0].data.sourceOperationId, "operation-123");
  assert.equal(harness.creates[0].data.createdAt, "OPERATION_TIMESTAMP");
  assert.equal(harness.creates[0].data.startDate, "OPERATION_TIMESTAMP");
  assert.equal(harness.creates[0].data.endDate, null);
  assert.equal(harness.creates[0].data.tenantId, undefined);
  assert.equal(harness.creates[0].data.brandId, undefined);
}

async function testExistingTargetIsNoOp() {
  const harness = makeHarness({existingTask: {status: "running"}});
  await harness.handler(harness.event);
  assert.equal(harness.creates.length, 0);
}

async function testMissingPlannerUsesNoFakeValues() {
  const harness = makeHarness();
  await harness.handler(harness.event);

  assert.equal(harness.creates.length, 1);
  assert.equal("brandName" in harness.creates[0].data, false);
  assert.equal("productName" in harness.creates[0].data, false);
  assert.equal("targetSeller" in harness.creates[0].data, false);
  assert.equal("initialUrl" in harness.creates[0].data, false);
  assert.equal(
      harness.creates[0].data.taskName,
      "Bosch fren balatası taraması",
  );
}

async function testInvalidPlannerInputsAreIgnored() {
  for (const input of [null, "invalid", []]) {
    const harness = makeHarness({plannerData: {input}});
    await harness.handler(harness.event);
    assert.equal(harness.creates.length, 1);
    assert.equal("brandName" in harness.creates[0].data, false);
    assert.equal("productName" in harness.creates[0].data, false);
  }
}

async function testInvalidEventsCompleteWithoutCreate() {
  const noParams = makeHarness();
  await noParams.handler({...noParams.event, params: undefined});
  assert.equal(noParams.creates.length, 0);

  const noBrand = makeHarness();
  await noBrand.handler({
    ...noBrand.event,
    params: {operationId: "operation-123"},
  });
  assert.equal(noBrand.creates.length, 0);

  const noOperation = makeHarness();
  await noOperation.handler({
    ...noOperation.event,
    params: {brandUid: "brand-path"},
  });
  assert.equal(noOperation.creates.length, 0);

  const noName = makeHarness();
  await noName.handler({
    ...noName.event,
    data: makeSnapshot(noName.event.data.ref, {
      title: " ",
      objective: " ",
      priority: "normal",
    }),
  });
  assert.equal(noName.creates.length, 0);
}

async function testObjectiveProvidesTaskNameFallback() {
  const harness = makeHarness();
  await harness.handler({
    ...harness.event,
    data: makeSnapshot(harness.event.data.ref, {
      title: " ",
      objective: "Amaçtan türetilen görev adı",
      priority: "normal",
      createdAt: "OPERATION_TIMESTAMP",
    }),
  });

  assert.equal(harness.creates.length, 1);
  assert.equal(
      harness.creates[0].data.taskName,
      "Amaçtan türetilen görev adı",
  );
}

async function main() {
  await testPureMapping();
  await testBridgeContractHasNoExternalDispatch();
  await testCreateAndDuplicate();
  await testExistingTargetIsNoOp();
  await testMissingPlannerUsesNoFakeValues();
  await testInvalidPlannerInputsAreIgnored();
  await testInvalidEventsCompleteWithoutCreate();
  await testObjectiveProvidesTaskNameFallback();
  console.log("ai_field_operation_bridge.test.js: PASS");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
