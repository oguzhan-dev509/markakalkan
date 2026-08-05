# MarkaKalkan Public Lite n8n Gateway

This package defines the HRT-EXEC-1C-4A contract gateway for anonymous
Public Lite risk scans.

## Safety state

The committed workflow is intentionally inactive. Its webhook node is disabled
until an n8n Header Auth credential is bound. The result callback template is
also disabled and unconnected. The workflow must not be activated before:

1. both Public Lite credentials are provisioned,
2. real acquisition adapters exist,
3. HRT-EXEC-1D result materialization is installed,
4. live protection probes pass.

The gateway never emits a synthetic zero-finding result.

## Generate

```text
node tools/create_public_lite_gateway_workflow.js
node tools/create_public_lite_gateway_workflow.js --check
```

A credential-bound import artifact can be produced later without embedding
secret values:

```text
node tools/create_public_lite_gateway_workflow.js ^
  --output <path> ^
  --webhook-credential-id <n8n-id> ^
  --webhook-credential-name <name> ^
  --result-credential-id <n8n-id> ^
  --result-credential-name <name>
```

The credential-bound workflow remains inactive. Activation is a separate,
explicit production operation.
