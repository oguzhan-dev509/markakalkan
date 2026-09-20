"use strict";

const {createHash} = require("node:crypto");
const {
  HttpsError,
  onCall,
} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {
  FieldValue,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");

const CALLABLE_NAME = "createDigitalDetectiveTask";
const CALLABLE_OPTIONS = Object.freeze({
  region: "europe-west3",
  enforceAppCheck: true,
  maxInstances: 1,
});

const CLIENT_FIELDS = Object.freeze([
  "taskName",
  "brandName",
  "productName",
  "categoryId",
  "subcategory",
  "violationIds",
  "sources",
  "searchTerms",
  "excludedTerms",
  "countries",
  "cities",
  "minimumPrice",
  "maximumPrice",
  "currency",
  "frequency",
  "riskLevel",
  "startDate",
  "endDate",
  "submissionId",
]);

const CLIENT_FORBIDDEN_FIELDS = Object.freeze([
  "brandUid",
  "ownerUid",
  "ownerEmail",
  "status",
  "resultCount",
  "processedCount",
  "createdAt",
  "updatedAt",
  "taskId",
]);

function fail(code, message, details = undefined) {
  throw new HttpsError(code, message, details);
}

function assertCallableRequest(request) {
  if (!request?.auth?.uid) {
    fail("unauthenticated", "Oturum açmanız gerekir.");
  }
  if (!request?.app?.appId) {
    fail("failed-precondition", "Uygulama doğrulaması gerekir.");
  }
  return request.auth.uid;
}

function plainObject(value, field = "data") {
  if (
    value === null ||
    typeof value !== "object" ||
    Array.isArray(value)
  ) {
    fail("invalid-argument", `${field} nesne olmalıdır.`);
  }
  return value;
}

function rejectUnsupportedFields(data) {
  const keys = Object.keys(data);
  const forbidden = keys.filter((key) =>
    CLIENT_FORBIDDEN_FIELDS.includes(key));
  if (forbidden.length > 0) {
    fail(
        "invalid-argument",
        "Sunucuya ait alanlar istemci tarafından gönderilemez.",
        {unsupported: forbidden.sort()},
    );
  }

  const unsupported = keys.filter((key) => !CLIENT_FIELDS.includes(key));
  if (unsupported.length > 0) {
    fail(
        "invalid-argument",
        "Desteklenmeyen görev alanı gönderildi.",
        {unsupported: unsupported.sort()},
    );
  }
}

function requiredString(value, field, min = 1, max = 512) {
  if (typeof value !== "string") {
    fail("invalid-argument", `${field} metin olmalıdır.`);
  }
  const cleaned = value.trim();
  if (cleaned.length < min || cleaned.length > max) {
    fail("invalid-argument", `${field} uzunluğu geçersiz.`);
  }
  return cleaned;
}

function nullableString(value, field, max = 512) {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") {
    fail("invalid-argument", `${field} metin veya null olmalıdır.`);
  }
  const cleaned = value.trim();
  if (!cleaned) return null;
  if (cleaned.length > max) {
    fail("invalid-argument", `${field} uzunluğu geçersiz.`);
  }
  return cleaned;
}

function stringList(value, field, maxItems = 100, maxItemLength = 300) {
  if (!Array.isArray(value) || value.length > maxItems) {
    fail("invalid-argument", `${field} geçerli bir liste olmalıdır.`);
  }
  return Object.freeze(value.map((item, index) => {
    if (typeof item !== "string") {
      fail(
          "invalid-argument",
          `${field}[${index}] metin olmalıdır.`,
      );
    }
    const cleaned = item.trim();
    if (!cleaned || cleaned.length > maxItemLength) {
      fail(
          "invalid-argument",
          `${field}[${index}] geçersizdir.`,
      );
    }
    return cleaned;
  }));
}

function nullableNumber(value, field) {
  if (value === null || value === undefined) return null;
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < 0
  ) {
    fail("invalid-argument", `${field} geçerli bir sayı olmalıdır.`);
  }
  return value;
}

function isoDate(value, field) {
  const source = requiredString(value, field, 10, 64);
  const parsed = new Date(source);
  if (Number.isNaN(parsed.getTime())) {
    fail("invalid-argument", `${field} geçerli bir tarih olmalıdır.`);
  }
  return parsed;
}

