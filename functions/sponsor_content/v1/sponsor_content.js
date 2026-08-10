const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  ROLES,
  requirePlatformRole,
} = require("../../common/platform_admin");

const COLLECTION = "platform_sponsor_content";
const EVENTS = "platform_sponsor_content_events";
const SCHEMA_VERSION = "sponsor-content-v1";

const STATUSES = new Set([
  "draft",
  "active",
  "inactive",
  "archived",
]);

const CATEGORY_CODES = new Set([
  "technology",
  "legal_ip",
  "ecommerce",
  "telecom",
  "logistics",
  "corporate",
  "other",
]);

const CATEGORY_LABELS = Object.freeze({
  technology: "Teknoloji",
  legal_ip: "Hukuk ve IP",
  ecommerce: "E-ticaret",
  telecom: "Telekom",
  logistics: "Lojistik",
  corporate: "Kurumsal",
  other: "Diğer",
});

function cleanText(value, fieldName, maxLength, required = false) {
  if (value === null || value === undefined) {
    if (required) {
      throw new HttpsError(
          "invalid-argument",
          `${fieldName} zorunludur.`,
      );
    }
    return "";
  }
  if (typeof value !== "string") {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} metin olmalidir.`,
    );
  }
  const cleaned = value.trim();
  if ((required && !cleaned) || cleaned.length > maxLength) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} gecersiz.`,
    );
  }
  return cleaned;
}

function optionalHttpsUrl(value, fieldName) {
  const cleaned = cleanText(value, fieldName, 2048, false);
  if (!cleaned) return "";
  let parsed;
  try {
    parsed = new URL(cleaned);
  } catch (_) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} gecersiz.`,
    );
  }
  if (parsed.protocol !== "https:") {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} HTTPS olmalidir.`,
    );
  }
  return parsed.toString();
}

function cleanId(value) {
  const cleaned = cleanText(value, "id", 160, false);
  if (!cleaned) return "";
  if (!/^[A-Za-z0-9_-]+$/.test(cleaned)) {
    throw new HttpsError("invalid-argument", "id gecersiz.");
  }
  return cleaned;
}

function cleanInteger(value, fieldName, min, max) {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} gecersiz.`,
    );
  }
  return value;
}

function optionalDateIso(value, fieldName) {
  const cleaned = cleanText(value, fieldName, 80, false);
  if (!cleaned) return "";
  const parsed = new Date(cleaned);
  if (!Number.isFinite(parsed.getTime())) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} gecersiz.`,
    );
  }
  return parsed.toISOString();
}

function normalizeSponsorPayload(raw) {
  const source = raw && typeof raw === "object" ? raw : {};
  const displayName = cleanText(
      source.displayName,
      "displayName",
      160,
      true,
  );
  const categoryCode = cleanText(
      source.categoryCode,
      "categoryCode",
      40,
      true,
  );
  if (!CATEGORY_CODES.has(categoryCode)) {
    throw new HttpsError(
        "invalid-argument",
        "categoryCode gecersiz.",
    );
  }

  const categoryLabel = cleanText(
      source.categoryLabel,
      "categoryLabel",
      120,
      false,
  ) || CATEGORY_LABELS[categoryCode];

  const status = cleanText(source.status, "status", 40, true);
  if (!STATUSES.has(status)) {
    throw new HttpsError("invalid-argument", "status gecersiz.");
  }

  const startsAtIso = optionalDateIso(source.startsAt, "startsAt");
  const endsAtIso = optionalDateIso(source.endsAt, "endsAt");
  if (
    startsAtIso &&
    endsAtIso &&
    new Date(endsAtIso).getTime() <= new Date(startsAtIso).getTime()
  ) {
    throw new HttpsError(
        "invalid-argument",
        "endsAt startsAt degerinden sonra olmalidir.",
    );
  }

  return {
    displayName,
    categoryCode,
    categoryLabel,
    websiteUrl: optionalHttpsUrl(source.websiteUrl, "websiteUrl"),
    logoUrl: optionalHttpsUrl(source.logoUrl, "logoUrl"),
    logoAlt: cleanText(source.logoAlt, "logoAlt", 240, false),
    displayOrder: cleanInteger(
        source.displayOrder,
        "displayOrder",
        0,
        9999,
    ),
    status,
    startsAtIso,
    endsAtIso,
  };
}

function instantMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") {
    const millis = new Date(value).getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  return null;
}

function instantIso(value) {
  const millis = instantMillis(value);
  return millis === null ? "" : new Date(millis).toISOString();
}

function isPubliclyVisible(data, nowMillis) {
  if (!data || data.status !== "active") return false;
  const starts = instantMillis(data.startsAt);
  const ends = instantMillis(data.endsAt);
  if (starts !== null && nowMillis < starts) return false;
  if (ends !== null && nowMillis >= ends) return false;
  return true;
}

function publicProjection(id, data) {
  return {
    id,
    schemaVersion: SCHEMA_VERSION,
    displayName: cleanText(data.displayName, "displayName", 160, true),
    categoryCode: cleanText(
        data.categoryCode,
        "categoryCode",
        40,
        true,
    ),
    categoryLabel: cleanText(
        data.categoryLabel,
        "categoryLabel",
        120,
        true,
    ),
    websiteUrl: cleanText(data.websiteUrl, "websiteUrl", 2048, false),
    logoUrl: cleanText(data.logoUrl, "logoUrl", 2048, false),
    logoAlt: cleanText(data.logoAlt, "logoAlt", 240, false),
    displayOrder: Number.isInteger(data.displayOrder) ?
      data.displayOrder :
      9999,
  };
}

function adminProjection(id, data) {
  return {
    ...publicProjection(id, data),
    status: cleanText(data.status, "status", 40, true),
    startsAt: instantIso(data.startsAt),
    endsAt: instantIso(data.endsAt),
    createdAt: instantIso(data.createdAt),
    updatedAt: instantIso(data.updatedAt),
    createdByUid: cleanText(
        data.createdByUid,
        "createdByUid",
        240,
        false,
    ),
    updatedByUid: cleanText(
        data.updatedByUid,
        "updatedByUid",
        240,
        false,
    ),
  };
}

function buildListPublicSponsorContent({db}) {
  return onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async () => {
        const snapshot = await db.collection(COLLECTION)
            .orderBy("displayOrder", "asc")
            .limit(100)
            .get();
        const nowMillis = Date.now();
        const entries = snapshot.docs
            .filter((doc) => isPubliclyVisible(doc.data(), nowMillis))
            .map((doc) => publicProjection(doc.id, doc.data()));
        return {
          schemaVersion: SCHEMA_VERSION,
          entries,
        };
      },
  );
}

function buildListSponsorContentForAdmin({db}) {
  return onCall(
      {
        enforceAppCheck: true,
        maxInstances: 3,
      },
      async (request) => {
        await requirePlatformRole(
            request,
            db,
            ROLES.superAdmin,
        );
        const snapshot = await db.collection(COLLECTION)
            .orderBy("displayOrder", "asc")
            .limit(200)
            .get();
        return {
          schemaVersion: SCHEMA_VERSION,
          entries: snapshot.docs.map(
              (doc) => adminProjection(doc.id, doc.data()),
          ),
        };
      },
  );
}

const SPONSOR_LOGO_MAX_BYTES = 2 * 1024 * 1024;
const SPONSOR_LOGO_MIME_EXTENSIONS = Object.freeze({
  "image/png": ["png"],
  "image/jpeg": ["jpg", "jpeg"],
  "image/webp": ["webp"],
});

