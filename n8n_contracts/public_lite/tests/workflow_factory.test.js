"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const vm = require("node:vm");

const validDispatch = require("../fixtures/valid_dispatch_envelope.json");
const {
  ACQUISITION_COMMAND_VERSION,
  ACQUISITION_HEADER,
  ACQUISITION_NODE_IDS,
  ACQUISITION_RECEIPT_VERSION,
  ACQUISITION_WEBHOOK_PATH,
  ACQUISITION_WORKFLOW_NAME,
  CALLBACK_URL,
  DISPATCH_RECEIPT_VERSION_V2,
  HANDOFF_HEADER,
  HANDOFF_RECEIPT_VERSION,
  HANDOFF_REQUEST_VERSION,
  HANDOFF_URL,
  NODE_IDS,
  RESULT_HEADER,
  WEBHOOK_HEADER,
  WEBHOOK_PATH,
  WORKFLOW_NAME,
  acquisitionCommandValidatorCode,
  acquisitionGuardCode,
  acquisitionPlanCode,
  acquisitionReceiptCode,
  buildAcquisitionWorkflow,
  buildWorkflow,
  canonicalJson,
  handoffRequestCode,
  marketplaceNormalizerCode,
  providerAssemblerCode,
  receiptCode,
  resultTemplateBody,
  serializeWorkflow,
  validatorCode,
} = require("../src/workflow_factory");

function findNode(workflow, name) {
  return workflow.nodes.find((node) => node.name === name);
}

async function executeCode(code, {
  input,
  executionId = "12345",
  contextByNode = {},
} = {}) {
  const functionBody = `"use strict";\n${code}`;
  const runner = new Function(
    "$input",
    "$execution",
    "$",
    functionBody,
  );
  return runner(
    {
      first() {
        return {json: input};
      },
    },
    {id: executionId},
    (nodeName) => ({
      first() {
        if (!Object.hasOwn(contextByNode, nodeName)) {
          throw new Error(`missing test context: ${nodeName}`);
        }
        return {json: contextByNode[nodeName]};
      },
    }),
  );
}

function executeCodeInRestrictedVm(code, {
  input,
  executionId = "12345",
} = {}) {
  const context = {
    $input: {
      first() {
        return {json: input};
      },
    },
    $execution: {id: executionId},
  };
  return vm.runInNewContext(
    `"use strict"; (() => {${code}})();`,
    context,
    {timeout: 1000},
  );
}

async function executeIntegrationCode(code, {
  input,
  contextByNode = {},
  executionId = "12345",
} = {}) {
  const runner = new Function(
    "$input",
    "$",
    "$execution",
    `"use strict"; return (async () => {${code}})();`,
  );
  return runner(
    {
      first() {
        return {json: input};
      },
    },
    (nodeName) => ({
      first() {
        if (!Object.hasOwn(contextByNode, nodeName)) {
          throw new Error(`missing test context: ${nodeName}`);
        }
        return {json: contextByNode[nodeName]};
      },
    }),
    {id: executionId},
  );
}

function validAcquisitionCommand() {
  return {
    contractVersion: ACQUISITION_COMMAND_VERSION,
    handoffId: "d".repeat(64),
    executionId: validDispatch.executionId,
    scanRunId: validDispatch.scanRunId,
    dispatchEnvelope: validDispatch,
    attempt: 1,
    leaseToken: "e".repeat(64),
  };
}

function validHandoffReceipt() {
  return {
    contractVersion: HANDOFF_RECEIPT_VERSION,
    providerCode: "n8n_public_lite",
    handoffId: "d".repeat(64),
    executionId: validDispatch.executionId,
    scanRunId: validDispatch.scanRunId,
    gatewayExecutionId: "n8n:998877",
    acceptedAt: "2026-08-06T12:00:00.000Z",
    state: "accepted",
    replayed: false,
  };
}

test("durable handoff contract constants are stable", () => {
  assert.equal(
    HANDOFF_REQUEST_VERSION,
    "risk-scan-public-lite-provider-handoff-request-v1",
  );
  assert.equal(
    HANDOFF_RECEIPT_VERSION,
    "risk-scan-public-lite-provider-handoff-receipt-v1",
  );
  assert.equal(
    DISPATCH_RECEIPT_VERSION_V2,
    "risk-scan-public-lite-dispatch-receipt-v2",
  );
  assert.equal(
    ACQUISITION_COMMAND_VERSION,
    "risk-scan-public-lite-acquisition-command-v1",
  );
  assert.equal(
    ACQUISITION_RECEIPT_VERSION,
    "risk-scan-public-lite-acquisition-dispatch-receipt-v2",
  );
});

test("parent gateway identity and eight nodes are deterministic", () => {
  const workflow = buildWorkflow();
  assert.equal(workflow.name, WORKFLOW_NAME);
  assert.equal(
    workflow.versionId,
    "8fcca337-2349-590e-a27b-fa9ab52e49c3",
  );
  assert.equal(workflow.active, false);
  assert.equal(workflow.nodes.length, 8);
  assert.deepEqual(
    workflow.nodes.map((node) => node.id).sort(),
    Object.values(NODE_IDS).sort(),
  );
});

test("child worker identity and thirteen nodes are deterministic", () => {
  const workflow = buildAcquisitionWorkflow();
  assert.equal(workflow.name, ACQUISITION_WORKFLOW_NAME);
  assert.equal(
    workflow.versionId,
    "24501e82-58b3-5cd1-8ed3-00eb5d7581a7",
  );
  assert.equal(workflow.active, false);
  assert.equal(workflow.nodes.length, 13);
  assert.deepEqual(
    workflow.nodes.map((node) => node.id).sort(),
    Object.values(ACQUISITION_NODE_IDS).sort(),
  );
});

test("unbound parent ingress and handoff HTTP nodes are disabled", () => {
  const workflow = buildWorkflow();
  const webhook = findNode(
    workflow,
    "Public Lite Dispatch Webhook",
  );
  const handoff = findNode(
    workflow,
    "Persist Durable Provider Handoff",
  );
  assert.equal(webhook.disabled, true);
  assert.equal(webhook.parameters.path, WEBHOOK_PATH);
  assert.equal(webhook.parameters.authentication, undefined);
  assert.equal(webhook.credentials, undefined);
  assert.equal(handoff.disabled, true);
  assert.equal(handoff.parameters.url, HANDOFF_URL);
  assert.equal(handoff.parameters.authentication, "none");
  assert.equal(handoff.credentials, undefined);
});

