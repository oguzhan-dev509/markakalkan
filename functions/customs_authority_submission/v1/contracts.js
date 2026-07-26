/* eslint-disable max-len */
const {createHash} = require("node:crypto");

const SUBMISSION_STATUSES = Object.freeze([
  "draft",
  "awaiting_human_review",
  "awaiting_rights_holder_approval",
  "approved_for_package",
  "package_generated",
  "submitted_externally",
  "receipt_recorded",
  "authority_review",
  "additional_information_requested",
  "concluded",
  "withdrawn",
  "rejected",
  "archived",
]);

const SUBMISSION_TYPES = Object.freeze([
  "fsmh_protection_application",
  "customs_smuggling_notification",
  "domestic_organized_counterfeit_notification",
  "emergency_incident_notification",
  "digital_cyber_referral",
  "additional_information_response",
  "other_official_submission",
]);

const TARGET_AUTHORITIES = Object.freeze([
  "customs_enforcement",
  "police_anti_smuggling",
  "emergency_112",
  "cyber_crime",
  "fsmh_program",
  "other_authorized_body",
]);

const CHANNEL_TYPES = Object.freeze([
  "fsmh_portal",
  "official_online_form",
  "electronic_signature",
  "registered_email",
  "physical_delivery",
  "telephone_136",
  "emergency_112",
  "official_correspondence",
  "other",
]);

const EXTERNAL_REFERENCE_TYPES = Object.freeze([
  "none",
  "kep_message_id",
  "portal_transaction_id",
  "physical_delivery_reference",
  "official_correspondence_reference",
  "telephone_reference",
  "other_reference",
]);

const EXTERNAL_SUBMISSION_CONFIRMATION_VERSION =
  "customs-external-submission-confirmation-v1";

const PACKAGE_TYPES = Object.freeze([
  "fsmh_application_package",
  "authority_referral_package",
  "additional_information_package",
]);

const RESPONSE_TYPES = Object.freeze([
  "receipt",
  "acknowledgement",
  "information_request",
  "status_update",
  "decision",
  "closure_notice",
  "rejection_notice",
  "other",
]);

const OUTCOME_CODES = Object.freeze([
  "pending",
  "accepted_for_review",
  "action_taken",
  "temporary_measure_recorded",
  "goods_detained_or_suspended",
  "goods_seizure_reported",
  "no_action",
  "referred_to_other_authority",
  "additional_procedure_required",
  "closed",
  "rejected",
  "other",
]);

const OUTCOME_FINALITY_LEVELS = Object.freeze([
  "informational",
  "preliminary",
  "administrative_final",
  "judicial_final",
  "not_stated",
]);

const FINAL_RESPONSE_TYPES = Object.freeze([
  "decision",
  "closure_notice",
  "rejection_notice",
]);

const OUTCOME_HUMAN_ENTRY_CONFIRMATION_VERSION =
  "customs-authority-outcome-human-entry-v1";

const NON_TERMINAL_OUTCOME_CODES = Object.freeze([
  "accepted_for_review",
  "temporary_measure_recorded",
  "goods_detained_or_suspended",
  "goods_seizure_reported",
  "additional_procedure_required",
]);

const TERMINAL_OUTCOME_MATRIX = Object.freeze({
  decision: Object.freeze({
    outcomeCodes: Object.freeze([
      "action_taken",
      "no_action",
      "referred_to_other_authority",
      "closed",
      "rejected",
      "other",
    ]),
    finalityLevels: Object.freeze([
      "administrative_final",
      "judicial_final",
    ]),
  }),
  closure_notice: Object.freeze({
    outcomeCodes: Object.freeze([
      "closed",
      "no_action",
      "referred_to_other_authority",
      "other",
    ]),
    finalityLevels: Object.freeze([
      "administrative_final",
      "judicial_final",
      "not_stated",
    ]),
  }),
  rejection_notice: Object.freeze({
    outcomeCodes: Object.freeze(["rejected"]),
    finalityLevels: Object.freeze([
      "administrative_final",
      "judicial_final",
      "not_stated",
    ]),
  }),
});

const REDACTION_ACTIONS = Object.freeze([
  "remove",
  "mask",
  "generalize",
  "retain",
]);

