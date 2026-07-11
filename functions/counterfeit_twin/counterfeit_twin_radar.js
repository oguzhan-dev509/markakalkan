const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {
  ROLES,
  requireAuthenticatedUser,
  requirePlatformRole,
} = require("../common/platform_admin");

const REPORTS = "counterfeit_twin_reports";
const REPORT_DELETIONS = "counterfeit_twin_report_deletions";
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


const PUBLIC_CATEGORIES = new Set(["physical", "digital", "ai_robot"]);

const PUBLIC_SUBCATEGORY_RULES = Object.freeze({
  food_beverage: ["physical", ["physical_product"]],
  pharma_medical_health: ["physical", ["physical_product"]],
  cosmetics_personal_care: ["physical", ["physical_product"]],
  textile_fashion: ["physical", ["physical_product"]],
  electronics_electrical: ["physical", ["physical_product"]],
  automotive_machinery: ["physical", ["physical_product"]],
  home_furniture_construction: ["physical", ["physical_product"]],
  packaging_label_security: ["physical", ["physical_product"]],
  document_certificate_identity: ["physical", ["physical_product"]],
  production_tool_mold_component: ["physical", ["physical_product"]],
  luxury_jewelry_collectible: ["physical", ["physical_product"]],
  toy_child_sports: ["physical", ["physical_product"]],
  agriculture_chemical_industrial: ["physical", ["physical_product"]],
  other_physical: ["physical", ["physical_product"]],

  website_domain: ["digital", ["website"]],
  mobile_application: ["digital", ["mobile_application"]],
  ecommerce_platform: ["digital", ["ecommerce_platform"]],
  marketplace_store: ["digital", ["marketplace_store"]],
  saas_cloud: ["digital", ["saas_platform"]],
  social_media: ["digital", ["social_media_account"]],
  payment_page: ["digital", ["payment_page"]],
  financial_investment: ["digital", ["financial_service"]],
  tourism_booking: ["digital", ["tourism_booking_platform"]],
  customer_support: ["digital", ["customer_support_channel"]],
  digital_product_software: ["digital", ["digital_product"]],
  corporate_digital_identity: ["digital", ["institution"]],
  email_messaging_identity: ["digital", ["service"]],
  digital_document_certificate: ["digital", ["digital_product"]],
  subscription_membership: ["digital", ["service"]],
  other_digital: ["digital", ["other"]],

  autonomous_ai_agent: ["ai_robot", ["autonomous_ai_agent"]],
  chatbot_customer_agent: ["ai_robot", ["autonomous_ai_agent"]],
  voice_persona_virtual_identity: ["ai_robot", ["autonomous_ai_agent"]],
  software_robot_rpa: ["ai_robot", ["autonomous_ai_agent"]],
  industrial_robot: ["ai_robot", ["robotic_system"]],
  service_robot: ["ai_robot", ["robotic_system"]],
  humanoid_robot: ["ai_robot", ["robotic_system"]],
  medical_robot: ["ai_robot", ["robotic_system"]],
  logistics_delivery_robot: ["ai_robot", ["robotic_system"]],
  security_surveillance_robot: ["ai_robot", ["robotic_system"]],
  domestic_robot: ["ai_robot", ["robotic_system"]],
  robotic_device_smart_machine: ["ai_robot", ["robotic_system"]],
  control_software_firmware: ["ai_robot", ["robotic_system"]],
  robot_fleet_device_identity: ["ai_robot", ["robotic_system"]],
  serial_device_certificate_clone: ["ai_robot", ["robotic_system"]],
  teleoperation_channel: ["ai_robot", ["robotic_system"]],
  robot_service_maintenance_network: ["ai_robot", ["robotic_system"]],
  other_ai_robot: ["ai_robot", ["robotic_system"]],
});

const PUBLIC_SUBCATEGORIES =
  new Set(Object.keys(PUBLIC_SUBCATEGORY_RULES));


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


