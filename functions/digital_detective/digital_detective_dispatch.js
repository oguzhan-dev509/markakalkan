const {defineSecret} = require("firebase-functions/params");

const N8N_DIGITAL_DETECTIVE_WEBHOOK_TOKEN = defineSecret(
    "N8N_DIGITAL_DETECTIVE_WEBHOOK_TOKEN",
);

const DIGITAL_DETECTIVE_WEBHOOK_URL =
    "https://sofrasofra-n8n.app.n8n.cloud/webhook/" +
    "markakalkan/digital-detective/task-created";

const TASK_DOCUMENT =
    "brands/{brandUid}/digitalDetectiveTasks/{taskId}";

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function cleanStringList(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
      .map((item) => cleanString(item))
      .filter((item) => item.length > 0)
      .slice(0, 100);
}

function timestampToIso(value, fallbackIso) {
  if (value && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = new Date(value);

    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }

  return fallbackIso;
}

function normalizePriority(riskLevel) {
  const normalized = cleanString(riskLevel).toLowerCase();

  if (normalized === "critical" || normalized === "high") {
    return "high";
  }

  if (normalized === "medium") {
    return "medium";
  }

  return "low";
}

function formatList(label, values) {
  const cleaned = cleanStringList(values);

  return cleaned.length > 0 ? `${label}: ${cleaned.join(", ")}` : "";
}

function formatPriceRange(data) {
  const minimum = Number.isFinite(data.minimumPrice) ?
    data.minimumPrice :
    null;
  const maximum = Number.isFinite(data.maximumPrice) ?
    data.maximumPrice :
    null;

  if (minimum === null && maximum === null) {
    return "";
  }

  const currency = cleanString(data.currency) || "TRY";
  const minimumText = minimum === null ? "belirtilmedi" : String(minimum);
  const maximumText = maximum === null ? "belirtilmedi" : String(maximum);

  return `Fiyat aralığı: ${minimumText}-${maximumText} ${currency}`;
}

function buildTargetSummary(data) {
  const parts = [
    cleanString(data.taskName) ?
      `Operasyon başlığı: ${cleanString(data.taskName)}` :
      "",
    cleanString(data.objective) ?
      `Operasyon amacı: ${cleanString(data.objective)}` :
      "",
    cleanString(data.brandName) ?
      `Marka: ${cleanString(data.brandName)}` :
      "",
    cleanString(data.productName) ?
      `Ürün: ${cleanString(data.productName)}` :
      "",
    cleanString(data.targetSeller) ?
      `Hedef satıcı/mağaza: ${cleanString(data.targetSeller)}` :
      "",
    cleanString(data.initialUrl) ?
      `Başlangıç URL'si: ${cleanString(data.initialUrl)}` :
      "",
    cleanString(data.categoryId) ?
      `Kategori: ${cleanString(data.categoryId)}` :
      "",
    cleanString(data.subcategory) ?
      `Alt kategori: ${cleanString(data.subcategory)}` :
      "",
    formatList("İhlal türleri", data.violationIds),
    formatList("Kaynaklar", data.sources),
    formatList("Arama terimleri", data.searchTerms),
    formatList("Hariç tutulan terimler", data.excludedTerms),
    formatList("Ülkeler", data.countries),
    formatList("Şehirler", data.cities),
    formatPriceRange(data),
    cleanString(data.frequency) ?
      `Tarama sıklığı: ${cleanString(data.frequency)}` :
      "",
    cleanString(data.riskLevel) ?
      `Risk seviyesi: ${cleanString(data.riskLevel)}` :
      "",
  ].filter((item) => item.length > 0);

  return parts.join(" | ").slice(0, 8000);
}

function buildContext(data, fallbackIso) {
  return {
    taskName: cleanString(data.taskName),
    brandName: cleanString(data.brandName),
    productName: cleanString(data.productName),
    categoryId: cleanString(data.categoryId),
    subcategory: cleanString(data.subcategory) || null,
    violationIds: cleanStringList(data.violationIds),
    sources: cleanStringList(data.sources),
    searchTerms: cleanStringList(data.searchTerms),
    excludedTerms: cleanStringList(data.excludedTerms),
    countries: cleanStringList(data.countries),
    cities: cleanStringList(data.cities),
    minimumPrice: Number.isFinite(data.minimumPrice) ?
      data.minimumPrice :
      null,
    maximumPrice: Number.isFinite(data.maximumPrice) ?
      data.maximumPrice :
      null,
    currency: cleanString(data.currency),
    frequency: cleanString(data.frequency),
    riskLevel: cleanString(data.riskLevel),
    startDate: timestampToIso(data.startDate, fallbackIso),
    endDate: data.endDate == null ?
      null :
      timestampToIso(data.endDate, fallbackIso),
  };
}

function buildWebhookPayload({
  brandUid,
  taskId,
  taskData,
  fallbackIso,
}) {
  return {
    taskId,
    tenantId: brandUid,
    brandId: brandUid,
    taskType: "digital_market_intelligence",
    target: buildTargetSummary(taskData),
    priority: normalizePriority(taskData.riskLevel),
    createdAt: timestampToIso(taskData.createdAt, fallbackIso),
    context: buildContext(taskData, fallbackIso),
  };
}

function safeResponseText(value) {
  return cleanString(value).replace(/\s+/g, " ").slice(0, 1000);
}

