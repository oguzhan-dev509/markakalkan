/* eslint-disable max-len */
const {RiskOperationsError, riskOperationsRequestV1} = require("./contracts");
const {baseProjection, caseCandidacy, evidenceQuality, monitoringProjection, timelineEvent, traceabilityProjection} = require("./projection");

const dataOf = (snapshot) => ({id: snapshot.id, data: snapshot.data() || {},
  version: snapshot.updateTime && snapshot.updateTime.toDate ?
    snapshot.updateTime.toDate().toISOString() : null});
async function resolveTenantContextV1({db, uid, request}) {
  const memberships = (await db.collection("tenant_memberships").where("uid", "==", uid).limit(20).get()).docs.map(dataOf).filter((item) => item.data.status === "active");
  const eligible = request.tenantId ? memberships.filter((item) => item.data.tenantId === request.tenantId) : memberships;
  if (eligible.length === 0) throw new RiskOperationsError("failed-precondition", request.tenantId ? "tenant membership mismatch" : "no active tenant");
  if (eligible.length !== 1) throw new RiskOperationsError("failed-precondition", "tenant context ambiguous");
  const membership = eligible[0];
  const brands = (await db.collection("canonical_brands").where("tenantId", "==", membership.data.tenantId).limit(20).get()).docs.map(dataOf).filter((item) => item.data.status === "active");
  const eligibleBrands = request.canonicalBrandId ? brands.filter((item) => item.id === request.canonicalBrandId) : brands;
  if (eligibleBrands.length === 0) throw new RiskOperationsError("failed-precondition", request.canonicalBrandId ? "brand membership mismatch" : "no active brand");
  if (eligibleBrands.length !== 1) throw new RiskOperationsError("failed-precondition", "brand context ambiguous");
  return Object.freeze({tenantId: membership.data.tenantId, brandId: eligibleBrands[0].id, membershipId: membership.id, uid});
}
function sharedRiskProjection({id, data, context, evaluatedAt}) {
  if (data.tenantId !== context.tenantId) throw new Error("shared_risk.tenant_mismatch");
  const severity = data.canonicalSeverity || data.severity || "info";
  const refs = Array.isArray(data.evidenceRefs) ? data.evidenceRefs : [];
  const evidence = evidenceQuality({evidenceRefs: refs, sourceCount: Number(data.sourceCount) || (refs.length ? 1 : 0), primaryVerified: data.primaryVerified === true});
  const confidenceValue = typeof data.confidence === "object" ? Number(data.confidence.value) : Number(data.confidence);
  const safeConfidence = Number.isFinite(confidenceValue) ? Math.max(0, Math.min(1, confidenceValue)) : null;
  const candidacy = caseCandidacy({severity, confidenceValue: safeConfidence, evidence, sourceCount: Number(data.sourceCount) || 1, repeated: data.repeated === true, identityResolved: Boolean(data.subjectId || data.canonicalSubjectId), criticalSafetyRisk: data.criticalSafetyRisk === true, evaluatedAt});
  const sourceSystem = data.sourceModule || data.signalSource?.module || "shared_risk";
  const occurred = data.occurredAt || data.sourceTimestamps?.occurredAt;
  return baseProjection({sourceSystem: "shared_risk", sourceRecordId: id, sourceRecordVersion: data.contractVersion || "v1", tenantId: context.tenantId, canonicalBrandId: context.brandId, canonicalSubjectId: data.subjectId || data.canonicalSubjectId || id, subjectType: data.subjectType || "source_record", title: data.title || "Ortak risk sinyali", summary: data.summary, occurredAt: occurred, observedAt: data.detectedAt, ingestedAt: data.createdAt || data.persistedAt, currentStatus: data.reviewStatus || data.status, riskClass: data.riskClass || data.riskCategory?.value || "other", severity, confidenceValue: safeConfidence, evidence, candidacy, timeline: [timelineEvent({sourceSystem, sourceRecordId: id, occurredAt: occurred, summary: data.summary, evidenceReferenceCount: refs.length})]});
}
async function querySource(db, name, field, value, limit = 200) {
  return (await db.collection(name).where(field, "==", value).limit(limit).get()).docs.map(dataOf);
}
async function readSources({db, context, evaluatedAt}) {
  const sources = [
    ["monitoring", async () => (await querySource(db, "monitoring_signals", "tenantId", context.tenantId)).filter((item) => item.data.brandId === context.brandId).map((item) => monitoringProjection({...item, data: {...item.data, sourceRecordVersion: item.version || item.data.sourceRecordVersion}, context, evaluatedAt}))],
    ["traceability", async () => (await querySource(db, "verificationScans", "ownerUid", context.uid)).map((item) => traceabilityProjection({...item, data: {...item.data, sourceRecordVersion: item.version || item.data.sourceRecordVersion}, context, evaluatedAt}))],
    ["shared_risk", async () => (await querySource(db, "shared_risk_signals", "tenantId", context.tenantId)).map((item) => sharedRiskProjection({...item, context, evaluatedAt}))],
    ["digital_detective", async () => {
      const snap = await db.collection("brands").doc(context.uid).collection("digitalDetectiveTasks").limit(200).get(); return snap.docs.map(dataOf).filter((item) => item.data.status === "completed").map((item) => sharedRiskProjection({id: item.id, data: {...item.data, contractVersion: item.version || item.data.contractVersion, tenantId: context.tenantId, canonicalSubjectId: item.id, subjectType: "source_record", sourceModule: "digital_detective", title: item.data.title || "Dijital Dedektif sonucu", riskClass: item.data.riskClass || "other"}, context, evaluatedAt}));
    }],
  ];
  const settled = await Promise.allSettled(sources.map((item) => item[1]()));
  const items = []; const availability = [];
  settled.forEach((result, index) => {
    const name = sources[index][0]; if (result.status === "fulfilled") {
      items.push(...result.value); availability.push({sourceSystem: name, status: "available"});
    } else {
      availability.push({sourceSystem: name, status: "unavailable", reasonCode: "source.read_failed"});
    }
  });
  return {items, availability};
}
function decodeCursor(token) {
  if (!token) return null; try {
    const parsed = JSON.parse(Buffer.from(token, "base64url").toString("utf8")); if (!parsed || typeof parsed.occurredAtKey !== "string" || typeof parsed.signalId !== "string") throw new Error(); return parsed;
  } catch (_) {
    throw new RiskOperationsError("invalid-argument", "pageToken invalid");
  }
}
const occurredKey = (item) => item.occurredAt || "0000-00-00T00:00:00.000Z";
function compare(a, b) {
  const date = occurredKey(b).localeCompare(occurredKey(a)); return date || a.signalId.localeCompare(b.signalId);
}
function applyFilters(items, request) {
  return items.filter((item) => (!request.sourceSystem || item.sourceSystem === request.sourceSystem) && (!request.riskClass || item.riskClass === request.riskClass) && (!request.severity || item.severity === request.severity) && (!request.evidenceQuality || item.evidenceQuality.level === request.evidenceQuality) && (!request.caseCandidacy || item.caseCandidacy.status === request.caseCandidacy) && (!request.occurredFrom || (item.occurredAt && item.occurredAt >= request.occurredFrom)) && (!request.occurredTo || (item.occurredAt && item.occurredAt <= request.occurredTo)) && (!request.query || `${item.title} ${item.summary} ${item.sourceSystem} ${item.riskClass}`.toLocaleLowerCase("tr-TR").includes(request.query)));
}
function paginate(items, request) {
  const sorted = [...items].sort(compare); const cursor = decodeCursor(request.pageToken); const after = cursor ? sorted.filter((item) => occurredKey(item) < cursor.occurredAtKey || (occurredKey(item) === cursor.occurredAtKey && item.signalId > cursor.signalId)) : sorted; const page = after.slice(0, request.pageSize); const last = page.at(-1); return {items: page, nextPageToken: after.length > page.length && last ? Buffer.from(JSON.stringify({occurredAtKey: occurredKey(last), signalId: last.signalId})).toString("base64url") : null};
}
function summary(items) {
  return Object.freeze({totalVisibleSignals: items.length, highOrCriticalRisk: items.filter((item) => ["high", "critical"].includes(item.severity)).length, awaitingHumanReview: items.filter((item) => item.caseCandidacy.requiresHumanReview && item.caseCandidacy.status !== "not_candidate").length, strongCaseCandidates: items.filter((item) => item.caseCandidacy.status === "strong_candidate").length, insufficientEvidence: items.filter((item) => ["insufficient", "unavailable"].includes(item.evidenceQuality.level)).length});
}
function createRiskOperationsReadServiceV1({db, clock = {now: () => new Date().toISOString()}}) {
  return Object.freeze({async list(raw, invocation) {
    const request = riskOperationsRequestV1(raw); if (!invocation || typeof invocation.uid !== "string" || !invocation.uid) throw new RiskOperationsError("unauthenticated", "authentication required"); const context = await resolveTenantContextV1({db, uid: invocation.uid, request}); const evaluatedAt = clock.now(); const sources = await readSources({db, context, evaluatedAt}); const filtered = applyFilters(sources.items, request); const page = paginate(filtered, request); return Object.freeze({contractVersion: "risk-operations-read-v1", tenantContext: {tenantId: context.tenantId, canonicalBrandId: context.brandId}, summary: summary(filtered), items: page.items, nextPageToken: page.nextPageToken, sourceAvailability: sources.availability, readOnly: true, writesPerformed: 0});
  }});
}
module.exports = {applyFilters, compare, createRiskOperationsReadServiceV1, paginate, readSources, resolveTenantContextV1, sharedRiskProjection, summary};