const CONTRACT = Object.freeze({
  createRequest: "customs-authority-submission-create-request-v1",
  updateRequest: "customs-authority-submission-update-request-v1",
  transitionRequest: "customs-authority-submission-transition-request-v1",
  packageRequest: "customs-submission-package-generate-request-v1",
  receiptRequest: "customs-submission-receipt-record-request-v1",
  responseRequest: "customs-authority-response-append-request-v1",
  listRequest: "customs-authority-submission-list-request-v1",
  detailRequest: "customs-authority-submission-detail-request-v1",
  externalSubmissionRequest: "customs-external-submission-record-request-v1",
  outcomeRequest: "customs-authority-outcome-record-request-v1",
});

class AuthoritySubmissionError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "AuthoritySubmissionError";
    this.code = code;
  }
}

function objectRequired(value, field = "request") {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new AuthoritySubmissionError("invalid-argument", `${field} object required`);
  }
}

function strict(raw, version, fields) {
  objectRequired(raw);
  const allowed = new Set(["contractVersion", ...fields]);
  const extra = Object.keys(raw).filter((key) => !allowed.has(key));
  if (raw.contractVersion !== version || extra.length) {
    throw new AuthoritySubmissionError("invalid-argument", "request contract invalid");
  }
}

function cleanText(value, field, minimum, maximum, optional = false) {
  if (value == null && optional) return null;
  if (typeof value !== "string") {
    throw new AuthoritySubmissionError("invalid-argument", `${field} invalid`);
  }
  const clean = value.trim();
  const forbidden = [...clean].some((character) => {
    const code = character.charCodeAt(0);
    return code === 127 || (code < 32 && ![9, 10, 13].includes(code));
  });
  if (clean.length < minimum || clean.length > maximum || forbidden) {
    throw new AuthoritySubmissionError("invalid-argument", `${field} invalid`);
  }
  return clean;
}

function enumValue(value, allowed, field, optional = false) {
  if (value == null && optional) return null;
  const clean = cleanText(value, field, 1, 120);
  if (!allowed.includes(clean)) {
    throw new AuthoritySubmissionError("invalid-argument", `${field} unsupported`);
  }
  return clean;
}

function uuid(value) {
  const clean = cleanText(value, "requestId", 36, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(clean)) {
    throw new AuthoritySubmissionError("invalid-argument", "requestId invalid");
  }
  return clean.toLowerCase();
}

function booleanValue(value, field, defaultValue = false) {
  if (value == null) return defaultValue;
  if (typeof value !== "boolean") {
    throw new AuthoritySubmissionError("invalid-argument", `${field} invalid`);
  }
  return value;
}

function iso(value, field, optional = false) {
  if (value == null && optional) return null;
  const clean = cleanText(value, field, 20, 40);
  const date = new Date(clean);
  if (Number.isNaN(date.getTime()) || date.toISOString() !== clean) {
    throw new AuthoritySubmissionError("invalid-argument", `${field} invalid`);
  }
  return clean;
}

function integer(value, field, minimum, maximum, optional = false) {
  if (value == null && optional) return null;
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new AuthoritySubmissionError("invalid-argument", `${field} invalid`);
  }
  return value;
}

function stringArray(value, field, maximumItems = 100, maximumLength = 500, optional = false) {
  if (value == null && optional) return [];
  if (!Array.isArray(value) || value.length > maximumItems) {
    throw new AuthoritySubmissionError("invalid-argument", `${field} invalid`);
  }
  const result = value.map((item, index) => cleanText(item, `${field}[${index}]`, 1, maximumLength));
  if (new Set(result).size !== result.length) {
    throw new AuthoritySubmissionError("invalid-argument", `${field} duplicates`);
  }
  return Object.freeze(result);
}

function sha256Hex(value, field, optional = false) {
  if (value == null && optional) return null;
  const clean = cleanText(value, field, 64, 64).toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(clean)) {
    throw new AuthoritySubmissionError("invalid-argument", `${field} invalid`);
  }
  return clean;
}

