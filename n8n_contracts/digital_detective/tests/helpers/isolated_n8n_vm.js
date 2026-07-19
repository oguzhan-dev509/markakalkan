"use strict";

const vm = require("node:vm");

const clone = (value) => JSON.parse(JSON.stringify(value));
const FORBIDDEN_GLOBALS = ["process", "require", "module", "Buffer",
  "TextEncoder", "TextDecoder", "URL", "URLSearchParams", "fetch",
  "crypto", "items", "$json"];

function runCodeNodeInIsolatedContext(jsCode, inputItems) {
  const original = clone(inputItems), supplied = clone(inputItems);
  const context = vm.createContext({$input: {all: () => clone(supplied)}});
  const source = `(function(){${jsCode}\n})()`;
  let output;
  try {
    output = new vm.Script(source, {filename: "n8n-code-node.js"})
        .runInContext(context, {timeout: 2000});
  } catch (_) {
    throw new Error("ISOLATED_CODE_NODE_EXECUTION_FAILED");
  }
  if (JSON.stringify(inputItems) !== JSON.stringify(original)) {
    throw new Error("ISOLATED_CODE_NODE_INPUT_MUTATED");
  }
  return clone(output);
}

function isolatedGlobalTypes() {
  const context = vm.createContext({$input: {all: () => []}});
  const expression = `Object.fromEntries(${JSON.stringify(FORBIDDEN_GLOBALS)}.map(` +
    "(name) => [name, typeof globalThis[name]]))";
  return clone(new vm.Script(expression).runInContext(context, {timeout: 500}));
}

function runRuntimeExpressionInIsolatedContext(bundle, expression) {
  const context = vm.createContext({});
  const source = `${bundle}\n;JSON.stringify(${expression})`;
  try {
    return JSON.parse(new vm.Script(source, {filename: "n8n-runtime.js"})
        .runInContext(context, {timeout: 2000}));
  } catch (_) {
    throw new Error("ISOLATED_RUNTIME_EXECUTION_FAILED");
  }
}

function runRuntimeWithForeignInput(bundle, input) {
  const foreignRealm = vm.createContext({serialized: JSON.stringify(input)});
  const foreignInput = new vm.Script("JSON.parse(serialized)")
      .runInContext(foreignRealm, {timeout: 500});
  const runtimeRealm = vm.createContext({foreignInput});
  const source = `${bundle}\n;JSON.stringify(` +
    "MarkaKalkanDdtRuntime.runContractPipeline(foreignInput))";
  try {
    return JSON.parse(new vm.Script(source, {filename: "n8n-cross-realm.js"})
        .runInContext(runtimeRealm, {timeout: 2000}));
  } catch (_) {
    throw new Error("ISOLATED_CROSS_REALM_EXECUTION_FAILED");
  }
}

module.exports = {FORBIDDEN_GLOBALS, isolatedGlobalTypes,
  runCodeNodeInIsolatedContext, runRuntimeExpressionInIsolatedContext,
  runRuntimeWithForeignInput};
