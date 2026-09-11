"use strict";
const {canonicalJson}=require("./contracts");
function p(c, pc, r, q) {
  return Object.freeze({contractVersion: "odla-verification-profile-v1", profileCode: c, profileVersion: 1, productClassCode: pc, defaultRiskTier: r, testQuestionPolicies: Object.freeze(q.map((x)=>Object.freeze({testQuestionCode: x, acceptableMethodFamilyCodes: Object.freeze([`${x}_METHOD_FAMILY`])}))), hardcodedUniversalAnalyticalMethod: false});
}
const BASE_PROFILES_V1=Object.freeze([
  p("PHARMACEUTICAL_V1", "pharmaceutical", "CRITICAL", ["IDENTITY_AUTHENTICITY", "QUALITY_CONFORMANCE"]),
  p("COSMETIC_V1", "cosmetic", "HIGH", ["FORMULATION_OR_REFERENCE_CONSISTENCY"]),
  p("FOOD_V1", "food", "HIGH", ["COMPOSITION_OR_ADULTERATION"]),
  p("FOOD_SUPPLEMENT_V1", "food_supplement", "HIGH", ["DECLARED_INGREDIENT_IDENTITY"]),
  p("AUTOMOTIVE_PART_V1", "automotive_part", "CRITICAL", ["MATERIAL_OR_DIMENSIONAL_CONSISTENCY"]),
  p("BATTERY_V1", "battery", "CRITICAL", ["CAPACITY_OR_PERFORMANCE_CONSISTENCY"]),
  p("CHARGER_V1", "charger", "CRITICAL", ["ELECTRICAL_OUTPUT_CONSISTENCY"]),
  p("ELECTRICAL_PRODUCT_V1", "electrical_product", "CRITICAL", ["ELECTRICAL_SAFETY_IF_RISK_TRIGGERED"]),
  p("CHILD_PRODUCT_V1", "child_product", "CRITICAL", ["CHEMICAL_SAFETY_IF_RISK_TRIGGERED"]),
  p("TOY_V1", "toy", "CRITICAL", ["MECHANICAL_OR_PHYSICAL_SAFETY_IF_RISK_TRIGGERED"]),
  p("PERFUME_FRAGRANCE_V1", "perfume_fragrance", "MEDIUM_HIGH", ["REFERENCE_PROFILE_CONSISTENCY"]),
  p("LUXURY_GOODS_V1", "luxury_goods", "MEDIUM", ["MATERIAL_REFERENCE_CONSISTENCY"]),
  p("APPAREL_ACCESSORY_V1", "apparel_accessory", "MEDIUM", ["LABEL_AND_MARKING_CONSISTENCY"]),
  p("OTHER_CONFIGURABLE_V1", "other_configurable", "UNASSIGNED_FAIL_CLOSED", [])]);
function findProfile(pc) {
  return BASE_PROFILES_V1.find((x)=>x.productClassCode===pc)||null;
}
function assertProfileVersionBinding(a, b) {
  return a&&b&&a.profileCode===b.profileCode&&a.profileVersion===b.profileVersion?{ok: true}:{ok: false, code: "RETROACTIVE_PROFILE_REWRITE_DENIED"};
}
function resolveVerificationPolicy(i) {
  const b=findProfile(i&&i.productClassCode); if (!b||b.productClassCode==="other_configurable") return {ok: false, code: "HOLD_FOR_PROFILE_CONFIGURATION"}; if (!i||typeof i.countryCode!=="string"||!/^[A-Z]{2}$/u.test(i.countryCode)) return {ok: false, code: "HOLD_FOR_POLICY_CONFIGURATION"}; const o=i.jurisdictionOverride; if (!o||o.status!=="active"||o.countryCode!==i.countryCode) return {ok: false, code: "HOLD_FOR_POLICY_CONFIGURATION"}; if (o.productClassCode!==b.productClassCode) return {ok: false, code: "STOP_PROFILE_POLICY_CONFLICT"}; return {ok: true, profile: b, jurisdictionOverride: Object.freeze({...o}), policyFingerprint: canonicalJson({profileCode: b.profileCode, profileVersion: b.profileVersion, jurisdictionOverride: o})};
}
function resolveTestQuestion(p, q) {
  if (!p||p.ok!==true) return {ok: false, code: "POLICY_NOT_RESOLVED"}; if (!q) return {ok: false, code: "TEST_QUESTION_REQUIRED_BEFORE_METHOD"}; const x=p.profile.testQuestionPolicies.find((y)=>y.testQuestionCode===q); return x?{ok: true, question: x}:{ok: false, code: "TEST_QUESTION_NOT_CONFIGURED"};
}
function evaluateLaboratoryEligibility(i) {
  const l=i&&i.laboratory, p=i&&i.policyResolution, q=i&&i.questionResolution, m=i&&i.methodCode; if (!p||p.ok!==true) return {eligible: false, code: "POLICY_NOT_RESOLVED"}; if (!q||q.ok!==true) return {eligible: false, code: "TEST_QUESTION_NOT_RESOLVED"}; if (!l||l.status!=="active") return {eligible: false, code: "LAB_NOT_ACTIVE"}; if (!Array.isArray(l.productClassCodes)||!l.productClassCodes.includes(p.profile.productClassCode)) return {eligible: false, code: "PRODUCT_CLASS_SCOPE_MISMATCH"}; if (!Array.isArray(l.testMethodCodes)||!l.testMethodCodes.includes(m)) return {eligible: false, code: "METHOD_SCOPE_MISMATCH"}; if (!Array.isArray(l.scopeCodes)||!l.scopeCodes.length) return {eligible: false, code: "ACCREDITATION_SCOPE_MISSING"}; if (i.requireChainOfCustody===true&&l.chainOfCustodySupported!==true) return {eligible: false, code: "CHAIN_OF_CUSTODY_CAPABILITY_MISSING"}; if (i.appealPrimaryLaboratoryId&&l.laboratoryId===i.appealPrimaryLaboratoryId) return {eligible: false, code: "APPEAL_LAB_NOT_INDEPENDENT"}; return {eligible: true, code: "ELIGIBLE"};
}
function selectEligibleLaboratories(i) {
  return (Array.isArray(i&&i.laboratories)?i.laboratories:[]).filter((l)=>evaluateLaboratoryEligibility({...i, laboratory: l}).eligible).sort((a, b)=>(a.turnaroundHours??1e12)-(b.turnaroundHours??1e12)||(a.costMinor??1e12)-(b.costMinor??1e12));
}
module.exports={BASE_PROFILES_V1, resolveVerificationPolicy, resolveTestQuestion, evaluateLaboratoryEligibility, selectEligibleLaboratories, assertProfileVersionBinding};
