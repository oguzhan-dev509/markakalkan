const {immutableSnapshot} = require("../../persistence/v1/storage_contracts");

class MonitoringPersistenceErrorV1 extends Error {
  constructor(code, message) {
    super(message);
    this.name = "MonitoringPersistenceErrorV1";
    this.code = code;
  }
}

function required(value, field) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new MonitoringPersistenceErrorV1(
        "request.invalid", `${field} required`);
  }
  return value.trim();
}

function monitoringRiskPersistenceRequestV1(input) {
  const allowed = ["monitoringSignalId", "dryRun", "correlationId",
    "requestedAt"];
  const extras = Object.keys(input || {})
      .filter((key) => !allowed.includes(key));
  if (extras.length > 0) {
    throw new MonitoringPersistenceErrorV1("request.untrusted_field",
        `Unsupported request fields: ${extras.sort().join(",")}`);
  }
  if (typeof input.dryRun !== "boolean") {
    throw new MonitoringPersistenceErrorV1(
        "request.invalid", "dryRun required");
  }
  return immutableSnapshot({
    monitoringSignalId: required(
        input.monitoringSignalId, "monitoringSignalId"),
    dryRun: input.dryRun,
    correlationId: input.correlationId ? required(input.correlationId,
        "correlationId") : null,
    requestedAt: required(input.requestedAt, "requestedAt"),
  });
}

function verifiedServerInvocationContextV1(input) {
  return immutableSnapshot({
    authenticatedUid: required(input.authenticatedUid, "authenticatedUid"),
    authenticationType: required(input.authenticationType,
        "authenticationType"),
    invocationId: required(input.invocationId, "invocationId"),
    receivedAt: required(input.receivedAt, "receivedAt"),
    correlationId: input.correlationId || null,
    metadata: input.metadata || {},
  });
}

module.exports = {MonitoringPersistenceErrorV1,
  monitoringRiskPersistenceRequestV1, verifiedServerInvocationContextV1};