function manifestItems(value, field) {
  if (!Array.isArray(value) || value.length > 100) {
    throw new AuthoritySubmissionError("invalid-argument", `${field} invalid`);
  }
  const ids = new Set();
  return Object.freeze(value.map((item, index) => {
    objectRequired(item, `${field}[${index}]`);
    const allowed = new Set(["referenceId", "title", "sha256", "mimeType", "sizeBytes"]);
    if (Object.keys(item).some((key) => !allowed.has(key))) {
      throw new AuthoritySubmissionError("invalid-argument", `${field}[${index}] invalid`);
    }
    const referenceId = cleanText(item.referenceId, `${field}[${index}].referenceId`, 1, 240);
    if (ids.has(referenceId)) {
      throw new AuthoritySubmissionError("invalid-argument", `${field} duplicates`);
    }
    ids.add(referenceId);
    return Object.freeze({
      referenceId,
      title: cleanText(item.title, `${field}[${index}].title`, 1, 300),
      sha256: sha256Hex(item.sha256, `${field}[${index}].sha256`),
      mimeType: cleanText(item.mimeType, `${field}[${index}].mimeType`, 1, 160, true),
      sizeBytes: integer(item.sizeBytes, `${field}[${index}].sizeBytes`, 0, 1000000000, true),
    });
  }));
}

function redactionItems(value) {
  if (!Array.isArray(value) || value.length > 100) {
    throw new AuthoritySubmissionError("invalid-argument", "redactionManifest invalid");
  }
  return Object.freeze(value.map((item, index) => {
    objectRequired(item, `redactionManifest[${index}]`);
    const allowed = new Set(["fieldPath", "action", "reason"]);
    if (Object.keys(item).some((key) => !allowed.has(key))) {
      throw new AuthoritySubmissionError("invalid-argument", `redactionManifest[${index}] invalid`);
    }
    return Object.freeze({
      fieldPath: cleanText(item.fieldPath, `redactionManifest[${index}].fieldPath`, 1, 300),
      action: enumValue(item.action, REDACTION_ACTIONS, `redactionManifest[${index}].action`),
      reason: cleanText(item.reason, `redactionManifest[${index}].reason`, 3, 1000),
    });
  }));
}

function pageSize(value) {
  if (value == null) return 25;
  return integer(value, "pageSize", 1, 100);
}

function pageToken(value) {
  return cleanText(value, "pageToken", 1, 256, true);
}

function commonScope(raw) {
  return {
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128, true),
    canonicalBrandId: cleanText(raw.canonicalBrandId, "canonicalBrandId", 1, 128, true),
  };
}

function assertSource(protectionProfileId, interventionId) {
  if (!protectionProfileId && !interventionId) {
    throw new AuthoritySubmissionError("invalid-argument", "protectionProfileId or interventionId required");
  }
}

function createRequest(raw) {
  strict(raw, CONTRACT.createRequest, [
    "tenantId",
    "canonicalBrandId",
    "submissionType",
    "targetAuthority",
    "targetUnit",
    "channelType",
    "protectionProfileId",
    "interventionId",
    "caseId",
    "legalMatterId",
    "incidentReference",
    "title",
    "authoritySummary",
    "humanReviewReference",
    "rightsHolderApprovalReference",
    "dataMinimizationConfirmed",
    "nonAccusatoryLanguageConfirmed",
    "requestId",
  ]);
  const protectionProfileId = cleanText(raw.protectionProfileId, "protectionProfileId", 1, 128, true);
  const interventionId = cleanText(raw.interventionId, "interventionId", 1, 128, true);
  assertSource(protectionProfileId, interventionId);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    ...commonScope(raw),
    submissionType: enumValue(raw.submissionType, SUBMISSION_TYPES, "submissionType"),
    targetAuthority: enumValue(raw.targetAuthority, TARGET_AUTHORITIES, "targetAuthority"),
    targetUnit: cleanText(raw.targetUnit, "targetUnit", 1, 300, true),
    channelType: enumValue(raw.channelType, CHANNEL_TYPES, "channelType", true),
    protectionProfileId,
    interventionId,
    caseId: cleanText(raw.caseId, "caseId", 1, 128, true),
    legalMatterId: cleanText(raw.legalMatterId, "legalMatterId", 1, 128, true),
    incidentReference: cleanText(raw.incidentReference, "incidentReference", 3, 240),
    title: cleanText(raw.title, "title", 5, 240),
    authoritySummary: cleanText(raw.authoritySummary, "authoritySummary", 20, 5000),
    humanReviewReference: cleanText(raw.humanReviewReference, "humanReviewReference", 1, 500, true),
    rightsHolderApprovalReference: cleanText(raw.rightsHolderApprovalReference, "rightsHolderApprovalReference", 1, 500, true),
    dataMinimizationConfirmed: booleanValue(raw.dataMinimizationConfirmed, "dataMinimizationConfirmed"),
    nonAccusatoryLanguageConfirmed: booleanValue(raw.nonAccusatoryLanguageConfirmed, "nonAccusatoryLanguageConfirmed"),
    requestId: uuid(raw.requestId),
  });
}