function normalizeCreateTaskInput(raw) {
  const data = plainObject(raw);
  rejectUnsupportedFields(data);

  const startDate = isoDate(data.startDate, "startDate");
  const endDate = isoDate(data.endDate, "endDate");
  if (endDate.getTime() < startDate.getTime()) {
    fail(
        "invalid-argument",
        "endDate startDate değerinden önce olamaz.",
    );
  }

  const minimumPrice = nullableNumber(
      data.minimumPrice,
      "minimumPrice",
  );
  const maximumPrice = nullableNumber(
      data.maximumPrice,
      "maximumPrice",
  );
  if (
    minimumPrice !== null &&
    maximumPrice !== null &&
    maximumPrice < minimumPrice
  ) {
    fail(
        "invalid-argument",
        "maximumPrice minimumPrice değerinden küçük olamaz.",
    );
  }

  return Object.freeze({
    taskName: requiredString(data.taskName, "taskName", 2, 180),
    brandName: requiredString(data.brandName, "brandName", 2, 160),
    productName: requiredString(data.productName, "productName", 2, 180),
    categoryId: requiredString(data.categoryId, "categoryId", 1, 128),
    subcategory: nullableString(data.subcategory, "subcategory", 160),
    violationIds: stringList(data.violationIds, "violationIds"),
    sources: stringList(data.sources, "sources"),
    searchTerms: stringList(data.searchTerms, "searchTerms"),
    excludedTerms: stringList(data.excludedTerms, "excludedTerms"),
    countries: stringList(data.countries, "countries"),
    cities: stringList(data.cities, "cities"),
    minimumPrice,
    maximumPrice,
    currency: requiredString(data.currency, "currency", 1, 16),
    frequency: requiredString(data.frequency, "frequency", 1, 64),
    riskLevel: requiredString(data.riskLevel, "riskLevel", 1, 64),
    startDate,
    endDate,
    submissionId: requiredString(
        data.submissionId,
        "submissionId",
        8,
        256,
    ),
  });
}

function stableInputForFingerprint(input) {
  return Object.freeze({
    taskName: input.taskName,
    brandName: input.brandName,
    productName: input.productName,
    categoryId: input.categoryId,
    subcategory: input.subcategory,
    violationIds: input.violationIds,
    sources: input.sources,
    searchTerms: input.searchTerms,
    excludedTerms: input.excludedTerms,
    countries: input.countries,
    cities: input.cities,
    minimumPrice: input.minimumPrice,
    maximumPrice: input.maximumPrice,
    currency: input.currency,
    frequency: input.frequency,
    riskLevel: input.riskLevel,
    startDate: input.startDate.toISOString(),
    endDate: input.endDate.toISOString(),
  });
}