test("bound parent uses separate webhook and handoff credentials", () => {
  const workflow = buildWorkflow({
    webhookCredentialId: "webhook-id",
    webhookCredentialName: "Public Lite Webhook Header Auth",
    handoffCredentialId: "handoff-id",
    handoffCredentialName: "Public Lite Handoff Header Auth",
  });
  const webhook = findNode(
    workflow,
    "Public Lite Dispatch Webhook",
  );
  const handoff = findNode(
    workflow,
    "Persist Durable Provider Handoff",
  );
  assert.equal(webhook.disabled, false);
  assert.equal(webhook.parameters.authentication, "headerAuth");
  assert.deepEqual(webhook.credentials, {
    httpHeaderAuth: {
      id: "webhook-id",
      name: "Public Lite Webhook Header Auth",
    },
  });
  assert.equal(handoff.disabled, false);
  assert.equal(
    handoff.parameters.authentication,
    "genericCredentialType",
  );
  assert.equal(
    handoff.parameters.genericAuthType,
    "httpHeaderAuth",
  );
  assert.deepEqual(handoff.credentials, {
    httpHeaderAuth: {
      id: "handoff-id",
      name: "Public Lite Handoff Header Auth",
    },
  });
  assert.equal(workflow.active, false);
  assert.equal(workflow.meta.activationAllowed, false);
});

test("partial parent credential bindings are rejected", () => {
  assert.throws(
    () => buildWorkflow({
      webhookCredentialId: "webhook-id",
    }),
    /webhook credential id and name must be supplied together/u,
  );
  assert.throws(
    () => buildWorkflow({
      handoffCredentialName: "Handoff Credential",
    }),
    /handoff credential id and name must be supplied together/u,
  );
});

test("parent topology persists before building and returning HTTP 202", () => {
  const workflow = buildWorkflow();
  assert.deepEqual(workflow.connections, {
    "Public Lite Dispatch Webhook": {
      main: [[{
        node: "Validate Public Lite Dispatch",
        type: "main",
        index: 0,
      }]],
    },
    "Validate Public Lite Dispatch": {
      main: [[{
        node: "Build Durable Provider Handoff Request",
        type: "main",
        index: 0,
      }]],
    },
    "Build Durable Provider Handoff Request": {
      main: [[{
        node: "Persist Durable Provider Handoff",
        type: "main",
        index: 0,
      }]],
    },
    "Persist Durable Provider Handoff": {
      main: [[{
        node: "Build Durable Dispatch Receipt",
        type: "main",
        index: 0,
      }]],
    },
    "Build Durable Dispatch Receipt": {
      main: [[{
        node: "Return 202 Durable Dispatch Receipt",
        type: "main",
        index: 0,
      }]],
    },
  });
  const response = findNode(
    workflow,
    "Return 202 Durable Dispatch Receipt",
  );
  assert.equal(response.parameters.respondWith, "json");
  assert.equal(response.parameters.responseBody, "={{ $json.receipt }}");
  assert.equal(response.parameters.options.responseCode, 202);
});

test("parent contains no acquisition or callback execution nodes", () => {
  const workflow = buildWorkflow();
  const names = workflow.nodes.map((node) => node.name);
  assert.equal(
    names.some((name) => /Trendyol|Marketplace Acquisition/u.test(name)),
    false,
  );
  assert.equal(
    names.some((name) => /Result Callback/u.test(name)),
    false,
  );
  assert.equal(workflow.meta.outboundAcquisition, false);
  assert.equal(workflow.meta.resultCallback, false);
});

test("parent safety note requires durable acceptance before HTTP 202", () => {
  const workflow = buildWorkflow();
  const note = findNode(
    workflow,
    "Gateway V2 Deployment Safety Gate",
  );
  assert.match(note.parameters.content, /HTTP 202 only after/u);
  assert.match(note.parameters.content, /durably accepted/u);
  assert.match(note.parameters.content, /no marketplace acquisition/u);
  assert.match(note.parameters.content, /Do not activate/u);
});

test("parent workflow contains header names but no secret values", () => {
  const serialized = serializeWorkflow(buildWorkflow());
  assert.match(serialized, new RegExp(WEBHOOK_HEADER));
  assert.match(serialized, new RegExp(HANDOFF_HEADER));
  assert.doesNotMatch(serialized, /Bearer\s+[A-Za-z0-9._-]+/u);
  assert.doesNotMatch(serialized, /AIza[0-9A-Za-z_-]{20,}/u);
  assert.doesNotMatch(
    serialized,
    /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----/u,
  );
});

test("validator code accepts webhook and direct dispatch envelopes", async () => {
  const webhookOutput = await executeCode(validatorCode(), {
    input: {body: validDispatch},
  });
  const directOutput = await executeCode(validatorCode(), {
    input: validDispatch,
  });
  assert.equal(
    webhookOutput[0].json.dispatchEnvelope.executionId,
    validDispatch.executionId,
  );
  assert.equal(
    directOutput[0].json.dispatchEnvelope.scanRunId,
    validDispatch.scanRunId,
  );
});

test("validator code rejects tenant and token-like drift", async () => {
  await assert.rejects(
    async () => executeCode(validatorCode(), {
      input: {
        body: {
          ...validDispatch,
          tenantId: "forbidden",
        },
      },
    }),
    /PUBLIC_LITE_DISPATCH_REJECTED/u,
  );
  const dispatch = JSON.parse(JSON.stringify(validDispatch));
  dispatch.target.token = "forbidden";
  await assert.rejects(
    async () => executeCode(validatorCode(), {
      input: {body: dispatch},
    }),
    /target keys are invalid/u,
  );
});

test("handoff request binds dispatch to the parent execution", async () => {
  const output = await executeCode(handoffRequestCode(), {
    input: {dispatchEnvelope: validDispatch},
    executionId: "998877",
  });
  const request = output[0].json.handoffRequest;
  assert.deepEqual(request, {
    contractVersion: HANDOFF_REQUEST_VERSION,
    providerCode: "n8n_public_lite",
    executionId: validDispatch.executionId,
    scanRunId: validDispatch.scanRunId,
    gatewayExecutionId: "n8n:998877",
    dispatchEnvelope: validDispatch,
  });
});

test("handoff request rejects a missing parent execution id", async () => {
  await assert.rejects(
    async () => executeCode(handoffRequestCode(), {
      input: {dispatchEnvelope: validDispatch},
      executionId: "",
    }),
    /n8n execution id missing/u,
  );
});

test("durable receipt maps backend acceptance to dispatch receipt v2", async () => {
  const requestContext = {
    dispatchEnvelope: validDispatch,
    handoffRequest: {
      contractVersion: HANDOFF_REQUEST_VERSION,
      providerCode: "n8n_public_lite",
      executionId: validDispatch.executionId,
      scanRunId: validDispatch.scanRunId,
      gatewayExecutionId: "n8n:998877",
      dispatchEnvelope: validDispatch,
    },
  };
  const output = await executeIntegrationCode(receiptCode(), {
    input: {
      statusCode: 200,
      body: validHandoffReceipt(),
    },
    contextByNode: {
      "Build Durable Provider Handoff Request": requestContext,
    },
  });
  assert.deepEqual(output[0].json.receipt, {
    contractVersion: DISPATCH_RECEIPT_VERSION_V2,
    providerCode: "n8n_public_lite",
    executionId: validDispatch.executionId,
    externalExecutionId: "n8n:998877",
    handoffId: "d".repeat(64),
    acceptedAt: "2026-08-06T12:00:00.000Z",
  });
  assert.equal(
    output[0].json.gatewayState.durableProviderHandoffAccepted,
    true,
  );
  assert.equal(output[0].json.gatewayState.outboundAcquisition, false);
});