function updateRequest(raw) {
  strict(raw, CONTRACT.updateRequest, [
    "submissionId",
    "tenantId",
    "canonicalBrandId",
    "targetUnit",
    "channelType",
    "title",
    "authoritySummary",
    "humanReviewReference",
    "rightsHolderApprovalReference",
    "dataMinimizationConfirmed",
    "nonAccusatoryLanguageConfirmed",
    "requestId",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    submissionId: cleanText(raw.submissionId, "submissionId", 1, 128),
    ...commonScope(raw),
    targetUnit: cleanText(raw.targetUnit, "targetUnit", 1, 300, true),
    channelType: enumValue(raw.channelType, CHANNEL_TYPES, "channelType", true),
    title: cleanText(raw.title, "title", 5, 240),
    authoritySummary: cleanText(raw.authoritySummary, "authoritySummary", 20, 5000),
    humanReviewReference: cleanText(raw.humanReviewReference, "humanReviewReference", 1, 500, true),
    rightsHolderApprovalReference: cleanText(raw.rightsHolderApprovalReference, "rightsHolderApprovalReference", 1, 500, true),
    dataMinimizationConfirmed: booleanValue(raw.dataMinimizationConfirmed, "dataMinimizationConfirmed"),
    nonAccusatoryLanguageConfirmed: booleanValue(raw.nonAccusatoryLanguageConfirmed, "nonAccusatoryLanguageConfirmed"),
    requestId: uuid(raw.requestId),
  });
}

function transitionRequest(raw) {
  strict(raw, CONTRACT.transitionRequest, [
    "submissionId",
    "tenantId",
    "canonicalBrandId",
    "nextStatus",
    "reason",
    "submittedAt",
    "externalSubmissionStatement",
    "requestId",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    submissionId: cleanText(raw.submissionId, "submissionId", 1, 128),
    ...commonScope(raw),
    nextStatus: enumValue(raw.nextStatus, SUBMISSION_STATUSES, "nextStatus"),
    reason: cleanText(raw.reason, "reason", 10, 3000),
    submittedAt: iso(raw.submittedAt, "submittedAt", true),
    externalSubmissionStatement: cleanText(raw.externalSubmissionStatement, "externalSubmissionStatement", 10, 1000, true),
    requestId: uuid(raw.requestId),
  });
}

function externalSubmissionRequest(raw) {
  strict(raw, CONTRACT.externalSubmissionRequest, [
    "submissionId",
    "tenantId",
    "canonicalBrandId",
    "packageId",
    "packageVersion",
    "packageHash",
    "submissionChannel",
    "submittedAt",
    "externalSubmissionConfirmation",
    "externalSubmissionConfirmationVersion",
    "externalSubmissionStatement",
    "externalReferenceType",
    "externalReferenceValue",
    "requestId",
  ]);
  if (raw.externalSubmissionConfirmation !== true) {
    throw new AuthoritySubmissionError(
        "invalid-argument",
        "external submission confirmation required",
    );
  }
  if (raw.externalSubmissionConfirmationVersion !==
      EXTERNAL_SUBMISSION_CONFIRMATION_VERSION) {
    throw new AuthoritySubmissionError(
        "invalid-argument",
        "external submission confirmation version invalid",
    );
  }
  const submissionChannel = enumValue(
      raw.submissionChannel,
      CHANNEL_TYPES,
      "submissionChannel",
  );
  const externalReferenceType = enumValue(
      raw.externalReferenceType,
      EXTERNAL_REFERENCE_TYPES,
      "externalReferenceType",
  );
  const allowedReferenceTypes = {
    fsmh_portal: ["none", "portal_transaction_id"],
    official_online_form: ["none", "portal_transaction_id"],
    electronic_signature: ["none", "portal_transaction_id"],
    registered_email: ["none", "kep_message_id"],
    physical_delivery: ["none", "physical_delivery_reference"],
    telephone_136: ["none", "telephone_reference"],
    emergency_112: ["none", "telephone_reference"],
    official_correspondence: ["none", "official_correspondence_reference"],
    other: ["none", "other_reference"],
  };
  if (!allowedReferenceTypes[submissionChannel].includes(externalReferenceType)) {
    throw new AuthoritySubmissionError(
        "invalid-argument",
        "external reference incompatible with submission channel",
    );
  }
  let externalReferenceValue = null;
  if (externalReferenceType === "none") {
    if (raw.externalReferenceValue != null &&
        (typeof raw.externalReferenceValue !== "string" ||
         raw.externalReferenceValue.trim() !== "")) {
      throw new AuthoritySubmissionError(
          "invalid-argument",
          "externalReferenceValue must be empty",
      );
    }
  } else {
    externalReferenceValue = cleanText(
        raw.externalReferenceValue,
        "externalReferenceValue",
        3,
        300,
    );
  }
  return Object.freeze({
    contractVersion: raw.contractVersion,
    submissionId: cleanText(raw.submissionId, "submissionId", 1, 128),
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128),
    canonicalBrandId: cleanText(
        raw.canonicalBrandId,
        "canonicalBrandId",
        1,
        128,
    ),
    packageId: cleanText(raw.packageId, "packageId", 1, 128),
    packageVersion: integer(raw.packageVersion, "packageVersion", 1, 1000000),
    packageHash: sha256Hex(raw.packageHash, "packageHash"),
    submissionChannel,
    submittedAt: iso(raw.submittedAt, "submittedAt"),
    externalSubmissionConfirmation: true,
    externalSubmissionConfirmationVersion:
      EXTERNAL_SUBMISSION_CONFIRMATION_VERSION,
    externalSubmissionStatement: cleanText(
        raw.externalSubmissionStatement,
        "externalSubmissionStatement",
        20,
        2000,
    ),
    externalReferenceType,
    externalReferenceValue,
    requestId: uuid(raw.requestId),
  });
}

