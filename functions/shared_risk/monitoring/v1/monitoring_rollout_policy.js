const MODES = Object.freeze({
  disabled: "disabled",
  dryRunOnly: "dry_run_only",
  singleSignalWrite: "single_signal_write",
});

const POLICY_VERSION = "monitoring-risk-rollout-policy-v1";

function parseAllowedSignalIds(raw) {
  if (typeof raw !== "string" || raw.trim().length === 0) return [];
  return [...new Set(raw.split(",").map((item) => item.trim())
      .filter((item) => item.length > 0))];
}

function evaluateMonitoringRolloutPolicyV1({mode, allowedSignalIds,
  monitoringSignalId, dryRun, projectId, expectedProjectId,
  evaluatedAt, effectiveAt = null, expiresAt = null}) {
  const reasons = [];
  if (projectId !== expectedProjectId) reasons.push("rollout.project_denied");
  if (!Object.values(MODES).includes(mode)) {
    reasons.push("rollout.mode_invalid");
  }
  if (effectiveAt && evaluatedAt < effectiveAt) {
    reasons.push("rollout.not_effective");
  }
  if (expiresAt && evaluatedAt >= expiresAt) reasons.push("rollout.expired");
  if (allowedSignalIds.length > 1) reasons.push("rollout.allowlist_invalid");
  if (mode === MODES.disabled) reasons.push("rollout.disabled");
  if (mode === MODES.dryRunOnly && !dryRun) {
    reasons.push("rollout.write_disabled");
  }
  if (mode === MODES.singleSignalWrite && !dryRun &&
      (allowedSignalIds.length !== 1 ||
       allowedSignalIds[0] !== monitoringSignalId)) {
    reasons.push("rollout.signal_not_allowed");
  }
  return Object.freeze({allowed: reasons.length === 0,
    reasons: Object.freeze([...new Set(reasons)].sort()),
    mode, policyVersion: POLICY_VERSION,
    allowedSignalCount: allowedSignalIds.length, evaluatedAt});
}

module.exports = {MODES, POLICY_VERSION,
  evaluateMonitoringRolloutPolicyV1, parseAllowedSignalIds};
