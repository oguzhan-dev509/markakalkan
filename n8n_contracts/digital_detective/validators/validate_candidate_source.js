"use strict";
const {canonicalizeUrl} = require("./canonicalize_url");
const {buildSourceId} = require("./deterministic_ids");
const {issue, result} = require("./validator_result");
const {readValidationContext} = require("./context_validation");
const {validateSchema} = require("./schema_engine");

function validateCandidateSourceInternal(candidate, context) {
  const schema = validateSchema("candidate_source", candidate);
  if (!schema.valid) return schema;
  const errors = [];
  const validationContext = readValidationContext(context);
  if (!validationContext) {
    return result({errors: [issue("CONTEXT_REQUIRED", "$",
      "Task ve execution context zorunludur.")]});
  }
  const canonical = canonicalizeUrl(candidate.sourceUrl);
  if (!canonical.valid) errors.push(issue("CANDIDATE_URL_INVALID", "sourceUrl", canonical.errors.join(",")));
  if (canonical.valid && candidate.canonicalUrl !== canonical.canonicalUrl) errors.push(issue("CANONICAL_URL_MISMATCH", "canonicalUrl", "Canonical URL does not match."));
  if (canonical.valid && candidate.sourceId !== buildSourceId(candidate.taskId, candidate.executionId, canonical.canonicalUrl)) errors.push(issue("SOURCE_ID_MISMATCH", "sourceId", "Source ID does not match."));
  if (candidate.taskId !== validationContext.taskId) errors.push(issue("TASK_ID_MISMATCH", "taskId", "Task ID mismatch."));
  if (candidate.executionId !== validationContext.executionId) errors.push(issue("EXECUTION_ID_MISMATCH", "executionId", "Execution ID mismatch."));
  if (candidate.robotsPolicy === "blocked" && candidate.acquisitionStatus !== "blocked") errors.push(issue("ROBOTS_STATUS_MISMATCH", "acquisitionStatus", "Blocked robots policy requires blocked status."));
  if (["captcha", "login_required"].includes(candidate.errorCode) && candidate.acquisitionStatus === "acquired") errors.push(issue("ACCESS_BARRIER_ACQUIRED", "acquisitionStatus", "Access barrier cannot be acquired."));
  return result({errors});
}

function validateCandidateSource(candidate, context) {
  try {
    return validateCandidateSourceInternal(candidate, context);
  } catch (_) {
    return result({errors: [issue("CANDIDATE_VALIDATION_EXCEPTION", "$",
      "Doğrulama güvenli biçimde tamamlanamadı.")]});
  }
}
module.exports = {validateCandidateSource};
