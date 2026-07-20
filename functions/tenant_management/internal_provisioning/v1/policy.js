/* eslint-disable max-len */
const {ALLOWED_PROJECT_IDS, PERMISSION, PILOT_CODE} = require("./contracts");

function evaluateProvisioningPolicyV1({request, invocation, admin}) {
  const blockers = [];
  if (!ALLOWED_PROJECT_IDS.includes(invocation.projectId)) {
    blockers.push("project.denied");
  }
  if (!admin || admin.exists !== true) blockers.push("admin.missing");
  if (!admin || !admin.data || admin.data.active !== true) blockers.push("admin.inactive");
  if (!admin || !admin.data || !Array.isArray(admin.data.roles) ||
      !admin.data.roles.includes("super_admin")) blockers.push("admin.role_missing");
  if (request.pilotCode !== PILOT_CODE) blockers.push("pilot.denied");
  return Object.freeze({allowed: blockers.length === 0,
    blockers: Object.freeze([...new Set(blockers)].sort()),
    permissions: blockers.length === 0 ? Object.freeze([PERMISSION]) :
      Object.freeze([]), policyVersion: "internal-provisioning-policy-v1"});
}

module.exports = {evaluateProvisioningPolicyV1};