function normalizeSponsorLogoMutation(raw) {
  const source = raw && typeof raw === "object" ? raw : {};

  if (
    source.removeLogo !== undefined &&
    typeof source.removeLogo !== "boolean"
  ) {
    throw new HttpsError("invalid-argument", "removeLogo boolean olmalidir.");
  }

  const removeLogo = source.removeLogo === true;
  const rawUpload = source.logoUpload;

  if (rawUpload === null || rawUpload === undefined) {
    return {removeLogo, upload: null};
  }
  if (removeLogo) {
    throw new HttpsError(
        "invalid-argument",
        "Logo yukleme ve kaldirma ayni anda istenemez.",
    );
  }
  if (typeof rawUpload !== "object" || Array.isArray(rawUpload)) {
    throw new HttpsError("invalid-argument", "logoUpload gecersiz.");
  }

  const fileName = cleanText(
      rawUpload.fileName,
      "logoUpload.fileName",
      160,
      true,
  );
  if (fileName.includes("/") || fileName.includes("\\")) {
    throw new HttpsError(
        "invalid-argument",
        "logoUpload.fileName gecersiz.",
    );
  }

  const mimeType = cleanText(
      rawUpload.mimeType,
      "logoUpload.mimeType",
      80,
      true,
  ).toLowerCase();
  const extensions = SPONSOR_LOGO_MIME_EXTENSIONS[mimeType];
  if (!extensions) {
    throw new HttpsError(
        "invalid-argument",
        "Logo tipi PNG, JPEG veya WebP olmalidir.",
    );
  }

  const lowerName = fileName.toLowerCase();
  if (!extensions.some((extension) => lowerName.endsWith(`.${extension}`))) {
    throw new HttpsError(
        "invalid-argument",
        "Logo dosya uzantisi MIME tipiyle uyusmuyor.",
    );
  }

  if (
    !Number.isSafeInteger(rawUpload.sizeBytes) ||
    rawUpload.sizeBytes < 1 ||
    rawUpload.sizeBytes > SPONSOR_LOGO_MAX_BYTES
  ) {
    throw new HttpsError(
        "invalid-argument",
        "Logo boyutu 2 MiB sinirini asamaz.",
    );
  }

  if (typeof rawUpload.base64Data !== "string") {
    throw new HttpsError(
        "invalid-argument",
        "logoUpload.base64Data gecersiz.",
    );
  }

  const base64Data = rawUpload.base64Data.trim();
  const maxBase64Length = Math.ceil(SPONSOR_LOGO_MAX_BYTES / 3) * 4;
  if (
    !base64Data ||
    base64Data.length > maxBase64Length ||
    base64Data.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(base64Data)
  ) {
    throw new HttpsError(
        "invalid-argument",
        "logoUpload.base64Data gecersiz.",
    );
  }

  const bytes = Buffer.from(base64Data, "base64");
  if (
    bytes.length !== rawUpload.sizeBytes ||
    bytes.length > SPONSOR_LOGO_MAX_BYTES ||
    bytes.toString("base64") !== base64Data
  ) {
    throw new HttpsError(
        "invalid-argument",
        "Logo veri boyutu dogrulanamadi.",
    );
  }

  const magicMatches =
    (mimeType === "image/png" &&
      bytes.length >= 8 &&
      bytes.subarray(0, 8).equals(
          Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      )) ||
    (mimeType === "image/jpeg" &&
      bytes.length >= 3 &&
      bytes[0] === 0xFF &&
      bytes[1] === 0xD8 &&
      bytes[2] === 0xFF) ||
    (mimeType === "image/webp" &&
      bytes.length >= 12 &&
      bytes.subarray(0, 4).toString("ascii") === "RIFF" &&
      bytes.subarray(8, 12).toString("ascii") === "WEBP");

  if (!magicMatches) {
    throw new HttpsError(
        "invalid-argument",
        "Logo dosya imzasi MIME tipiyle uyusmuyor.",
    );
  }

  return {
    removeLogo: false,
    upload: {
      fileName,
      mimeType,
      bytes,
    },
  };
}

