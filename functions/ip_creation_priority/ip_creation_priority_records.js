const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

const RECORDS_COLLECTION = "ip_creation_priority_records";
const VERSIONS_COLLECTION = "ip_creation_priority_versions";

const CREATION_TYPES = new Set([
  "invention", "utility_model", "industrial_design", "product_concept",
  "software", "source_code", "algorithm", "literary_work", "screenplay",
  "visual_work", "music_work", "audio_visual_work", "research",
  "education_content", "business_model", "formula", "recipe",
  "creative_idea", "other",
]);

const CONFIDENTIALITY_LEVELS = new Set([
  "private", "selected_people", "professional_access", "public_statement",
]);

const DEVELOPMENT_STAGES = new Set([
  "initial_idea", "concept", "draft", "research", "design", "prototype",
  "testing", "final_work", "registration",
]);

function requiredText(value, fieldName, maxLength) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} metin olmalidir.`);
  }

  const cleaned = value.trim();

  if (cleaned.length === 0 || cleaned.length > maxLength) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} 1-${maxLength} karakter olmalidir.`,
    );
  }

  return cleaned;
}

function optionalText(value, fieldName, maxLength) {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} metin olmalidir.`);
  }

  const cleaned = value.trim();

  if (cleaned.length === 0) {
    return null;
  }

  if (cleaned.length > maxLength) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} en fazla ${maxLength} karakter olabilir.`,
    );
  }

  return cleaned;
}

function requiredId(value, fieldName) {
  const cleaned = requiredText(value, fieldName, 240);

  if (cleaned.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} "/" karakteri iceremez.`,
    );
  }

  return cleaned;
}

function requiredEnum(value, fieldName, allowedValues) {
  if (typeof value !== "string" || !allowedValues.has(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }

  return value;
}

function stringList(value, fieldName, maxItems = 500) {
  if (!Array.isArray(value) || value.length > maxItems) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz liste.`);
  }

  const cleaned = value.map((item) => requiredId(item, fieldName));

  if (new Set(cleaned).size !== cleaned.length) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} tekrar eden deger iceremez.`,
    );
  }

  return cleaned;
}

function optionalDate(value, fieldName, admin) {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }

  return admin.firestore.Timestamp.fromDate(parsed);
}

function plainObject(value, fieldName) {
  if (value === null || value === undefined) {
    return {};
  }

  if (typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${fieldName} nesne olmalidir.`);
  }

  return value;
}

function fileManifest(value) {
  if (!Array.isArray(value) || value.length > 100) {
    throw new HttpsError("invalid-argument", "fileManifest gecersiz liste.");
  }

  return value.map((item) => {
    if (item === null || typeof item !== "object" || Array.isArray(item)) {
      throw new HttpsError(
          "invalid-argument",
          "fileManifest yalniz nesne elemanlari icerebilir.",
      );
    }

    return item;
  });
}

function cleanRecordPayload(data, admin) {
  return {
    title: requiredText(data.title, "title", 300),
    summary: optionalText(data.summary, "summary", 5000),
    creatorName: optionalText(data.creatorName, "creatorName", 300),
    creationType: requiredEnum(
        data.creationType,
        "creationType",
        CREATION_TYPES,
    ),
    confidentialityLevel: requiredEnum(
        data.confidentialityLevel,
        "confidentialityLevel",
        CONFIDENTIALITY_LEVELS,
    ),
    coCreatorIds: stringList(data.coCreatorIds ?? [], "coCreatorIds"),
    authorizedUserIds: stringList(
        data.authorizedUserIds ?? [],
        "authorizedUserIds",
    ),
    tags: stringList(data.tags ?? [], "tags"),
    relatedAssetIds: stringList(
        data.relatedAssetIds ?? [],
        "relatedAssetIds",
    ),
    firstThoughtAt: optionalDate(
        data.firstThoughtAt,
        "firstThoughtAt",
        admin,
    ),
    metadata: plainObject(data.metadata ?? {}, "metadata"),
  };
}

