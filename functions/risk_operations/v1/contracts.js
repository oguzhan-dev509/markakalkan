/* eslint-disable max-len */
const SOURCES = Object.freeze(["monitoring", "traceability", "digital_detective", "shared_risk"]);
const RISK_CLASSES = Object.freeze(["counterfeit", "traceability_anomaly", "marketplace_abuse", "identity_risk", "safety_risk", "other"]);
const SEVERITIES = Object.freeze(["info", "low", "medium", "high", "critical"]);
const EVIDENCE_LEVELS = Object.freeze(["verified_primary", "corroborated", "single_source", "insufficient", "unavailable"]);
const CASE_STATUSES = Object.freeze(["not_candidate", "review_candidate", "strong_candidate", "blocked_insufficient_evidence"]);
const LOAD_TRIGGERS = Object.freeze(["initial_mount", "date_change", "filter_change", "pull_to_refresh", "error_retry", "pagination"]);
const DIAGNOSTIC_FIELDS = Object.freeze(["clientTabId", "navigationId", "pageInstanceId", "loadAttemptId", "trigger", "attemptSequence"]);
const ALLOWED = Object.freeze(["tenantId", "canonicalBrandId", "pageSize", "pageToken", "sourceSystem", "riskClass", "severity", "evidenceQuality", "caseCandidacy", "occurredFrom", "occurredTo", "query", ...DIAGNOSTIC_FIELDS]);

class RiskOperationsError extends Error {
  constructor(code, message) {
    super(message); this.name = "RiskOperationsError"; this.code = code;
  }
}
function optionalString(value, field, max = 160) {
  if (value == null) return null;
  if (typeof value !== "string" || value.trim().length === 0 || value.trim().length > max) throw new RiskOperationsError("invalid-argument", `${field} invalid`);
  return value.trim();
}
function enumValue(value, allowed, field) {
  const clean = optionalString(value, field, 80);
  if (clean != null && !allowed.includes(clean)) throw new RiskOperationsError("invalid-argument", `${field} unsupported`);
  return clean;
}
function iso(value, field) {
  const clean = optionalString(value, field, 40);
  if (clean == null) return null;
  const parsed = new Date(clean);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString() !== clean) throw new RiskOperationsError("invalid-argument", `${field} invalid`);
  return clean;
}
function diagnosticId(value, field) {
  const clean = optionalString(value, field, 64);
  if (clean == null || clean.length < 8 || !/^[A-Za-z0-9_-]+$/.test(clean)) throw new RiskOperationsError("invalid-argument", `${field} invalid`);
  return clean;
}
function riskOperationsDiagnosticsV1(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new RiskOperationsError("invalid-argument", "request object required");
  if (!Number.isInteger(raw.attemptSequence) || raw.attemptSequence < 1 || raw.attemptSequence > 1000000) throw new RiskOperationsError("invalid-argument", "attemptSequence invalid");
  return Object.freeze({clientTabId: diagnosticId(raw.clientTabId, "clientTabId"), navigationId: diagnosticId(raw.navigationId, "navigationId"), pageInstanceId: diagnosticId(raw.pageInstanceId, "pageInstanceId"), loadAttemptId: diagnosticId(raw.loadAttemptId, "loadAttemptId"), trigger: enumValue(raw.trigger, LOAD_TRIGGERS, "trigger"), attemptSequence: raw.attemptSequence});
}
function riskOperationsRequestV1(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new RiskOperationsError("invalid-argument", "request object required");
  const extras = Object.keys(raw).filter((key) => !ALLOWED.includes(key));
  if (extras.length) throw new RiskOperationsError("invalid-argument", `unsupported filters: ${extras.sort().join(",")}`);
  const pageSize = raw.pageSize == null ? 25 : raw.pageSize;
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 50) throw new RiskOperationsError("invalid-argument", "pageSize invalid");
  const from = iso(raw.occurredFrom, "occurredFrom");
  const to = iso(raw.occurredTo, "occurredTo");
  if (from && to && from > to) throw new RiskOperationsError("invalid-argument", "date range invalid");
  const diagnostics = riskOperationsDiagnosticsV1(raw);
  return Object.freeze({tenantId: optionalString(raw.tenantId, "tenantId"), canonicalBrandId: optionalString(raw.canonicalBrandId, "canonicalBrandId"), pageSize, pageToken: optionalString(raw.pageToken, "pageToken", 500), sourceSystem: enumValue(raw.sourceSystem, SOURCES, "sourceSystem"), riskClass: enumValue(raw.riskClass, RISK_CLASSES, "riskClass"), severity: enumValue(raw.severity, SEVERITIES, "severity"), evidenceQuality: enumValue(raw.evidenceQuality, EVIDENCE_LEVELS, "evidenceQuality"), caseCandidacy: enumValue(raw.caseCandidacy, CASE_STATUSES, "caseCandidacy"), occurredFrom: from, occurredTo: to, query: optionalString(raw.query, "query", 120)?.toLocaleLowerCase("tr-TR") || null, diagnostics});
}
module.exports = {CASE_STATUSES, EVIDENCE_LEVELS, LOAD_TRIGGERS, RISK_CLASSES, RiskOperationsError, SEVERITIES, SOURCES, riskOperationsDiagnosticsV1, riskOperationsRequestV1};
