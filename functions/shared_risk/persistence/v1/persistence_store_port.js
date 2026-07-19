const {EXACT_PERMISSIONS, TARGETS} = require("./storage_contracts");

function validateAuthoritativeFactsForPortV1(facts) {
  const blockers = [...(facts.validationBlockers || [])];
  if (!facts.resolvedIdentityScope ||
      typeof facts.resolvedIdentityScope.tenantId !== "string" ||
      facts.resolvedIdentityScope.tenantId.length === 0) {
    blockers.push("port.resolved_tenant_missing");
  }
  if (TARGETS[facts.subjectType] !== facts.targetNamespace) {
    blockers.push("port.subject_target_mismatch");
  }
  if (!facts.grantedPermissions ||
      !facts.grantedPermissions.includes(
          EXACT_PERMISSIONS[facts.subjectType],
      )) {
    blockers.push("port.exact_permission_missing");
  }
  if (!facts.readinessDecision || facts.readinessDecision.allowed !== true) {
    blockers.push("port.readiness_denied");
  }
  return Object.freeze([...new Set(blockers)].sort());
}

function assertPersistenceStorePortV1(store) {
  if (!store || typeof store.runTransaction !== "function" ||
      typeof store.referencesFor !== "function") {
    throw new TypeError("Persistence store port is invalid");
  }
  return store;
}

module.exports = {
  assertPersistenceStorePortV1,
  validateAuthoritativeFactsForPortV1,
};