function legacyPublicSubcategory(targetType, robotType) {
  if (targetType === "physical_product") return "other_physical";
  if (targetType === "website") return "website_domain";
  if (targetType === "mobile_application") return "mobile_application";
  if (targetType === "ecommerce_platform") return "ecommerce_platform";
  if (targetType === "marketplace_store") return "marketplace_store";
  if (targetType === "saas_platform") return "saas_cloud";
  if (targetType === "social_media_account") return "social_media";
  if (targetType === "payment_page") return "payment_page";
  if (targetType === "financial_service") return "financial_investment";
  if (targetType === "tourism_booking_platform") return "tourism_booking";
  if (targetType === "customer_support_channel") return "customer_support";
  if (targetType === "digital_product") return "digital_product_software";
  if (targetType === "institution") return "corporate_digital_identity";
  if (targetType === "service") return "subscription_membership";
  if (targetType === "other") return "other_digital";

  if (targetType === "autonomous_ai_agent") {
    return "autonomous_ai_agent";
  }

  const robotMap = Object.freeze({
    industrial_robot: "industrial_robot",
    service_robot: "service_robot",
    humanoid_robot: "humanoid_robot",
    medical_robot: "medical_robot",
    logistics_robot: "logistics_delivery_robot",
    security_robot: "security_surveillance_robot",
    domestic_robot: "domestic_robot",
    robotic_device: "robotic_device_smart_machine",
    software_robot: "control_software_firmware",
    other: "other_ai_robot",
  });

  return robotMap[robotType] || "other_ai_robot";
}

function normalizePublicTaxonomy(data, targetType, robotType) {
  const fallbackCategory = publicCategory(targetType);
  const category = enumValue(
      data.publicCategory,
      "publicCategory",
      PUBLIC_CATEGORIES,
      fallbackCategory,
  );
  const fallbackSubcategory =
    legacyPublicSubcategory(targetType, robotType);
  const subcategory = enumValue(
      data.publicSubcategory,
      "publicSubcategory",
      PUBLIC_SUBCATEGORIES,
      fallbackSubcategory,
  );
  const rule = PUBLIC_SUBCATEGORY_RULES[subcategory];

  if (!rule || rule[0] !== category) {
    throw new HttpsError(
        "invalid-argument",
        "publicSubcategory secilen publicCategory ile uyumlu degil.",
    );
  }
  if (!rule[1].includes(targetType)) {
    throw new HttpsError(
        "invalid-argument",
        "publicSubcategory secilen targetType ile uyumlu degil.",
    );
  }

  return {category, subcategory};
}


const CRITICAL_RISK_SUBCATEGORIES = new Set([
  "food_beverage",
  "pharma_medical_health",
  "cosmetics_personal_care",
  "electronics_electrical",
  "automotive_machinery",
  "home_furniture_construction",
  "production_tool_mold_component",
  "toy_child_sports",
  "agriculture_chemical_industrial",
]);

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

