const MODULE = "digital_market_monitoring";
const SEVERITIES = new Set(["info", "low", "medium", "high", "critical"]);
const STATUSES = new Set(["new", "under_review", "confirmed", "dismissed",
  "escalated", "resolved", "archived"]);

function required(value, field) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`monitoring.${field}_required`);
  }
  return value.trim();
}

function iso(value, field) {
  const date = value && typeof value.toDate === "function" ? value.toDate() :
    new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`monitoring.${field}_invalid`);
  }
  return date.toISOString();
}

function ref(entityType, entityId, displayCode) {
  const output = {module: MODULE, entityType,
    entityId: required(entityId, entityType)};
  if (displayCode && displayCode.trim()) {
    output.displayCode = displayCode.trim();
  }
  return output;
}

function adaptMonitoringRiskSignalV1({signalId, signal, event, adaptedAt}) {
  const tenantId = required(signal.tenantId, "tenantId");
  const brandId = required(signal.brandId, "brandId");
  const id = required(signalId, "signalId");
  const level = required(signal.signalLevel, "signalLevel");
  const status = required(signal.status, "status");
  if (!SEVERITIES.has(level)) {
    throw new Error("monitoring.severity_unsupported");
  }
  if (!STATUSES.has(status)) {
    throw new Error("monitoring.lifecycle_unsupported");
  }
  if (event && (event.id !== signal.eventId || event.tenantId !== tenantId ||
      event.brandId !== brandId || event.sourceId !== signal.sourceId ||
      event.pageId !== signal.pageId)) {
    throw new Error("monitoring.event_scope_mismatch");
  }
  const refs = [ref("monitoring_signal", id),
    ref("monitoring_event", signal.eventId),
    ref("monitoring_source", signal.sourceId),
    ref("monitored_page", signal.pageId),
    ref("signal_rule", signal.ruleId, signal.ruleName)];
  for (const [type, value] of [["product_listing", signal.listingId],
    ["seller", signal.sellerId], ["seller_store", signal.storeId]]) {
    if (typeof value === "string" && value.trim()) refs.push(ref(type, value));
  }
  if (event) {
    refs.push(ref("page_snapshot", event.previousSnapshotId),
        ref("page_snapshot", event.currentSnapshotId),
        ref("event_type", event.eventType),
        ref("event_category", event.eventCategory));
  }
  return {
    signalId: id,
    contractVersion: "risk-signal-v1",
    identityScope: {tenantId, brandId, resolutionStatus: "resolved",
      resolutionSource: "monitoring.signal", unresolvedReasons: []},
    canonicalAssetRef: {assetType: "monitored_page",
      assetId: required(signal.pageId, "pageId"), module: MODULE, brandId},
    signalSource: {module: MODULE, sourceType: "monitoring_signal",
      sourceId: required(signal.sourceId, "sourceId")},
    signalType: {namespace: "digital_market_monitoring.event_type",
      value: event ? event.eventType : signal.eventType || "rule_match"},
    canonicalSeverity: level,
    originalSeverity: level,
    summary: required(signal.summary, "summary"),
    evidenceRefs: [],
    relatedEntityRefs: refs,
    reviewStatus: status,
    detectedAt: iso(signal.detectedAt, "detectedAt"),
    createdAt: iso(signal.createdAt, "createdAt"),
    provenance: {producerModule: MODULE,
      producerVersion: "monitoring-risk-adapter-v1", sourceRecordId: id,
      sourceId: required(signal.sourceId, "sourceId"),
      ...(event ? {snapshotId: required(event.currentSnapshotId,
          "currentSnapshotId")} : {}),
      sourceCreatedAt: iso(signal.createdAt, "createdAt"),
      adaptedAt: iso(adaptedAt, "adaptedAt")},
  };
}

module.exports = {adaptMonitoringRiskSignalV1};
