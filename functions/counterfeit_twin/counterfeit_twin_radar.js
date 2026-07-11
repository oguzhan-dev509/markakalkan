const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {
  ROLES,
  requireAuthenticatedUser,
  requirePlatformRole,
} = require("../common/platform_admin");

const REPORTS = "counterfeit_twin_reports";
const PUBLIC_COMPARISONS = "counterfeit_twin_public_comparisons";

const TARGET_TYPES = new Set([
  "physical_product", "digital_product", "service", "saas_platform",
  "ecommerce_platform", "marketplace_store",
  "tourism_booking_platform", "financial_service", "payment_page",
  "mobile_application", "website", "social_media_account",
  "customer_support_channel", "institution", "robotic_system",
  "autonomous_ai_agent", "other",
]);

const INCIDENT_TYPES = new Set([
  "product_imitation", "brand_impersonation", "platform_impersonation",
  "website_clone", "mobile_app_impersonation", "interface_clone",
  "fake_checkout", "fake_payment_page", "fake_subscription",
  "fake_reservation", "fake_financial_service",
  "fake_investment_service", "fake_customer_support",
  "credential_phishing", "payment_diversion", "iban_diversion",
  "merchant_identity_deception", "unauthorized_card_charge",
  "personal_data_harvesting", "counterfeit_robot_hardware",
  "robot_identity_clone", "serial_number_clone",
  "device_certificate_clone", "control_software_clone",
  "firmware_clone", "fake_robot_certification",
  "teleoperation_channel_impersonation",
  "robot_fleet_impersonation", "ai_agent_impersonation",
  "voice_persona_clone", "fake_robot_service_network", "other",
]);

const ROBOT_TYPES = new Set([
  "industrial_robot",
  "service_robot",
  "humanoid_robot",
  "medical_robot",
  "logistics_robot",
  "security_robot",
  "domestic_robot",
  "robotic_device",
  "software_robot",
  "other",
]);

const DISPUTE_STATUSES = new Set([
  "not_submitted", "submitted", "under_review", "accepted", "rejected",
  "partially_resolved", "resolved",
]);

const RECOVERY_STATUSES = new Set([
  "no_recovery", "pending", "partial", "full", "unknown",
]);

