const CASE_STATUSES = Object.freeze([
  "open",
  "under_review",
  "confirmed",
  "false_positive",
  "action_required",
  "resolved",
  "closed",
  "archived",
]);

function normalizePlatform(value) {
  const allowed = [
    "web",
    "android",
    "ios",
    "windows",
    "macos",
    "linux",
    "other",
  ];
  if (typeof value !== "string") return "other";
  const normalized = value.trim().toLowerCase();
  return allowed.includes(normalized) ? normalized : "other";
}

function normalizeSource(value) {
  return value === "qr" ? "qr" : "manual";
}

function safeString(value, maxLength = 1500) {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLength);
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) return value.getTime();
  if (Number.isFinite(value)) return Number(value);
  return null;
}

function riskLevelForScore(score) {
  if (score <= 0) return "none";
  if (score < 20) return "low";
  if (score < 40) return "medium";
  if (score < 70) return "high";
  return "critical";
}

function evaluateVerificationRisk({
  found,
  status,
  previousScanCount,
  nextScanCount,
  previousVerifiedAt,
  verifiedAt,
  previousPlatform,
  platform,
  previousSource,
  source,
}) {
  let score = 0;
  const reasons = new Set();

  const add = (reason, points) => {
    reasons.add(reason);
    score += points;
  };

  if (!found) {
    add("unknown_code", 90);
  } else {
    if (status === "revoked") {
      add("revoked_code", 100);
    } else if (status === "blocked") {
      add("blocked_code", 90);
    } else if (status !== "active") {
      add("inactive_code", 60);
    }

    if (nextScanCount >= 10) {
      add("scan_volume_critical", 55);
    } else if (nextScanCount >= 5) {
      add("scan_volume_high", 40);
    } else if (nextScanCount >= 3) {
      add("repeated_scan", 25);
    } else if (nextScanCount >= 2) {
      add("repeat_scan_observed", 10);
    }

    const previousMillis = timestampMillis(previousVerifiedAt);
    const verifiedMillis = timestampMillis(verifiedAt);
    if (
      previousMillis != null &&
      verifiedMillis != null &&
      verifiedMillis >= previousMillis &&
      verifiedMillis - previousMillis <= 10 * 60 * 1000 &&
      nextScanCount > 1
    ) {
      add("rapid_repeat_scan", 25);
    }

    if (
      previousScanCount > 0 &&
      previousPlatform &&
      previousPlatform !== platform
    ) {
      add("platform_changed", 10);
    }

    if (
      previousScanCount > 0 &&
      previousSource &&
      previousSource !== source
    ) {
      add("scan_source_changed", 5);
    }
  }

  score = Math.min(100, score);
  const suspicious =
    !found ||
    status === "blocked" ||
    status === "revoked" ||
    score >= 20;

  return {
    riskScore: score,
    riskLevel: riskLevelForScore(score),
    riskReasons: [...reasons],
    suspicious,
    reviewStatus: suspicious ? "pending" : "not_required",
    riskVersion: 1,
  };
}

function requireAuthenticatedUser(request, HttpsError) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
  }
  return {uid};
}

function normalizeLimit(value, fallback = 50, maximum = 100) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) return fallback;
  return Math.min(parsed, maximum);
}

function serializeScan(snapshot) {
  const data = snapshot.data() || {};
  return {
    id: snapshot.id,
    publicCode: safeString(data.publicCode, 80),
    productId: safeString(data.productId, 160),
    batchId: safeString(data.batchId, 160),
    brandName: safeString(data.brandName, 160),
    productName: safeString(data.productName, 240),
    batchNumber: safeString(data.batchNumber, 160),
    status: safeString(data.status, 80),
    platform: safeString(data.platform, 40),
    source: safeString(data.source, 40),
    scanNumber: Number.isInteger(data.scanNumber) ? data.scanNumber : 0,
    repeatScan: data.repeatScan === true,
    suspicious: data.suspicious === true,
    riskScore: Number.isInteger(data.riskScore) ? data.riskScore : 0,
    riskLevel: safeString(data.riskLevel, 40) || "none",
    riskReasons: Array.isArray(data.riskReasons) ?
      data.riskReasons.filter((item) => typeof item === "string") :
      [],
    reviewStatus: safeString(data.reviewStatus, 40) || "pending",
    reviewNotes: safeString(data.reviewNotes, 1500),
    caseId: safeString(data.caseId, 160),
    createdAtMillis: timestampMillis(data.createdAt),
    reviewedAtMillis: timestampMillis(data.reviewedAt),
  };
}

