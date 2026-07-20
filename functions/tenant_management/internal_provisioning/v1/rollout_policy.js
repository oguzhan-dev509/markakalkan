/* eslint-disable max-len */
const MODES = Object.freeze({disabled: "disabled", dryRunOnly: "dry_run_only",
  singlePilotCreate: "single_pilot_create"});
const POLICY_VERSION = "internal-provisioning-rollout-policy-v1";

function parseAllowedPilotCodes(raw) {
  if (typeof raw !== "string" || raw.trim().length === 0) return [];
  return [...new Set(raw.split(",").map((item) => item.trim())
      .filter(Boolean))];
}

function evaluateProvisioningRolloutPolicyV1({mode, allowedPilotCodes,
  pilotCode, dryRun, projectId, expectedProjectId, evaluatedAt,
  expiresAt = null}) {
  const reasons = [];
  if (projectId !== expectedProjectId) reasons.push("rollout.project_denied");
  if (!Object.values(MODES).includes(mode)) reasons.push("rollout.mode_invalid");
  if (expiresAt && evaluatedAt >= expiresAt) reasons.push("rollout.expired");
  if (allowedPilotCodes.length > 1) reasons.push("rollout.allowlist_invalid");
  if (mode === MODES.disabled) reasons.push("rollout.disabled");
  if (mode === MODES.dryRunOnly && !dryRun) {
    reasons.push("rollout.write_disabled");
  }
  if (mode === MODES.singlePilotCreate && !dryRun &&
      (allowedPilotCodes.length !== 1 || allowedPilotCodes[0] !== pilotCode)) {
    reasons.push("rollout.pilot_not_allowed");
  }
  return Object.freeze({allowed: reasons.length === 0,
    reasons: Object.freeze([...new Set(reasons)].sort()), mode,
    policyVersion: POLICY_VERSION, allowedPilotCount: allowedPilotCodes.length});
}

module.exports = {MODES, POLICY_VERSION, evaluateProvisioningRolloutPolicyV1,
  parseAllowedPilotCodes};
