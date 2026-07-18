const assert = require("node:assert/strict");

const {
  AGENTS,
  EXPECTED_AGENT_CODES,
  RESULT_CONTRACT_VERSION,
  RESULT_TOKEN_HEADER,
  buildReceiveDigitalDetectiveResult,
  calculateExecutionStatus,
  constantTimeEqual,
  normalizeResultPayload,
  sha256Hex,
} = require("./digital_detective_result");

function clone(value) {
  return value === undefined ?
    undefined :
    JSON.parse(JSON.stringify(value));
}

class FakeDocumentReference {
  constructor(store, path) {
    this.store = store;
    this.path = path;
  }

  collection(name) {
    return new FakeCollectionReference(
        this.store,
        `${this.path}/${name}`,
    );
  }
}

class FakeCollectionReference {
  constructor(store, path) {
    this.store = store;
    this.path = path;
  }

  doc(id) {
    return new FakeDocumentReference(
        this.store,
        `${this.path}/${id}`,
    );
  }
}

class FakeFirestore {
  constructor(initialDocuments = {}) {
    this.documents = new Map(
        Object.entries(initialDocuments).map(
            ([path, value]) => [path, clone(value)],
        ),
    );
  }

  collection(name) {
    return new FakeCollectionReference(this, name);
  }

  snapshot(reference) {
    const value = this.documents.get(reference.path);

    return {
      exists: value !== undefined,
      data: () => clone(value),
    };
  }

  async runTransaction(callback) {
    const transaction = {
      get: async (reference) => this.snapshot(reference),
      set: (reference, value, options = {}) => {
        const existing = this.documents.get(reference.path);
        const nextValue = options.merge && existing ?
          {...clone(existing), ...clone(value)} :
          clone(value);

        this.documents.set(reference.path, nextValue);
      },
      update: (reference, value) => {
        const existing = this.documents.get(reference.path);

        if (existing === undefined) {
          throw new Error(`Missing document: ${reference.path}`);
        }

        this.documents.set(
            reference.path,
            {...clone(existing), ...clone(value)},
        );
      },
    };

    return callback(transaction);
  }
}

function makeAdmin() {
  return {
    firestore: {
      FieldValue: {
        serverTimestamp: () => "SERVER_TIMESTAMP",
      },
    },
  };
}