test("durable receipt rejects non-200 and mismatched scope", async () => {
  const requestContext = {
    dispatchEnvelope: validDispatch,
    handoffRequest: {
      contractVersion: HANDOFF_REQUEST_VERSION,
      providerCode: "n8n_public_lite",
      executionId: validDispatch.executionId,
      scanRunId: validDispatch.scanRunId,
      gatewayExecutionId: "n8n:998877",
      dispatchEnvelope: validDispatch,
    },
  };
  await assert.rejects(
    async () => executeIntegrationCode(receiptCode(), {
      input: {
        statusCode: 409,
        body: {ok: false, code: "conflict"},
      },
      contextByNode: {
        "Build Durable Provider Handoff Request": requestContext,
      },
    }),
    /did not return HTTP 200/u,
  );
  await assert.rejects(
    async () => executeIntegrationCode(receiptCode(), {
      input: {
        statusCode: 200,
        body: {
          ...validHandoffReceipt(),
          executionId: "f".repeat(64),
        },
      },
      contextByNode: {
        "Build Durable Provider Handoff Request": requestContext,
      },
    }),
    /scope does not match/u,
  );
});

test("unbound child ingress is disabled and unauthenticated", () => {
  const workflow = buildAcquisitionWorkflow();
  const webhook = findNode(
    workflow,
    "Acquisition Handoff Webhook",
  );
  assert.equal(webhook.disabled, true);
  assert.equal(webhook.parameters.path, ACQUISITION_WEBHOOK_PATH);
  assert.equal(webhook.parameters.authentication, undefined);
  assert.equal(webhook.credentials, undefined);
});

test("bound child ingress uses the acquisition header credential", () => {
  const workflow = buildAcquisitionWorkflow({
    acquisitionCredentialId: "acquisition-id",
    acquisitionCredentialName: "Acquisition Header Auth",
  });
  const webhook = findNode(
    workflow,
    "Acquisition Handoff Webhook",
  );
  assert.equal(webhook.disabled, false);
  assert.equal(webhook.parameters.authentication, "headerAuth");
  assert.deepEqual(webhook.credentials, {
    httpHeaderAuth: {
      id: "acquisition-id",
      name: "Acquisition Header Auth",
    },
  });
  assert.equal(workflow.active, false);
});

test("partial child credential bindings are rejected", () => {
  assert.throws(
    () => buildAcquisitionWorkflow({
      acquisitionCredentialId: "acquisition-id",
    }),
    /acquisition webhook credential id and name/u,
  );
  assert.throws(
    () => buildAcquisitionWorkflow({
      resultCredentialName: "Result Header Auth",
    }),
    /result credential id and name/u,
  );
});

test("child topology acknowledges before the disabled long path", () => {
  const workflow = buildAcquisitionWorkflow();
  assert.deepEqual(workflow.connections, {
    "Acquisition Handoff Webhook": {
      main: [[{
        node: "Validate Acquisition Handoff Command",
        type: "main",
        index: 0,
      }]],
    },
    "Validate Acquisition Handoff Command": {
      main: [[{
        node: "Build Acquisition Dispatch Receipt",
        type: "main",
        index: 0,
      }]],
    },
    "Build Acquisition Dispatch Receipt": {
      main: [[
        {
          node: "Return 202 Acquisition Dispatch Receipt",
          type: "main",
          index: 0,
        },
        {
          node: "Build Marketplace Limited Acquisition Plan",
          type: "main",
          index: 0,
        },
      ]],
    },
    "Build Marketplace Limited Acquisition Plan": {
      main: [[{
        node: "Assert Marketplace Acquisition Enabled",
        type: "main",
        index: 0,
      }]],
    },
    "Assert Marketplace Acquisition Enabled": {
      main: [[{
        node: "Trendyol Public Listing Acquisition - Disabled",
        type: "main",
        index: 0,
      }]],
    },
    "Trendyol Public Listing Acquisition - Disabled": {
      main: [[{
        node: "Normalize Marketplace Limited Result",
        type: "main",
        index: 0,
      }]],
    },
    "Normalize Marketplace Limited Result": {
      main: [[{
        node: "Assemble Canonical Provider Result",
        type: "main",
        index: 0,
      }]],
    },
  });
  const response = findNode(
    workflow,
    "Return 202 Acquisition Dispatch Receipt",
  );
  assert.equal(response.parameters.options.responseCode, 202);
  assert.equal(response.parameters.responseBody, "={{ $json.receipt }}");
});

test("acquisition command validator accepts the exact backend command", async () => {
  const output = await executeCode(
    acquisitionCommandValidatorCode(),
    {input: {body: validAcquisitionCommand()}},
  );
  const command = output[0].json.acquisitionCommand;
  assert.equal(command.contractVersion, ACQUISITION_COMMAND_VERSION);
  assert.equal(command.handoffId, "d".repeat(64));
  assert.equal(command.executionId, validDispatch.executionId);
  assert.equal(command.attempt, 1);
  assert.equal(command.leaseToken, "e".repeat(64));
});

test("acquisition command validator rejects drift and scope mismatch", async () => {
  await assert.rejects(
    async () => executeCode(
      acquisitionCommandValidatorCode(),
      {
        input: {
          body: {
            ...validAcquisitionCommand(),
            tenantId: "forbidden",
          },
        },
      },
    ),
    /acquisitionCommand keys are invalid/u,
  );
  const mismatched = validAcquisitionCommand();
  mismatched.dispatchEnvelope = {
    ...validDispatch,
    executionId: "f".repeat(64),
  };
  await assert.rejects(
    async () => executeCode(
      acquisitionCommandValidatorCode(),
      {input: {body: mismatched}},
    ),
    /dispatch scope does not match/u,
  );
});

test("acquisition command validator rejects an invalid attempt", async () => {
  await assert.rejects(
    async () => executeCode(
      acquisitionCommandValidatorCode(),
      {
        input: {
          body: {
            ...validAcquisitionCommand(),
            attempt: 6,
          },
        },
      },
    ),
    /outside child dispatch policy/u,
  );
});

test("acquisition receipt binds child execution and handoff scope", async () => {
  const command = validAcquisitionCommand();
  const output = await executeCode(acquisitionReceiptCode(), {
    input: {
      acquisitionCommand: command,
      dispatchEnvelope: validDispatch,
    },
    executionId: "child-7788",
  });
  const receipt = output[0].json.receipt;
  assert.equal(receipt.contractVersion, ACQUISITION_RECEIPT_VERSION);
  assert.equal(receipt.providerCode, "n8n_public_lite");
  assert.equal(receipt.handoffId, command.handoffId);
  assert.equal(receipt.executionId, command.executionId);
  assert.equal(
    receipt.externalExecutionId,
    `n8n-handoff:${command.handoffId}`,
  );
  assert.ok(Number.isFinite(Date.parse(receipt.acceptedAt)));
});

