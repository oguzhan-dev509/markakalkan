const assert = require("node:assert/strict");

const {
  TASK_DOCUMENT,
  buildDispatchDigitalDetectiveTask,
  buildTargetSummary,
  buildWebhookPayload,
  normalizePriority,
  safeResponseText,
  timestampToIso,
} = require("./digital_detective_dispatch");

function makeTimestamp(iso) {
  return {
    toDate: () => new Date(iso),
  };
}

async function testPureHelpers() {
  assert.equal(normalizePriority("critical"), "high");
  assert.equal(normalizePriority("HIGH"), "high");
  assert.equal(normalizePriority("medium"), "medium");
  assert.equal(normalizePriority("unknown"), "low");

  const fallbackIso = "2026-07-17T06:00:00.000Z";

  assert.equal(
      timestampToIso(
          makeTimestamp("2026-07-16T18:29:13.000Z"),
          fallbackIso,
      ),
      "2026-07-16T18:29:13.000Z",
  );
  assert.equal(timestampToIso(null, fallbackIso), fallbackIso);
  assert.equal(safeResponseText("  hello \n world  "), "hello world");

  const taskData = {
    taskName: "Yedek parça araştırması",
    brandName: "Örnek Marka",
    productName: "Fren balatası",
    categoryId: "automotive",
    subcategory: "spare_parts",
    violationIds: ["counterfeit_listing"],
    sources: ["marketplaces", "web"],
    searchTerms: ["örnek fren balatası"],
    excludedTerms: ["ikinci el"],
    countries: ["TR"],
    cities: ["İstanbul"],
    minimumPrice: 100,
    maximumPrice: 500,
    currency: "TRY",
    frequency: "once",
    riskLevel: "high",
    startDate: makeTimestamp("2026-07-16T00:00:00.000Z"),
    endDate: makeTimestamp("2026-07-31T00:00:00.000Z"),
    createdAt: makeTimestamp("2026-07-16T18:29:13.000Z"),
  };

  const target = buildTargetSummary(taskData);

  assert.match(target, /Marka: Örnek Marka/);
  assert.match(target, /Ürün: Fren balatası/);
  assert.match(target, /Arama terimleri: örnek fren balatası/);
  assert.match(target, /Fiyat aralığı: 100-500 TRY/);

  const payload = buildWebhookPayload({
    brandUid: "brand-123",
    taskId: "task-456",
    taskData,
    fallbackIso,
  });

  assert.equal(payload.taskId, "task-456");
  assert.equal(payload.tenantId, "brand-123");
  assert.equal(payload.brandId, "brand-123");
  assert.equal(payload.taskType, "digital_market_intelligence");
  assert.equal(payload.priority, "high");
  assert.equal(payload.createdAt, "2026-07-16T18:29:13.000Z");
  assert.deepEqual(payload.context.countries, ["TR"]);
}

