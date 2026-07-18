"use strict";
const fs = require("node:fs");
const path = require("node:path");
const Ajv2020 = require("ajv/dist/2020");
const addFormats = require("ajv-formats");

const root = path.resolve(__dirname, "..");
function json(relative) { return JSON.parse(fs.readFileSync(path.join(root, relative), "utf8")); }
function validators() {
  const ajv = new Ajv2020({allErrors: true, strict: true}); addFormats(ajv);
  for (const name of ["candidate_source", "acquisition_result", "structured_evidence", "digital_field_scanner_result"]) ajv.addSchema(json(`schemas/${name}.schema.json`));
  return {ajv, candidate: ajv.getSchema("candidate_source.schema.json"), acquisition: ajv.getSchema("acquisition_result.schema.json"), evidence: ajv.getSchema("structured_evidence.schema.json"), scanner: ajv.getSchema("digital_field_scanner_result.schema.json")};
}
function fixture(scenario, name) { return json(`fixtures/${scenario}/${name}.json`); }
function clone(value) { return JSON.parse(JSON.stringify(value)); }
module.exports = {clone, fixture, json, validators};
