"use strict";
const crypto = require("node:crypto");

function required(value, name) {
  if (typeof value !== "string" || value.length === 0) throw new TypeError(`${name} is required`);
  return value;
}
function hash(parts) { return crypto.createHash("sha256").update(parts.join("|"), "utf8").digest("hex"); }
function normalizeVisibleText(value) {
  return required(value, "visibleText").replace(/\r\n?/g, "\n").normalize("NFC");
}
function buildSourceId(taskId, executionId, canonicalUrl) {
  return hash(["source-v1", required(taskId, "taskId"),
    required(executionId, "executionId"), required(canonicalUrl, "canonicalUrl")]);
}
function buildContentHash(text) { return hash(["content-v1", normalizeVisibleText(text)]); }
function buildSnapshotId(taskId, executionId, sourceId, contentHash) {
  return hash(["snapshot-v1", required(taskId, "taskId"),
    required(executionId, "executionId"), required(sourceId, "sourceId"),
    required(contentHash, "contentHash")]);
}
function buildEvidenceFingerprint(references) {
  if (!Array.isArray(references)) throw new TypeError("evidenceReferences must be an array");
  const normalized = [...new Set(references.map((v) =>
    required(v, "evidenceReference")))].sort();
  return hash(["evidence-fingerprint-v1", ...normalized]);
}
function buildFindingKey(taskId, executionId, candidateId, signalType, evidenceReferences) {
  return hash(["finding-v1", required(taskId, "taskId"),
    required(executionId, "executionId"), required(candidateId, "candidateId"),
    required(signalType, "signalType"), buildEvidenceFingerprint(evidenceReferences)]);
}
module.exports = {buildSourceId, buildContentHash, buildSnapshotId,
  buildEvidenceFingerprint, buildFindingKey, normalizeVisibleText};
