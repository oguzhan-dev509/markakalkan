/* eslint-disable max-len */
const assert = require("node:assert/strict");
const test = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  READ_OPTIONS,
  WRITE_OPTIONS,
  createHandler,
  mapError,
} = require("./callable");

const silentLog = {
  info() {},
  error() {},
};

test("callable options keep reads bounded and writes App Check protected", () => {
  assert.equal(READ_OPTIONS.region, "europe-west3");
  assert.equal(READ_OPTIONS.enforceAppCheck, false);
  assert.equal(READ_OPTIONS.maxInstances, 3);
  assert.equal(WRITE_OPTIONS.region, "europe-west3");
  assert.equal(WRITE_OPTIONS.enforceAppCheck, true);
  assert.equal(WRITE_OPTIONS.maxInstances, 1);
});

test("callable auth and App Check gates fail closed before service access", async () => {
  const readHandler = createHandler("listSubmissions", {
    db: {},
    appCheck: false,
    log: silentLog,
  });
  await assert.rejects(
      () => readHandler({data: {}}),
      (error) => error instanceof HttpsError && error.code === "unauthenticated",
  );

  const writeHandler = createHandler("createSubmission", {
    db: {},
    appCheck: true,
    log: silentLog,
  });
  await assert.rejects(
      () => writeHandler({auth: {uid: "user-1"}, data: {}}),
      (error) => error instanceof HttpsError && error.code === "failed-precondition",
  );

  const externalSubmissionHandler = createHandler("recordExternalSubmission", {
    db: {},
    appCheck: true,
    log: silentLog,
  });
  await assert.rejects(
      () => externalSubmissionHandler({auth: {uid: "user-1"}, data: {}}),
      (error) => error instanceof HttpsError && error.code === "failed-precondition",
  );

  const outcomeHandler = createHandler("recordOutcome", {
    db: {},
    appCheck: true,
    log: silentLog,
  });
  await assert.rejects(
      () => outcomeHandler({auth: {uid: "user-1"}, data: {}}),
      (error) => error instanceof HttpsError && error.code === "failed-precondition",
  );
});

test("callable error mapping preserves legal and operational boundaries", () => {
  const permission = mapError({code: "authorization.denied"});
  assert.equal(permission.code, "permission-denied");

  const source = mapError({code: "source.precondition_failed"});
  assert.equal(source.code, "failed-precondition");

  const duplicate = mapError({code: "idempotency.conflict"});
  assert.equal(duplicate.code, "already-exists");

  const nonTerminal = mapError({code: "outcome.non_terminal"});
  assert.equal(nonTerminal.code, "failed-precondition");
  assert.match(nonTerminal.message, /Ara cevap/);

  const invalidTerminal = mapError({
    code: "outcome.terminal_combination_invalid",
  });
  assert.equal(invalidTerminal.code, "failed-precondition");

  const unknown = mapError({code: "unknown"});
  assert.equal(unknown.code, "invalid-argument");

  const existing = new HttpsError("not-found", "already mapped");
  assert.equal(mapError(existing), existing);
});
