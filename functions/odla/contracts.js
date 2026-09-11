"use strict";
const crypto=require("node:crypto");
const FINDING_CODES=Object.freeze(["SUSPECTED", "UNDER_VERIFICATION", "AUTHENTICITY_CONSISTENT_WITH_REFERENCE", "AUTHENTICITY_INCONSISTENT_WITH_REFERENCE", "QUALITY_NONCONFORMING", "SUBSTANDARD_SUSPECTED", "COUNTERFEIT_CONFIRMED_BY_RIGHTSHOLDER", "FALSIFIED_CONFIRMED_BY_COMPETENT_AUTHORITY", "INCONCLUSIVE", "CLEARED_AFTER_VERIFICATION", "INTEGRITY_CONFLICT"]);
const SAMPLE_ROLES=Object.freeze(["A_PRIMARY_EXAM", "B_PRIMARY_LAB", "C_APPEAL_RESERVE"]);
function canon(v) {
  if (Array.isArray(v)) return v.map(canon); if (!v||typeof v!=="object") return v; const o={}; for (const k of Object.keys(v).sort())o[k]=canon(v[k]); return o;
}
function canonicalJson(v) {
  return JSON.stringify(canon(v));
}
function sha256Hex(v) {
  return crypto.createHash("sha256").update(Buffer.from(String(v), "utf8")).digest("hex");
}
function deriveDeterministicId(domain, parts) {
  if (!domain||!Array.isArray(parts)||!parts.length) throw new TypeError("identity required"); const f=(s)=>`${Buffer.byteLength(String(s), "utf8")}:${String(s)}`; return sha256Hex([f(domain), ...parts.map(f)].join("|"));
}
function req(o, k) {
  if (!o||typeof o!=="object"||Array.isArray(o)||typeof o[k]!=="string"||!o[k]) throw new TypeError(`${k} required`);
}
function validateVerificationCase(o) {
  req(o, "caseId"); req(o, "brandUid"); req(o, "profileCode"); return Object.freeze({...o});
}
function validateSample(o) {
  req(o, "sampleId"); req(o, "caseId"); if (!SAMPLE_ROLES.includes(o.sampleRole)) throw new TypeError("invalid sampleRole"); return Object.freeze({...o});
}
function validateTestRequest(o) {
  for (const k of ["testRequestId", "sampleId", "laboratoryId", "testQuestionCode"])req(o, k); return Object.freeze({...o});
}
function validateTestResult(o) {
  for (const k of ["testResultId", "testRequestId", "sampleId", "laboratoryId", "laboratoryReportId"])req(o, k); if (!/^[a-f0-9]{64}$/u.test(o.reportSha256||"")) throw new TypeError("reportSha256"); if (o.appendOnly!==true) throw new TypeError("appendOnly"); return Object.freeze({...o});
}
function validateFinding(o) {
  req(o, "findingId"); if (!Number.isInteger(o.findingVersion)||o.findingVersion<1) throw new TypeError("findingVersion"); if (!FINDING_CODES.includes(o.findingCode)||o.appendOnly!==true) throw new TypeError("finding"); if (o.findingVersion>1&&!o.supersedesFindingId) throw new TypeError("supersedesFindingId"); return Object.freeze({...o});
}
function validateAppeal(o) {
  req(o, "appealId"); req(o, "challengedFindingId"); return Object.freeze({...o});
}
function validateFundingAuthorization(o) {
  req(o, "fundingAuthorizationId"); if (o.markakalkanEscrowUsed!==false) throw new TypeError("escrow prohibited"); return Object.freeze({...o});
}
function validateReporterReliability(o) {
  req(o, "reporterId"); if (o.automaticPunitiveActionAllowed===true) throw new TypeError("punitive prohibited"); return Object.freeze({...o, automaticPunitiveActionAllowed: false});
}
module.exports={FINDING_CODES, SAMPLE_ROLES, canonicalJson, sha256Hex, deriveDeterministicId, validateVerificationCase, validateSample, validateTestRequest, validateTestResult, validateFinding, validateAppeal, validateFundingAuthorization, validateReporterReliability};
