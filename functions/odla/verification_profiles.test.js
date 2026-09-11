"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const p = require("./verification_profiles");
const ov = (pc, c = "TR") => ({
  status: "active",
  countryCode: c,
  productClassCode: pc,
  overrideVersion: 1,
});
const pol = () =>
  p.resolveVerificationPolicy({
    productClassCode: "pharmaceutical",
    countryCode: "TR",
    jurisdictionOverride: ov("pharmaceutical"),
  });
const lab = (id = "L1") => ({
  laboratoryId: id,
  status: "active",
  productClassCodes: ["pharmaceutical"],
  testMethodCodes: ["IDENTITY_AUTHENTICITY_METHOD_FAMILY"],
  scopeCodes: ["scope"],
  chainOfCustodySupported: true,
});
test("14 unique profiles", () => {
  assert.equal(p.BASE_PROFILES_V1.length, 14);
  assert.equal(
      new Set(p.BASE_PROFILES_V1.map((x) => x.profileCode)).size,
      14,
  );
});
test("ADV-003 payer cannot force ineligible lab", () => {
  const q = p.resolveTestQuestion(pol(), "IDENTITY_AUTHENTICITY");
  assert.equal(
      p.evaluateLaboratoryEligibility({
        policyResolution: pol(),
        questionResolution: q,
        methodCode: "IDENTITY_AUTHENTICITY_METHOD_FAMILY",
        laboratory: {...lab(), testMethodCodes: []},
      }).eligible,
      false,
  );
});
test("ADV-005 affiliated/primary lab cannot be appeal lab", () => {
  const q = p.resolveTestQuestion(pol(), "IDENTITY_AUTHENTICITY");
  assert.equal(
      p.evaluateLaboratoryEligibility({
        policyResolution: pol(),
        questionResolution: q,
        methodCode: "IDENTITY_AUTHENTICITY_METHOD_FAMILY",
        laboratory: lab("L1"),
        appealPrimaryLaboratoryId: "L1",
      }).code,
      "APPEAL_LAB_NOT_INDEPENDENT",
  );
});
test("ADV-006 badge alone insufficient", () => {
  const q = p.resolveTestQuestion(pol(), "IDENTITY_AUTHENTICITY");
  assert.equal(
      p.evaluateLaboratoryEligibility({
        policyResolution: pol(),
        questionResolution: q,
        methodCode: "IDENTITY_AUTHENTICITY_METHOD_FAMILY",
        laboratory: {...lab(), scopeCodes: []},
      }).code,
      "ACCREDITATION_SCOPE_MISSING",
  );
});
test("ADV-020 unconfigured sector holds", () =>
  assert.equal(
      p.resolveVerificationPolicy({
        productClassCode: "other_configurable",
        countryCode: "TR",
        jurisdictionOverride: ov("other_configurable"),
      }).code,
      "HOLD_FOR_PROFILE_CONFIGURATION",
  ));
test("ADV-021 unknown jurisdiction holds", () =>
  assert.equal(
      p.resolveVerificationPolicy({
        productClassCode: "pharmaceutical",
        countryCode: "",
      }).code,
      "HOLD_FOR_POLICY_CONFIGURATION",
  ));
test("ADV-022 policy conflict no fallback", () =>
  assert.equal(
      p.resolveVerificationPolicy({
        productClassCode: "pharmaceutical",
        countryCode: "TR",
        jurisdictionOverride: ov("food"),
      }).code,
      "STOP_PROFILE_POLICY_CONFLICT",
  ));
test("ADV-023 historical profile version immutable", () =>
  assert.equal(
      p.assertProfileVersionBinding(
          {profileCode: "PHARMACEUTICAL_V1", profileVersion: 1},
          {profileCode: "PHARMACEUTICAL_V1", profileVersion: 2},
      ).ok,
      false,
  ));
test("ADV-024 question precedes method", () =>
  assert.equal(
      p.resolveTestQuestion(pol(), "").code,
      "TEST_QUESTION_REQUIRED_BEFORE_METHOD",
  ));
