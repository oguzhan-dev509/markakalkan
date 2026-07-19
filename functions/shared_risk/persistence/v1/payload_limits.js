const PAYLOAD_LIMITS = Object.freeze({
  titleCharacters: 300,
  summaryCharacters: 4000,
  reasonCharacters: 1000,
  reasons: 100,
  relatedRefs: 200,
  evidenceRefs: 200,
  metadataDepth: 6,
  metadataEstimatedBytes: 32768,
  provenanceFields: 64,
  canonicalPayloadEstimatedBytes: 524288,
});

function jsonBytes(value) {
  return Buffer.byteLength(JSON.stringify(value), "utf8");
}

function depth(value) {
  if (!value || typeof value !== "object") return 0;
  const children = Array.isArray(value) ? value : Object.values(value);
  return 1 + children.reduce((maximum, child) =>
    Math.max(maximum, depth(child)), 0);
}

function validatePayloadLimitsV1(payload, provenance) {
  const blockers = [];
  const add = (code) => blockers.push(code);
  if (typeof payload.title === "string" &&
      payload.title.length > PAYLOAD_LIMITS.titleCharacters) {
    add("payload.title_too_long");
  }
  if (typeof payload.summary === "string" &&
      payload.summary.length > PAYLOAD_LIMITS.summaryCharacters) {
    add("payload.summary_too_long");
  }
  if (Array.isArray(payload.reasons) &&
      payload.reasons.length > PAYLOAD_LIMITS.reasons) {
    add("payload.too_many_reasons");
  }
  if (Array.isArray(payload.reasons) && payload.reasons.some((reason) =>
    typeof reason === "string" &&
      reason.length > PAYLOAD_LIMITS.reasonCharacters)) {
    add("payload.reason_too_long");
  }
  const related = payload.relatedEntityRefs || [];
  const evidence = payload.evidenceRefs || [];
  if (related.length > PAYLOAD_LIMITS.relatedRefs) {
    add("payload.too_many_related_refs");
  }
  if (evidence.length > PAYLOAD_LIMITS.evidenceRefs) {
    add("payload.too_many_evidence_refs");
  }
  const uniqueCount = (values) => new Set(values.map((value) =>
    JSON.stringify(value))).size;
  if (uniqueCount(related) !== related.length) {
    add("payload.duplicate_related_refs");
  }
  if (uniqueCount(evidence) !== evidence.length) {
    add("payload.duplicate_evidence_refs");
  }
  const metadata = payload.metadata || {};
  if (depth(metadata) > PAYLOAD_LIMITS.metadataDepth) {
    add("payload.metadata_too_deep");
  }
  if (jsonBytes(metadata) > PAYLOAD_LIMITS.metadataEstimatedBytes) {
    add("payload.metadata_too_large");
  }
  if (jsonBytes(payload) > PAYLOAD_LIMITS.canonicalPayloadEstimatedBytes) {
    add("payload.document_budget_exceeded");
  }
  if (Object.keys(provenance || {}).length > PAYLOAD_LIMITS.provenanceFields) {
    add("payload.provenance_too_many_fields");
  }
  return Object.freeze([...new Set(blockers)].sort());
}

module.exports = {PAYLOAD_LIMITS, validatePayloadLimitsV1};