function serializeCase(snapshot) {
  const data = snapshot.data() || {};
  return {
    id: snapshot.id,
    caseCode: safeString(data.caseCode, 120),
    title: safeString(data.title, 240),
    summary: safeString(data.summary, 1500),
    status: safeString(data.status, 40) || "open",
    priority: safeString(data.priority, 40) || "normal",
    sourceType: safeString(data.sourceType, 80),
    riskScore: Number.isInteger(data.riskScore) ? data.riskScore : 0,
    riskLevel: safeString(data.riskLevel, 40) || "none",
    riskReasons: Array.isArray(data.riskReasons) ?
      data.riskReasons.filter((item) => typeof item === "string") :
      [],
    scanIds: Array.isArray(data.scanIds) ?
      data.scanIds.filter((item) => typeof item === "string") :
      [],
    publicCodes: Array.isArray(data.publicCodes) ?
      data.publicCodes.filter((item) => typeof item === "string") :
      [],
    productIds: Array.isArray(data.productIds) ?
      data.productIds.filter((item) => typeof item === "string") :
      [],
    batchIds: Array.isArray(data.batchIds) ?
      data.batchIds.filter((item) => typeof item === "string") :
      [],
    createdAtMillis: timestampMillis(data.createdAt),
    updatedAtMillis: timestampMillis(data.updatedAt),
  };
}

function priorityForRiskLevel(level) {
  if (level === "critical") return "critical";
  if (level === "high") return "high";
  if (level === "medium") return "normal";
  return "low";
}