function cleanVersionPayload(data) {
  return {
    title: requiredText(data.versionTitle ?? data.title, "versionTitle", 300),
    summary: optionalText(data.versionSummary, "versionSummary", 5000),
    description: optionalText(data.description, "description", 50000),
    originalElements: optionalText(
        data.originalElements,
        "originalElements",
        30000,
    ),
    problemStatement: optionalText(
        data.problemStatement,
        "problemStatement",
        30000,
    ),
    developmentStage: requiredEnum(
        data.developmentStage,
        "developmentStage",
        DEVELOPMENT_STAGES,
    ),
    fileManifest: fileManifest(data.fileManifest ?? []),
    metadata: plainObject(data.versionMetadata ?? {}, "versionMetadata"),
  };
}

function buildCreateIpCreationPriorityDraft({db, admin}) {
  return onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const uid = request.auth?.uid;

        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Yaratim kaydi olusturmak icin oturum acmalisiniz.",
          );
        }

        const data = request.data ?? {};
        const recordCode = requiredText(data.recordCode, "recordCode", 100);
        const recordCodeNormalized = recordCode.toUpperCase();
        const recordPayload = cleanRecordPayload(data, admin);
        const versionPayload = cleanVersionPayload(data);

        const recordRef = db.collection(RECORDS_COLLECTION).doc();
        const versionRef = db.collection(VERSIONS_COLLECTION).doc();

        const duplicateQuery = db
            .collection(RECORDS_COLLECTION)
            .where("tenantId", "==", uid)
            .where("brandId", "==", uid)
            .where("recordCodeNormalized", "==", recordCodeNormalized)
            .limit(1);

        try {
          await db.runTransaction(async (transaction) => {
            const duplicate = await transaction.get(duplicateQuery);

            if (!duplicate.empty) {
              throw new HttpsError(
                  "already-exists",
                  "Bu yaratim oncelik kayit kodu zaten kullaniliyor.",
              );
            }

            const now = admin.firestore.Timestamp.now();

            transaction.create(recordRef, {
              tenantId: uid,
              brandId: uid,
              recordCode,
              recordCodeNormalized,
              ...recordPayload,
              status: "draft",
              sealStatus: "unsealed",
              currentVersion: 1,
              activeVersionId: versionRef.id,
              evidencePackageIds: [],
              sealedAt: null,
              archivedAt: null,
              archiveReason: null,
              createdAt: now,
              createdBy: uid,
              updatedAt: now,
              updatedBy: null,
            });

            transaction.create(versionRef, {
              tenantId: uid,
              brandId: uid,
              recordId: recordRef.id,
              versionNumber: 1,
              ...versionPayload,
              sealStatus: "unsealed",
              previousVersionId: null,
              previousVersionHash: null,
              contentHash: null,
              hashAlgorithm: "SHA-256",
              sealedAt: null,
              timestampedAt: null,
              timestampAuthority: null,
              createdAt: now,
              createdBy: uid,
            });
          });

          logger.info("IP creation priority draft created", {
            recordId: recordRef.id,
            versionId: versionRef.id,
            tenantId: uid,
          });

          return {
            recordId: recordRef.id,
            versionId: versionRef.id,
          };
        } catch (error) {
          logger.error("IP creation priority draft create failed", {
            tenantId: uid,
            error,
          });

          if (error instanceof HttpsError) {
            throw error;
          }

          throw new HttpsError(
              "internal",
              "Yaratim oncelik taslagi olusturulurken sunucu hatasi olustu.",
          );
        }
      },
  );
}