function packageRequest(raw) {
  strict(raw, CONTRACT.packageRequest, [
    "submissionId",
    "tenantId",
    "canonicalBrandId",
    "packageType",
    "coverLetterText",
    "authoritySummary",
    "legalNeutralityStatement",
    "documentManifest",
    "evidenceManifest",
    "redactionManifest",
    "requestId",
  ]);
  const documentManifest = manifestItems(raw.documentManifest, "documentManifest");
  const evidenceManifest = manifestItems(raw.evidenceManifest, "evidenceManifest");
  if (!documentManifest.length && !evidenceManifest.length) {
    throw new AuthoritySubmissionError("invalid-argument", "package manifest required");
  }
  return Object.freeze({
    contractVersion: raw.contractVersion,
    submissionId: cleanText(raw.submissionId, "submissionId", 1, 128),
    ...commonScope(raw),
    packageType: enumValue(raw.packageType, PACKAGE_TYPES, "packageType"),
    coverLetterText: cleanText(raw.coverLetterText, "coverLetterText", 20, 20000),
    authoritySummary: cleanText(raw.authoritySummary, "authoritySummary", 20, 10000),
    legalNeutralityStatement: cleanText(raw.legalNeutralityStatement, "legalNeutralityStatement", 20, 3000),
    documentManifest,
    evidenceManifest,
    redactionManifest: redactionItems(raw.redactionManifest),
    requestId: uuid(raw.requestId),
  });
}

function receiptRequest(raw) {
  strict(raw, CONTRACT.receiptRequest, [
    "submissionId",
    "tenantId",
    "canonicalBrandId",
    "officialReferenceNumber",
    "receivedAt",
    "channelType",
    "receiptDocumentReference",
    "receiptDocumentHash",
    "summary",
    "requestId",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    submissionId: cleanText(raw.submissionId, "submissionId", 1, 128),
    ...commonScope(raw),
    officialReferenceNumber: cleanText(raw.officialReferenceNumber, "officialReferenceNumber", 2, 500),
    receivedAt: iso(raw.receivedAt, "receivedAt"),
    channelType: enumValue(raw.channelType, CHANNEL_TYPES, "channelType"),
    receiptDocumentReference: cleanText(raw.receiptDocumentReference, "receiptDocumentReference", 1, 500, true),
    receiptDocumentHash: sha256Hex(raw.receiptDocumentHash, "receiptDocumentHash", true),
    summary: cleanText(raw.summary, "summary", 10, 3000),
    requestId: uuid(raw.requestId),
  });
}

