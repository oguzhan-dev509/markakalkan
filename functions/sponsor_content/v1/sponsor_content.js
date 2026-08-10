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
        const requestedId = cleanId(request.data?.id);
        const ref = requestedId ?
          db.collection(COLLECTION).doc(requestedId) :
          db.collection(COLLECTION).doc();
        const eventRef = db.collection(EVENTS).doc();
        const now = admin.firestore.Timestamp.now();

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
            logoUrl: normalized.logoUrl,
            logoAlt: normalized.logoAlt,
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
            actorUid: actor.uid,
            actorEmail: actor.email,
            occurredAt: now,
          });
        });

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
  buildListPublicSponsorContent,
  buildListSponsorContentForAdmin,
  buildUpsertSponsorContentForAdmin,
  normalizeSponsorPayload,
  isPubliclyVisible,
  publicProjection,
};
