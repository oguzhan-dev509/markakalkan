"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION,
} = require("./public_lite_provider_handoff_contract");

const INDEX_PATH = path.resolve(
    __dirname,
    "../../..",
    "firestore.indexes.json");
const INDEX_CONFIG = JSON.parse(fs.readFileSync(INDEX_PATH, "utf8"));

function ledgerIndexes() {
  return INDEX_CONFIG.indexes.filter((index) =>
    index.collectionGroup === PUBLIC_LITE_PROVIDER_HANDOFF_COLLECTION);
}

test("provider handoff ledger has exactly one composite index", () => {
  assert.equal(ledgerIndexes().length, 1);
});

test("provider handoff due index has exact query scope", () => {
  assert.equal(ledgerIndexes()[0].queryScope, "COLLECTION");
});

test("provider handoff due index fields are exact and ordered", () => {
  assert.deepEqual(ledgerIndexes()[0].fields, [
    {fieldPath: "state", order: "ASCENDING"},
    {
      fieldPath: "childDispatchDueAtTimestamp",
      order: "ASCENDING",
    },
  ]);
});

test("provider handoff index does not create array or vector config", () => {
  const serialized = JSON.stringify(ledgerIndexes()[0]);
  assert.equal(serialized.includes("arrayConfig"), false);
  assert.equal(serialized.includes("vectorConfig"), false);
});
