"use strict";
const {FINDING_CODES}=require("./contracts");
const {evaluateLaboratoryEligibility}=require("./verification_profiles");
const {classifyCustodyIntegrity}=require("./chain_of_custody");
const CASE_STATES=Object.freeze(["opened", "precheck", "awaiting_funding", "purchase_authorized", "sample_in_custody", "verification_in_progress", "awaiting_finding", "appeal_open", "conflict_review", "closed", "integrity_conflict", "cancelled"]);
const TEST_REQUEST_STATES=Object.freeze(["requested", "accepted_by_lab", "sample_in_transit", "sample_received", "testing", "result_received", "completed", "cancelled", "integrity_conflict"]);
const APPEAL_STATES=Object.freeze(["opened", "eligibility_review", "second_lab_requested", "second_lab_in_progress", "adjudication_pending", "resolved", "rejected_ineligible", "integrity_conflict"]);
const CT=new Set(["opened->precheck", "precheck->awaiting_funding", "precheck->awaiting_finding", "awaiting_funding->purchase_authorized", "purchase_authorized->sample_in_custody", "sample_in_custody->verification_in_progress", "verification_in_progress->awaiting_finding", "awaiting_finding->closed", "awaiting_finding->appeal_open", "closed->appeal_open", "appeal_open->verification_in_progress", "appeal_open->conflict_review", "conflict_review->awaiting_finding"]);
const TT=new Set(["requested->accepted_by_lab", "accepted_by_lab->sample_in_transit", "sample_in_transit->sample_received", "sample_received->testing", "testing->result_received", "result_received->completed"]);
function evaluateCaseTransition(a, b, c={}) {
  if (!CASE_STATES.includes(a)||!CASE_STATES.includes(b)) return {allowed: false, code: "UNKNOWN_STATE"}; if (!CT.has(`${a}->${b}`)) return {allowed: false, code: "DENY_FAIL_CLOSED"}; if (b==="closed"&&(c.openMaterialAppeal||c.unresolvedIntegrityConflict)) return {allowed: false, code: "FINALITY_BLOCKED"}; return {allowed: true, code: "ALLOWED"};
}
function evaluateTestRequestTransition(a, b, c={}) {
  if (!TEST_REQUEST_STATES.includes(a)||!TEST_REQUEST_STATES.includes(b)) return {allowed: false, code: "UNKNOWN_STATE"}; if (!TT.has(`${a}->${b}`)) return {allowed: false, code: "DENY_FAIL_CLOSED"}; if (b==="accepted_by_lab"&&c.laboratoryInput) {
    const e=evaluateLaboratoryEligibility(c.laboratoryInput); if (!e.eligible) return {allowed: false, code: e.code};
  } return {allowed: true, code: "ALLOWED"};
}
function evaluateAppealEligibility(i={}) {
  return new Set(["sample_identity_dispute", "custody_integrity_dispute", "laboratory_method_or_scope_dispute", "new_material_provenance_evidence", "conflicting_rightsholder_authentication", "request_second_independent_lab"]).has(i.groundCode)?{eligible: true, code: "APPEAL_ELIGIBLE"}:{eligible: false, code: "APPEAL_NOT_MATERIAL"};
}
function evaluateSecondLabIndependence(a, b) {
  return a&&b&&a!==b?{allowed: true, code: "INDEPENDENT"}:{allowed: false, code: "APPEAL_LAB_NOT_INDEPENDENT"};
}
function deriveFinding(i={}) {
  if (i.integrityConflict) return {findingCode: "INTEGRITY_CONFLICT"}; if (i.qualityNonconforming) return {findingCode: "QUALITY_NONCONFORMING"}; if (i.authorityConfirmed===true) return {findingCode: "FALSIFIED_CONFIRMED_BY_COMPETENT_AUTHORITY"}; if (i.rightsholderConfirmed===true) return {findingCode: "COUNTERFEIT_CONFIRMED_BY_RIGHTSHOLDER"}; if (i.authenticityConsistent===true) return {findingCode: "AUTHENTICITY_CONSISTENT_WITH_REFERENCE"}; if (i.authenticityInconsistent===true) return {findingCode: "AUTHENTICITY_INCONSISTENT_WITH_REFERENCE"}; return {findingCode: "INCONCLUSIVE"};
}
function evaluateFinality(i={}) {
  if (!FINDING_CODES.includes(i.findingCode)) return {allowed: false, code: "INVALID_FINDING"}; if (i.openMaterialAppeal===true) return {allowed: false, code: "OPEN_MATERIAL_APPEAL"}; if (i.unresolvedIntegrityConflict===true) return {allowed: false, code: "INTEGRITY_CONFLICT"}; if (i.missingRequiredEvidence===true) return {allowed: false, code: "MISSING_REQUIRED_EVIDENCE"}; return new Set(["COUNTERFEIT_CONFIRMED_BY_RIGHTSHOLDER", "FALSIFIED_CONFIRMED_BY_COMPETENT_AUTHORITY", "CLEARED_AFTER_VERIFICATION"]).has(i.findingCode)?{allowed: true, code: "FINALITY_ALLOWED"}:{allowed: false, code: "NONFINAL_FINDING"};
}
function deriveMarketplaceRecommendation(i={}) {
  if (i.healthSafetyUrgency===true) return {recommendationCode: i.lotSpecific?"TEMPORARY_LOT_HOLD":"EXPEDITED_HEALTH_SAFETY_HOLD", counterfeitFinality: false}; if (i.permanentFinalityAllowed===true) return {recommendationCode: "PERMANENT_ENFORCEMENT_RECOMMENDED", counterfeitFinality: true}; return {recommendationCode: "MONITOR", counterfeitFinality: false};
}
function evaluateFundingGuard(i={}) {
  if (i.markakalkanEscrowUsed!==false) return {allowed: false, code: "ESCROW_V1_PROHIBITED"}; if (i.state!=="active") return {allowed: false, code: "FUNDING_NOT_ACTIVE"}; if (i.expired===true) return {allowed: false, code: "FUNDING_EXPIRED"}; if (i.covered===false) return {allowed: false, code: "COST_NOT_COVERED"}; return {allowed: true, code: "FUNDING_VALID"};
}
function evaluateReporterReliabilityEffect(i={}) {
  const n=Number.isFinite(i.reportCount)?i.reportCount:0, c=Number.isFinite(i.clearedCount)?i.clearedCount:0, h=i.sameTargetConcentrationBand==="HIGH"; return n>=3&&(c/Math.max(n, 1)>.5||h)?{effect: "ABUSE_REVIEW_AND_HIGHER_EVIDENCE_THRESHOLD", punitiveActionAllowed: false, finalityAllowed: false}:{effect: "STANDARD_TRIAGE", punitiveActionAllowed: false, finalityAllowed: false};
}
function evaluateCustodyForFinality(es, o={}) {
  const x=classifyCustodyIntegrity(es, o); return x.ok?{allowed: true, code: "CUSTODY_VALID"}:{allowed: false, code: x.code};
}
module.exports={CASE_STATES, TEST_REQUEST_STATES, APPEAL_STATES, evaluateCaseTransition, evaluateTestRequestTransition, evaluateAppealEligibility, evaluateSecondLabIndependence, deriveFinding, evaluateFinality, deriveMarketplaceRecommendation, evaluateFundingGuard, evaluateReporterReliabilityEffect, evaluateCustodyForFinality};