test("child safety note and metadata prohibit activation", () => {
  const workflow = buildAcquisitionWorkflow();
  const note = findNode(
    workflow,
    "Acquisition Worker Deployment Safety Gate",
  );
  assert.match(note.parameters.content, /acknowledges.*HTTP 202/is);
  assert.match(note.parameters.content, /remain disabled/u);
  assert.match(note.parameters.content, /Do not activate/u);
  assert.equal(workflow.meta.activationAllowed, false);
  assert.equal(workflow.meta.acquisitionExecutionEnabled, false);
  assert.equal(workflow.meta.resultCallbackEnabled, false);
});

test("child workflow contains header names but no secret values", () => {
  const serialized = serializeWorkflow(
    buildAcquisitionWorkflow(),
  );
  assert.match(serialized, new RegExp(ACQUISITION_HEADER));
  assert.match(serialized, new RegExp(RESULT_HEADER));
  assert.doesNotMatch(serialized, /Bearer\s+[A-Za-z0-9._-]+/u);
  assert.doesNotMatch(serialized, /AIza[0-9A-Za-z_-]{20,}/u);
});

test("acquisition plan is deterministic, public-only, and disabled", async () => {
  const input = {
    dispatchEnvelope: validDispatch,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n:123",
      acceptedAt: "2026-08-04T00:00:00.000Z",
    },
  };
  const output = await executeCode(acquisitionPlanCode(), {input});
  const plan = output[0].json.acquisitionPlan;
  assert.equal(plan.executionEnabled, false);
  assert.equal(plan.adapterCode, "trendyol_public_listing_v1");
  assert.equal(plan.channelCode, "marketplaceLimited");
  assert.equal(plan.request.method, "GET");
  assert.equal(plan.request.credentials, "omit");
  assert.equal(new URL(plan.request.url).hostname, "www.trendyol.com");
  assert.equal(new URL(plan.request.url).pathname, "/sr");
  assert.equal(new URL(plan.request.url).searchParams.get("q"), "trendyol");
  assert.deepEqual(Object.keys(plan.request.headers).sort(), [
    "Accept",
    "User-Agent",
  ]);
});

test("acquisition plan runs without URL host global in restricted sandbox", () => {
  const dispatch = JSON.parse(JSON.stringify(validDispatch));
  dispatch.target.brandNameNormalized = "marka kalkan ~ A&B";
  const input = {
    dispatchEnvelope: dispatch,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n:123",
      acceptedAt: "2026-08-04T00:00:00.000Z",
    },
  };

  assert.equal(vm.runInNewContext("typeof URL", {}), "undefined");
  const output = executeCodeInRestrictedVm(
    acquisitionPlanCode(),
    {input},
  );
  assert.equal(
    output[0].json.acquisitionPlan.request.url,
    "https://www.trendyol.com/sr?q=marka+kalkan+%7E+A%26B",
  );
  assert.doesNotMatch(acquisitionPlanCode(), /\bnew\s+URL\s*\(/u);
  assert.doesNotMatch(acquisitionPlanCode(), /\.searchParams\b/u);
});

test("acquisition guard rejects the installed disabled state", async () => {
  await assert.rejects(
    async () => executeCode(acquisitionGuardCode(), {
      input: {acquisitionPlan: {executionEnabled: false}},
    }),
    /PUBLIC_LITE_ACQUISITION_DISABLED/,
  );
});

test("acquisition guard accepts only explicit true", async () => {
  const input = {acquisitionPlan: {executionEnabled: true}};
  const output = await executeCode(acquisitionGuardCode(), {input});
  assert.deepEqual(output, [{json: input}]);
});

test("Trendyol HTTP node is disabled, unauthenticated, and bounded", () => {
  const workflow = buildAcquisitionWorkflow();
  const node = findNode(
    workflow,
    "Trendyol Public Listing Acquisition - Disabled",
  );
  assert.equal(node.disabled, true);
  assert.equal(node.parameters.method, "GET");
  assert.equal(node.parameters.authentication, undefined);
  assert.equal(node.credentials, undefined);
  assert.equal(node.parameters.options.timeout, 15000);
  assert.deepEqual(
    node.parameters.options.response.response,
    {
      fullResponse: true,
      neverError: true,
      responseFormat: "text",
    },
  );
  assert.deepEqual(
    node.parameters.headerParameters.parameters.map((entry) => entry.name),
    ["Accept", "User-Agent"],
  );
});

test("marketplace normalizer accepts n8n data response body", async () => {
  const fixture = require(
    "../fixtures/trendyol_public_listing_success.json"
  );
  const planOutput = await executeCode(acquisitionPlanCode(), {
    input: {
      dispatchEnvelope: validDispatch,
      receipt: {
        providerCode: "n8n_public_lite",
        externalExecutionId: "n8n:123",
        acceptedAt: "2026-08-04T00:00:00.000Z",
      },
    },
  });
  const context = planOutput[0].json;
  context.acquisitionPlan.executionEnabled = true;
  const output = await executeIntegrationCode(
    marketplaceNormalizerCode(),
    {
      input: {
        statusCode: fixture.status,
        data: fixture.body,
        headers: fixture.headers,
        url: fixture.url,
      },
      contextByNode: {
        "Build Marketplace Limited Acquisition Plan": context,
      },
    },
  );
  const item = output[0].json;
  assert.equal(
    item.marketplaceLimitedAdapterResult.contractVersion,
    "risk-scan-public-lite-channel-adapter-result-v1",
  );
  assert.equal(item.marketplaceLimitedAdapterResult.summary.candidateCount, 2);
  assert.equal(item.marketplaceLimitedChannel.status, "completed");
  assert.equal(item.marketplaceLimitedChannel.observations.length, 2);
  assert.equal(
    item.marketplaceLimitedChannel.observations[0].sourceHost,
    "www.trendyol.com",
  );
  assert.doesNotMatch(JSON.stringify(item), /must-not-be-recorded/);
});

test("marketplace normalizer preserves real zero-candidate completion", async () => {
  const planOutput = await executeCode(acquisitionPlanCode(), {
    input: {
      dispatchEnvelope: validDispatch,
      receipt: {
        providerCode: "n8n_public_lite",
        externalExecutionId: "n8n:123",
        acceptedAt: "2026-08-04T00:00:00.000Z",
      },
    },
  });
  const context = planOutput[0].json;
  context.acquisitionPlan.executionEnabled = true;
  const output = await executeIntegrationCode(
    marketplaceNormalizerCode(),
    {
      input: {
        statusCode: 200,
        data: "<!doctype html><html><body>No products</body></html>",
        headers: {"content-type": "text/html"},
        url: context.acquisitionPlan.request.url,
      },
      contextByNode: {
        "Build Marketplace Limited Acquisition Plan": context,
      },
    },
  );
  const channel = output[0].json.marketplaceLimitedChannel;
  assert.equal(channel.status, "completed");
  assert.equal(channel.observations.length, 0);
  assert.equal(
    channel.diagnostics.acquisitionOutcomeCode,
    "public_search_completed_no_candidates",
  );
});