function responseRequest(raw) {
  strict(raw, CONTRACT.responseRequest, [
    "submissionId",
    "tenantId",
    "canonicalBrandId",
    "responseType",
    "authorityReference",
    "receivedAt",
    "summary",
    "attachmentReferences",
    "attachmentHashes",
    "requestedDueAt",
    "outcomeCode",
    "requestId",
  ]);
  const attachmentReferences = stringArray(raw.attachmentReferences, "attachmentReferences", 100, 500, true);
  const attachmentHashes = stringArray(raw.attachmentHashes, "attachmentHashes", 100, 64, true)
      .map((value, index) => sha256Hex(value, `attachmentHashes[${index}]`));
  if (attachmentReferences.length !== attachmentHashes.length) {
    throw new AuthoritySubmissionError("invalid-argument", "attachment references and hashes mismatch");
  }
  return Object.freeze({
    contractVersion: raw.contractVersion,
    submissionId: cleanText(raw.submissionId, "submissionId", 1, 128),
    ...commonScope(raw),
    responseType: enumValue(raw.responseType, RESPONSE_TYPES, "responseType"),
    authorityReference: cleanText(raw.authorityReference, "authorityReference", 1, 500, true),
    receivedAt: iso(raw.receivedAt, "receivedAt"),
    summary: cleanText(raw.summary, "summary", 10, 5000),
    attachmentReferences: Object.freeze(attachmentReferences),
    attachmentHashes: Object.freeze(attachmentHashes),
    requestedDueAt: iso(raw.requestedDueAt, "requestedDueAt", true),
    outcomeCode: enumValue(raw.outcomeCode, OUTCOME_CODES, "outcomeCode", true),
    requestId: uuid(raw.requestId),
  });
}

function outcomeRequest(raw) {
  strict(raw, CONTRACT.outcomeRequest, [
    "submissionId",
    "tenantId",
    "canonicalBrandId",
    "responseType",
    "outcomeCode",
    "outcomeFinalityLevel",
    "authorityReferenceNumber",
    "officialDocumentDate",
    "receivedAt",
    "authorityNameSnapshot",
    "authorityUnitSnapshot",
    "summary",
    "humanEntryConfirmation",
    "humanEntryConfirmationVersion",
    "previousResponseId",
    "attachmentReferences",
    "attachmentHashes",
    "additionalNotes",
    "requestId",
  ]);
  if (raw.humanEntryConfirmation !== true) {
    throw new AuthoritySubmissionError(
        "invalid-argument",
        "human entry confirmation required",
    );
  }
  if (raw.humanEntryConfirmationVersion !==
      OUTCOME_HUMAN_ENTRY_CONFIRMATION_VERSION) {
    throw new AuthoritySubmissionError(
        "invalid-argument",
        "human entry confirmation version invalid",
    );
  }
  const responseType = enumValue(
      raw.responseType,
      FINAL_RESPONSE_TYPES,
      "responseType",
  );
  const outcomeFinalityLevel = enumValue(
      raw.outcomeFinalityLevel,
      OUTCOME_FINALITY_LEVELS,
      "outcomeFinalityLevel",
  );
  const outcomeCode = enumValue(raw.outcomeCode, [
    "accepted_for_review",
    "action_taken",
    "temporary_measure_recorded",
    "goods_detained_or_suspended",
    "goods_seizure_reported",
    "no_action",
    "referred_to_other_authority",
    "additional_procedure_required",
    "closed",
    "rejected",
    "other",
  ], "outcomeCode");
  if (NON_TERMINAL_OUTCOME_CODES.includes(outcomeCode)) {
    throw new AuthoritySubmissionError(
        "outcome.non_terminal",
        "Bu kurum cevabı dosyayı sonuçlandırmaz. Ara cevap olarak kaydedilmelidir.",
    );
  }
  const terminalRule = TERMINAL_OUTCOME_MATRIX[responseType];
  if (!terminalRule.outcomeCodes.includes(outcomeCode) ||
      !terminalRule.finalityLevels.includes(outcomeFinalityLevel)) {
    throw new AuthoritySubmissionError(
        "outcome.terminal_combination_invalid",
        "responseType, outcomeCode and outcomeFinalityLevel do not form a terminal outcome",
    );
  }
  const attachmentReferences = stringArray(
      raw.attachmentReferences,
      "attachmentReferences",
      100,
      500,
      true,
  );
  const attachmentHashes = stringArray(
      raw.attachmentHashes,
      "attachmentHashes",
      100,
      64,
      true,
  ).map((value, index) =>
    sha256Hex(value, `attachmentHashes[${index}]`),
  );
  if (attachmentReferences.length !== attachmentHashes.length) {
    throw new AuthoritySubmissionError(
        "invalid-argument",
        "attachment references and hashes mismatch",
    );
  }
  return Object.freeze({
    contractVersion: raw.contractVersion,
    submissionId: cleanText(raw.submissionId, "submissionId", 1, 128),
    tenantId: cleanText(raw.tenantId, "tenantId", 1, 128),
    canonicalBrandId: cleanText(
        raw.canonicalBrandId,
        "canonicalBrandId",
        1,
        128,
    ),
    responseType,
    outcomeCode,
    outcomeFinalityLevel,
    authorityReferenceNumber: cleanText(
        raw.authorityReferenceNumber,
        "authorityReferenceNumber",
        2,
        500,
    ),
    officialDocumentDate: iso(
        raw.officialDocumentDate,
        "officialDocumentDate",
    ),
    receivedAt: iso(raw.receivedAt, "receivedAt"),
    authorityNameSnapshot: cleanText(
        raw.authorityNameSnapshot,
        "authorityNameSnapshot",
        2,
        300,
    ),
    authorityUnitSnapshot: cleanText(
        raw.authorityUnitSnapshot,
        "authorityUnitSnapshot",
        1,
        300,
        true,
    ),
    summary: cleanText(raw.summary, "summary", 10, 5000),
    humanEntryConfirmation: true,
    humanEntryConfirmationVersion:
      OUTCOME_HUMAN_ENTRY_CONFIRMATION_VERSION,
    previousResponseId: cleanText(
        raw.previousResponseId,
        "previousResponseId",
        1,
        128,
        true,
    ),
    attachmentReferences: Object.freeze(attachmentReferences),
    attachmentHashes: Object.freeze(attachmentHashes),
    additionalNotes: cleanText(
        raw.additionalNotes,
        "additionalNotes",
        1,
        3000,
        true,
    ),
    requestId: uuid(raw.requestId),
  });
}

