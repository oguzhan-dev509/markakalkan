const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

const CONTROL_TYPES = new Set([
  "identity_verification",
  "authorization_review",
  "facility_inspection",
  "production_security",
  "capacity_consistency",
  "raw_material_traceability",
  "packaging_and_label_security",
  "shipment_security",
  "destruction_verification",
  "subcontractor_review",
  "document_and_certificate_review",
  "incident_follow_up",
  "custom",
]);

const SCOPES = new Set([
  "partner",
  "facility",
  "partner_and_facility",
]);

const RISK_LEVELS = new Set([
  "low",
  "medium",
  "high",
  "critical",
]);

const CONTROL_STATUSES = new Set([
  "draft",
  "planned",
  "in_progress",
  "overdue",
  "cancelled",
]);

const CONTROL_RESULTS = new Set([
  "not_evaluated",
  "passed",
  "passed_with_observation",
  "failed",
  "critical_failure",
  "not_applicable",
]);

function requiredText(value, fieldName, maxLength) {
  if (typeof value !== "string") {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} metin olmalidir.`,
    );
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
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} metin olmalidir.`,
    );
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
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} gecersiz.`,
    );
  }

  return value;
}

function requiredDate(value, fieldName, admin) {
  if (typeof value !== "string") {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} gecersiz.`,
    );
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} gecersiz.`,
    );
  }

  return admin.firestore.Timestamp.fromDate(parsed);
}

function optionalDate(value, fieldName, admin) {
  if (value === null || value === undefined) {
    return null;
  }

  return requiredDate(value, fieldName, admin);
}

function stringList(value, fieldName) {
  if (!Array.isArray(value)) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} liste olmalidir.`,
    );
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

