const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  COLLECTION,
  EVENTS,
  SCHEMA_VERSION,
  normalizeSponsorPayload,
  isPubliclyVisible,
  publicProjection,
} = require("./sponsor_content");

test("server-only collection contract is stable", () => {
  assert.equal(COLLECTION, "platform_sponsor_content");
  assert.equal(EVENTS, "platform_sponsor_content_events");
  assert.equal(SCHEMA_VERSION, "sponsor-content-v1");
});

test("normalizes a valid sponsor payload", () => {
  const result = normalizeSponsorPayload({
    displayName: "Örnek Teknoloji",
    categoryCode: "technology",
    categoryLabel: "",
    websiteUrl: "https://example.com",
    logoUrl: "https://cdn.example.com/logo.png",
    logoAlt: "Örnek Teknoloji logosu",
    displayOrder: 10,
    status: "active",
    startsAt: "2026-08-01T00:00:00Z",
    endsAt: "2027-08-01T00:00:00Z",
  });

  assert.equal(result.displayName, "Örnek Teknoloji");
  assert.equal(result.categoryLabel, "Teknoloji");
  assert.equal(result.displayOrder, 10);
  assert.equal(result.status, "active");
});

test("rejects non-HTTPS logo URLs", () => {
  assert.throws(
      () => normalizeSponsorPayload({
        displayName: "Örnek",
        categoryCode: "technology",
        displayOrder: 1,
        status: "active",
        logoUrl: "http://example.com/logo.png",
      }),
      (error) => error instanceof HttpsError &&
        error.code === "invalid-argument",
  );
});

test("rejects invalid schedule ordering", () => {
  assert.throws(
      () => normalizeSponsorPayload({
        displayName: "Örnek",
        categoryCode: "corporate",
        displayOrder: 1,
        status: "active",
        startsAt: "2027-01-01T00:00:00Z",
        endsAt: "2026-01-01T00:00:00Z",
      }),
      (error) => error instanceof HttpsError &&
        error.code === "invalid-argument",
  );
});

test("public visibility honors active status and schedule", () => {
  const now = Date.parse("2026-08-09T12:00:00Z");
  assert.equal(
      isPubliclyVisible({
        status: "active",
        startsAt: "2026-08-01T00:00:00Z",
        endsAt: "2026-09-01T00:00:00Z",
      }, now),
      true,
  );
  assert.equal(isPubliclyVisible({status: "draft"}, now), false);
  assert.equal(
      isPubliclyVisible({
        status: "active",
        startsAt: "2026-09-01T00:00:00Z",
      }, now),
      false,
  );
});

test("public projection excludes internal actor fields", () => {
  const projection = publicProjection("s1", {
    displayName: "Örnek",
    categoryCode: "technology",
    categoryLabel: "Teknoloji",
    websiteUrl: "https://example.com/",
    logoUrl: "https://example.com/logo.png",
    logoAlt: "Logo",
    displayOrder: 2,
    createdByUid: "secret-uid",
    updatedByEmail: "secret@example.com",
  });

  assert.equal(projection.id, "s1");
  assert.equal(projection.displayName, "Örnek");
  assert.equal("createdByUid" in projection, false);
  assert.equal("updatedByEmail" in projection, false);
});
