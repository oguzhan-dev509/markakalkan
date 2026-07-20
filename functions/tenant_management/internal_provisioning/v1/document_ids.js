/* eslint-disable max-len */
const {createHash} = require("node:crypto");
const {encodeParts, sha256Hex} = require("../../../shared_risk/persistence/v1/document_id");

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(
        Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  }
  return value;
}
function fingerprint(value) {
  return createHash("sha256").update(JSON.stringify(canonical(value))).digest("hex");
}
function buildIdsV1({pilotCode, projectId, uid}) {
  const key = encodeParts(["canonical-provisioning-v1",
    "internal_tenant_brand", pilotCode, projectId]);
  const id = (kind, ...parts) => sha256Hex(encodeParts([
    `canonical-${kind}-id-v1`, key, ...parts]));
  const tenantId = id("tenant");
  const brandId = id("brand", tenantId);
  const membershipId = id("membership", tenantId, uid);
  const receiptId = id("provisioning-receipt", tenantId, brandId);
  const auditId = id("provisioning-audit", receiptId);
  const commandId = encodeParts(["canonical-provisioning-command-v1", key,
    tenantId, brandId, membershipId]);
  return Object.freeze({canonicalProvisioningKey: key, tenantId, brandId,
    membershipId, receiptId, auditId, commandId});
}
module.exports = {buildIdsV1, fingerprint};