function buildTraceabilityCallables({
  db,
  admin,
  onCall,
  HttpsError,
  logger,
}) {
  const verifyProductCode = onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const publicCode = safeString(request.data?.publicCode, 80)
            .toUpperCase();
        const platform = normalizePlatform(request.data?.platform);
        const source = normalizeSource(request.data?.source);

        if (
          publicCode.length < 10 ||
          publicCode.length > 80 ||
          !/^MK-[A-Z0-9-]+$/.test(publicCode)
        ) {
          throw new HttpsError(
              "invalid-argument",
              "Geçerli bir MarkaKalkan ürün kodu girilmelidir.",
          );
        }

        const publicCodeRef = db
            .collection("publicProductCodes")
            .doc(publicCode);
        const privateCodeRef = db
            .collection("productCodes")
            .doc(publicCode);
        const scanRef = db.collection("verificationScans").doc();

        try {
          const result = await db.runTransaction(async (transaction) => {
            const publicSnapshot = await transaction.get(publicCodeRef);
            const privateSnapshot = await transaction.get(privateCodeRef);
            const verifiedAt = admin.firestore.Timestamp.now();

            if (!publicSnapshot.exists || !privateSnapshot.exists) {
              const risk = evaluateVerificationRisk({
                found: false,
                status: "not_found",
                previousScanCount: 0,
                nextScanCount: 0,
                previousVerifiedAt: null,
                verifiedAt,
                previousPlatform: "",
                platform,
                previousSource: "",
                source,
              });

              transaction.set(scanRef, {
                publicCode,
                found: false,
                result: "not_found",
                platform,
                source,
                repeatScan: false,
                ...risk,
                reviewNotes: "",
                reviewedAt: null,
                reviewedBy: null,
                caseId: null,
                createdAt: verifiedAt,
                updatedAt: verifiedAt,
              });

              return {
                found: false,
                publicCode,
                result: "not_found",
                ...risk,
              };
            }

            const publicData = publicSnapshot.data() || {};
            const privateData = privateSnapshot.data() || {};
            const previousScanCount =
              Number.isInteger(privateData.scanCount) ?
                privateData.scanCount :
                0;
            const nextScanCount = previousScanCount + 1;
            const repeatScan = nextScanCount > 1;

            const risk = evaluateVerificationRisk({
              found: true,
              status: privateData.status,
              previousScanCount,
              nextScanCount,
              previousVerifiedAt: privateData.lastVerifiedAt,
              verifiedAt,
              previousPlatform: safeString(
                  privateData.lastVerificationPlatform,
                  40,
              ),
              platform,
              previousSource: safeString(
                  privateData.lastVerificationSource,
                  40,
              ),
              source,
            });

            const previousSuspiciousCount =
              Number.isInteger(privateData.suspiciousScanCount) ?
                privateData.suspiciousScanCount :
                0;

            transaction.update(privateCodeRef, {
              scanCount: nextScanCount,
              suspiciousScanCount:
                previousSuspiciousCount + (risk.suspicious ? 1 : 0),
              firstVerifiedAt:
                privateData.firstVerifiedAt ?? verifiedAt,
              lastVerifiedAt: verifiedAt,
              lastVerificationPlatform: platform,
              lastVerificationSource: source,
              lastRiskScore: risk.riskScore,
              lastRiskLevel: risk.riskLevel,
              updatedAt: verifiedAt,
            });

            transaction.set(scanRef, {
              publicCode,
              ownerUid: privateData.ownerUid,
              productId: privateData.productId,
              batchId: privateData.batchId,
              brandName: publicData.brandName,
              productName: publicData.productName,
              batchNumber: publicData.batchNumber,
              status: privateData.status,
              found: true,
              result: privateData.status,
              platform,
              source,
              scanNumber: nextScanCount,
              repeatScan,
              ...risk,
              reviewNotes: "",
              reviewedAt: null,
              reviewedBy: null,
              caseId: null,
              createdAt: verifiedAt,
              updatedAt: verifiedAt,
            });

            return {
              found: true,
              publicCode,
              brandName: publicData.brandName,
              productName: publicData.productName,
              batchNumber: publicData.batchNumber,
              status: privateData.status,
              scanCount: nextScanCount,
              repeatScan,
              ...risk,
            };
          });

          logger.info("Product code verified", {
            publicCode,
            found: result.found,
            platform,
            source,
            suspicious: result.suspicious,
            riskScore: result.riskScore,
          });
          return result;
        } catch (error) {
          logger.error("Product verification failed", {
            publicCode,
            error,
          });
          if (error instanceof HttpsError) throw error;
          throw new HttpsError(
              "internal",
              "Ürün kodu doğrulanırken sunucu hatası oluştu.",
          );
        }
      },
  );

  const listSuspiciousVerificationScans = onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const actor = requireAuthenticatedUser(request, HttpsError);
        const limit = normalizeLimit(request.data?.limit);
        const reviewStatus = safeString(request.data?.reviewStatus, 40);
        const riskLevel = safeString(request.data?.riskLevel, 40);
        const fetchLimit = Math.min(200, Math.max(limit * 3, 50));

        const snapshot = await db
            .collection("verificationScans")
            .where("ownerUid", "==", actor.uid)
            .where("suspicious", "==", true)
            .orderBy("createdAt", "desc")
            .limit(fetchLimit)
            .get();

        const items = snapshot.docs
            .map(serializeScan)
            .filter((item) => {
              if (reviewStatus && item.reviewStatus !== reviewStatus) {
                return false;
              }
              if (riskLevel && item.riskLevel !== riskLevel) {
                return false;
              }
              return true;
            })
            .slice(0, limit);
        return {items};
      },
  );

  const reviewSuspiciousVerificationScan = onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const actor = requireAuthenticatedUser(request, HttpsError);
        const scanId = safeString(request.data?.scanId, 160);
        const reviewStatus = safeString(request.data?.reviewStatus, 40);
        const reviewNotes = safeString(request.data?.reviewNotes, 1500);

        if (!scanId) {
          throw new HttpsError(
              "invalid-argument",
              "Şüpheli tarama kimliği zorunludur.",
          );
        }
        if (!["reviewed", "dismissed", "escalated"].includes(reviewStatus)) {
          throw new HttpsError(
              "invalid-argument",
              "Geçerli bir inceleme durumu seçilmelidir.",
          );
        }

        const scanRef = db.collection("verificationScans").doc(scanId);
        const snapshot = await scanRef.get();
        if (!snapshot.exists) {
          throw new HttpsError("not-found", "Şüpheli tarama bulunamadı.");
        }

        const data = snapshot.data() || {};
        if (data.ownerUid !== actor.uid) {
          throw new HttpsError(
              "permission-denied",
              "Bu taramayı inceleme yetkiniz yok.",
          );
        }
        if (data.suspicious !== true) {
          throw new HttpsError(
              "failed-precondition",
              "Bu kayıt şüpheli tarama olarak işaretlenmemiş.",
          );
        }

        const now = admin.firestore.Timestamp.now();
        await scanRef.update({
          reviewStatus,
          reviewNotes,
          reviewedAt: now,
          reviewedBy: actor.uid,
          updatedAt: now,
        });

        return {item: serializeScan(await scanRef.get())};
      },
  );

  const createTraceabilityCaseFromScan = onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const actor = requireAuthenticatedUser(request, HttpsError);
        const scanId = safeString(request.data?.scanId, 160);
        const requestedTitle = safeString(request.data?.title, 240);
        const requestedSummary = safeString(request.data?.summary, 1500);

        if (!scanId) {
          throw new HttpsError(
              "invalid-argument",
              "Şüpheli tarama kimliği zorunludur.",
          );
        }

        const scanRef = db.collection("verificationScans").doc(scanId);
        const caseRef = db.collection("traceabilityCases").doc();

        const result = await db.runTransaction(async (transaction) => {
          const scanSnapshot = await transaction.get(scanRef);
          if (!scanSnapshot.exists) {
            throw new HttpsError("not-found", "Şüpheli tarama bulunamadı.");
          }

          const scan = scanSnapshot.data() || {};
          if (scan.ownerUid !== actor.uid) {
            throw new HttpsError(
                "permission-denied",
                "Bu taramadan vaka açma yetkiniz yok.",
            );
          }
          if (scan.suspicious !== true) {
            throw new HttpsError(
                "failed-precondition",
                "Yalnız şüpheli taramalardan vaka açılabilir.",
            );
          }

          const existingCaseId = safeString(scan.caseId, 160);
          if (existingCaseId) {
            const existingRef = db
                .collection("traceabilityCases")
                .doc(existingCaseId);
            const existingSnapshot = await transaction.get(existingRef);
            if (existingSnapshot.exists) {
              return {snapshot: existingSnapshot, created: false};
            }
          }

          const now = admin.firestore.Timestamp.now();
          const dateCode = now.toDate()
              .toISOString()
              .slice(0, 10)
              .replaceAll("-", "");
          const caseCode =
            `UKV-${dateCode}-${caseRef.id.slice(0, 8).toUpperCase()}`;
          const productName = safeString(scan.productName, 240);
          const publicCode = safeString(scan.publicCode, 80);
          const title =
            requestedTitle ||
            `${productName || "Ürün kodu"} şüpheli tarama vakası`;
          const summary =
            requestedSummary ||
            `${publicCode} kodu için oluşan şüpheli doğrulama taraması.`;
          const riskLevel = safeString(scan.riskLevel, 40) || "none";
          const riskReasons = Array.isArray(scan.riskReasons) ?
            scan.riskReasons.filter((item) => typeof item === "string") :
            [];

          const caseData = {
            ownerUid: actor.uid,
            caseCode,
            title,
            summary,
            status: "open",
            priority: priorityForRiskLevel(riskLevel),
            sourceType: "verification_scan",
            scanIds: [scanId],
            publicCodes: publicCode ? [publicCode] : [],
            productIds: scan.productId ? [scan.productId] : [],
            batchIds: scan.batchId ? [scan.batchId] : [],
            riskScore:
              Number.isInteger(scan.riskScore) ? scan.riskScore : 0,
            riskLevel,
            riskReasons,
            assignedToUid: null,
            evidenceCount: 0,
            noteCount: 0,
            createdBy: actor.uid,
            createdAt: now,
            updatedAt: now,
          };

          transaction.set(caseRef, caseData);
          transaction.update(scanRef, {
            caseId: caseRef.id,
            reviewStatus: "escalated",
            reviewedAt: now,
            reviewedBy: actor.uid,
            updatedAt: now,
          });

          return {
            snapshot: {id: caseRef.id, data: () => caseData},
            created: true,
          };
        });

        return {
          item: serializeCase(result.snapshot),
          created: result.created,
        };
      },
  );

  const listTraceabilityCases = onCall(
      {
        enforceAppCheck: false,
        maxInstances: 3,
      },
      async (request) => {
        const actor = requireAuthenticatedUser(request, HttpsError);
        const limit = normalizeLimit(request.data?.limit);
        const requestedStatus = safeString(request.data?.status, 40);
        if (requestedStatus && !CASE_STATUSES.includes(requestedStatus)) {
          throw new HttpsError(
              "invalid-argument",
              "Geçerli bir vaka durumu seçilmelidir.",
          );
        }

        const fetchLimit = Math.min(200, Math.max(limit * 3, 50));
        const snapshot = await db
            .collection("traceabilityCases")
            .where("ownerUid", "==", actor.uid)
            .orderBy("updatedAt", "desc")
            .limit(fetchLimit)
            .get();

        const items = snapshot.docs
            .map(serializeCase)
            .filter((item) => {
              return !requestedStatus || item.status === requestedStatus;
            })
            .slice(0, limit);
        return {items};
      },
  );

  return {
    verifyProductCode,
    listSuspiciousVerificationScans,
    reviewSuspiciousVerificationScan,
    createTraceabilityCaseFromScan,
    listTraceabilityCases,
  };
}

module.exports = {
  CASE_STATUSES,
  riskLevelForScore,
  evaluateVerificationRisk,
  buildTraceabilityCallables,
};
