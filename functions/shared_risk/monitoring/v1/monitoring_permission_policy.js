const {immutableSnapshot} = require("../../persistence/v1/storage_contracts");

function evaluateMonitoringPersistencePermissionV1({adminSnapshot,
  requestedPermission, evaluationTime}) {
  const data = adminSnapshot && adminSnapshot.exists ? adminSnapshot.data : {};
  const roles = [...new Set(Array.isArray(data.roles) ?
    data.roles.filter((value) => typeof value === "string") : [])].sort();
  const granted = data.active === true && roles.includes("super_admin") &&
    requestedPermission === "risk_signal.persist";
  return immutableSnapshot({granted, evaluationTime,
    authoritativeRoles: roles,
    derivedExactPermissions: granted ? ["risk_signal.persist"] : [],
    reasons: granted ? [] : ["authorization.super_admin_required"]});
}

module.exports = {evaluateMonitoringPersistencePermissionV1};