function text(value, fieldName, maxLength, required = false) {
  if (value === null || value === undefined) {
    if (required) {
      throw new HttpsError("invalid-argument", `${fieldName} zorunludur.`);
    }
    return "";
  }
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} metin olmalidir.`);
  }
  const cleaned = value.trim();
  if ((required && !cleaned) || cleaned.length > maxLength) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return cleaned;
}

function stringList(value, fieldName, maxItems = 12, maxLength = 1000) {
  if (value === null || value === undefined) return [];
  if (!Array.isArray(value) || value.length > maxItems) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return [...new Set(value.map((item) =>
    text(item, fieldName, maxLength, true),
  ))];
}

function positiveAmount(value, fieldName) {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return Math.round(value * 100) / 100;
}

function enumValue(value, fieldName, allowed, fallback) {
  const cleaned = text(value ?? fallback, fieldName, 80, true);
  if (!allowed.has(cleaned)) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return cleaned;
}

function enumList(value, fieldName, allowed) {
  const values = stringList(value, fieldName, 20, 80);
  for (const item of values) {
    if (!allowed.has(item)) {
      throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
    }
  }
  return values;
}

function booleanValue(value, fieldName, fallback = false) {
  if (value === null || value === undefined) return fallback;
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return value;
}

function isoDate(value, fieldName) {
  if (value === null || value === undefined || value === "") return "";
  const cleaned = text(value, fieldName, 80, true);
  const parsed = new Date(cleaned);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError("invalid-argument", `${fieldName} gecersiz.`);
  }
  return parsed.toISOString();
}

function cleanFinancialImpact(value) {
  const data = value ?? {};
  if (typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "financialImpact gecersiz.");
  }
  const hasMonetaryLoss = booleanValue(
      data.hasMonetaryLoss,
      "financialImpact.hasMonetaryLoss",
  );
  const lossAmount = positiveAmount(
      data.lossAmount,
      "financialImpact.lossAmount",
  );
  if (hasMonetaryLoss && (lossAmount === null || lossAmount <= 0)) {
    throw new HttpsError(
        "invalid-argument",
        "Maddi kayip varsa lossAmount zorunludur.",
    );
  }
  const disputeSubmitted = booleanValue(
      data.disputeSubmitted,
      "financialImpact.disputeSubmitted",
  );

  return {
    hasMonetaryLoss,
    lossAmount,
    currency: text(
        data.currency || "TRY",
        "financialImpact.currency",
        12,
        true,
    ).toUpperCase(),
    transactionDate: isoDate(
        data.transactionDate,
        "financialImpact.transactionDate",
    ),
    paymentMethod: text(
        data.paymentMethod,
        "financialImpact.paymentMethod",
        120,
    ),
    bankOrPaymentProvider: text(
        data.bankOrPaymentProvider,
        "financialImpact.bankOrPaymentProvider",
        240,
    ),
    merchantDescriptor: text(
        data.merchantDescriptor,
        "financialImpact.merchantDescriptor",
        300,
    ),
    transactionReferenceMasked: text(
        data.transactionReferenceMasked,
        "financialImpact.transactionReferenceMasked",
        240,
    ),
    recipientNameMasked: text(
        data.recipientNameMasked,
        "financialImpact.recipientNameMasked",
        240,
    ),
    ibanMasked: text(data.ibanMasked, "financialImpact.ibanMasked", 120),
    disputeSubmitted,
    disputeSubmittedAt: isoDate(
        data.disputeSubmittedAt,
        "financialImpact.disputeSubmittedAt",
    ),
    disputeReference: text(
        data.disputeReference,
        "financialImpact.disputeReference",
        240,
    ),
    disputeStatus: enumValue(
        data.disputeStatus,
        "financialImpact.disputeStatus",
        DISPUTE_STATUSES,
        disputeSubmitted ? "submitted" : "not_submitted",
    ),
    refundAmount: positiveAmount(
        data.refundAmount,
        "financialImpact.refundAmount",
    ),
    recoveryStatus: enumValue(
        data.recoveryStatus,
        "financialImpact.recoveryStatus",
        RECOVERY_STATUSES,
        "unknown",
    ),
  };
}

function comparisonLabel(targetType) {
  if (targetType === "physical_product") {
    return "Gercek Urun - Sahte Ikiz";
  }
  if (targetType === "mobile_application") {
    return "Gercek Uygulama - Sahte Uygulama";
  }
  if (targetType === "institution" || targetType === "financial_service") {
    return "Gercek Kurum - Sahte Kurum";
  }
  if (targetType === "payment_page") {
    return "Gercek Odeme Sayfasi - Sahte Odeme Sayfasi";
  }
  if (targetType === "robotic_system") {
    return "Gercek Robot - Sahte Robot";
  }
  if (targetType === "autonomous_ai_agent") {
    return "Gercek Otonom Ajan - Sahte Ajan";
  }
  return "Gercek Platform - Sahte Platform";
}

function publicCategory(targetType) {
  if (targetType === "physical_product") {
    return "physical";
  }
  if (
    targetType === "robotic_system" ||
    targetType === "autonomous_ai_agent"
  ) {
    return "ai_robot";
  }
  return "digital";
}

function slugifyPublicValue(value) {
  const replacements = Object.freeze({
    "ç": "c",
    "ğ": "g",
    "ı": "i",
    "ö": "o",
    "ş": "s",
    "ü": "u",
  });

  return String(value || "")
      .trim()
      .toLocaleLowerCase("tr-TR")
      .split("")
      .map((character) => replacements[character] || character)
      .join("")
      .normalize("NFKD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 72);
}

function buildPublicSlug(report, publicId) {
  const source =
    report.originalEntityName ||
    report.originalBrandName ||
    report.originalProductName ||
    "sahte-ikiz";
  const base = slugifyPublicValue(source) || "sahte-ikiz";
  const suffix = String(publicId || "").slice(0, 10).toLowerCase();
  return `${base}-${suffix}`;
}

function buildPublicRecordCode(now, publicId) {
  const timestampDate = now?.toDate?.();
  const year = timestampDate instanceof Date ?
    timestampDate.getUTCFullYear() :
    new Date().getUTCFullYear();
  const suffix = String(publicId || "").slice(0, 8).toUpperCase();
  return `MK-SI-${year}-${suffix}`;
}

function buildShareTitle(report) {
  const original =
    report.originalEntityName ||
    report.originalBrandName ||
    report.originalProductName ||
    "Gerçek varlık";
  return `Doğrulanmış Sahte İkiz Kaydı: ${original}`.slice(0, 160);
}

function buildShareDescription(report) {
  const original =
    report.originalEntityName ||
    report.originalBrandName ||
    report.originalProductName ||
    "Gerçek varlık";
  const suspected =
    report.suspectedEntityName ||
    report.suspectedBrandName ||
    report.suspectedProductName ||
    "şüpheli ikiz";
  return (
    `${original} ile ${suspected} karşılaştırması. ` +
    "Gerçeği doğrula, sahte ikizi görünür kıl."
  ).slice(0, 240);
}

function safePublicStringList(value, maxItems = 20) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
      .filter((item) => typeof item === "string")
      .map((item) => item.trim())
      .filter(Boolean)
      .slice(0, maxItems);
}

function timestampMillis(value) {
  return value?.toMillis?.() ?? null;
}

function safeFinancialImpactSummary(value) {
  const data = value && typeof value === "object" ? value : {};
  return {
    hasMonetaryLoss: data.hasMonetaryLoss === true,
    lossAmount:
      typeof data.lossAmount === "number" ? data.lossAmount : null,
    currency:
      typeof data.currency === "string" ? data.currency : "TRY",
    bankOrPaymentProvider:
      typeof data.bankOrPaymentProvider === "string" ?
        data.bankOrPaymentProvider :
        "",
    disputeSubmitted: data.disputeSubmitted === true,
    disputeStatus:
      typeof data.disputeStatus === "string" ?
        data.disputeStatus :
        "not_submitted",
    refundAmount:
      typeof data.refundAmount === "number" ? data.refundAmount : null,
    recoveryStatus:
      typeof data.recoveryStatus === "string" ?
        data.recoveryStatus :
        "unknown",
  };
}

function safePublicComparison(doc) {
  const data = doc.data() || {};
  const publicationState = data.publicationState || "published";
  if (publicationState !== "published") {
    return null;
  }

  const targetType = data.targetType || "physical_product";
  const slug = data.slug || buildPublicSlug(data, doc.id);
  const canonicalPath = data.canonicalPath || `/sahte-ikiz/${slug}`;
  const recordCode =
    data.publicRecordCode ||
    buildPublicRecordCode(data.publishedAt, doc.id);

  return {
    id: doc.id,
    slug,
    publicRecordCode: recordCode,
    publicCategory:
      data.publicCategory || publicCategory(targetType),
    targetType,
    comparisonLabel:
      data.comparisonLabel || comparisonLabel(targetType),
    title: typeof data.title === "string" ? data.title : "",
    originalEntityName:
      typeof data.originalEntityName === "string" ?
        data.originalEntityName :
        "",
    suspectedEntityName:
      typeof data.suspectedEntityName === "string" ?
        data.suspectedEntityName :
        "",
    originalBrandName:
      typeof data.originalBrandName === "string" ?
        data.originalBrandName :
        "",
    originalProductName:
      typeof data.originalProductName === "string" ?
        data.originalProductName :
        "",
    originalCountry:
      typeof data.originalCountry === "string" ?
        data.originalCountry :
        "",
    originalImageUrls: safePublicStringList(data.originalImageUrls),
    originalUrls: safePublicStringList(data.originalUrls),
    suspectedBrandName:
      typeof data.suspectedBrandName === "string" ?
        data.suspectedBrandName :
        "",
    suspectedProductName:
      typeof data.suspectedProductName === "string" ?
        data.suspectedProductName :
        "",
    claimedOriginCountry:
      typeof data.claimedOriginCountry === "string" ?
        data.claimedOriginCountry :
        "",
    allegedSupplyCountry:
      typeof data.allegedSupplyCountry === "string" ?
        data.allegedSupplyCountry :
        "",
    suspectedImageUrls: safePublicStringList(data.suspectedImageUrls),
    suspectedUrls: safePublicStringList(data.suspectedUrls),
    incidentTypes: safePublicStringList(data.incidentTypes),
    robotType:
      typeof data.robotType === "string" ? data.robotType : "",
    platformName:
      typeof data.platformName === "string" ? data.platformName : "",
    storeDisplayName:
      typeof data.storeDisplayName === "string" ?
        data.storeDisplayName :
        "",
    authorizedPriceMin:
      typeof data.authorizedPriceMin === "number" ?
        data.authorizedPriceMin :
        null,
    authorizedPriceMax:
      typeof data.authorizedPriceMax === "number" ?
        data.authorizedPriceMax :
        null,
    suspectedPrice:
      typeof data.suspectedPrice === "number" ?
        data.suspectedPrice :
        null,
    currency:
      typeof data.currency === "string" ? data.currency : "TRY",
    differenceNotes: safePublicStringList(data.differenceNotes),
    financialImpactSummary:
      safeFinancialImpactSummary(data.financialImpactSummary),
    publicSummary:
      typeof data.publicSummary === "string" ?
        data.publicSummary :
        "",
    verificationLabel:
      typeof data.verificationLabel === "string" ?
        data.verificationLabel :
        "delille_dogrulandi",
    canonicalPath,
    shareTitle:
      typeof data.shareTitle === "string" ?
        data.shareTitle :
        buildShareTitle(data),
    shareDescription:
      typeof data.shareDescription === "string" ?
        data.shareDescription :
        buildShareDescription(data),
    publicationState,
    publishedAtMillis: timestampMillis(data.publishedAt),
    updatedAtMillis: timestampMillis(data.updatedAt),
    withdrawnAtMillis: timestampMillis(data.withdrawnAt),
  };
}

function cleanReportPayload(data) {
  const targetType = enumValue(
      data.targetType,
      "targetType",
      TARGET_TYPES,
      "physical_product",
  );
  const robotType = data.robotType === null ||
      data.robotType === undefined ||
      data.robotType === "" ?
    "" :
    enumValue(data.robotType, "robotType", ROBOT_TYPES, "other");

  if (
    ["robotic_system", "autonomous_ai_agent"].includes(targetType) &&
    !robotType
  ) {
    throw new HttpsError(
        "invalid-argument",
        "Robot veya otonom ajan vakalarinda robotType zorunludur.",
    );
  }
  const legacyOriginal = text(
      data.originalProductName,
      "originalProductName",
      500,
  );
  const legacySuspected = text(
      data.suspectedProductName,
      "suspectedProductName",
      500,
  );
  const originalEntityName = text(
      data.originalEntityName || legacyOriginal,
      "originalEntityName",
      500,
      true,
  );
  const suspectedEntityName = text(
      data.suspectedEntityName || legacySuspected,
      "suspectedEntityName",
      500,
      true,
  );

  return {
    targetType,
    originalEntityName,
    suspectedEntityName,
    originalBrandName: text(
        data.originalBrandName,
        "originalBrandName",
        240,
        targetType === "physical_product",
    ),
    originalProductName: legacyOriginal || originalEntityName,
    originalCountry: text(data.originalCountry, "originalCountry", 120),
    originalImageUrls: stringList(
        data.originalImageUrls,
        "originalImageUrls",
    ),
    originalUrls: stringList(data.originalUrls, "originalUrls", 20, 1200),
    suspectedBrandName: text(
        data.suspectedBrandName,
        "suspectedBrandName",
        240,
    ),
    suspectedProductName: legacySuspected || suspectedEntityName,
    claimedOriginCountry: text(
        data.claimedOriginCountry,
        "claimedOriginCountry",
        120,
    ),
    allegedSupplyCountry: text(
        data.allegedSupplyCountry,
        "allegedSupplyCountry",
        120,
    ),
    suspectedImageUrls: stringList(
        data.suspectedImageUrls,
        "suspectedImageUrls",
    ),
    suspectedUrls: stringList(
        data.suspectedUrls,
        "suspectedUrls",
        20,
        1200,
    ),
    incidentTypes: enumList(
        data.incidentTypes,
        "incidentTypes",
        INCIDENT_TYPES,
    ),
    robotType,
    platformName: text(data.platformName, "platformName", 160, true),
    storeDisplayName: text(
        data.storeDisplayName,
        "storeDisplayName",
        240,
    ),
    listingUrl: text(data.listingUrl, "listingUrl", 1200),
    authorizedPriceMin: positiveAmount(
        data.authorizedPriceMin,
        "authorizedPriceMin",
    ),
    authorizedPriceMax: positiveAmount(
        data.authorizedPriceMax,
        "authorizedPriceMax",
    ),
    suspectedPrice: positiveAmount(data.suspectedPrice, "suspectedPrice"),
    currency: text(data.currency || "TRY", "currency", 12, true).toUpperCase(),
    differenceNotes: stringList(
        data.differenceNotes,
        "differenceNotes",
        20,
        500,
    ),
    evidenceNotes: text(data.evidenceNotes, "evidenceNotes", 5000, true),
    financialImpact: cleanFinancialImpact(data.financialImpact),
  };
}

function buildSubmitCounterfeitTwinReport({db, admin}) {
  return onCall(async (request) => {
    const actor = requireAuthenticatedUser(request);
    const payload = cleanReportPayload(request.data || {});
    const now = admin.firestore.Timestamp.now();
    const reportRef = db.collection(REPORTS).doc();
    await reportRef.create({
      ...payload,
      reporterUid: actor.uid,
      reporterEmail: actor.email,
      status: "submitted",
      createdAt: now,
      updatedAt: now,
      reviewedAt: null,
      reviewedByUid: null,
      reviewedByEmail: null,
      reviewNote: "",
      publicSummary: "",
      counterfeitTwinRecordId: null,
      publicComparisonId: null,
    });
    logger.info("Counterfeit twin report submitted", {
      reportId: reportRef.id,
      reporterUid: actor.uid,
    });
    return {reportId: reportRef.id, status: "submitted"};
  });
}

function buildListCounterfeitTwinReportsForAdmin({db}) {
  return onCall(async (request) => {
    await requirePlatformRole(request, db, ROLES.counterfeitTwinReviewer);
    const snapshot = await db.collection(REPORTS)
        .orderBy("createdAt", "desc")
        .limit(200)
        .get();
    return {
      reports: snapshot.docs.map((doc) => {
        const data = doc.data();
        const {createdAt, updatedAt, reviewedAt, ...safeData} = data;
        return {
          id: doc.id,
          ...safeData,
          createdAtMillis: createdAt?.toMillis?.() ?? null,
          updatedAtMillis: updatedAt?.toMillis?.() ?? null,
          reviewedAtMillis: reviewedAt?.toMillis?.() ?? null,
        };
      }),
    };
  });
}

function buildReviewCounterfeitTwinReport({db, admin}) {
  return onCall(async (request) => {
    const decision = text(request.data?.decision, "decision", 40, true);
    const role = decision === "published" ?
      ROLES.counterfeitTwinPublisher :
      ROLES.counterfeitTwinReviewer;
    const actor = await requirePlatformRole(request, db, role);
    if (!["under_review", "rejected", "published"].includes(decision)) {
      throw new HttpsError("invalid-argument", "Gecersiz karar.");
    }
    const reportId = text(request.data?.reportId, "reportId", 240, true);
    if (reportId.includes("/")) {
      throw new HttpsError("invalid-argument", "reportId gecersiz.");
    }
    const reviewNote = text(request.data?.reviewNote, "reviewNote", 5000);
    const publicSummary = text(
        request.data?.publicSummary,
        "publicSummary",
        5000,
    );
    if (decision === "rejected" && !reviewNote) {
      throw new HttpsError("invalid-argument", "Ret gerekcesi zorunludur.");
    }
    if (decision === "published" && !publicSummary) {
      throw new HttpsError(
          "invalid-argument",
          "Kamuya acik ozet zorunludur.",
      );
    }

    const reportRef = db.collection(REPORTS).doc(reportId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reportRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Bildirim bulunamadi.");
      }
      const report = snapshot.data() || {};
      if (!["submitted", "under_review"].includes(report.status)) {
        throw new HttpsError(
            "failed-precondition",
            "Bildirim bu karar icin uygun durumda degil.",
        );
      }
      const now = admin.firestore.Timestamp.now();
      const update = {
        status: decision,
        reviewNote,
        publicSummary,
        reviewedAt: now,
        reviewedByUid: actor.uid,
        reviewedByEmail: actor.email,
        updatedAt: now,
      };

      if (decision === "published") {
        const publicRef = db.collection(PUBLIC_COMPARISONS).doc();
        const targetType = report.targetType || "physical_product";
        const slug = buildPublicSlug(report, publicRef.id);
        const publicRecordCode =
          buildPublicRecordCode(now, publicRef.id);
        const canonicalPath = `/sahte-ikiz/${slug}`;

        transaction.create(publicRef, {
          reportId,
          counterfeitTwinRecordId: null,
          publicCategory: publicCategory(targetType),
          targetType,
          comparisonLabel: comparisonLabel(targetType),
          title: `${report.originalEntityName || report.originalBrandName}: ` +
            comparisonLabel(targetType),
          slug,
          publicRecordCode,
          canonicalPath,
          shareTitle: buildShareTitle(report),
          shareDescription: buildShareDescription(report),
          publicationState: "published",
          originalEntityName:
            report.originalEntityName || report.originalProductName,
          suspectedEntityName:
            report.suspectedEntityName || report.suspectedProductName,
          originalBrandName: report.originalBrandName || "",
          originalProductName: report.originalProductName || "",
          originalCountry: report.originalCountry || "",
          originalImageUrls: report.originalImageUrls || [],
          originalUrls: report.originalUrls || [],
          suspectedBrandName:
            report.suspectedBrandName || report.originalBrandName || "",
          suspectedProductName: report.suspectedProductName || "",
          claimedOriginCountry: report.claimedOriginCountry || "",
          allegedSupplyCountry: report.allegedSupplyCountry || "",
          suspectedImageUrls: report.suspectedImageUrls || [],
          suspectedUrls: report.suspectedUrls || [],
          incidentTypes: report.incidentTypes || [],
          robotType: report.robotType || "",
          platformName: report.platformName,
          storeDisplayName: report.storeDisplayName || "",
          authorizedPriceMin: report.authorizedPriceMin ?? null,
          authorizedPriceMax: report.authorizedPriceMax ?? null,
          suspectedPrice: report.suspectedPrice ?? null,
          currency: report.currency || "TRY",
          differenceNotes: report.differenceNotes || [],
          financialImpactSummary: {
            hasMonetaryLoss:
              report.financialImpact?.hasMonetaryLoss === true,
            lossAmount: report.financialImpact?.lossAmount ?? null,
            currency: report.financialImpact?.currency || "TRY",
            bankOrPaymentProvider:
              report.financialImpact?.bankOrPaymentProvider || "",
            disputeSubmitted:
              report.financialImpact?.disputeSubmitted === true,
            disputeStatus:
              report.financialImpact?.disputeStatus || "not_submitted",
            refundAmount: report.financialImpact?.refundAmount ?? null,
            recoveryStatus:
              report.financialImpact?.recoveryStatus || "unknown",
          },
          publicSummary,
          verificationLabel: "delille_dogrulandi",
          publishedAt: now,
          updatedAt: now,
          withdrawnAt: null,
        });
        update.counterfeitTwinRecordId = null;
        update.publicComparisonId = publicRef.id;
      }

      transaction.update(reportRef, update);
    });

    logger.info("Counterfeit twin report reviewed", {
      reportId,
      decision,
      adminUid: actor.uid,
    });
    return {reportId, status: decision};
  });
}

function buildListPublicCounterfeitTwinComparisons({db}) {
  return onCall(async () => {
    const snapshot = await db.collection(PUBLIC_COMPARISONS)
        .orderBy("publishedAt", "desc")
        .limit(100)
        .get();
    const comparisons = snapshot.docs
        .map((doc) => safePublicComparison(doc))
        .filter((item) => item !== null);
    return {comparisons};
  });
}

function buildGetPublicCounterfeitTwinComparison({db}) {
  return onCall(async (request) => {
    const slug = text(request.data?.slug, "slug", 120, true);
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)) {
      throw new HttpsError("invalid-argument", "slug gecersiz.");
    }

    const snapshot = await db.collection(PUBLIC_COMPARISONS)
        .where("slug", "==", slug)
        .limit(1)
        .get();

    if (snapshot.empty) {
      throw new HttpsError(
          "not-found",
          "Yayimlanmis sahte ikiz kaydi bulunamadi.",
      );
    }

    const comparison = safePublicComparison(snapshot.docs[0]);
    if (comparison === null) {
      throw new HttpsError(
          "not-found",
          "Yayimlanmis sahte ikiz kaydi bulunamadi.",
      );
    }

    return {comparison};
  });
}

module.exports = {
  buildSubmitCounterfeitTwinReport,
  buildListCounterfeitTwinReportsForAdmin,
  buildReviewCounterfeitTwinReport,
  buildListPublicCounterfeitTwinComparisons,
  buildGetPublicCounterfeitTwinComparison,
};