function makeResponse() {
  return {
    statusCode: 200,
    headers: {},
    body: null,
    set(name, value) {
      this.headers[name] = value;
      return this;
    },
    status(value) {
      this.statusCode = value;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
  };
}

function makePayload(agent, overrides = {}) {
  return {
    contractVersion: RESULT_CONTRACT_VERSION,
    tenantId: "brand-123",
    brandId: "brand-123",
    taskId: "task-456",
    executionId: "execution-789",
    agentCode: agent.code,
    agentSequence: agent.sequence,
    status: "completed",
    output: `Çıktı: ${agent.name}`,
    metadata: {
      test: true,
    },
    ...overrides,
  };
}

function makeHandler({db, tokenValue = "result-secret"}) {
  let capturedOptions;
  let capturedHandler;

  const onRequest = (options, handler) => {
    capturedOptions = options;
    capturedHandler = handler;
    return {options, handler};
  };
  const logs = [];

  buildReceiveDigitalDetectiveResult({
    db,
    admin: makeAdmin(),
    onRequest,
    logger: {
      info: (message, data) => logs.push({level: "info", message, data}),
      warn: (message, data) => logs.push({level: "warn", message, data}),
      error: (message, data) => logs.push({level: "error", message, data}),
    },
    resultToken: {
      value: () => tokenValue,
    },
  });

  return {
    capturedOptions,
    handler: capturedHandler,
    logs,
  };
}

async function invoke(handler, {
  body,
  token = "result-secret",
  method = "POST",
}) {
  const response = makeResponse();
  const request = {
    method,
    body,
    headers: {
      [RESULT_TOKEN_HEADER.toLowerCase()]: token,
    },
    get(name) {
      return this.headers[name.toLowerCase()];
    },
  };

  await handler(request, response);
  return response;
}

async function testPureHelpers() {
  assert.equal(constantTimeEqual("abc", "abc"), true);
  assert.equal(constantTimeEqual("abc", "abd"), false);
  assert.equal(sha256Hex("value").length, 64);

  assert.equal(
      calculateExecutionStatus({
        completedAgentCodes: ["task_planner"],
        failedAgentCodes: [],
      }),
      "running",
  );
  assert.equal(
      calculateExecutionStatus({
        completedAgentCodes: EXPECTED_AGENT_CODES,
        failedAgentCodes: [],
      }),
      "completed",
  );
  assert.equal(
      calculateExecutionStatus({
        completedAgentCodes: EXPECTED_AGENT_CODES.slice(0, -1),
        failedAgentCodes: [EXPECTED_AGENT_CODES.at(-1)],
      }),
      "failed",
  );

  const normalized = normalizeResultPayload(
      makePayload(AGENTS[0]),
  );

  assert.equal(normalized.agentCode, "task_planner");
  assert.equal(normalized.agentSequence, 1);
  assert.equal(normalized.outputType, "text");

  assert.throws(
      () => normalizeResultPayload(
          makePayload(AGENTS[0], {
            agentSequence: 12,
          }),
      ),
      /agentSequence/,
  );
}

async function testAuthorizationAndMethod() {
  const db = new FakeFirestore();
  const {capturedOptions, handler} = makeHandler({db});

  assert.equal(capturedOptions.timeoutSeconds, 60);
  assert.equal(capturedOptions.maxInstances, 5);
  assert.equal(capturedOptions.secrets.length, 1);

  const forbidden = await invoke(handler, {
    body: makePayload(AGENTS[0]),
    token: "wrong-secret",
  });

  assert.equal(forbidden.statusCode, 403);
  assert.equal(forbidden.body.code, "forbidden");

  const methodNotAllowed = await invoke(handler, {
    body: makePayload(AGENTS[0]),
    method: "GET",
  });

  assert.equal(methodNotAllowed.statusCode, 405);
  assert.equal(methodNotAllowed.headers.Allow, "POST");
}

async function testAllAgentsAndDuplicate() {
  const taskPath =
    "brands/brand-123/digitalDetectiveTasks/task-456";
  const db = new FakeFirestore({
    [taskPath]: {
      ownerUid: "brand-123",
      status: "running",
      processedCount: 0,
      resultCount: 0,
    },
  });
  const {handler} = makeHandler({db});

  const firstResponse = await invoke(handler, {
    body: makePayload(AGENTS[0]),
  });

  assert.equal(firstResponse.statusCode, 200);
  assert.equal(firstResponse.body.duplicate, false);
  assert.equal(firstResponse.body.receivedAgentCount, 1);
  assert.equal(
      db.documents.get(taskPath).status,
      "running",
  );
  assert.equal(
      db.documents.get(taskPath).processedCount,
      1,
  );

  const duplicateResponse = await invoke(handler, {
    body: makePayload(AGENTS[0]),
  });

  assert.equal(duplicateResponse.statusCode, 200);
  assert.equal(duplicateResponse.body.duplicate, true);
  assert.equal(duplicateResponse.body.receivedAgentCount, 1);

  for (const agent of AGENTS.slice(1)) {
    const response = await invoke(handler, {
      body: makePayload(agent),
    });

    assert.equal(response.statusCode, 200);
  }

  const task = db.documents.get(taskPath);

  assert.equal(task.status, "completed");
  assert.equal(task.processedCount, 12);
  assert.equal(task.resultCount, 0);
  assert.equal(task.completedAt, "SERVER_TIMESTAMP");
  assert.equal(task.resultProcessing.receivedAgentCount, 12);
  assert.equal(task.resultProcessing.failedAgentCount, 0);

  const resultDocuments = [...db.documents.keys()]
      .filter((path) => path.includes("/agentResults/"));

  assert.equal(resultDocuments.length, 12);
}

async function testFailedExecution() {
  const taskPath =
    "brands/brand-123/digitalDetectiveTasks/task-456";
  const db = new FakeFirestore({
    [taskPath]: {
      ownerUid: "brand-123",
      status: "running",
      processedCount: 0,
      resultCount: 0,
    },
  });
  const {handler} = makeHandler({db});

  for (const agent of AGENTS) {
    const response = await invoke(handler, {
      body: makePayload(agent, {
        status: agent.code === "visual_matcher" ?
          "failed" :
          "completed",
        output: agent.code === "visual_matcher" ?
          {error: "Model output unavailable"} :
          `Çıktı: ${agent.name}`,
      }),
    });

    assert.equal(response.statusCode, 200);
  }

  const task = db.documents.get(taskPath);

  assert.equal(task.status, "failed");
  assert.equal(task.processedCount, 12);
  assert.equal(task.resultProcessing.failedAgentCount, 1);
}

async function testMissingTask() {
  const db = new FakeFirestore();
  const {handler} = makeHandler({db});

  const response = await invoke(handler, {
    body: makePayload(AGENTS[0]),
  });

  assert.equal(response.statusCode, 404);
  assert.equal(response.body.code, "task_not_found");
}

async function main() {
  await testPureHelpers();
  await testAuthorizationAndMethod();
  await testAllAgentsAndDuplicate();
  await testFailedExecution();
  await testMissingTask();

  console.log("digital_detective_result.test.js: PASS");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