async function testSuccessfulDispatch() {
  const fieldValue = {
    serverTimestamp: () => "SERVER_TIMESTAMP",
  };
  const now = {
    toDate: () => new Date("2026-07-17T06:00:00.000Z"),
  };
  const admin = {
    firestore: {
      FieldValue: fieldValue,
      Timestamp: {
        now: () => now,
      },
    },
  };

  const taskData = {
    taskName: "Test görevi",
    brandName: "MarkaKalkan",
    productName: "Test ürün",
    categoryId: "test",
    violationIds: ["counterfeit"],
    sources: ["web"],
    searchTerms: ["test"],
    excludedTerms: [],
    countries: ["TR"],
    cities: [],
    minimumPrice: null,
    maximumPrice: null,
    currency: "TRY",
    frequency: "once",
    riskLevel: "medium",
    startDate: makeTimestamp("2026-07-17T00:00:00.000Z"),
    endDate: makeTimestamp("2026-07-18T00:00:00.000Z"),
    createdAt: makeTimestamp("2026-07-17T06:00:00.000Z"),
    status: "queued",
  };

  const updates = [];
  const taskRef = {
    update: async (data) => {
      updates.push(data);
    },
    get: async () => ({
      exists: true,
      data: () => ({
        dispatch: {
          status: "dispatched",
        },
      }),
    }),
  };
  const currentSnapshot = {
    exists: true,
    data: () => taskData,
  };
  const db = {
    runTransaction: async (callback) => callback({
      get: async () => currentSnapshot,
      update: (_reference, data) => {
        updates.push(data);
      },
    }),
  };

  let capturedOptions;
  let capturedHandler;
  const onDocumentCreated = (options, handler) => {
    capturedOptions = options;
    capturedHandler = handler;
    return {options, handler};
  };

  let request;
  const fetchImpl = async (url, options) => {
    request = {url, options};

    return {
      ok: true,
      status: 200,
      text: async () => "{\"message\":\"Workflow was started\"}",
    };
  };

  const webhookToken = {
    value: () => "secret-token",
  };
  const logger = {
    info: () => {},
    warn: () => {},
    error: () => {},
  };

  buildDispatchDigitalDetectiveTask({
    db,
    admin,
    onDocumentCreated,
    logger,
    fetchImpl,
    webhookToken,
    webhookUrl: "https://example.test/webhook",
  });

  assert.equal(capturedOptions.document, TASK_DOCUMENT);
  assert.equal(capturedOptions.retry, false);
  assert.equal(capturedOptions.timeoutSeconds, 60);
  assert.deepEqual(capturedOptions.secrets, [webhookToken]);

  await capturedHandler({
    id: "event-001",
    params: {
      brandUid: "brand-123",
      taskId: "task-456",
    },
    data: {
      ref: taskRef,
    },
  });

  assert.equal(request.url, "https://example.test/webhook");
  assert.equal(request.options.method, "POST");
  assert.equal(
      request.options.headers["X-MarkaKalkan-Token"],
      "secret-token",
  );

  const body = JSON.parse(request.options.body);

  assert.equal(body.taskId, "task-456");
  assert.equal(body.tenantId, "brand-123");
  assert.equal(body.priority, "medium");
  assert.equal(updates.length, 2);
  assert.equal(updates[0].status, "running");
  assert.equal(updates[0]["dispatch.status"], "dispatching");
  assert.equal(updates[1]["dispatch.status"], "dispatched");
  assert.equal(updates[1]["dispatch.httpStatus"], 200);
}

async function testDuplicateDispatchIsSkipped() {
  const admin = {
    firestore: {
      FieldValue: {
        serverTimestamp: () => "SERVER_TIMESTAMP",
      },
      Timestamp: {
        now: () => ({
          toDate: () => new Date("2026-07-17T06:00:00.000Z"),
        }),
      },
    },
  };

  const taskRef = {
    update: async () => {
      throw new Error("No update expected");
    },
  };
  const db = {
    runTransaction: async (callback) => callback({
      get: async () => ({
        exists: true,
        data: () => ({
          status: "running",
          dispatch: {
            status: "dispatched",
          },
        }),
      }),
      update: () => {
        throw new Error("No transaction update expected");
      },
    }),
  };

  let handler;
  const onDocumentCreated = (_options, callback) => {
    handler = callback;
    return callback;
  };
  let fetchCalled = false;

  buildDispatchDigitalDetectiveTask({
    db,
    admin,
    onDocumentCreated,
    logger: {
      info: () => {},
      warn: () => {},
      error: () => {},
    },
    fetchImpl: async () => {
      fetchCalled = true;
    },
    webhookToken: {
      value: () => "secret-token",
    },
  });

  await handler({
    id: "event-duplicate",
    params: {
      brandUid: "brand-123",
      taskId: "task-456",
    },
    data: {
      ref: taskRef,
    },
  });

  assert.equal(fetchCalled, false);
}

async function main() {
  await testPureHelpers();
  await testSuccessfulDispatch();
  await testDuplicateDispatchIsSkipped();
  console.log("digital_detective_dispatch.test.js: PASS");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
