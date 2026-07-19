"use strict";

function validateTaskEnvelope(input) {
  const invalid = () => ({
    valid: false,
    reason: "TASK_ENVELOPE_INVALID",
    snapshot: null,
  });
  try {
    if (input === null || typeof input !== "object" || Array.isArray(input)) {
      return invalid();
    }
    const fields = ["taskId", "tenantId", "brandId", "taskType", "target",
      "priority", "createdAt"];
    const priorities = ["critical", "high", "low", "medium", "normal"];
    const snapshot = Object.create(null);
    for (const field of fields) {
      if (!Object.prototype.hasOwnProperty.call(input, field)) return invalid();
      const descriptor = Object.getOwnPropertyDescriptor(input, field);
      if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor,
          "value") || typeof descriptor.value !== "string") return invalid();
      const cleaned = descriptor.value.trim();
      if (!cleaned) return invalid();
      if (field === "priority") {
        const normalized = cleaned.toLowerCase();
        if (!priorities.includes(normalized)) return invalid();
        snapshot[field] = normalized;
      } else {
        snapshot[field] = cleaned;
      }
    }
    return {
      valid: true,
      reason: "READY_FOR_PLANNING",
      snapshot,
    };
  } catch (_) {
    return invalid();
  }
}

function taskEnvelopeGateSource() {
  return `"use strict";\nconst validateTaskEnvelope = ${validateTaskEnvelope.toString()};`;
}

module.exports = {taskEnvelopeGateSource, validateTaskEnvelope};