test("provider assembler creates canonical three-channel result envelope", async () => {
  const now = "2026-08-04T00:00:00.000Z";
  const input = {
    dispatchEnvelope: validDispatch,
    receipt: {
      providerCode: "n8n_public_lite",
      externalExecutionId: "n8n:123",
      acceptedAt: now,
    },
    marketplaceLimitedChannel: {
      channelCode: "marketplaceLimited",
      status: "completed",
      startedAt: now,
      completedAt: now,
      observations: [],
      diagnostics: {
        acquisitionOutcomeCode: "public_search_completed_no_candidates",
      },
    },
  };
  const output = await executeIntegrationCode(
    providerAssemblerCode(),
    {input},
  );
  const envelope = output[0].json.resultEnvelope;
  assert.equal(
    envelope.contractVersion,
    "risk-scan-public-lite-result-envelope-v1",
  );
  assert.deepEqual(
    envelope.resultPayload.channels.map((channel) => channel.channelCode),
    ["similarDomains", "openWeb", "marketplaceLimited"],
  );
  assert.equal(envelope.resultPayload.executionStatus, "partial");
  assert.equal(envelope.resultPayload.summary.observationCount, 0);
  assert.equal(
    envelope.resultPayload.engine.engineCode,
    "public_lite_marketplace_limited_v1",
  );
});

test("callback remains disabled and unconnected after result assembly", () => {
  const workflow = buildAcquisitionWorkflow();
  const callback = findNode(
    workflow,
    "Result Callback Template - Disabled",
  );
  assert.equal(callback.disabled, true);
  assert.equal(
    workflow.connections["Assemble Canonical Provider Result"],
    undefined,
  );
  assert.equal(
    workflow.connections["Result Callback Template - Disabled"],
    undefined,
  );
});

test("integration workflow contains no tenant, auth, cookie, or API key fields", () => {
  const serialized = serializeWorkflow(buildAcquisitionWorkflow()).toLowerCase();
  assert.doesNotMatch(serialized, /"tenantid"/);
  assert.doesNotMatch(serialized, /"brandid"/);
  assert.doesNotMatch(serialized, /"actoruid"/);
  assert.doesNotMatch(serialized, /"authorization"/);
  assert.doesNotMatch(serialized, /"cookie"/);
  assert.doesNotMatch(serialized, /"x-api-key"/);
  assert.match(serialized, /captch[a-z-]*.*false/);
});

test("explicit activation capabilities remain opt-in and workflow-inactive", () => {
  const workflow = buildAcquisitionWorkflow();
  const acquisition = findNode(
    workflow,
    "Trendyol Public Listing Acquisition - Disabled",
  );
  const callback = findNode(
    workflow,
    "Result Callback Template - Disabled",
  );
  const plan = findNode(
    workflow,
    "Build Marketplace Limited Acquisition Plan",
  );

  assert.equal(workflow.active, false);
  assert.equal(acquisition.disabled, true);
  assert.equal(callback.disabled, true);
  assert.equal(
    workflow.connections["Assemble Canonical Provider Result"],
    undefined,
  );
  assert.match(
    plan.parameters.jsCode,
    /executionEnabled:\s*false/u,
  );
});

test("acquisition can be explicitly enabled without activating workflow", () => {
  const workflow = buildAcquisitionWorkflow({
    acquisitionExecutionEnabled: true,
  });
  const acquisition = findNode(
    workflow,
    "Trendyol Public Listing Acquisition - Disabled",
  );
  const plan = findNode(
    workflow,
    "Build Marketplace Limited Acquisition Plan",
  );

  assert.equal(workflow.active, false);
  assert.equal(acquisition.disabled, false);
  assert.match(
    plan.parameters.jsCode,
    /executionEnabled:\s*true/u,
  );
});

test("result callback enable requires bound result credential", () => {
  assert.throws(
    () => buildAcquisitionWorkflow({
      resultCallbackEnabled: true,
    }),
    /requires result credential binding/u,
  );
});

test("result callback can be explicitly enabled and connected", () => {
  const workflow = buildAcquisitionWorkflow({
    resultCredentialId: "credential-result-activation-1",
    resultCredentialName: "Public Lite Result Header Auth",
    resultCallbackEnabled: true,
  });
  const callback = findNode(
    workflow,
    "Result Callback Template - Disabled",
  );

  assert.equal(workflow.active, false);
  assert.equal(callback.disabled, false);
  assert.equal(
    callback.parameters.authentication,
    "genericCredentialType",
  );
  assert.equal(
    callback.parameters.genericAuthType,
    "httpHeaderAuth",
  );
  assert.deepEqual(callback.credentials, {
    httpHeaderAuth: {
      id: "credential-result-activation-1",
      name: "Public Lite Result Header Auth",
    },
  });
  assert.deepEqual(
    workflow.connections["Assemble Canonical Provider Result"],
    {
      main: [[{
        node: "Result Callback Template - Disabled",
        type: "main",
        index: 0,
      }]],
    },
  );
});

test("activation capability flags must be booleans", () => {
  assert.throws(
    () => buildAcquisitionWorkflow({
      acquisitionExecutionEnabled: "true",
    }),
    /acquisitionExecutionEnabled must be a boolean/u,
  );
  assert.throws(
    () => buildAcquisitionWorkflow({
      resultCallbackEnabled: 1,
    }),
    /resultCallbackEnabled must be a boolean/u,
  );
  assert.throws(
    () => acquisitionPlanCode({
      executionEnabled: "true",
    }),
    /executionEnabled must be a boolean/u,
  );
});


