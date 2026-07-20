/* eslint-disable max-len */
const PILOT_CODE = "MK-RST-0J-INTERNAL-001";
const PROJECT_ID = "demo-markakalkan-rst-0k";
const PERMISSION = "internal_tenant_brand.provision";

function required(value, field) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new TypeError(`${field} is required`);
  }
  return value.trim();
}

function provisioningRequestV1(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new TypeError("request must be an object");
  }
  const allowed = ["pilotCode", "dryRun", "correlationId"];
  const unknown = Object.keys(input).filter((key) => !allowed.includes(key));
  if (unknown.length > 0) throw new TypeError("request contains unknown fields");
  if (typeof input.dryRun !== "boolean") throw new TypeError("dryRun is required");
  return Object.freeze({pilotCode: required(input.pilotCode, "pilotCode"),
    dryRun: input.dryRun,
    correlationId: input.correlationId ?
      required(input.correlationId, "correlationId") : null});
}

function invocationContextV1(input) {
  if (!input || typeof input !== "object") throw new TypeError("invocation required");
  return Object.freeze({authenticatedUid:
    required(input.authenticatedUid, "authenticatedUid"),
  projectId: required(input.projectId, "projectId"),
  receivedAt: required(input.receivedAt, "receivedAt")});
}

module.exports = {PERMISSION, PILOT_CODE, PROJECT_ID, invocationContextV1,
  provisioningRequestV1};
