"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {fixture} = require("./test_helpers");
const {validateSchema, __testing} = require("../validators/schema_engine");

test("schema initialization read failure is fail closed", () => {
  const engine=__testing.createSchemaEngine({readFileSync(){throw new Error("RAW_SECRET_SCHEMA_PATH");}});
  let out; assert.doesNotThrow(()=>{out=engine.validateSchema("candidate_source",{});});
  assert.equal(out.valid,false); assert.equal(out.errors[0].code,"SCHEMA_ENGINE_INITIALIZATION_FAILED");
  assert.equal(out.errors[0].path,""); assert(!JSON.stringify(out).includes("RAW_SECRET_SCHEMA_PATH"));
});

test("failed initialization result is stable and attempted once", () => {
  let attempts=0; const engine=__testing.createSchemaEngine({readFileSync(){attempts++;throw new Error("ONCE_ONLY");}});
  const first=engine.validateSchema("candidate_source",{}),second=engine.validateSchema("candidate_source",{});
  assert.deepEqual(second,first); assert.equal(attempts,1); assert(!JSON.stringify(first).includes("ONCE_ONLY"));
});

test("Ajv constructor and addFormats failures do not escape", () => {
  for(const injected of [{AjvClass:class{constructor(){throw new Error("AJV_RAW");}}},{addFormatsFn(){throw new Error("FORMAT_RAW");}}]){
    const engine=__testing.createSchemaEngine(injected);let out;assert.doesNotThrow(()=>{out=engine.validateSchema("candidate_source",{});});
    assert.equal(out.errors[0].code,"SCHEMA_ENGINE_INITIALIZATION_FAILED");assert(!/AJV_RAW|FORMAT_RAW/.test(JSON.stringify(out)));
  }
});

test("unknown schema remains unsupported even after injected failure", () => {
  const engine=__testing.createSchemaEngine({readFileSync(){throw new Error("unused");}});
  const out=engine.validateSchema("unknown",{});assert.equal(out.errors[0].code,"SCHEMA_NAME_UNSUPPORTED");
});

test("normal schema engine still accepts a valid fixture", () => {
  assert.equal(validateSchema("candidate_source",fixture("no_signal","candidate_sources")[0]).valid,true);
});