test(
  "acquisition receipt logical identity ignores physical n8n execution",
  async () => {
  const command = validAcquisitionCommand();
  const first = await executeCode(acquisitionReceiptCode(), {
    input: {
      acquisitionCommand: command,
      dispatchEnvelope: validDispatch,
    },
    executionId: "physical-1",
  });
  const second = await executeCode(acquisitionReceiptCode(), {
    input: {
      acquisitionCommand: command,
      dispatchEnvelope: validDispatch,
    },
    executionId: "physical-2",
  });
  assert.equal(
    first[0].json.receipt.externalExecutionId,
    `n8n-handoff:${command.handoffId}`,
  );
  assert.equal(
    second[0].json.receipt.externalExecutionId,
    first[0].json.receipt.externalExecutionId,
  );
  },
);
test("realm-safe plain-object gates accept cross-realm records and reject arrays", () => {
  const vm = require("node:vm");
  const factory = require("../src/workflow_factory");
  const expectedPlain = "function plain(value) {\n  if (value === null ||\n      typeof value !== \"object\" ||\n      Array.isArray(value)) {\n    return false;\n  }\n  const prototype = Object.getPrototypeOf(value);\n  return prototype === null ||\n    Object.getPrototypeOf(prototype) === null;\n}";

  const parent = factory.buildWorkflow();
  const child = factory.buildAcquisitionWorkflow();
  const targetCodes = [
    parent.nodes.find(
      (node) => node.name === "Validate Public Lite Dispatch",
    ).parameters.jsCode,
    parent.nodes.find(
      (node) => node.name === "Build Durable Dispatch Receipt",
    ).parameters.jsCode,
    child.nodes.find(
      (node) => node.name === "Validate Acquisition Handoff Command",
    ).parameters.jsCode,
  ];

  for (const code of targetCodes) {
    assert.equal(code.includes(expectedPlain), true);
    assert.equal(code.includes("prototype === Object.prototype"), false);
  }

  function evaluatePlain(input) {
    return vm.runInNewContext(
      "(" + expectedPlain + ")(input)",
      {input},
      {timeout: 1000},
    );
  }

  const crossRealmRecord = vm.runInNewContext("({value: 1})", {});
  const nullPrototypeRecord = Object.create(null);
  nullPrototypeRecord.value = 1;
  const crossRealmArray = vm.runInNewContext("[1, 2]", {});
  class NonRecordClass {}

  assert.equal(evaluatePlain(crossRealmRecord), true);
  assert.equal(evaluatePlain(nullPrototypeRecord), true);
  assert.equal(evaluatePlain(crossRealmArray), false);
  assert.equal(evaluatePlain(new NonRecordClass()), false);
});

