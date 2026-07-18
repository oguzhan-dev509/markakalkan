"use strict";

const fs = require("node:fs");
const path = require("node:path");
const Ajv2020 = require("ajv/dist/2020");
const addFormats = require("ajv-formats");
const {issue, result} = require("./validator_result");

const SCHEMAS = [
  "candidate_source",
  "acquisition_result",
  "structured_evidence",
  "digital_field_scanner_result",
];
function safePath(error) {
  const base = String(error.instancePath || "")
      .replace(/^\//, "").replace(/\//g, ".");
  if (error.keyword === "required") {
    return [base, error.params && error.params.missingProperty]
        .filter(Boolean).join(".");
  }
  if (error.keyword === "additionalProperties") {
    return [base, error.params && error.params.additionalProperty]
        .filter(Boolean).join(".");
  }
  return base || "$";
}

function safeMessage(keyword) {
  const messages = {
    required: "Zorunlu alan eksik.",
    type: "Alan tipi geçersiz.",
    additionalProperties: "Beklenmeyen alan.",
    format: "Alan biçimi geçersiz.",
    pattern: "Alan biçimi geçersiz.",
    const: "Alan değeri geçersiz.",
    enum: "Alan değeri izin verilen değerlerden biri değil.",
    minLength: "Alan çok kısa.",
    maxLength: "Alan çok uzun.",
    minItems: "Dizi yeterli öğe içermiyor.",
    maxItems: "Dizi çok fazla öğe içeriyor.",
    uniqueItems: "Dizi yinelenen öğe içeriyor.",
    minimum: "Sayısal değer alt sınırın altında.",
    maximum: "Sayısal değer üst sınırın üzerinde.",
    oneOf: "Alan sözleşmeyle eşleşmiyor.",
    if: "Koşullu sözleşme sağlanmıyor.",
  };
  return messages[keyword] || "Schema doğrulaması başarısız.";
}

function createSchemaEngine(injected = {}) {
  const dependencies = {
    AjvClass: Ajv2020,
    addFormatsFn: addFormats,
    readFileSync: fs.readFileSync,
    schemaDirectory: path.resolve(__dirname, "..", "schemas"),
    ...injected,
  };
  const state = {initialized: false, initializationError: null,
    validators: null};

  function initialize() {
    if (state.initialized) return;
    state.initialized = true;
    try {
      const ajv = new dependencies.AjvClass({allErrors: true, strict: true});
      dependencies.addFormatsFn(ajv);
      for (const name of SCHEMAS) {
        const location = path.join(dependencies.schemaDirectory,
            `${name}.schema.json`);
        const schema = JSON.parse(dependencies.readFileSync(location, "utf8"));
        ajv.addSchema(schema);
      }
      const compiled = new Map();
      for (const name of SCHEMAS) {
        const validate = ajv.getSchema(`${name}.schema.json`);
        if (typeof validate !== "function") throw new Error("schema unavailable");
        compiled.set(name, validate);
      }
      state.validators = compiled;
    } catch (_) {
      state.initializationError = true;
      state.validators = null;
    }
  }

  function validateSchema(schemaName, value) {
    if (!SCHEMAS.includes(schemaName)) {
      return result({errors: [issue("SCHEMA_NAME_UNSUPPORTED", "$",
        "Schema adı desteklenmiyor.")]});
    }
    initialize();
    if (state.initializationError || !state.validators) {
      return result({errors: [issue("SCHEMA_ENGINE_INITIALIZATION_FAILED", "",
        "Şema doğrulama altyapısı başlatılamadı.")]});
    }
    const validate = state.validators.get(schemaName);
    try {
      const valid = validate(value);
      if (valid) return result();
      const errors = (validate.errors || []).map((error) => issue(
          `SCHEMA_${String(error.keyword).toUpperCase()}`,
          safePath(error), safeMessage(error.keyword)));
      return result({errors});
    } catch (_) {
      return result({errors: [issue("SCHEMA_VALIDATION_EXCEPTION", "$",
        "Schema doğrulaması güvenli biçimde tamamlanamadı.")]});
    }
  }

  return {validateSchema};
}

const defaultEngine = createSchemaEngine();
module.exports = {validateSchema: defaultEngine.validateSchema,
  __testing: {createSchemaEngine}};
