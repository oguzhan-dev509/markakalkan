/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {CASE_STATUSES, EVIDENCE_LEVELS, SEVERITIES} = require("./contracts");
const ADAPTER_VERSION = "risk-operations-read-adapter-v1";
const EVALUATOR_VERSION = "risk-operations-evaluator-v1";
const iso = (value) => {
  const date = value && typeof value.toDate === "function" ? value.toDate() : value ? new Date(value) : null; return date && !Number.isNaN(date.getTime()) ? date.toISOString() : null;
};
const text = (value, fallback = "") => typeof value === "string" && value.trim() ? value.trim().slice(0, 500) : fallback;
const stableId = (...parts) => createHash("sha256").update(parts.join("\u001f")).digest("hex");
const confidence = (value) => Number.isFinite(value) ? Math.max(0, Math.min(1, Number(value))) : null;
function evidenceQuality({evidenceRefs = [], sourceCount = 0, primaryVerified = false, assessable = true}) {
  let level; const reasons = [];
  if (!assessable) {
    level = "unavailable"; reasons.push("evidence.assessment_unavailable");
  } else if (primaryVerified) {
    level = "verified_primary"; reasons.push("evidence.primary_verified");
  } else if (sourceCount >= 2) {
    level = "corroborated"; reasons.push("evidence.multiple_independent_sources");
  } else if (evidenceRefs.length > 0 || sourceCount === 1) {
    level = "single_source"; reasons.push("evidence.single_source_only");
  } else {
    level = "insufficient"; reasons.push("evidence.references_missing");
  }
  return Object.freeze({level, reasonCodes: reasons, evaluatedFrom: Object.freeze({evidenceReferenceCount: evidenceRefs.length, sourceCount, primaryVerified}), evaluatorVersion: EVALUATOR_VERSION});
}
function caseCandidacy({severity, confidenceValue, evidence, sourceCount = 0, repeated = false, identityResolved = false, criticalSafetyRisk = false, evaluatedAt}) {
  let status; const reasons = [];
  if (["insufficient", "unavailable"].includes(evidence.level)) {
    status = "blocked_insufficient_evidence"; reasons.push("case.evidence_insufficient");
  } else if ((severity === "critical" || criticalSafetyRisk) && (confidenceValue || 0) >= .8 && identityResolved && (sourceCount >= 2 || repeated)) {
    status = "strong_candidate"; reasons.push("case.high_risk_corroborated");
  } else if (["high", "critical"].includes(severity) || repeated || (confidenceValue || 0) >= .6) {
    status = "review_candidate"; reasons.push("case.human_review_threshold");
  } else {
    status = "not_candidate"; reasons.push("case.threshold_not_met");
  }
  return Object.freeze({status, reasonCodes: reasons, evaluatedAt, evaluatorVersion: EVALUATOR_VERSION, requiresHumanReview: true});
}
function timelineEvent({sourceSystem, sourceRecordId, occurredAt, summary, evidenceReferenceCount = 0, immutableSource = true}) {
  const normalized = iso(occurredAt);
  return Object.freeze({eventId: stableId("timeline", sourceSystem, sourceRecordId, normalized || "unknown"), eventType: "source_observed", occurredAt: normalized, occurredAtStatus: normalized ? "known" : "unknown", sourceSystem, sourceRecordId, summary: text(summary, "Kaynak olayı"), evidenceReferenceCount, immutableSource});
}
function maskLabel(value) {
  const clean = text(value, "Kayıt"); if (clean.length <= 4) return "***"; return `${clean.slice(0, 2)}***${clean.slice(-2)}`;
}
function graphNode({id, type, label, sourceSystem, confidenceValue, evidence, firstObservedAt, lastObservedAt}) {
  return Object.freeze({canonicalId: id, type, maskedLabel: maskLabel(label), sourceSystem, confidence: confidenceValue, evidenceQuality: evidence.level, firstObservedAt: iso(firstObservedAt), lastObservedAt: iso(lastObservedAt)});
}
function baseProjection({sourceSystem, sourceRecordId, sourceRecordVersion = "v1", tenantId, canonicalBrandId, canonicalSubjectId, subjectType, title, summary, occurredAt, observedAt, ingestedAt, currentStatus, riskClass, severity, confidenceValue, evidence, candidacy, timeline, nodes = [], edges = []}) {
  if (!SEVERITIES.includes(severity) || !EVIDENCE_LEVELS.includes(evidence.level) || !CASE_STATUSES.includes(candidacy.status)) throw new Error("projection.enum_invalid");
  const signalId = stableId("risk-operation", sourceSystem, sourceRecordId, sourceRecordVersion);
  return Object.freeze({signalId, sourceSystem, sourceRecordId, sourceRecordVersion, tenantId, canonicalBrandId, canonicalSubjectId, subjectType, title: text(title, "Risk sinyali"), summary: text(summary, "Ayrıntı bulunmuyor"), occurredAt: iso(occurredAt), observedAt: iso(observedAt), ingestedAt: iso(ingestedAt), currentStatus: text(currentStatus, "unknown"), riskClass, severity, confidence: confidenceValue, evidenceQuality: evidence, caseCandidacy: candidacy, timeline, timelineSummary: Object.freeze({eventCount: timeline.length, unknownTimeCount: timeline.filter((item) => item.occurredAt == null).length}), relationshipGraph: Object.freeze({nodes, edges}), relationshipSummary: Object.freeze({nodeCount: nodes.length, edgeCount: edges.length}), adapterVersion: ADAPTER_VERSION});
}
function monitoringProjection({id, data, context, evaluatedAt}) {
  const severity = SEVERITIES.includes(data.signalLevel) ? data.signalLevel : "info";
  const refs = Array.isArray(data.evidenceRefs) ? data.evidenceRefs : [];
  const evidence = evidenceQuality({evidenceRefs: refs, sourceCount: 1, primaryVerified: data.evidenceVerified === true});
  const confidenceValue = confidence(data.confidence);
  const candidacy = caseCandidacy({severity, confidenceValue, evidence, sourceCount: 1, repeated: data.repeated === true, identityResolved: true, criticalSafetyRisk: data.criticalSafetyRisk === true, evaluatedAt});
  const occurred = data.detectedAt || data.occurredAt;
  const timeline = [timelineEvent({sourceSystem: "monitoring", sourceRecordId: id, occurredAt: occurred, summary: data.summary, evidenceReferenceCount: refs.length})];
  const node = graphNode({id: context.brandId, type: "brand", label: data.brandName || "Marka", sourceSystem: "monitoring", confidenceValue, evidence, firstObservedAt: occurred, lastObservedAt: occurred});
  return baseProjection({sourceSystem: "monitoring", sourceRecordId: id, tenantId: context.tenantId, canonicalBrandId: context.brandId, canonicalSubjectId: data.pageId || id, subjectType: data.listingId ? "listing" : "source_record", title: data.title, summary: data.summary, occurredAt: occurred, observedAt: data.detectedAt, ingestedAt: data.createdAt, currentStatus: data.status, riskClass: data.eventCategory || "marketplace_abuse", severity, confidenceValue, evidence, candidacy, timeline, nodes: [node]});
}
function traceabilityProjection({id, data, context, evaluatedAt}) {
  const severity = SEVERITIES.includes(data.riskLevel) ? data.riskLevel : "info";
  const evidence = evidenceQuality({evidenceRefs: [], sourceCount: 1, primaryVerified: data.found === true});
  const confidenceValue = Number.isFinite(data.riskScore) ? Math.max(0, Math.min(1, data.riskScore / 100)) : null;
  const candidacy = caseCandidacy({severity, confidenceValue, evidence, sourceCount: 1, repeated: data.repeatScan === true, identityResolved: Boolean(data.productId || data.publicCode), criticalSafetyRisk: ["blocked", "revoked"].includes(data.status), evaluatedAt});
  const timeline = [timelineEvent({sourceSystem: "traceability", sourceRecordId: id, occurredAt: data.createdAt, summary: "Ürün doğrulama taraması", immutableSource: true})];
  return baseProjection({sourceSystem: "traceability", sourceRecordId: id, tenantId: context.tenantId, canonicalBrandId: context.brandId, canonicalSubjectId: data.productId || stableId("scan-subject", id), subjectType: "product", title: text(data.productName, "Şüpheli ürün taraması"), summary: Array.isArray(data.riskReasons) && data.riskReasons.length ? data.riskReasons.join(", ") : "Doğrulama taraması", occurredAt: data.createdAt, observedAt: data.createdAt, ingestedAt: data.createdAt, currentStatus: data.reviewStatus, riskClass: "traceability_anomaly", severity, confidenceValue, evidence, candidacy, timeline, nodes: [graphNode({id: context.brandId, type: "brand", label: data.brandName || "Marka", sourceSystem: "traceability", confidenceValue, evidence, firstObservedAt: data.createdAt, lastObservedAt: data.createdAt})]});
}
module.exports = {ADAPTER_VERSION, EVALUATOR_VERSION, baseProjection, caseCandidacy, evidenceQuality, graphNode, maskLabel, monitoringProjection, timelineEvent, traceabilityProjection};