function listRequest(raw) {
  strict(raw, CONTRACT.listRequest, [
    "tenantId",
    "canonicalBrandId",
    "status",
    "targetAuthority",
    "pageSize",
    "pageToken",
  ]);
  const status = enumValue(raw.status, SUBMISSION_STATUSES, "status", true);
  const targetAuthority = enumValue(raw.targetAuthority, TARGET_AUTHORITIES, "targetAuthority", true);
  if (status && targetAuthority) {
    throw new AuthoritySubmissionError("invalid-argument", "choose status or targetAuthority filter");
  }
  return Object.freeze({
    contractVersion: raw.contractVersion,
    ...commonScope(raw),
    status,
    targetAuthority,
    pageSize: pageSize(raw.pageSize),
    pageToken: pageToken(raw.pageToken),
  });
}

function detailRequest(raw) {
  strict(raw, CONTRACT.detailRequest, [
    "submissionId",
    "tenantId",
    "canonicalBrandId",
  ]);
  return Object.freeze({
    contractVersion: raw.contractVersion,
    submissionId: cleanText(raw.submissionId, "submissionId", 1, 128),
    ...commonScope(raw),
  });
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(
        Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

function fingerprint(value) {
  return createHash("sha256")
      .update(JSON.stringify(canonicalize(value)), "utf8")
      .digest("hex");
}

module.exports = {
  AuthoritySubmissionError,
  CHANNEL_TYPES,
  CONTRACT,
  EXTERNAL_REFERENCE_TYPES,
  EXTERNAL_SUBMISSION_CONFIRMATION_VERSION,
  FINAL_RESPONSE_TYPES,
  OUTCOME_FINALITY_LEVELS,
  OUTCOME_HUMAN_ENTRY_CONFIRMATION_VERSION,
  NON_TERMINAL_OUTCOME_CODES,
  TERMINAL_OUTCOME_MATRIX,
  OUTCOME_CODES,
  PACKAGE_TYPES,
  REDACTION_ACTIONS,
  RESPONSE_TYPES,
  SUBMISSION_STATUSES,
  SUBMISSION_TYPES,
  TARGET_AUTHORITIES,
  createRequest,
  detailRequest,
  externalSubmissionRequest,
  fingerprint,
  listRequest,
  outcomeRequest,
  packageRequest,
  receiptRequest,
  responseRequest,
  transitionRequest,
  updateRequest,
};