function plainObject(value, fieldName) {
  if (
    value === null ||
    typeof value !== "object" ||
    Array.isArray(value)
  ) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} nesne olmalidir.`,
    );
  }

  return value;
}

function deterministicControlId(tenantId, normalizedCode) {
  const digest = crypto
      .createHash("sha256")
      .update(`${tenantId}\n${normalizedCode}`, "utf8")
      .digest("hex")
      .slice(0, 40);

  return `spc_${digest}`;
}

function validateTargetShape(scope, partnerId, facilityId) {
  if (scope === "partner" && (!partnerId || facilityId)) {
    throw new HttpsError(
        "invalid-argument",
        "Partner kapsaminda yalniz partner hedefi secilmelidir.",
    );
  }

  if (scope === "facility" && (!facilityId || partnerId)) {
    throw new HttpsError(
        "invalid-argument",
        "Tesis kapsaminda yalniz tesis hedefi secilmelidir.",
    );
  }

  if (scope === "partner_and_facility" && (!partnerId || !facilityId)) {
    throw new HttpsError(
        "invalid-argument",
        "Partner ve tesis hedefleri birlikte secilmelidir.",
    );
  }
}

function buildCreateSupplyProtectionControl({db, admin}) {
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
              "Koruma kontrolu olusturmak icin oturum acmalisiniz.",
          );
        }

        const data = request.data ?? {};
        const controlCode = requiredText(
            data.controlCode,
            "Kontrol kodu",
            100,
        );
        const normalizedCode = controlCode.toUpperCase();
        const title = requiredText(data.title, "Kontrol adi", 200);
        const controlType = requiredEnum(
            data.controlType,
            "Kontrol turu",
            CONTROL_TYPES,
        );
        const scope = requiredEnum(data.scope, "Kontrol kapsami", SCOPES);
        const riskLevel = requiredEnum(
            data.riskLevel,
            "Risk seviyesi",
            RISK_LEVELS,
        );
        const partnerId = data.partnerId == null ?
          null :
          requiredId(data.partnerId, "Partner kimligi");
        const facilityId = data.facilityId == null ?
          null :
          requiredId(data.facilityId, "Tesis kimligi");
        const description = optionalText(
            data.description,
            "Aciklama",
            5000,
        );
        const assignedToName = optionalText(
            data.assignedToName,
            "Atanan kisi",
            300,
        );
        const notes = optionalText(data.notes, "Notlar", 5000);
        const plannedAt = requiredDate(
            data.plannedAt,
            "Planlanan tarih",
            admin,
        );

        validateTargetShape(scope, partnerId, facilityId);

        const controlId = deterministicControlId(uid, normalizedCode);
        const controlRef = db
            .collection("supply_security_protection_controls")
            .doc(controlId);
        const existingQuery = db
            .collection("supply_security_protection_controls")
            .where("tenantId", "==", uid)
            .where("brandId", "==", uid)
            .where("controlCodeNormalized", "==", normalizedCode)
            .limit(1);

        try {
          const existingSnapshot = await existingQuery.get();

          if (!existingSnapshot.empty) {
            throw new HttpsError(
                "already-exists",
                "Ayni marka altinda bu kontrol kodu zaten kullaniliyor.",
            );
          }

          await db.runTransaction(async (transaction) => {
            const reads = [];
            let partnerRef = null;
            let facilityRef = null;

            if (partnerId) {
              partnerRef = db
                  .collection("supply_security_partners")
                  .doc(partnerId);
              reads.push(transaction.get(partnerRef));
            }

            if (facilityId) {
              facilityRef = db
                  .collection("supply_security_facilities")
                  .doc(facilityId);
              reads.push(transaction.get(facilityRef));
            }

            reads.push(transaction.get(controlRef));

            const snapshots = await Promise.all(reads);
            let snapshotIndex = 0;
            let partnerSnapshot = null;
            let facilitySnapshot = null;

            if (partnerRef) {
              partnerSnapshot = snapshots[snapshotIndex];
              snapshotIndex += 1;
            }

            if (facilityRef) {
              facilitySnapshot = snapshots[snapshotIndex];
              snapshotIndex += 1;
            }

            const controlSnapshot = snapshots[snapshotIndex];

            if (controlSnapshot.exists) {
              throw new HttpsError(
                  "already-exists",
                  "Ayni marka altinda bu kontrol kodu zaten kullaniliyor.",
              );
            }

            if (partnerSnapshot) {
              const partner = partnerSnapshot.data();

              if (!partnerSnapshot.exists || !partner) {
                throw new HttpsError(
                    "failed-precondition",
                    "Kontrole baglanacak partner bulunamadi.",
                );
              }

              if (partner.tenantId !== uid || partner.brandId !== uid) {
                throw new HttpsError(
                    "permission-denied",
                    "Partner bu marka hesabina ait degil.",
                );
              }

              if (partner.status === "archived") {
                throw new HttpsError(
                    "failed-precondition",
                    "Arsivlenmis partner koruma kontrolune baglanamaz.",
                );
              }
            }

            if (facilitySnapshot) {
              const facility = facilitySnapshot.data();

              if (!facilitySnapshot.exists || !facility) {
                throw new HttpsError(
                    "failed-precondition",
                    "Kontrole baglanacak tesis bulunamadi.",
                );
              }

              if (facility.tenantId !== uid || facility.brandId !== uid) {
                throw new HttpsError(
                    "permission-denied",
                    "Tesis bu marka hesabina ait degil.",
                );
              }

              if (facility.status === "archived") {
                throw new HttpsError(
                    "failed-precondition",
                    "Arsivlenmis tesis koruma kontrolune baglanamaz.",
                );
              }

              if (partnerId && facility.partnerId !== partnerId) {
                throw new HttpsError(
                    "failed-precondition",
                    "Secilen tesis belirtilen partnere bagli degil.",
                );
              }
            }

            const now = admin.firestore.Timestamp.now();

            transaction.create(controlRef, {
              tenantId: uid,
              brandId: uid,
              controlCode,
              controlCodeNormalized: normalizedCode,
              title,
              controlType,
              scope,
              status: "planned",
              result: "not_evaluated",
              riskLevel,
              partnerId,
              facilityId,
              description,
              assignedToId: null,
              assignedToName,
              plannedAt,
              startedAt: null,
              completedAt: null,
              nextControlAt: null,
              findings: null,
              evidenceDocumentIds: [],
              relatedProductIds: [],
              correctiveAction: null,
              correctiveActionOwnerId: null,
              correctiveActionOwnerName: null,
              correctiveActionDueAt: null,
              correctiveActionCompletedAt: null,
              notes,
              archiveReason: null,
              archivedAt: null,
              metadata: {},
              createdAt: now,
              createdBy: uid,
              updatedAt: now,
              updatedBy: uid,
            });
          });

          logger.info("Supply protection control created", {
            controlId,
            tenantId: uid,
            controlCodeNormalized: normalizedCode,
            scope,
          });

          return {controlId};
        } catch (error) {
          logger.error("Supply protection control creation failed", {
            tenantId: uid,
            controlCodeNormalized: normalizedCode,
            error,
          });

          if (error instanceof HttpsError) {
            throw error;
          }

          throw new HttpsError(
              "internal",
              "Koruma kontrolu olusturulurken sunucu hatasi olustu.",
          );
        }
      },
  );
}

function buildUpdateSupplyProtectionControl({db, admin}) {
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
              "Koruma kontrolunu guncellemek icin oturum acmalisiniz.",
          );
        }

        const data = request.data ?? {};
        const controlId = requiredId(data.controlId, "Kontrol kimligi");
        const title = requiredText(data.title, "Kontrol adi", 200);
        const controlType = requiredEnum(
            data.controlType,
            "Kontrol turu",
            CONTROL_TYPES,
        );
        const scope = requiredEnum(data.scope, "Kontrol kapsami", SCOPES);
        const status = requiredEnum(
            data.status,
            "Kontrol durumu",
            CONTROL_STATUSES,
        );
        const result = requiredEnum(
            data.result,
            "Kontrol sonucu",
            CONTROL_RESULTS,
        );
        const riskLevel = requiredEnum(
            data.riskLevel,
            "Risk seviyesi",
            RISK_LEVELS,
        );

        const partnerId = data.partnerId == null ?
          null :
          requiredId(data.partnerId, "Partner kimligi");
        const facilityId = data.facilityId == null ?
          null :
          requiredId(data.facilityId, "Tesis kimligi");

        validateTargetShape(scope, partnerId, facilityId);

        const description = optionalText(
            data.description,
            "Aciklama",
            5000,
        );
        const assignedToId = data.assignedToId == null ?
          null :
          requiredId(data.assignedToId, "Atanan kisi kimligi");
        const assignedToName = optionalText(
            data.assignedToName,
            "Atanan kisi",
            300,
        );
        const findings = optionalText(data.findings, "Bulgular", 10000);
        const correctiveAction = optionalText(
            data.correctiveAction,
            "Duzeltici faaliyet",
            10000,
        );
        const correctiveActionOwnerId =
          data.correctiveActionOwnerId == null ?
            null :
            requiredId(
                data.correctiveActionOwnerId,
                "Duzeltici faaliyet sorumlusu kimligi",
            );
        const correctiveActionOwnerName = optionalText(
            data.correctiveActionOwnerName,
            "Duzeltici faaliyet sorumlusu",
            300,
        );
        const notes = optionalText(data.notes, "Notlar", 5000);

        const evidenceDocumentIds = stringList(
            data.evidenceDocumentIds ?? [],
            "Kanit belge kimlikleri",
        );
        const relatedProductIds = stringList(
            data.relatedProductIds ?? [],
            "Iliskili urun kimlikleri",
        );
        const metadata = plainObject(data.metadata ?? {}, "Metadata");

        const plannedAt = optionalDate(
            data.plannedAt,
            "Planlanan tarih",
            admin,
        );
        const startedAt = optionalDate(
            data.startedAt,
            "Baslangic tarihi",
            admin,
        );
        const nextControlAt = optionalDate(
            data.nextControlAt,
            "Sonraki kontrol tarihi",
            admin,
        );
        const correctiveActionDueAt = optionalDate(
            data.correctiveActionDueAt,
            "Duzeltici faaliyet son tarihi",
            admin,
        );
        const correctiveActionCompletedAt = optionalDate(
            data.correctiveActionCompletedAt,
            "Duzeltici faaliyet tamamlanma tarihi",
            admin,
        );

        const isFailure =
          result === "failed" || result === "critical_failure";

        if (isFailure && !correctiveAction) {
          throw new HttpsError(
              "invalid-argument",
              "Uygunsuz kontrolde duzeltici faaliyet zorunludur.",
          );
        }

        const controlRef = db
            .collection("supply_security_protection_controls")
            .doc(controlId);

        try {
          await db.runTransaction(async (transaction) => {
            const controlSnapshot = await transaction.get(controlRef);

            if (!controlSnapshot.exists) {
              throw new HttpsError(
                  "not-found",
                  "Guncellenecek koruma kontrolu bulunamadi.",
              );
            }

            const current = controlSnapshot.data();

            if (!current) {
              throw new HttpsError(
                  "not-found",
                  "Guncellenecek koruma kontrolu bulunamadi.",
              );
            }

            if (current.tenantId !== uid || current.brandId !== uid) {
              throw new HttpsError(
                  "permission-denied",
                  "Koruma kontrolu bu marka hesabina ait degil.",
              );
            }

            if (current.status === "archived") {
              throw new HttpsError(
                  "failed-precondition",
                  "Arsivlenmis koruma kontrolu guncellenemez.",
              );
            }

            const targetReads = [];
            let partnerRef = null;
            let facilityRef = null;

            if (partnerId) {
              partnerRef = db
                  .collection("supply_security_partners")
                  .doc(partnerId);
              targetReads.push(transaction.get(partnerRef));
            }

            if (facilityId) {
              facilityRef = db
                  .collection("supply_security_facilities")
                  .doc(facilityId);
              targetReads.push(transaction.get(facilityRef));
            }

            const targetSnapshots = await Promise.all(targetReads);
            let targetIndex = 0;
            let partnerSnapshot = null;
            let facilitySnapshot = null;

            if (partnerRef) {
              partnerSnapshot = targetSnapshots[targetIndex];
              targetIndex += 1;
            }

            if (facilityRef) {
              facilitySnapshot = targetSnapshots[targetIndex];
            }

            if (partnerSnapshot) {
              const partner = partnerSnapshot.data();

              if (!partnerSnapshot.exists || !partner) {
                throw new HttpsError(
                    "failed-precondition",
                    "Kontrole baglanacak partner bulunamadi.",
                );
              }

              if (partner.tenantId !== uid || partner.brandId !== uid) {
                throw new HttpsError(
                    "permission-denied",
                    "Partner bu marka hesabina ait degil.",
                );
              }

              if (partner.status === "archived") {
                throw new HttpsError(
                    "failed-precondition",
                    "Arsivlenmis partner koruma kontrolune baglanamaz.",
                );
              }
            }

            if (facilitySnapshot) {
              const facility = facilitySnapshot.data();

              if (!facilitySnapshot.exists || !facility) {
                throw new HttpsError(
                    "failed-precondition",
                    "Kontrole baglanacak tesis bulunamadi.",
                );
              }

              if (facility.tenantId !== uid || facility.brandId !== uid) {
                throw new HttpsError(
                    "permission-denied",
                    "Tesis bu marka hesabina ait degil.",
                );
              }

              if (facility.status === "archived") {
                throw new HttpsError(
                    "failed-precondition",
                    "Arsivlenmis tesis koruma kontrolune baglanamaz.",
                );
              }

              if (partnerId && facility.partnerId !== partnerId) {
                throw new HttpsError(
                    "failed-precondition",
                    "Secilen tesis belirtilen partnere bagli degil.",
                );
              }
            }

            transaction.update(controlRef, {
              title,
              controlType,
              scope,
              status,
              result,
              riskLevel,
              partnerId,
              facilityId,
              description,
              assignedToId,
              assignedToName,
              plannedAt,
              startedAt,
              nextControlAt,
              findings,
              evidenceDocumentIds,
              relatedProductIds,
              correctiveAction,
              correctiveActionOwnerId,
              correctiveActionOwnerName,
              correctiveActionDueAt,
              correctiveActionCompletedAt,
              notes,
              metadata,
              updatedAt: admin.firestore.Timestamp.now(),
              updatedBy: uid,
            });
          });

          logger.info("Supply protection control updated", {
            controlId,
            tenantId: uid,
            status,
            result,
          });

          return {controlId};
        } catch (error) {
          logger.error("Supply protection control update failed", {
            controlId,
            tenantId: uid,
            error,
          });

          if (error instanceof HttpsError) {
            throw error;
          }

          throw new HttpsError(
              "internal",
              "Koruma kontrolu guncellenirken sunucu hatasi olustu.",
          );
        }
      },
  );
}

module.exports = {
  buildCreateSupplyProtectionControl,
  buildUpdateSupplyProtectionControl,
};
