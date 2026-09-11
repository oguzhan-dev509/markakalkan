"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const a = require("./adjudication");
test("ADV-001 malicious reports cannot create finality", () =>
  assert.equal(
      a.evaluateReporterReliabilityEffect({
        reportCount: 10,
        clearedCount: 8,
        sameTargetConcentrationBand: "HIGH",
      }).finalityAllowed,
      false,
  ));
test("ADV-002 sybil/concentration stays abuse triage", () =>
  assert.equal(
      a.evaluateReporterReliabilityEffect({
        reportCount: 5,
        clearedCount: 1,
        sameTargetConcentrationBand: "HIGH",
      }).punitiveActionAllowed,
      false,
  ));
test("ADV-007 seller sample alone cannot clear", () =>
  assert.equal(
      a.evaluateFinality({
        findingCode: "AUTHENTICITY_CONSISTENT_WITH_REFERENCE",
      }).allowed,
      false,
  ));
test("ADV-014 open appeal blocks finality", () =>
  assert.equal(
      a.evaluateFinality({
        findingCode: "COUNTERFEIT_CONFIRMED_BY_RIGHTSHOLDER",
        openMaterialAppeal: true,
      }).code,
      "OPEN_MATERIAL_APPEAL",
  ));
test("ADV-015 same lab appeal denied", () =>
  assert.equal(a.evaluateSecondLabIndependence("L1", "L1").allowed, false));
test("ADV-016 conflicting labs use conflict review path", () =>
  assert.equal(
      a.evaluateCaseTransition("appeal_open", "conflict_review", {}).allowed,
      true,
  ));
test("ADV-017 quality failure not counterfeit", () =>
  assert.equal(
      a.deriveFinding({qualityNonconforming: true}).findingCode,
      "QUALITY_NONCONFORMING",
  ));
test("ADV-018 rightsholder is not authority", () =>
  assert.equal(
      a.deriveFinding({rightsholderConfirmed: true}).findingCode,
      "COUNTERFEIT_CONFIRMED_BY_RIGHTSHOLDER",
  ));
test("ADV-019 safety hold not counterfeit finality", () =>
  assert.equal(
      a.deriveMarketplaceRecommendation({healthSafetyUrgency: true})
          .counterfeitFinality,
      false,
  ));
test("ADV-027 closed case no direct backward move", () =>
  assert.equal(
      a.evaluateCaseTransition("closed", "verification_in_progress", {}).code,
      "DENY_FAIL_CLOSED",
  ));
test("ADV-028 expired funding blocks paid test", () =>
  assert.equal(
      a.evaluateFundingGuard({
        markakalkanEscrowUsed: false,
        state: "active",
        expired: true,
        covered: true,
      }).allowed,
      false,
  ));