function sponsorLogoDownloadUrl(bucketName, objectPath, token) {
  const encodedObject = encodeURIComponent(objectPath);
  const encodedToken = encodeURIComponent(token);
  return "https://firebasestorage.googleapis.com/v0/b/" +
    `${bucketName}/o/${encodedObject}?alt=media&token=${encodedToken}`;
}

async function deleteSponsorLogoBestEffort(bucket, objectPath) {
  if (!objectPath) return;
  try {
    await bucket.file(objectPath).delete({ignoreNotFound: true});
  } catch {
    // Cleanup failure must not roll back an already committed sponsor record.
  }
}

async function uploadSponsorLogo({admin, sponsorId, actorUid, upload}) {
  const crypto = require("node:crypto");
  const extension = SPONSOR_LOGO_MIME_EXTENSIONS[upload.mimeType][0];
  const objectPath =
    `platform/sponsors/${sponsorId}/logo/` +
    `${crypto.randomUUID()}.${extension}`;
  const downloadToken = crypto.randomUUID();
  const sha256 = crypto.createHash("sha256")
      .update(upload.bytes)
      .digest("hex");

  const bucket = admin.storage().bucket();
  const file = bucket.file(objectPath);

  await file.save(upload.bytes, {
    resumable: false,
    metadata: {
      contentType: upload.mimeType,
      cacheControl: "public,max-age=3600",
      metadata: {
        firebaseStorageDownloadTokens: downloadToken,
        sponsorId,
        sha256,
        uploadedByUid: actorUid,
        originalFileName: upload.fileName,
      },
    },
  });

  return {
    bucket,
    objectPath,
    logoUrl: sponsorLogoDownloadUrl(
        bucket.name,
        objectPath,
        downloadToken,
    ),
    sha256,
    mimeType: upload.mimeType,
    originalFileName: upload.fileName,
  };
}

