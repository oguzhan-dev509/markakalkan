const OPERATION_DOCUMENT =
    "brands/{brandUid}/aiFieldOperations/{operationId}";
const BRIDGE_VERSION = "ai-field-operation-v1";

function cleanString(value, maximumLength = 2000) {
  return typeof value === "string" ?
    value.trim().slice(0, maximumLength) :
    "";
}

function normalizePriority(value) {
  const normalized = cleanString(value, 40).toLowerCase();

  if (normalized === "critical" || normalized === "high") {
    return "high";
  }

  if (normalized === "normal") {
    return "medium";
  }

  return "low";
}

function plannerInputFromSnapshot(snapshot) {
  if (!snapshot || !snapshot.exists) {
    return {};
  }

  const data = snapshot.data() || {};
  return data.input && typeof data.input === "object" &&
    !Array.isArray(data.input) ? data.input : {};
}

function buildTaskName(operationData) {
  const title = cleanString(operationData.title, 180);

  if (title) {
    return title;
  }

  return cleanString(operationData.objective, 180);
}

function buildDigitalDetectiveTaskData({
  brandUid,
  operationId,
  operationData,
  plannerInput,
  serverTimestamp,
}) {
  const operationTimestamp = operationData.createdAt || serverTimestamp;

  const taskData = {
    taskName: buildTaskName(operationData),
    frequency: "once",
    riskLevel: normalizePriority(operationData.priority),
    startDate: operationTimestamp,
    endDate: null,
    status: "queued",
    ownerUid: brandUid,
    ownerEmail: null,
    resultCount: 0,
    processedCount: 0,
    createdAt: operationTimestamp,
    updatedAt: serverTimestamp,
    objective: cleanString(operationData.objective, 2000),
    sourceType: "ai_field_operation",
    sourceOperationId: operationId,
    bridgeVersion: BRIDGE_VERSION,
  };

  const optionalStrings = {
    brandName: cleanString(plannerInput.brandName, 160),
    productName: cleanString(plannerInput.productName, 240),
    targetSeller: cleanString(plannerInput.sellerName, 500),
    initialUrl: cleanString(plannerInput.targetUrl, 2000),
  };

  for (const [field, value] of Object.entries(optionalStrings)) {
    if (value) {
      taskData[field] = value;
    }
  }

  return taskData;
}

function buildAiFieldOperationBridge({
  db,
  admin,
  onDocumentCreated,
  logger,
}) {
  return onDocumentCreated(
      {
        document: OPERATION_DOCUMENT,
        retry: true,
        timeoutSeconds: 60,
      },
      async (event) => {
        const snapshot = event?.data;

        if (!snapshot) {
          logger.warn("AI field operation bridge event has no snapshot", {
            eventId: event?.id || null,
          });
          return;
        }

        const params = event?.params || {};
        const brandUid = cleanString(params.brandUid, 200);
        const operationId = cleanString(params.operationId, 200);

        if (!brandUid || !operationId) {
          logger.error("AI field operation bridge is missing path parameters", {
            eventId: event?.id || null,
          });
          return;
        }

        const operationData = snapshot.data() || {};

        if (!buildTaskName(operationData)) {
          logger.warn("AI field operation has no usable task name", {
            eventId: event?.id || null,
            brandUid,
            operationId,
          });
          return;
        }

        const operationRef = snapshot.ref;
        const plannerRef = operationRef.collection("agentTasks")
            .doc("task_planner");
        const taskRef = db.collection("brands")
            .doc(brandUid)
            .collection("digitalDetectiveTasks")
            .doc(operationId);
        const fieldValue = admin.firestore.FieldValue;
        const result = await db.runTransaction(async (transaction) => {
          const taskSnapshot = await transaction.get(taskRef);

          if (taskSnapshot.exists) {
            return {created: false};
          }

          const plannerSnapshot = await transaction.get(plannerRef);
          const taskData = buildDigitalDetectiveTaskData({
            brandUid,
            operationId,
            operationData,
            plannerInput: plannerInputFromSnapshot(plannerSnapshot),
            serverTimestamp: fieldValue.serverTimestamp(),
          });

          transaction.create(taskRef, taskData);
          return {created: true};
        });

        logger.info("AI field operation bridge completed", {
          eventId: event?.id || null,
          brandUid,
          operationId,
          created: result.created,
        });
      },
  );
}

module.exports = {
  BRIDGE_VERSION,
  OPERATION_DOCUMENT,
  buildAiFieldOperationBridge,
  buildDigitalDetectiveTaskData,
  buildTaskName,
  normalizePriority,
  plannerInputFromSnapshot,
};
