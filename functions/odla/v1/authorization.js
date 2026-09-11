"use strict";

const ODLA_ROLES = Object.freeze([
  "verified_rightsholder",
  "authorized_representative",
  "assigned_laboratory",
  "authorized_operator",
  "authorized_reviewer",
]);

const ODLA_ACTIONS = Object.freeze([
  "create_case",
  "read_workspace",
  "append_custody",
  "create_test_request",
  "record_test_result",
  "adjudicate_finding",
  "open_appeal",
  "resolve_appeal",
]);

const ROLE_ACTIONS = Object.freeze({
  verified_rightsholder: Object.freeze([
    "create_case",
    "read_workspace",
    "append_custody",
    "create_test_request",
    "open_appeal",
  ]),
  authorized_representative: Object.freeze([
    "create_case",
    "read_workspace",
    "append_custody",
    "create_test_request",
    "open_appeal",
  ]),
  assigned_laboratory: Object.freeze([
    "read_workspace",
    "append_custody",
    "record_test_result",
  ]),
  authorized_operator: Object.freeze(["append_custody"]),
  authorized_reviewer: Object.freeze([
    "read_workspace",
    "create_test_request",
    "adjudicate_finding",
    "resolve_appeal",
  ]),
});

function fail(code, message) {
  const error = new Error(message || code);
  error.code = code;
  throw error;
}

function arr(value) {
  return Array.isArray(value) ?
    value.filter((x) => typeof x === "string" && x) :
    [];
}

function assertAuthenticatedRequest(request) {
  if (
    !request ||
    !request.auth ||
    typeof request.auth.uid !== "string" ||
    !request.auth.uid
  ) {
    fail("unauthenticated", "Firebase authentication required");
  }
  const token =
    request.auth.token && typeof request.auth.token === "object" ?
      request.auth.token :
      {};
  const odla =
    token.odlaAuthority && typeof token.odlaAuthority === "object" ?
      token.odlaAuthority :
      {};
  const roles = arr(
    odla.roles && odla.roles.length ? odla.roles : token.odlaRoles,
  ).filter((r) => ODLA_ROLES.includes(r));
  const tenantId =
    typeof odla.tenantId === "string" && odla.tenantId ?
      odla.tenantId :
      typeof token.tenantId === "string" && token.tenantId ?
        token.tenantId :
        null;
  const brandUids = arr(
    odla.brandUids && odla.brandUids.length ?
      odla.brandUids :
      token.brandUids,
  );
  const assignedLaboratoryIds = arr(
    odla.assignedLaboratoryIds && odla.assignedLaboratoryIds.length ?
      odla.assignedLaboratoryIds :
      token.assignedLaboratoryIds,
  );
  return Object.freeze({
    uid: request.auth.uid,
    roles: Object.freeze([...roles]),
    tenantId,
    brandUids: Object.freeze([...brandUids]),
    assignedLaboratoryIds: Object.freeze([...assignedLaboratoryIds]),
    source: "firebase_auth_trusted_claims",
  });
}

function assertTenantMatch(authority, target) {
  if (!authority || !target || typeof target !== "object") {
    fail("permission-denied", "Authority and target required");
  }
  if (target.tenantId && authority.tenantId !== target.tenantId) {
    fail("permission-denied", "Cross-tenant ODLA access denied");
  }
  if (target.brandUid && !authority.brandUids.includes(target.brandUid)) {
    fail("permission-denied", "Cross-brand ODLA access denied");
  }
  return true;
}

function assertActionAuthorized(authority, action) {
  if (!ODLA_ACTIONS.includes(action)) {
    fail("permission-denied", "Unknown ODLA action");
  }
  if (!authority || !Array.isArray(authority.roles)) {
    fail("permission-denied", "Trusted ODLA authority required");
  }
  const allowed = authority.roles.some(
      (role) =>
        Array.isArray(ROLE_ACTIONS[role]) &&
      ROLE_ACTIONS[role].includes(action),
  );
  if (!allowed) fail("permission-denied", "ODLA action denied");
  return true;
}

function assertAssignedLaboratory(authority, laboratoryId) {
  assertActionAuthorized(authority, "record_test_result");
  if (
    !laboratoryId ||
    !authority.assignedLaboratoryIds.includes(laboratoryId)
  ) {
    fail("permission-denied", "Laboratory is not assigned to this caller");
  }
  return true;
}

module.exports = {
  ODLA_ACTIONS,
  ODLA_ROLES,
  assertAuthenticatedRequest,
  assertTenantMatch,
  assertActionAuthorized,
  assertAssignedLaboratory,
};