function sha256(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function payloadFingerprint(input) {
  return sha256(JSON.stringify(stableInputForFingerprint(input)));
}

function receiptId(uid, submissionId) {
  return sha256(`${uid}\n${submissionId}`);
}

function buildTaskDocument({input, uid, ownerEmail}) {
  return Object.freeze({
    taskName: input.taskName,
    brandName: input.brandName,
    productName: input.productName,
    categoryId: input.categoryId,
    subcategory: input.subcategory,
    violationIds: input.violationIds,
    sources: input.sources,
    searchTerms: input.searchTerms,
    excludedTerms: input.excludedTerms,
    countries: input.countries,
    cities: input.cities,
    minimumPrice: input.minimumPrice,
    maximumPrice: input.maximumPrice,
    currency: input.currency,
    frequency: input.frequency,
    riskLevel: input.riskLevel,
    startDate: Timestamp.fromDate(input.startDate),
    endDate: Timestamp.fromDate(input.endDate),
    status: "queued",
    ownerUid: uid,
    ownerEmail,
    resultCount: 0,
    processedCount: 0,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function snapshotData(snapshot) {
  if (!snapshot || snapshot.exists !== true) return null;
  const data = snapshot.data();
  return data && typeof data === "object" ? data : null;
}

function assertBrandScope(brandData, uid) {
  if (!brandData) {
    fail(
        "permission-denied",
        "Yetkili marka kapsamı bulunamadı.",
    );
  }
  if (
    typeof brandData.ownerUid === "string" &&
    brandData.ownerUid.trim() &&
    brandData.ownerUid !== uid
  ) {
    fail(
        "permission-denied",
        "Marka kapsamı bu kullanıcıya ait değil.",
    );
  }
}

async function createTaskAtomic({
  db,
  uid,
  ownerEmail,
  input,
}) {
  const brandRef = db.collection("brands").doc(uid);
  const tasks = brandRef.collection("digitalDetectiveTasks");
  const receipts = brandRef.collection(
      "_digitalDetectiveTaskCreateReceipts",
  );
  const fingerprint = payloadFingerprint(input);
  const createReceiptRef = receipts.doc(
      receiptId(uid, input.submissionId),
  );
  const candidateTaskRef = tasks.doc();

  return db.runTransaction(async (transaction) => {
    const brandSnapshot = await transaction.get(brandRef);
    const brandData = snapshotData(brandSnapshot);
    assertBrandScope(brandData, uid);

    const receiptSnapshot = await transaction.get(createReceiptRef);
    const existingReceipt = snapshotData(receiptSnapshot);

    if (existingReceipt) {
      if (
        existingReceipt.payloadFingerprint !== fingerprint ||
        typeof existingReceipt.taskId !== "string" ||
        !existingReceipt.taskId
      ) {
        fail(
            "already-exists",
            "submissionId farklı bir görev yüküyle daha önce kullanıldı.",
        );
      }
      return Object.freeze({
        taskId: existingReceipt.taskId,
        idempotentReplay: true,
      });
    }

    transaction.create(
        candidateTaskRef,
        buildTaskDocument({input, uid, ownerEmail}),
    );
    transaction.create(createReceiptRef, {
      recordType: "digital_detective_task_create_receipt",
      taskId: candidateTaskRef.id,
      payloadFingerprint: fingerprint,
      ownerUid: uid,
      createdAt: FieldValue.serverTimestamp(),
      immutable: true,
    });

    return Object.freeze({
      taskId: candidateTaskRef.id,
      idempotentReplay: false,
    });
  });
}

function mapError(error) {
  if (error instanceof HttpsError) return error;
  return new HttpsError(
      "internal",
      "Dijital Dedektif görevi oluşturulamadı.",
  );
}

function createDigitalDetectiveTaskHandler({
  db,
  log = logger,
}) {
  if (
    !db ||
    typeof db.collection !== "function" ||
    typeof db.runTransaction !== "function"
  ) {
    throw new TypeError("db must be a Firestore-compatible instance");
  }

  return async (request) => {
    const uid = assertCallableRequest(request);
    try {
      const input = normalizeCreateTaskInput(request.data);
      const tokenEmail = request?.auth?.token?.email;
      const ownerEmail = typeof tokenEmail === "string" ?
        tokenEmail.trim().toLowerCase() || null :
        null;

      const result = await createTaskAtomic({
        db,
        uid,
        ownerEmail,
        input,
      });

      log.info("digital detective task create completed", {
        outcome: "completed",
        idempotentReplay: result.idempotentReplay,
        transactionCommitted: !result.idempotentReplay,
      });
      return result;
    } catch (error) {
      const mapped = mapError(error);
      log.error("digital detective task create failed", {
        outcome: "failed",
        code: mapped.code,
      });
      throw mapped;
    }
  };
}

function buildCreateDigitalDetectiveTask(dependencies = {}) {
  const db = dependencies.db || getFirestore();
  const handler = createDigitalDetectiveTaskHandler({
    db,
    log: dependencies.log || logger,
  });
  const onCallImpl = dependencies.onCallImpl || onCall;
  return onCallImpl(CALLABLE_OPTIONS, handler);
}

module.exports = Object.freeze({
  CALLABLE_NAME,
  CALLABLE_OPTIONS,
  CLIENT_FIELDS,
  CLIENT_FORBIDDEN_FIELDS,
  assertCallableRequest,
  buildCreateDigitalDetectiveTask,
  buildTaskDocument,
  createDigitalDetectiveTaskHandler,
  createTaskAtomic,
  mapError,
  normalizeCreateTaskInput,
  payloadFingerprint,
  receiptId,
});
