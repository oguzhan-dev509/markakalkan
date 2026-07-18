"use strict";

function issue(code, path, message) {
  return {code, path, message};
}

function isPlainRecord(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function result({errors = [], warnings = [], acceptedFindingCount = 0,
  rejectedFindingCount = 0} = {}) {
  return {valid: errors.length === 0, errors, warnings,
    acceptedFindingCount, rejectedFindingCount};
}

module.exports = {isPlainRecord, issue, result};