function buildUpdateIpCreationPriorityDraft({db, admin}) {
  return onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const uid = request.auth?.uid;

        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Yaratim kaydini guncellemek icin oturum acmalisiniz.",
          );
        }

        const data = request.data ?? {};
        const recordId = requiredId(data.recordId, "recordId");
        const versionId = requiredId(data.versionId, "versionId");
        const recordPayload = cleanRecordPayload(data, admin);
        const versionPayload = cleanVersionPayload(data);

        const recordRef = db.collection(RECORDS_COLLECTION).doc(recordId);
        const versionRef = db.collection(VERSIONS_COLLECTION).doc(versionId);

        try {
          await db.runTransaction(async (transaction) => {
            const recordSnapshot = await transaction.get(recordRef);
            const versionSnapshot = await transaction.get(versionRef);
            const record = recordSnapshot.data();
            const version = versionSnapshot.data();

            if (!recordSnapshot.exists || !record) {
              throw new HttpsError(
                  "not-found",
                  "Guncellenecek yaratim oncelik kaydi bulunamadi.",
              );
            }

            if (!versionSnapshot.exists || !version) {
              throw new HttpsError(
                  "not-found",
                  "Guncellenecek yaratim surumu bulunamadi.",
              );
            }

            if (record.tenantId !== uid || record.brandId !== uid) {
              throw new HttpsError(
                  "permission-denied",
                  "Bu yaratim oncelik kaydina erisim yetkiniz yok.",
              );
            }

            if (version.tenantId !== uid || version.brandId !== uid) {
              throw new HttpsError(
                  "permission-denied",
                  "Bu yaratim surumune erisim yetkiniz yok.",
              );
            }

            if (record.status !== "draft" || record.sealStatus !== "unsealed") {
              throw new HttpsError(
                  "failed-precondition",
                  "Yalniz muhurlenmemis taslak kayit guncellenebilir.",
              );
            }

            if (
              record.activeVersionId !== versionId ||
              version.recordId !== recordId ||
              version.versionNumber !== 1 ||
              version.sealStatus !== "unsealed"
            ) {
              throw new HttpsError(
                  "failed-precondition",
                  "Taslak kayit ile aktif surum baglantisi gecersiz.",
              );
            }

            const now = admin.firestore.Timestamp.now();

            transaction.update(recordRef, {
              ...recordPayload,
              updatedAt: now,
              updatedBy: uid,
            });

            transaction.update(versionRef, {
              ...versionPayload,
            });
          });

          logger.info("IP creation priority draft updated", {
            recordId,
            versionId,
            tenantId: uid,
          });

          return {recordId, versionId};
        } catch (error) {
          logger.error("IP creation priority draft update failed", {
            recordId,
            versionId,
            tenantId: uid,
            error,
          });

          if (error instanceof HttpsError) {
            throw error;
          }

          throw new HttpsError(
              "internal",
              "Yaratim oncelik taslagi guncellenirken sunucu hatasi olustu.",
          );
        }
      },
  );
}


function canonicalize(value) {
  if (Array.isArray(value)) {
    return value.map(canonicalize);
  }

  if (value !== null && typeof value === "object") {
    const result = {};

    for (const key of Object.keys(value).sort()) {
      result[key] = canonicalize(value[key]);
    }

    return result;
  }

  return value;
}

function sha256Hex(value) {
  return crypto
      .createHash("sha256")
      .update(JSON.stringify(canonicalize(value)), "utf8")
      .digest("hex");
}

function versionHashPayload({
  recordId,
  versionNumber,
  versionPayload,
  previousVersionId,
  previousVersionHash,
}) {
  return {
    recordId,
    versionNumber,
    title: versionPayload.title,
    summary: versionPayload.summary,
    description: versionPayload.description,
    originalElements: versionPayload.originalElements,
    problemStatement: versionPayload.problemStatement,
    developmentStage: versionPayload.developmentStage,
    fileManifest: versionPayload.fileManifest,
    metadata: versionPayload.metadata,
    previousVersionId,
    previousVersionHash,
    hashAlgorithm: "SHA-256",
  };
}