function buildUpsertSponsorContentForAdmin({db, admin}) {
  return onCall(
      {
        enforceAppCheck: true,
        maxInstances: 1,
      },
      async (request) => {
        const actor = await requirePlatformRole(
            request,
            db,
            ROLES.superAdmin,
        );
        const normalized = normalizeSponsorPayload(request.data);
        const logoMutation = normalizeSponsorLogoMutation(request.data);

        if (logoMutation.upload && normalized.logoUrl) {
          throw new HttpsError(
              "invalid-argument",
              "Logo dosyasi ile harici logoUrl ayni anda kullanilamaz.",
          );
        }
        if (logoMutation.removeLogo && normalized.logoUrl) {
          throw new HttpsError(
              "invalid-argument",
              "Logo kaldirilirken logoUrl bos olmalidir.",
          );
        }

        const requestedId = cleanId(request.data?.id);
        const ref = requestedId ?
          db.collection(COLLECTION).doc(requestedId) :
          db.collection(COLLECTION).doc();
        const eventRef = db.collection(EVENTS).doc();
        const now = admin.firestore.Timestamp.now();

        let uploaded = null;
        if (logoMutation.upload) {
          uploaded = await uploadSponsorLogo({
            admin,
            sponsorId: ref.id,
            actorUid: actor.uid,
            upload: logoMutation.upload,
          });
        }

        let previousStoragePath = "";
        let nextStoragePath = "";

        try {
          await db.runTransaction(async (transaction) => {
            const snapshot = await transaction.get(ref);
            const current = snapshot.exists ? snapshot.data() || {} : {};

            if (
              current.status === "archived" &&
              normalized.status !== "archived"
            ) {
              throw new HttpsError(
                  "failed-precondition",
                  "Arsivlenmis sponsor kaydi yeniden acilamaz.",
              );
            }

            previousStoragePath = cleanText(
                current.logoStoragePath,
                "logoStoragePath",
                1024,
                false,
            );

            let logoUrl = normalized.logoUrl;
            let logoStoragePath = "";
            let logoSha256 = "";
            let logoMimeType = "";
            let logoOriginalFileName = "";

            if (uploaded) {
              logoUrl = uploaded.logoUrl;
              logoStoragePath = uploaded.objectPath;
              logoSha256 = uploaded.sha256;
              logoMimeType = uploaded.mimeType;
              logoOriginalFileName = uploaded.originalFileName;
            } else if (logoMutation.removeLogo || !normalized.logoUrl) {
              logoUrl = "";
            } else if (
              normalized.logoUrl ===
              cleanText(current.logoUrl, "current.logoUrl", 2048, false)
            ) {
              logoStoragePath = previousStoragePath;
              logoSha256 = cleanText(
                  current.logoSha256,
                  "logoSha256",
                  128,
                  false,
              );
              logoMimeType = cleanText(
                  current.logoMimeType,
                  "logoMimeType",
                  80,
                  false,
              );
              logoOriginalFileName = cleanText(
                  current.logoOriginalFileName,
                  "logoOriginalFileName",
                  160,
                  false,
              );
            }

            nextStoragePath = logoStoragePath;

            const startsAt = normalized.startsAtIso ?
              admin.firestore.Timestamp.fromDate(
                  new Date(normalized.startsAtIso),
              ) :
              null;
            const endsAt = normalized.endsAtIso ?
              admin.firestore.Timestamp.fromDate(
                  new Date(normalized.endsAtIso),
              ) :
              null;

            const record = {
              schemaVersion: SCHEMA_VERSION,
              displayName: normalized.displayName,
              categoryCode: normalized.categoryCode,
              categoryLabel: normalized.categoryLabel,
              websiteUrl: normalized.websiteUrl,
              logoUrl,
              logoAlt: normalized.logoAlt,
              logoStoragePath,
              logoSha256,
              logoMimeType,
              logoOriginalFileName,
              displayOrder: normalized.displayOrder,
              status: normalized.status,
              startsAt,
              endsAt,
              createdAt: snapshot.exists ? current.createdAt || now : now,
              createdByUid: snapshot.exists ?
                current.createdByUid || actor.uid :
                actor.uid,
              createdByEmail: snapshot.exists ?
                current.createdByEmail || actor.email :
                actor.email,
              updatedAt: now,
              updatedByUid: actor.uid,
              updatedByEmail: actor.email,
            };

            transaction.set(ref, record, {merge: false});
            transaction.set(eventRef, {
              schemaVersion: "sponsor-content-event-v1",
              sponsorId: ref.id,
              eventType: snapshot.exists ? "updated" : "created",
              status: normalized.status,
              displayOrder: normalized.displayOrder,
              logoOperation: uploaded ?
                "uploaded" :
                (logoMutation.removeLogo ? "removed" : "preserved_or_url"),
              actorUid: actor.uid,
              actorEmail: actor.email,
              occurredAt: now,
            });
          });
        } catch (error) {
          if (uploaded) {
            await deleteSponsorLogoBestEffort(
                uploaded.bucket,
                uploaded.objectPath,
            );
          }
          throw error;
        }

        if (previousStoragePath && previousStoragePath !== nextStoragePath) {
          const bucket = uploaded?.bucket || admin.storage().bucket();
          await deleteSponsorLogoBestEffort(bucket, previousStoragePath);
        }

        return {
          schemaVersion: SCHEMA_VERSION,
          sponsorId: ref.id,
        };
      },
  );
}

module.exports = {
  COLLECTION,
  EVENTS,
  SCHEMA_VERSION,
  SPONSOR_LOGO_MAX_BYTES,
  buildListPublicSponsorContent,
  buildListSponsorContentForAdmin,
  buildUpsertSponsorContentForAdmin,
  normalizeSponsorPayload,
  normalizeSponsorLogoMutation,
  isPubliclyVisible,
  publicProjection,
};
