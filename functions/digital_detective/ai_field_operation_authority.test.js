/* eslint-disable max-len */
"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AGENTS,
  CALLABLE_OPTIONS,
  CONTRACT_VERSION,
  SERVICE_CODE,
  evaluateReadiness,
  normalizeInput,
  operationId,
} = require("./ai_field_operation_authority");

function timestamp(value) {
  return {toMillis: () => value};
}
function validCommand(overrides = {}) {
  return {
    contractVersion: CONTRACT_VERSION,
    requestId: "123e4567-e89b-42d3-a456-426614174000",
    idempotencyKey: "ai-field-operation:123e4567-e89b-42d3-a456-426614174000",
    title: "Dijital saha taraması",
    objective: "Şüpheli satış kanallarını incele",
    priority: "normal",
    initialInput: {productName: "Fren balatası", sellerName: "", targetUrl: "", requestedAgentCount: 12, brandName: "istemci değeri"},
    ...overrides,
  };
}

test("callables require App Check and bounded runtime", () => {
  assert.equal(CALLABLE_OPTIONS.enforceAppCheck, true);
  assert.equal(CALLABLE_OPTIONS.region, "europe-west3");
  assert.equal(CALLABLE_OPTIONS.maxInstances, 3);
});

test("canonical catalog contains twelve stable agents", () => {
  assert.equal(AGENTS.length, 12);
  assert.equal(AGENTS[0][0], "task_planner");
  assert.equal(AGENTS[11][0], "reporting_intervention_preparer");
});

test("readiness requires active brand, entitlement, time and authority", () => {
  const ready = evaluateReadiness({
    brand: {status: "active"},
    entitlement: {serviceCode: SERVICE_CODE, status: "active", validFrom: timestamp(100), validUntil: timestamp(300), operationCreationAuthorized: true, permissions: ["create_operation"]},
    nowMillis: 200,
  });
  assert.equal(ready.ready, true);
  assert.deepEqual(ready.reasons, []);
  const expired = evaluateReadiness({brand: {status: "active"}, entitlement: {serviceCode: SERVICE_CODE, status: "active", validFrom: timestamp(100), validUntil: timestamp(200), operationCreationAuthorized: true, permissions: ["create_operation"]}, nowMillis: 200});
  assert.equal(expired.ready, false);
  assert.ok(expired.reasons.includes("active_service_entitlement_required"));
});

test("command requires one concrete target and canonical idempotency", () => {
  assert.equal(normalizeInput(validCommand()).productName, "Fren balatası");
  assert.throws(() => normalizeInput(validCommand({initialInput: {productName: "", sellerName: "", targetUrl: ""}})), HttpsError);
  assert.throws(() => normalizeInput(validCommand({idempotencyKey: "wrong"})), HttpsError);
});

test("operation id is deterministic and actor scoped", () => {
  const requestId = "123e4567-e89b-42d3-a456-426614174000";
  assert.equal(operationId("brand-a", requestId), operationId("brand-a", requestId));
  assert.notEqual(operationId("brand-a", requestId), operationId("brand-b", requestId));
});
