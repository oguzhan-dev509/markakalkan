"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const vm = require("node:vm");

const validDispatch = require("../fixtures/valid_dispatch_envelope.json");
const {
  CALLBACK_URL,
  NODE_IDS,
  RESULT_HEADER,
  WEBHOOK_HEADER,
  WEBHOOK_PATH,
  WORKFLOW_NAME,
  acquisitionGuardCode,
  acquisitionPlanCode,
  buildWorkflow,
  canonicalJson,
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
} = {}) {
  const functionBody = `"use strict";\n${code}`;
  const runner = new Function(
    "$input",
    "$execution",
    functionBody,
  );
  return runner(
    {
      first() {
        return {json: input};
      },
    },
    {id: executionId},
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

test("workflow identity is stable", () => {
  const workflow = buildWorkflow();
  assert.equal(workflow.name, WORKFLOW_NAME);
  assert.equal(
    workflow.versionId,
    "7fe6860d-8f63-5c16-94e1-ef7a8245b7cb",
  );
  assert.equal(workflow.active, false);
});

test("workflow contains thirteen deterministic nodes", () => {
  const workflow = buildWorkflow();
  assert.equal(workflow.nodes.length, 13);
  assert.deepEqual(
    workflow.nodes.map((node) => node.id).sort(),
    Object.values(NODE_IDS).sort(),
  );
});

test("unbound webhook is disabled and unauthenticated", () => {
  const workflow = buildWorkflow();
  const webhook = findNode(
    workflow,
    "Public Lite Dispatch Webhook",
  );
  assert.equal(webhook.disabled, true);
  assert.equal(webhook.parameters.path, WEBHOOK_PATH);
  assert.equal(webhook.parameters.httpMethod, "POST");
  assert.equal(webhook.parameters.responseMode, "responseNode");
  assert.equal(webhook.parameters.authentication, undefined);
  assert.equal(webhook.credentials, undefined);
});

test("credential-bound webhook uses header auth but remains inactive", () => {
  const workflow = buildWorkflow({
    webhookCredentialId: "credential-webhook-1",
    webhookCredentialName: "Public Lite Webhook Header Auth",
  });
  const webhook = findNode(
    workflow,
    "Public Lite Dispatch Webhook",
  );
  assert.equal(webhook.disabled, false);
  assert.equal(webhook.parameters.authentication, "headerAuth");
  assert.deepEqual(webhook.credentials, {
    httpHeaderAuth: {
      id: "credential-webhook-1",
      name: "Public Lite Webhook Header Auth",
    },
  });
  assert.equal(workflow.active, false);
  assert.equal(workflow.meta.activationAllowed, false);
});

test("partial webhook credential binding is rejected", () => {
  assert.throws(
    () => buildWorkflow({
      webhookCredentialId: "credential-webhook-1",
    }),
    /must be supplied together/,
  );
});

test("partial result credential binding is rejected", () => {
  assert.throws(
    () => buildWorkflow({
      resultCredentialName: "Public Lite Result Header Auth",
    }),
    /must be supplied together/,
  );
});

test("result callback template is disabled and unconnected", () => {
  const workflow = buildWorkflow();
  const result = findNode(
    workflow,
    "Result Callback Template - Disabled",
  );
  assert.equal(result.disabled, true);
  assert.equal(result.parameters.url, CALLBACK_URL);
  assert.equal(result.parameters.method, "POST");
  assert.equal(
    workflow.connections[
      "Result Callback Template - Disabled"
    ],
    undefined,
  );
  const serialized = JSON.stringify(workflow);
  assert.match(serialized, new RegExp(RESULT_HEADER));
});

test("result callback credential can be bound without enabling node", () => {
  const workflow = buildWorkflow({
    resultCredentialId: "credential-result-1",
    resultCredentialName: "Public Lite Result Header Auth",
  });
  const result = findNode(
    workflow,
    "Result Callback Template - Disabled",
  );
  assert.equal(result.disabled, true);
  assert.equal(
    result.parameters.authentication,
    "genericCredentialType",
  );
  assert.equal(
    result.parameters.genericAuthType,
    "httpHeaderAuth",
  );
  assert.deepEqual(result.credentials, {
    httpHeaderAuth: {
      id: "credential-result-1",
      name: "Public Lite Result Header Auth",
    },
  });
});

test("gateway branches to receipt and guarded acquisition integration", () => {
  const workflow = buildWorkflow();
  assert.deepEqual(
    workflow.connections,
    {
      "Public Lite Dispatch Webhook": {
        main: [[{
          node: "Validate Public Lite Dispatch",
          type: "main",
          index: 0,
        }]],
      },
      "Validate Public Lite Dispatch": {
        main: [[{
          node: "Build Dispatch Receipt",
          type: "main",
          index: 0,
        }]],
      },
      "Build Dispatch Receipt": {
        main: [[
          {
            node: "Return 202 Dispatch Receipt",
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
    },
  );
});

test("gateway response is HTTP 202 JSON receipt", () => {
  const workflow = buildWorkflow();
  const response = findNode(
    workflow,
    "Return 202 Dispatch Receipt",
  );
  assert.equal(response.parameters.respondWith, "json");
  assert.equal(response.parameters.responseBody, "={{ $json.receipt }}");
  assert.equal(response.parameters.options.responseCode, 202);
});

test("workflow contains no embedded secret values", () => {
  const serialized = serializeWorkflow(buildWorkflow());
  assert.doesNotMatch(
    serialized,
    /Bearer\s+[A-Za-z0-9._-]+/,
  );
  assert.doesNotMatch(
    serialized,
    /AIza[0-9A-Za-z_-]{20,}/,
  );
  assert.doesNotMatch(
    serialized,
    /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----/,
  );
  assert.match(serialized, new RegExp(WEBHOOK_HEADER));
  assert.match(serialized, new RegExp(RESULT_HEADER));
});

test("workflow safety note prohibits activation", () => {
  const workflow = buildWorkflow();
  const note = findNode(workflow, "Deployment Safety Gate");
  assert.match(note.parameters.content, /Do not activate/i);
  assert.match(note.parameters.content, /real marketplaceLimited adapter/i);
  assert.match(note.parameters.content, /execution guard is false/i);
  assert.match(note.parameters.content, /result materialization/i);
});

test("workflow result note prohibits synthetic zero findings", () => {
  const workflow = buildWorkflow();
  const note = findNode(
    workflow,
    "Result Contract Safety Note",
  );
  assert.match(note.parameters.content, /No synthetic result/i);
  assert.match(note.parameters.content, /synthetic result/i);
  assert.match(note.parameters.content, /placeholder evidence/i);
});

test("validator code accepts webhook body envelope", async () => {
  const output = await executeCode(validatorCode(), {
    input: {body: validDispatch},
  });
  assert.equal(output.length, 1);
  assert.equal(
    output[0].json.dispatchEnvelope.executionId,
    validDispatch.executionId,
  );
  assert.deepEqual(
    output[0].json.dispatchEnvelope.channelCodes,
    validDispatch.channelCodes,
  );
});

test("validator code accepts direct envelope", async () => {
  const output = await executeCode(validatorCode(), {
    input: validDispatch,
  });
  assert.equal(
    output[0].json.dispatchEnvelope.scanRunId,
    validDispatch.scanRunId,
  );
});

test("validator code rejects extra tenant field", async () => {
  await assert.rejects(
    async () => executeCode(validatorCode(), {
      input: {
        body: {
          ...validDispatch,
          tenantId: "forbidden",
        },
      },
    }),
    /PUBLIC_LITE_DISPATCH_REJECTED/,
  );
});

test("validator code rejects token-like nested keys", async () => {
  const dispatch = JSON.parse(JSON.stringify(validDispatch));
  dispatch.target.token = "forbidden";
  await assert.rejects(
    async () => executeCode(validatorCode(), {
      input: {body: dispatch},
    }),
    /target keys are invalid/,
  );
});

test("receipt code returns provider acceptance", async () => {
  const output = await executeCode(receiptCode(), {
    input: {dispatchEnvelope: validDispatch},
    executionId: "998877",
  });
  assert.equal(output.length, 1);
  assert.equal(
    output[0].json.receipt.providerCode,
    "n8n_public_lite",
  );
  assert.equal(
    output[0].json.receipt.externalExecutionId,
    "n8n:998877",
  );
  assert.equal(
    output[0].json.gatewayState.acquisitionEngineInstalled,
    true,
  );
  assert.equal(
    output[0].json.gatewayState.acquisitionEngineEnabled,
    false,
  );
  assert.equal(
    output[0].json.gatewayState.activationAllowed,
    false,
  );
  assert.ok(
    Number.isFinite(Date.parse(output[0].json.receipt.acceptedAt)),
  );
});

test("receipt code rejects missing execution id", async () => {
  await assert.rejects(
    async () => executeCode(receiptCode(), {
      input: {dispatchEnvelope: validDispatch},
      executionId: "",
    }),
    /n8n execution id missing/,
  );
});

test("result template serializes only assembled result envelope", () => {
  const body = resultTemplateBody();
  assert.equal(
    body,
    "={{ JSON.stringify($json.resultEnvelope) }}",
  );
  assert.doesNotMatch(body, /replace-with-provider-event-id/);
  assert.doesNotMatch(body, /public_lite_engine_pending/);
});

test("result template does not synthesize findings", () => {
  const body = resultTemplateBody();
  assert.doesNotMatch(body, /findingCount/);
  assert.doesNotMatch(body, /riskLevel/);
  assert.doesNotMatch(body, /channels: \[\]/);
});

test("serialized workflow is stable across builds", () => {
  const first = serializeWorkflow(buildWorkflow());
  const second = serializeWorkflow(buildWorkflow());
  assert.equal(first, second);
});

test("canonical workflow JSON helper is deterministic", () => {
  assert.equal(
    canonicalJson({z: [2, {b: 1, a: 2}], a: 3}),
    '{"a":3,"z":[2,{"a":2,"b":1}]}',
  );
});

test("workflow metadata records the HRT phase", () => {
  const workflow = buildWorkflow();
  assert.equal(workflow.meta.hrtPhase, "HRT-MKT-TR-1B");
  assert.equal(
    workflow.meta.gatewayContractVersion,
    "risk-scan-public-lite-dispatch-envelope-v1",
  );
  assert.equal(workflow.meta.providerCode, "n8n_public_lite");
  assert.equal(workflow.meta.acquisitionEngineInstalled, true);
  assert.equal(workflow.meta.acquisitionEngineEnabled, false);
  assert.equal(
    workflow.meta.acquisitionAdapterCode,
    "trendyol_public_listing_v1",
  );
  assert.equal(
    workflow.meta.acquisitionChannelCode,
    "marketplaceLimited",
  );
  assert.equal(
    workflow.meta.channelAdapterResultContractVersion,
    "risk-scan-public-lite-channel-adapter-result-v1",
  );
  assert.equal(workflow.meta.webhookHeader, WEBHOOK_HEADER);
  assert.equal(workflow.meta.resultHeader, RESULT_HEADER);
});

test("all credential bindings mark setup complete only together", () => {
  const workflow = buildWorkflow({
    webhookCredentialId: "credential-webhook-1",
    webhookCredentialName: "Public Lite Webhook Header Auth",
    resultCredentialId: "credential-result-1",
    resultCredentialName: "Public Lite Result Header Auth",
  });
  assert.equal(
    workflow.meta.templateCredsSetupCompleted,
    true,
  );
  assert.equal(workflow.active, false);
});


async function executeIntegrationCode(code, {
  input,
  contextByNode = {},
} = {}) {
  const runner = new Function(
    "$input",
    "$",
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
  );
}

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
  const workflow = buildWorkflow();
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
  const workflow = buildWorkflow();
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
  const serialized = serializeWorkflow(buildWorkflow()).toLowerCase();
  assert.doesNotMatch(serialized, /"tenantid"/);
  assert.doesNotMatch(serialized, /"brandid"/);
  assert.doesNotMatch(serialized, /"actoruid"/);
  assert.doesNotMatch(serialized, /"authorization"/);
  assert.doesNotMatch(serialized, /"cookie"/);
  assert.doesNotMatch(serialized, /"x-api-key"/);
  assert.match(serialized, /captch[a-z-]*.*false/);
});