function approvedImageSelection(value, available, fieldName) {
  if (value === undefined || value === null) {
    return [];
  }
  if (!Array.isArray(value)) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} liste olmalidir.`,
    );
  }
  if (value.length > 4) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} en fazla 4 gorsel icerebilir.`,
    );
  }

  const availableSet = new Set(safePublicStringList(available, 20));
  const selected = [];
  for (const item of value) {
    if (typeof item !== "string") {
      throw new HttpsError(
          "invalid-argument",
          `${fieldName} yalniz metin URL icerebilir.`,
      );
    }
    const url = item.trim();
    if (!url || url.length > 2000) {
      throw new HttpsError(
          "invalid-argument",
          `${fieldName} gecersiz URL iceriyor.`,
      );
    }
    if (!availableSet.has(url)) {
      throw new HttpsError(
          "invalid-argument",
          "Secilen gorsel bildirime ait degil.",
      );
    }
    if (!selected.includes(url)) {
      selected.push(url);
    }
  }
  return selected;
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
  const category =
    data.publicCategory || publicCategory(targetType);
  const subcategory =
    data.publicSubcategory ||
    legacyPublicSubcategory(targetType, data.robotType || "");
  const slug = data.slug || buildPublicSlug(data, doc.id);
  const canonicalPath = data.canonicalPath || `/sahte-ikiz/${slug}`;
  const recordCode =
    data.publicRecordCode ||
    buildPublicRecordCode(data.publishedAt, doc.id);

  return {
    id: doc.id,
    slug,
    publicRecordCode: recordCode,
    publicCategory: category,
    publicSubcategory: subcategory,
    targetType,
    comparisonLabel:
      data.comparisonLabel || comparisonLabel(targetType),
    title: typeof data.title === "string" ? data.title : "",
    usagePurpose:
      typeof data.usagePurpose === "string" ? data.usagePurpose : "",
    technicalIdentity:
      typeof data.technicalIdentity === "string" ?
        data.technicalIdentity :
        "",
    counterfeitRisk:
      typeof data.counterfeitRisk === "string" ? data.counterfeitRisk : "",
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

  const taxonomy =
    normalizePublicTaxonomy(data, targetType, robotType);

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
    publicCategory: taxonomy.category,
    publicSubcategory: taxonomy.subcategory,
    originalEntityName,
    suspectedEntityName,
    usagePurpose: text(data.usagePurpose, "usagePurpose", 300, true),
    technicalIdentity: text(
        data.technicalIdentity,
        "technicalIdentity",
        500,
    ),
    counterfeitRisk: text(
        data.counterfeitRisk,
        "counterfeitRisk",
        500,
        CRITICAL_RISK_SUBCATEGORIES.has(taxonomy.subcategory),
    ),
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
      const approvedOriginalImageUrls = approvedImageSelection(
          request.data?.approvedOriginalImageUrls,
          report.originalImageUrls,
          "approvedOriginalImageUrls",
      );
      const approvedSuspectedImageUrls = approvedImageSelection(
          request.data?.approvedSuspectedImageUrls,
          report.suspectedImageUrls,
          "approvedSuspectedImageUrls",
      );
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
        approvedOriginalImageUrls,
        approvedSuspectedImageUrls,
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
          publicCategory:
            report.publicCategory || publicCategory(targetType),
          publicSubcategory:
            report.publicSubcategory ||
            legacyPublicSubcategory(
                targetType,
                report.robotType || "",
            ),
          targetType,
          comparisonLabel: comparisonLabel(targetType),
          title: `${report.originalEntityName || report.originalBrandName}: ` +
            comparisonLabel(targetType),
          usagePurpose: report.usagePurpose || "",
          technicalIdentity: report.technicalIdentity || "",
          counterfeitRisk: report.counterfeitRisk || "",
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
          originalImageUrls: approvedOriginalImageUrls,
          originalUrls: report.originalUrls || [],
          suspectedBrandName:
            report.suspectedBrandName || report.originalBrandName || "",
          suspectedProductName: report.suspectedProductName || "",
          claimedOriginCountry: report.claimedOriginCountry || "",
          allegedSupplyCountry: report.allegedSupplyCountry || "",
          suspectedImageUrls: approvedSuspectedImageUrls,
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


function buildDeleteCounterfeitTwinReport({db, admin}) {
  return onCall(async (request) => {
    const actor = await requirePlatformRole(
        request,
        db,
        ROLES.superAdmin,
    );
    const reportId = text(
        request.data?.reportId,
        "reportId",
        240,
        true,
    );
    if (reportId.includes("/")) {
      throw new HttpsError("invalid-argument", "reportId gecersiz.");
    }

    const deleteReason = text(
        request.data?.deleteReason,
        "deleteReason",
        1000,
        true,
    );
    if (deleteReason.length < 10) {
      throw new HttpsError(
          "invalid-argument",
          "Silme nedeni en az 10 karakter olmalidir.",
      );
    }

    const reportRef = db.collection(REPORTS).doc(reportId);
    const auditRef = db.collection(REPORT_DELETIONS).doc();

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reportRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Bildirim bulunamadi.");
      }

      const report = snapshot.data() || {};
      if (report.status === "published" || report.publicComparisonId) {
        throw new HttpsError(
            "failed-precondition",
            "Yayimlanmis bildirim silinemez.",
        );
      }

      const deletableStatuses = [
        "submitted",
        "under_review",
        "rejected",
      ];
      if (!deletableStatuses.includes(report.status)) {
        throw new HttpsError(
            "failed-precondition",
            "Bildirim silme icin uygun durumda degil.",
        );
      }

      const now = admin.firestore.Timestamp.now();
      transaction.create(auditRef, {
        reportId,
        previousStatus: report.status,
        deleteReason,
        deletedAt: now,
        deletedByUid: actor.uid,
        deletedByEmail: actor.email,
      });
      transaction.delete(reportRef);
    });

    logger.warn("Counterfeit twin report deleted", {
      reportId,
      adminUid: actor.uid,
    });
    return {reportId, status: "deleted"};
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
  buildDeleteCounterfeitTwinReport,
  buildListPublicCounterfeitTwinComparisons,
  buildGetPublicCounterfeitTwinComparison,
};