function buildDispatchDigitalDetectiveTask({
  db,
  admin,
  onDocumentCreated,
  logger,
  fetchImpl,
  webhookToken = N8N_DIGITAL_DETECTIVE_WEBHOOK_TOKEN,
  webhookUrl = DIGITAL_DETECTIVE_WEBHOOK_URL,
}) {
  const requestFetch = fetchImpl || global.fetch;

  if (typeof requestFetch !== "function") {
    throw new Error("Global fetch is not available");
  }

  return onDocumentCreated(
      {
        document: TASK_DOCUMENT,
        secrets: [webhookToken],
        retry: false,
        timeoutSeconds: 60,
      },
      async (event) => {
        const snapshot = event.data;

        if (!snapshot) {
          logger.warn("Digital Detective task event has no snapshot", {
            eventId: event.id || null,
          });
          return;
        }

        const brandUid = cleanString(event.params.brandUid);
        const taskId = cleanString(event.params.taskId);
        const eventId = cleanString(event.id);

        if (!brandUid || !taskId) {
          logger.error("Digital Detective task event is missing parameters", {
            eventId: eventId || null,
            brandUid: brandUid || null,
            taskId: taskId || null,
          });
          return;
        }

        const taskRef = snapshot.ref;
        const now = admin.firestore.Timestamp.now();
        const fieldValue = admin.firestore.FieldValue;
        const claim = await db.runTransaction(async (transaction) => {
          const currentSnapshot = await transaction.get(taskRef);

          if (!currentSnapshot.exists) {
            return {claimed: false, reason: "task_missing"};
          }

          const currentData = currentSnapshot.data() || {};
          const dispatch = currentData.dispatch || {};

          if (dispatch.status === "dispatching" ||
              dispatch.status === "dispatched") {
            return {
              claimed: false,
              reason: `already_${dispatch.status}`,
            };
          }

          if (currentData.status !== "queued" &&
              currentData.status !== "failed") {
            return {
              claimed: false,
              reason: `status_${cleanString(currentData.status) || "unknown"}`,
            };
          }

          const attemptCount = Number.isInteger(dispatch.attemptCount) ?
            dispatch.attemptCount + 1 :
            1;

          transaction.update(taskRef, {
            status: "running",
            ["dispatch.status"]: "dispatching",
            ["dispatch.eventId"]: eventId || null,
            ["dispatch.attemptCount"]: attemptCount,
            ["dispatch.claimedAt"]: fieldValue.serverTimestamp(),
            ["dispatch.lastError"]: null,
            updatedAt: fieldValue.serverTimestamp(),
          });

          return {
            claimed: true,
            taskData: currentData,
            attemptCount,
          };
        });

        if (!claim.claimed) {
          logger.info("Digital Detective dispatch skipped", {
            eventId: eventId || null,
            brandUid,
            taskId,
            reason: claim.reason,
          });
          return;
        }

        const fallbackIso = now.toDate().toISOString();
        const payload = buildWebhookPayload({
          brandUid,
          taskId,
          taskData: claim.taskData,
          fallbackIso,
        });

        const token = cleanString(webhookToken.value());

        if (!token) {
          const message = "Webhook token is empty";

          await taskRef.update({
            status: "failed",
            ["dispatch.status"]: "failed",
            ["dispatch.failedAt"]: fieldValue.serverTimestamp(),
            ["dispatch.lastError"]: message,
            updatedAt: fieldValue.serverTimestamp(),
          });

          throw new Error(message);
        }

        try {
          const response = await requestFetch(webhookUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-MarkaKalkan-Token": token,
            },
            body: JSON.stringify(payload),
          });
          const responseText = safeResponseText(await response.text());

          if (!response.ok) {
            const message =
              `n8n webhook returned HTTP ${response.status}` +
              (responseText ? `: ${responseText}` : "");

            await taskRef.update({
              status: "failed",
              ["dispatch.status"]: "failed",
              ["dispatch.httpStatus"]: response.status,
              ["dispatch.failedAt"]: fieldValue.serverTimestamp(),
              ["dispatch.lastError"]: message.slice(0, 1000),
              updatedAt: fieldValue.serverTimestamp(),
            });

            throw new Error(message);
          }

          await taskRef.update({
            status: "running",
            ["dispatch.status"]: "dispatched",
            ["dispatch.httpStatus"]: response.status,
            ["dispatch.responseBody"]: responseText || null,
            ["dispatch.dispatchedAt"]: fieldValue.serverTimestamp(),
            ["dispatch.lastError"]: null,
            updatedAt: fieldValue.serverTimestamp(),
          });

          logger.info("Digital Detective task dispatched", {
            eventId: eventId || null,
            brandUid,
            taskId,
            attemptCount: claim.attemptCount,
            httpStatus: response.status,
          });
        } catch (error) {
          const message = error instanceof Error ?
            error.message :
            String(error);

          const latestSnapshot = await taskRef.get();
          const latestData = latestSnapshot.exists ?
            latestSnapshot.data() || {} :
            {};
          const latestDispatch = latestData.dispatch || {};

          if (latestDispatch.status !== "failed") {
            await taskRef.update({
              status: "failed",
              ["dispatch.status"]: "failed",
              ["dispatch.failedAt"]: fieldValue.serverTimestamp(),
              ["dispatch.lastError"]: message.slice(0, 1000),
              updatedAt: fieldValue.serverTimestamp(),
            });
          }

          logger.error("Digital Detective task dispatch failed", {
            eventId: eventId || null,
            brandUid,
            taskId,
            error: message,
          });

          throw error;
        }
      },
  );
}

module.exports = {
  DIGITAL_DETECTIVE_WEBHOOK_URL,
  N8N_DIGITAL_DETECTIVE_WEBHOOK_TOKEN,
  TASK_DOCUMENT,
  buildDispatchDigitalDetectiveTask,
  buildTargetSummary,
  buildWebhookPayload,
  normalizePriority,
  safeResponseText,
  timestampToIso,
};
