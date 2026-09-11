"use strict";
const {canonicalJson, deriveDeterministicId, sha256Hex}=require("./contracts");
const CUSTODY_CONFLICT_CODES=Object.freeze(["CUSTODY_SEQUENCE_GAP", "CUSTODY_PREVIOUS_LINK_MISMATCH", "CUSTODY_EVENT_HASH_MISMATCH", "SEAL_MISMATCH", "SAMPLE_IDENTITY_MISMATCH", "LAB_RECEIPT_SAMPLE_MISMATCH", "UNAUTHORIZED_CUSTODY_ACTOR", "REQUIRED_TRANSPORT_EVIDENCE_MISSING", "DUPLICATE_SEQUENCE_DIFFERENT_PAYLOAD"]);
function nohash(e) {
  const x={...e}; delete x.eventPayloadSha256; return x;
}
function eh(e) {
  return sha256Hex(canonicalJson(nohash(e)));
}
function buildCustodyEvent(i) {
  const e={contractVersion: "odla-chain-of-custody-event-v1", tenantId: i.tenantId, brandUid: i.brandUid, caseId: i.caseId, sampleId: i.sampleId, eventSequence: i.eventSequence, eventType: i.eventType, occurredAt: i.occurredAt, recordedAt: i.recordedAt, actorType: i.actorType, actorId: i.actorId, locationCode: i.locationCode, sealId: i.sealId??null, previousEventId: i.previousEventId??null, previousEventPayloadSha256: i.previousEventPayloadSha256??null, evidenceRefs: Array.isArray(i.evidenceRefs)?[...i.evidenceRefs]:[], appendOnly: true}; e.eventId=deriveDeterministicId("odla-custody-event-v1", [e.tenantId, e.brandUid, e.caseId, e.sampleId, e.eventSequence, e.eventType, e.occurredAt]); e.eventPayloadSha256=eh(e); return Object.freeze(e);
}
function validateCustodyGenesis(e) {
  if (!e||e.eventSequence!==1) return {ok: false, code: "CUSTODY_SEQUENCE_GAP"}; if (e.previousEventId!==null||e.previousEventPayloadSha256!==null) return {ok: false, code: "CUSTODY_PREVIOUS_LINK_MISMATCH"}; if (eh(e)!==e.eventPayloadSha256) return {ok: false, code: "CUSTODY_EVENT_HASH_MISMATCH"}; return {ok: true, code: "OK"};
}
function validateSampleIdentityContinuity(a, b) {
  return a&&b&&a.sampleId===b.sampleId?{ok: true, code: "OK"}:{ok: false, code: "SAMPLE_IDENTITY_MISMATCH"};
}
function validateSealTransition(a, b) {
  if (!a||!b) return {ok: false, code: "SEAL_MISMATCH"}; const opening=b.eventType==="package_opened"||b.eventType==="lab_opened"; return opening&&a.sealId&&b.sealId!==a.sealId?{ok: false, code: "SEAL_MISMATCH"}:{ok: true, code: "OK"};
}
function validateCustodyAppend(a, b, o={}) {
  if (!a||!b) return {ok: false, code: "CUSTODY_PREVIOUS_LINK_MISMATCH"}; if (b.eventSequence===a.eventSequence) return b.eventId===a.eventId&&b.eventPayloadSha256===a.eventPayloadSha256?{ok: true, code: "IDEMPOTENT_NOOP"}:{ok: false, code: "DUPLICATE_SEQUENCE_DIFFERENT_PAYLOAD"}; if (b.eventSequence!==a.eventSequence+1) return {ok: false, code: "CUSTODY_SEQUENCE_GAP"}; if (b.previousEventId!==a.eventId||b.previousEventPayloadSha256!==a.eventPayloadSha256) return {ok: false, code: "CUSTODY_PREVIOUS_LINK_MISMATCH"}; if (eh(b)!==b.eventPayloadSha256) return {ok: false, code: "CUSTODY_EVENT_HASH_MISMATCH"}; let x=validateSampleIdentityContinuity(a, b); if (!x.ok) return x; x=validateSealTransition(a, b); if (!x.ok) return x; if (o.transportEvidenceRequired===true&&(!Array.isArray(b.evidenceRefs)||!b.evidenceRefs.length)) return {ok: false, code: "REQUIRED_TRANSPORT_EVIDENCE_MISSING"}; return {ok: true, code: "OK"};
}
function classifyCustodyIntegrity(es, o={}) {
  if (!Array.isArray(es)||!es.length) return {ok: false, code: "CUSTODY_SEQUENCE_GAP"}; let x=validateCustodyGenesis(es[0]); if (!x.ok) return x; for (let i=1; i<es.length; i++) {
    x=validateCustodyAppend(es[i-1], es[i], o); if (!x.ok) return x;
  } return {ok: true, code: "OK"};
}
module.exports={CUSTODY_CONFLICT_CODES, buildCustodyEvent, validateCustodyGenesis, validateCustodyAppend, validateSealTransition, validateSampleIdentityContinuity, classifyCustodyIntegrity};
