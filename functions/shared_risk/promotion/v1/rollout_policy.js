/* eslint-disable max-len */
const MODES = Object.freeze({disabled: "disabled", dryRunOnly: "dry_run_only",
  singleSourceCreate: "single_source_create"});
const POLICY_VERSION = "shared-risk-promotion-rollout-policy-v1";

const sourceKey = (request) => [request.sourceSystem, request.sourceRecordId,
  request.expectedSourceRecordVersion].join(":");
function parseAllowlist(raw) {
  if (typeof raw !== "string" || !raw.trim()) return [];
  return [...new Set(raw.split(",").map((value) => value.trim())
      .filter(Boolean))];
}
function evaluateRolloutV1({mode, allowlist, request, projectId,
  expectedProjectId}) {
  const reasons = [];
  if (projectId !== expectedProjectId) reasons.push("rollout.project_denied");
  if (!Object.values(MODES).includes(mode)) reasons.push("rollout.mode_invalid");
  if (mode === MODES.disabled) reasons.push("rollout.disabled");
  if (mode === MODES.dryRunOnly && !request.dryRun) {
    reasons.push("rollout.write_disabled");
  }
  if (allowlist.length > 1) reasons.push("rollout.allowlist_invalid");
  if (mode === MODES.singleSourceCreate && !request.dryRun &&
      (allowlist.length !== 1 || allowlist[0] !== sourceKey(request))) {
    reasons.push("rollout.source_not_allowed");
  }
  return Object.freeze({allowed: reasons.length === 0, reasons: Object.freeze(
      [...new Set(reasons)].sort()), mode, policyVersion: POLICY_VERSION});
}
module.exports = {MODES, POLICY_VERSION, evaluateRolloutV1, parseAllowlist,
  sourceKey};