function buildSealIpCreationPriorityRecord({db, admin}) {
  return onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const uid = request.auth?.uid;

        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Yaratim kaydini muhurlamak icin oturum acmalisiniz.",
          );
        }

        const data = request.data ?? {};
        const recordId = requiredId(data.recordId, "recordId");
        const versionId = requiredId(data.versionId, "versionId");
        const recordRef = db.collection(RECORDS_COLLECTION).doc(recordId);
        const versionRef = db.collection(VERSIONS_COLLECTION).doc(versionId);

        try {
          let contentHash = null;

          await db.runTransaction(async (transaction) => {
            const recordSnapshot = await transaction.get(recordRef);
            const versionSnapshot = await transaction.get(versionRef);
            const record = recordSnapshot.data();
            const version = versionSnapshot.data();

            if (!recordSnapshot.exists || !record) {
              throw new HttpsError(
                  "not-found",
                  "Muhurlenecek yaratim oncelik kaydi bulunamadi.",
              );
            }

            if (!versionSnapshot.exists || !version) {
              throw new HttpsError(
                  "not-found",
                  "Muhurlenecek yaratim surumu bulunamadi.",
              );
            }

            if (
              record.tenantId !== uid ||
              record.brandId !== uid ||
              version.tenantId !== uid ||
              version.brandId !== uid
            ) {
              throw new HttpsError(
                  "permission-denied",
                  "Bu yaratim kaydini muhurlama yetkiniz yok.",
              );
            }

            if (
              record.status !== "draft" ||
              record.sealStatus !== "unsealed" ||
              record.activeVersionId !== versionId ||
              record.currentVersion !== 1 ||
              version.recordId !== recordId ||
              version.versionNumber !== 1 ||
              version.sealStatus !== "unsealed"
            ) {
              throw new HttpsError(
                  "failed-precondition",
                  "Yalniz eslesen muhurlenmemis ilk taslak surum " +
                  "muhurlenebilir.",
              );
            }

            const versionPayload = {
              title: version.title,
              summary: version.summary ?? null,
              description: version.description ?? null,
              originalElements: version.originalElements ?? null,
              problemStatement: version.problemStatement ?? null,
              developmentStage: version.developmentStage,
              fileManifest: version.fileManifest ?? [],
              metadata: version.metadata ?? {},
            };

            contentHash = sha256Hex(versionHashPayload({
              recordId,
              versionNumber: 1,
              versionPayload,
              previousVersionId: null,
              previousVersionHash: null,
            }));

            const now = admin.firestore.Timestamp.now();

            transaction.update(versionRef, {
              sealStatus: "sealed",
              contentHash,
              hashAlgorithm: "SHA-256",
              sealedAt: now,
            });

            transaction.update(recordRef, {
              status: "sealed",
              sealStatus: "sealed",
              sealedAt: now,
              updatedAt: now,
              updatedBy: uid,
            });
          });

          logger.info("IP creation priority record sealed", {
            recordId,
            versionId,
            tenantId: uid,
            contentHash,
          });

          return {recordId, versionId, contentHash};
        } catch (error) {
          logger.error("IP creation priority seal failed", {
            recordId,
            versionId,
            tenantId: uid,
            error,
          });

          if (error instanceof HttpsError) {
            throw error;
          }

          throw new HttpsError(
              "internal",
              "Yaratim oncelik kaydi muhurlenirken sunucu hatasi olustu.",
          );
        }
      },
  );
}

