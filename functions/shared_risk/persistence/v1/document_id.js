const {createHash} = require("node:crypto");

const {STORAGE_SCHEMA_VERSION} = require("./storage_contracts");

const DOCUMENT_ID_ALGORITHM = "sha256-length-prefixed-v1";

function required(value, field) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new TypeError(`${field} is required`);
  }
  return value.trim();
}

function encodeParts(parts) {
  return parts.map((part) => {
    const value = required(part, "canonical part");
    return `${Buffer.byteLength(value, "utf8")}:${value}`;
  }).join("|");
}

function sha256Hex(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function buildPersistenceDocumentIdV1({tenantId, targetNamespace,
  idempotencyCanonicalKey}) {
  return sha256Hex(encodeParts([
    STORAGE_SCHEMA_VERSION,
    tenantId,
    targetNamespace,
    idempotencyCanonicalKey,
  ]));
}

function buildPersistenceReceiptIdV1(persistenceDocumentId) {
  return sha256Hex(encodeParts([
    "shared-risk-persistence-receipt-id-v1",
    required(persistenceDocumentId, "persistenceDocumentId"),
  ]));
}

module.exports = {
  DOCUMENT_ID_ALGORITHM,
  buildPersistenceDocumentIdV1,
  buildPersistenceReceiptIdV1,
  encodeParts,
  sha256Hex,
};
