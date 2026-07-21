/* eslint-disable max-len */
const CONTRACT_VERSION = "shared-risk-promotion-command-v1";
const CALLABLE_NAME = "promoteRiskOperationToSharedRisk";
const EXACT_PERMISSION = "risk_signal.persist";
const SOURCES = Object.freeze(["traceability", "monitoring", "digital_detective"]);

class PromotionError extends Error {
  constructor(code) {
    super(code); this.code = code;
  }
}

function text(value, field, max = 200) {
  if (typeof value !== "string" || !value.trim() || value.length > max) {
    throw new PromotionError(`request.${field}_invalid`);
  }
  return value.trim();
}

function promotionRequestV1(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new PromotionError("request.invalid");
  }
  const allowed = ["sourceSystem", "sourceRecordId",
    "expectedSourceRecordVersion", "expectedProjectionFingerprint",
    "dryRun", "correlationId"];
  if (Object.keys(raw).some((key) => !allowed.includes(key))) {
    throw new PromotionError("request.authority_field_forbidden");
  }
  const sourceSystem = text(raw.sourceSystem, "source_system", 40);
  if (!SOURCES.includes(sourceSystem)) {
    throw new PromotionError("request.source_system_unsupported");
  }
  if (typeof raw.dryRun !== "boolean") {
    throw new PromotionError("request.dry_run_invalid");
  }
  return Object.freeze({sourceSystem,
    sourceRecordId: text(raw.sourceRecordId, "source_record_id"),
    expectedSourceRecordVersion: text(raw.expectedSourceRecordVersion,
        "source_record_version"),
    expectedProjectionFingerprint: text(raw.expectedProjectionFingerprint,
        "projection_fingerprint", 64), dryRun: raw.dryRun,
    correlationId: text(raw.correlationId, "correlation_id", 100)});
}

module.exports = {CALLABLE_NAME, CONTRACT_VERSION, EXACT_PERMISSION,
  PromotionError, SOURCES, promotionRequestV1};