function buildCreateIpCreationPriorityVersion({db, admin}) {
  return onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const uid = request.auth?.uid;

        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Yeni yaratim surumu icin oturum acmalisiniz.",
          );
        }

        const data = request.data ?? {};
        const recordId = requiredId(data.recordId, "recordId");
        const versionPayload = cleanVersionPayload(data);
        const recordRef = db.collection(RECORDS_COLLECTION).doc(recordId);
        const newVersionRef = db.collection(VERSIONS_COLLECTION).doc();

        try {
          let versionNumber = null;
          let contentHash = null;

          await db.runTransaction(async (transaction) => {
            const recordSnapshot = await transaction.get(recordRef);
            const record = recordSnapshot.data();

            if (!recordSnapshot.exists || !record) {
              throw new HttpsError(
                  "not-found",
                  "Yeni surum eklenecek yaratim kaydi bulunamadi.",
              );
            }

            if (record.tenantId !== uid || record.brandId !== uid) {
              throw new HttpsError(
                  "permission-denied",
                  "Bu yaratim kaydina yeni surum ekleme yetkiniz yok.",
              );
            }

            if (
              record.status === "archived" ||
              record.sealStatus === "unsealed" ||
              !Number.isInteger(record.currentVersion) ||
              record.currentVersion < 1
            ) {
              throw new HttpsError(
                  "failed-precondition",
                  "Yalniz muhurlenmis ve aktif kayda yeni surum eklenebilir.",
              );
            }

            const previousVersionId = requiredId(
                record.activeVersionId,
                "activeVersionId",
            );
            const previousVersionRef = db
                .collection(VERSIONS_COLLECTION)
                .doc(previousVersionId);
            const previousVersionSnapshot = await transaction.get(
                previousVersionRef,
            );
            const previousVersion = previousVersionSnapshot.data();

            if (!previousVersionSnapshot.exists || !previousVersion) {
              throw new HttpsError(
                  "failed-precondition",
                  "Aktif onceki yaratim surumu bulunamadi.",
              );
            }

            if (
              previousVersion.tenantId !== uid ||
              previousVersion.brandId !== uid ||
              previousVersion.recordId !== recordId ||
              previousVersion.versionNumber !== record.currentVersion ||
              previousVersion.sealStatus === "unsealed" ||
              typeof previousVersion.contentHash !== "string" ||
              previousVersion.contentHash.length !== 64
            ) {
              throw new HttpsError(
                  "failed-precondition",
                  "Onceki muhurlu surum zinciri gecersiz.",
              );
            }

            versionNumber = record.currentVersion + 1;
            const previousVersionHash = previousVersion.contentHash;

            contentHash = sha256Hex(versionHashPayload({
              recordId,
              versionNumber,
              versionPayload,
              previousVersionId,
              previousVersionHash,
            }));

            const now = admin.firestore.Timestamp.now();

            transaction.create(newVersionRef, {
              tenantId: uid,
              brandId: uid,
              recordId,
              versionNumber,
              ...versionPayload,
              sealStatus: "sealed",
              previousVersionId,
              previousVersionHash,
              contentHash,
              hashAlgorithm: "SHA-256",
              sealedAt: now,
              timestampedAt: null,
              timestampAuthority: null,
              createdAt: now,
              createdBy: uid,
            });

            transaction.update(recordRef, {
              status: "developing",
              sealStatus: "sealed",
              currentVersion: versionNumber,
              activeVersionId: newVersionRef.id,
              updatedAt: now,
              updatedBy: uid,
            });
          });

          logger.info("IP creation priority version created", {
            recordId,
            versionId: newVersionRef.id,
            versionNumber,
            tenantId: uid,
            contentHash,
          });

          return {
            recordId,
            versionId: newVersionRef.id,
            versionNumber,
            contentHash,
          };
        } catch (error) {
          logger.error("IP creation priority version create failed", {
            recordId,
            tenantId: uid,
            error,
          });

          if (error instanceof HttpsError) {
            throw error;
          }

          throw new HttpsError(
              "internal",
              "Yeni yaratim surumu olusturulurken sunucu hatasi olustu.",
          );
        }
      },
  );
}

module.exports = {
  buildCreateIpCreationPriorityDraft,
  buildUpdateIpCreationPriorityDraft,
  buildSealIpCreationPriorityRecord,
  buildCreateIpCreationPriorityVersion,
};