test("URL-global-independent helper preserves supported WHATWG semantics and fail-closed restrictions", () => {
  const vm = require("node:vm");
  const factory = require("../src/workflow_factory");
  const parent = factory.buildWorkflow();
  const child = factory.buildAcquisitionWorkflow();

  const urlNodes = [
    parent.nodes.find(
      (node) => node.name === "Validate Public Lite Dispatch",
    ).parameters.jsCode,
    child.nodes.find(
      (node) => node.name === "Validate Acquisition Handoff Command",
    ).parameters.jsCode,
    child.nodes.find(
      (node) => node.name === "Normalize Marketplace Limited Result",
    ).parameters.jsCode,
  ];

  for (const code of urlNodes) {
    assert.doesNotMatch(code, /\bnew\s+URL\s*\(/u);
    assert.match(code, /function\s+parseHttpUrlWithoutGlobal\s*\(/u);
  }

  const validatorCodeValue = urlNodes[0];
  const markerIndex = validatorCodeValue.indexOf("\n\nconst EXPECTED_KEYS");
  assert.ok(markerIndex > 0);
  const helperSource = validatorCodeValue.slice(0, markerIndex);

  assert.equal(vm.runInNewContext("typeof URL", {}), "undefined");

  const helper = vm.runInNewContext(
    "(() => {\n" + helperSource +
      "\nreturn parseHttpUrlWithoutGlobal;\n})()",
    {},
    {timeout: 1000},
  );

  function snapshotUrl(value) {
    return {
      protocol: value.protocol,
      hostname: value.hostname,
      port: value.port,
      pathname: value.pathname,
      search: value.search,
      hash: value.hash,
      username: value.username,
      password: value.password,
      href: value.toString(),
    };
  }

  const supported = [
    ["HTTPS://Example.COM:443/a/../b?x=1#frag", undefined],
    ["http://example.com:80/", undefined],
    ["../c?q=a%20b#f", "https://example.com/a/b/"],
  ];

  for (const [value, base] of supported) {
    const expected = base === undefined ?
      new URL(value) :
      new URL(value, base);
    const actual = base === undefined ?
      helper(value) :
      helper(value, base);
    assert.deepEqual(snapshotUrl(actual), snapshotUrl(expected));
  }

  const actual = helper("https://example.com/a/b?x=1#old");
  const expected = new URL("https://example.com/a/b?x=1#old");
  actual.hostname = "sub.example.com";
  expected.hostname = "sub.example.com";
  actual.port = "8443";
  expected.port = "8443";
  actual.pathname = "/c/d";
  expected.pathname = "/c/d";
  actual.search = "?q=1&x=2";
  expected.search = "?q=1&x=2";
  actual.hash = "#frag";
  expected.hash = "#frag";
  assert.deepEqual(snapshotUrl(actual), snapshotUrl(expected));

  assert.throws(
    () => helper("https://user:pass@example.com/"),
  );
  assert.throws(
    () => helper("ftp://example.com/"),
  );
});
// R0G-BE-V5 ingress normalization regression block
const hrtBeV5Test = require("node:test");
const hrtBeV5Assert = require("node:assert/strict");
const hrtBeV5Vm = require("node:vm");
const hrtBeV5Fs = require("node:fs");
const hrtBeV5Path = require("node:path");
const {webcrypto: hrtBeV5Webcrypto} = require("node:crypto");
const {TextEncoder: HrtBeV5TextEncoder} = require("node:util");

function hrtBeV5Workflow(fileName) {
  return JSON.parse(hrtBeV5Fs.readFileSync(
    hrtBeV5Path.join(__dirname, "..", "workflows", fileName), "utf8"));
}
function hrtBeV5NodeCode(workflow, name) {
  const matches = workflow.nodes.filter((node) => node.name === name);
  hrtBeV5Assert.equal(matches.length, 1);
  hrtBeV5Assert.equal(typeof matches[0].parameters.jsCode, "string");
  return matches[0].parameters.jsCode;
}
function hrtBeV5HostRecord() {
  const base = Object.create(null);
  const middle = Object.create(base);
  return Object.create(middle);
}
function hrtBeV5HostifyDeep(value) {
  if (Array.isArray(value)) return value.map((item) => hrtBeV5HostifyDeep(item));
  if (value !== null && typeof value === "object") {
    const output = hrtBeV5HostRecord();
    for (const key of Object.keys(value)) output[key] = hrtBeV5HostifyDeep(value[key]);
    return output;
  }
  return value;
}
function hrtBeV5HostWrapper(body) {
  const wrapper = hrtBeV5HostRecord();
  wrapper.body = body;
  const headers = hrtBeV5HostRecord();
  headers["content-type"] = "application/json";
  wrapper.headers = headers;
  wrapper.query = hrtBeV5HostRecord();
  return wrapper;
}
function hrtBeV5Clone(value) { return JSON.parse(JSON.stringify(value)); }
function hrtBeV5Execute(code, input) {
  const context = {
    Buffer, TextEncoder: HrtBeV5TextEncoder, URL, crypto: hrtBeV5Webcrypto,
    $input: {first() { return {json: input}; }},
    $execution: {id: "r0g-be-v5-local-test"},
    $workflow: {id: "r0g-be-v5-local-workflow"},
    $: (nodeName) => ({first() { throw new Error("unexpected node lookup: " + nodeName); }}),
  };
  return hrtBeV5Vm.runInNewContext(`(async()=>{\n${code}\n})()`, context, {timeout: 5000});
}
function hrtBeV5Codes() {
  const parent = hrtBeV5Workflow("MarkaKalkan Public Lite Risk Scan Gateway - V1.json");
  const child = hrtBeV5Workflow("MarkaKalkan Public Lite Risk Scan Acquisition Worker - V1.json");
  return {
    parent: hrtBeV5NodeCode(parent, "Validate Public Lite Dispatch"),
    child: hrtBeV5NodeCode(child, "Validate Acquisition Handoff Command"),
  };
}

hrtBeV5Test("ingress normalization accepts host-shaped parent and child webhook records", async () => {
  const codes = hrtBeV5Codes();
  const parentInput = hrtBeV5HostWrapper(hrtBeV5HostifyDeep(hrtBeV5Clone(validDispatch)));
  const childInput = hrtBeV5HostWrapper(hrtBeV5HostifyDeep(hrtBeV5Clone(validAcquisitionCommand())));
  const parentOutput = await hrtBeV5Execute(codes.parent, parentInput);
  const childOutput = await hrtBeV5Execute(codes.child, childInput);
  hrtBeV5Assert.equal(parentOutput.length, 1);
  hrtBeV5Assert.equal(childOutput.length, 1);
});

hrtBeV5Test("ingress normalization preserves strict direct class-instance rejection", async () => {
  const codes = hrtBeV5Codes();
  class HrtBeV5DispatchClass {}
  class HrtBeV5CommandClass {}
  const dispatch = Object.assign(new HrtBeV5DispatchClass(), hrtBeV5Clone(validDispatch));
  const command = Object.assign(new HrtBeV5CommandClass(), hrtBeV5Clone(validAcquisitionCommand()));
  await hrtBeV5Assert.rejects(() => hrtBeV5Execute(codes.parent, dispatch), /dispatchEnvelope must be an object/u);
  await hrtBeV5Assert.rejects(() => hrtBeV5Execute(codes.child, command), /acquisitionCommand must be an object/u);
});

hrtBeV5Test("ingress normalization rejects hostile non-envelope webhook bodies safely", async () => {
  const {parent} = hrtBeV5Codes();
  const protoPayload = hrtBeV5Clone(validDispatch);
  Object.defineProperty(protoPayload, "__proto__", {value: {polluted: true}, enumerable: true, configurable: true, writable: true});
  const cyclic = hrtBeV5Clone(validDispatch); cyclic.extra = cyclic;
  for (const body of [new Date(0), new Map([["a", 1]]), [1, 2, 3], protoPayload, cyclic]) {
    await hrtBeV5Assert.rejects(() => hrtBeV5Execute(parent, hrtBeV5HostWrapper(body)));
  }
  hrtBeV5Assert.equal(Object.prototype.polluted, undefined);
  hrtBeV5Assert.equal(({}).polluted, undefined);
});
// R0G-BE-V5.24 parent canonical null-prototype regression block
hrtBeV5Test(
    "parent canonical envelope survives skewed object prototype identity without relaxing raw input gate",
    async () => {
      const {parent} = hrtBeV5Codes();
      const parentInput = hrtBeV5HostWrapper(
          hrtBeV5HostifyDeep(hrtBeV5Clone(validDispatch)));

      const nativeObject = Object;
      const sentinelBase = {};
      const sentinel = Object.create(sentinelBase);
      const skewedObject = {
        create: nativeObject.create.bind(nativeObject),
        keys: nativeObject.keys.bind(nativeObject),
        getPrototypeOf(value) {
          const prototype = Reflect.getPrototypeOf(value);
          if (prototype === null) return null;
          if (Reflect.getPrototypeOf(prototype) === null) {
            return sentinel;
          }
          return prototype;
        },
        prototype: nativeObject.prototype,
      };

      const context = {
        Buffer,
        TextEncoder: HrtBeV5TextEncoder,
        URL,
        crypto: hrtBeV5Webcrypto,
        Object: skewedObject,
        $input: {first() { return {json: parentInput}; }},
        $execution: {id: "r0g-be-v5-24-local-test"},
        $workflow: {id: "r0g-be-v5-24-local-workflow"},
        $: (nodeName) => ({
          first() {
            throw new Error("unexpected node lookup: " + nodeName);
          },
        }),
      };

      const output = await hrtBeV5Vm.runInNewContext(
          `(async()=>{\n${parent}\n})()`,
          context,
          {timeout: 5000});

      hrtBeV5Assert.equal(output.length, 1);
      hrtBeV5Assert.equal(
          output[0].json.dispatchEnvelope.contractVersion,
          "risk-scan-public-lite-dispatch-envelope-v1");
      hrtBeV5Assert.equal(
          output[0].json.dispatchEnvelope.scanRunId,
          validDispatch.scanRunId);
    },
);

// BRT-0AH parent ingress body access regression
test("BRT-0AH parent accepts inherited readable n8n wrapper body", async () => {
  class InheritedWebhookWrapper {
    constructor(body) {
      Object.defineProperty(this, "_body", {
        value: body,
        enumerable: false,
        writable: false,
      });
    }

    get body() {
      return this._body;
    }

    get headers() {
      return {};
    }

    get params() {
      return {};
    }

    get query() {
      return {};
    }

    get webhookUrl() {
      return "https://example.invalid/webhook";
    }

    get executionMode() {
      return "webhook";
    }
  }

  const input = new InheritedWebhookWrapper(
    JSON.parse(JSON.stringify(validDispatch)),
  );
  assert.equal(
    Object.prototype.hasOwnProperty.call(input, "body"),
    false,
  );
  const output = await executeCode(validatorCode(), {input});
  assert.equal(output.length, 1);
  assert.equal(
    output[0].json.dispatchEnvelope.scanRunId,
    validDispatch.scanRunId,
  );
});

test("BRT-0AH parent accepts proxy-readable n8n wrapper body", async () => {
  class InheritedWebhookWrapper {
    constructor(body) {
      Object.defineProperty(this, "_body", {
        value: body,
        enumerable: false,
        writable: false,
      });
    }

    get body() {
      return this._body;
    }

    get headers() {
      return {};
    }

    get params() {
      return {};
    }

    get query() {
      return {};
    }

    get webhookUrl() {
      return "https://example.invalid/webhook";
    }

    get executionMode() {
      return "webhook";
    }
  }

  const target = new InheritedWebhookWrapper(
    JSON.parse(JSON.stringify(validDispatch)),
  );
  const input = new Proxy(target, {
    getOwnPropertyDescriptor(object, key) {
      if (key === "body") {
        return undefined;
      }
      return Reflect.getOwnPropertyDescriptor(object, key);
    },
    get(object, key, receiver) {
      return Reflect.get(object, key, receiver);
    },
  });

  assert.equal(
    Object.prototype.hasOwnProperty.call(input, "body"),
    false,
  );
  const output = await executeCode(validatorCode(), {input});
  assert.equal(output.length, 1);
});

test("BRT-0AH parent keeps direct non-plain envelope rejection", async () => {
  class DirectEnvelope {}
  const input = Object.assign(
    new DirectEnvelope(),
    JSON.parse(JSON.stringify(validDispatch)),
  );
  await assert.rejects(
    async () => executeCode(validatorCode(), {input}),
    /dispatchEnvelope must be an object/u,
  );
});

test("BRT-0AH parent rejects inherited body without wrapper markers", async () => {
  const input = Object.create({
    body: JSON.parse(JSON.stringify(validDispatch)),
  });
  await assert.rejects(
    async () => executeCode(validatorCode(), {input}),
    /dispatchEnvelope must be an object/u,
  );
});

// BRT-0BF readable body before plain fallback regression
test("BRT-0BF parent accepts plain proxy-readable wrapper body before plain fallback", async () => {
  const body = JSON.parse(JSON.stringify(validDispatch));
  const input = new Proxy({}, {
    getOwnPropertyDescriptor(target, key) {
      if (key === "body") return undefined;
      return Reflect.getOwnPropertyDescriptor(target, key);
    },
    get(target, key, receiver) {
      if (key === "body") return body;
      if (key === "headers") return {};
      if (key === "params") return {};
      if (key === "query") return {};
      if (key === "webhookUrl") return "https://example.invalid/webhook";
      if (key === "executionMode") return "webhook";
      return Reflect.get(target, key, receiver);
    },
  });

  assert.equal(
      Object.prototype.hasOwnProperty.call(input, "body"),
      false,
  );
  const output = await executeCode(validatorCode(), {input});
  assert.equal(output.length, 1);
  assert.equal(
      output[0].json.dispatchEnvelope.scanRunId,
      validDispatch.scanRunId,
  );
});

test("BRT-0BF parent rejects plain proxy-readable body without wrapper marker threshold", async () => {
  const body = JSON.parse(JSON.stringify(validDispatch));
  const input = new Proxy({}, {
    getOwnPropertyDescriptor(target, key) {
      if (key === "body") return undefined;
      return Reflect.getOwnPropertyDescriptor(target, key);
    },
    get(target, key, receiver) {
      if (key === "body") return body;
      if (key === "headers") return {};
      return Reflect.get(target, key, receiver);
    },
  });

  await assert.rejects(
      async () => executeCode(validatorCode(), {input}),
      /PUBLIC_LITE_DISPATCH_REJECTED: dispatchEnvelope/u,
  );
});

// BRT-0BP direct-envelope precedence adversarial regressions
test("BRT-0BP parent keeps exact direct envelope ahead of inherited readable wrapper fields", async () => {
  const body = JSON.parse(JSON.stringify(validDispatch));
  const proto = {
    body,
    headers: {},
    params: {},
  };
  const target = Object.assign(
      Object.create(proto),
      JSON.parse(JSON.stringify(validDispatch)),
  );
  const input = new Proxy(target, {
    getPrototypeOf() {
      // Model a plain runtime facade while values remain inherited.
      return Object.prototype;
    },
  });

  assert.equal(Object.prototype.hasOwnProperty.call(input, "body"), false);
  const output = await executeCode(validatorCode(), {input});
  assert.equal(output.length, 1);
  assert.equal(
      output[0].json.dispatchEnvelope.scanRunId,
      validDispatch.scanRunId,
  );
});

test("BRT-0BP parent keeps exact direct envelope ahead of proxy-synthetic body and markers", async () => {
  const body = JSON.parse(JSON.stringify(validDispatch));
  const target = JSON.parse(JSON.stringify(validDispatch));
  const input = new Proxy(target, {
    getOwnPropertyDescriptor(inner, key) {
      if (key === "body" || key === "headers" || key === "params") {
        return undefined;
      }
      return Reflect.getOwnPropertyDescriptor(inner, key);
    },
    get(inner, key, receiver) {
      if (key === "body") return body;
      if (key === "headers") return {};
      if (key === "params") return {};
      return Reflect.get(inner, key, receiver);
    },
  });

  assert.equal(Object.prototype.hasOwnProperty.call(input, "body"), false);
  const output = await executeCode(validatorCode(), {input});
  assert.equal(output.length, 1);
  assert.equal(
      output[0].json.dispatchEnvelope.scanRunId,
      validDispatch.scanRunId,
  );
});

// BRT-0BY tri-state introspection fail-closed regressions
test("BRT-0BY parent fails closed when direct-envelope ownKeys introspection throws", async () => {
  const body = JSON.parse(JSON.stringify(validDispatch));
  const target = JSON.parse(JSON.stringify(validDispatch));
  const input = new Proxy(target, {
    ownKeys() {
      throw new Error("BRT_0BY_TRAP_OWN_KEYS");
    },
    get(inner, key, receiver) {
      if (key === "body") return body;
      if (key === "headers") return {};
      if (key === "params") return {};
      return Reflect.get(inner, key, receiver);
    },
  });

  await assert.rejects(
      async () => executeCode(validatorCode(), {input}),
      /PUBLIC_LITE_DISPATCH_REJECTED: dispatchEnvelope introspection failed/u,
  );
});

test("BRT-0BY parent fails closed when direct-envelope getPrototypeOf introspection throws", async () => {
  const body = JSON.parse(JSON.stringify(validDispatch));
  const target = JSON.parse(JSON.stringify(validDispatch));
  const input = new Proxy(target, {
    getPrototypeOf() {
      throw new Error("BRT_0BY_TRAP_GET_PROTOTYPE_OF");
    },
    get(inner, key, receiver) {
      if (key === "body") return body;
      if (key === "headers") return {};
      if (key === "params") return {};
      return Reflect.get(inner, key, receiver);
    },
  });

  await assert.rejects(
      async () => executeCode(validatorCode(), {input}),
      /PUBLIC_LITE_DISPATCH_REJECTED: dispatchEnvelope introspection failed/u,
  );
});

test("BRT-0BY parent fails closed when direct-envelope property-descriptor introspection throws", async () => {
  const body = JSON.parse(JSON.stringify(validDispatch));
  const target = JSON.parse(JSON.stringify(validDispatch));
  const trappedKey = Object.keys(target).sort()[0];
  const input = new Proxy(target, {
    getOwnPropertyDescriptor(inner, key) {
      if (key === trappedKey) {
        throw new Error("BRT_0BY_TRAP_GET_OWN_PROPERTY_DESCRIPTOR");
      }
      if (key === "body") return undefined;
      return Reflect.getOwnPropertyDescriptor(inner, key);
    },
    get(inner, key, receiver) {
      if (key === "body") return body;
      if (key === "headers") return {};
      if (key === "params") return {};
      return Reflect.get(inner, key, receiver);
    },
  });

  await assert.rejects(
      async () => executeCode(validatorCode(), {input}),
      /PUBLIC_LITE_DISPATCH_REJECTED: dispatchEnvelope introspection failed/u,
  );
});
