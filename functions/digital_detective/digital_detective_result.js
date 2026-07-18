const crypto = require("node:crypto");
const {defineSecret} = require("firebase-functions/params");

const N8N_DIGITAL_DETECTIVE_RESULT_TOKEN = defineSecret(
    "N8N_DIGITAL_DETECTIVE_RESULT_TOKEN",
);

const RESULT_CONTRACT_VERSION = "digital-detective-result-v1";
const RESULT_TOKEN_HEADER = "X-MarkaKalkan-Result-Token";
const MAX_OUTPUT_BYTES = 250000;
const MAX_METADATA_BYTES = 20000;

const AGENTS = Object.freeze([
  {
    code: "task_planner",
    sequence: 1,
    name: "Görev Planlama Ajanı",
  },
  {
    code: "digital_field_scanner",
    sequence: 2,
    name: "Dijital Saha Tarama Ajanı",
  },
  {
    code: "page_change_monitor",
    sequence: 3,
    name: "Sayfa Değişim İzleme Ajanı",
  },
  {
    code: "visual_matcher",
    sequence: 4,
    name: "Görsel Eşleştirme Ajanı",
  },
  {
    code: "text_language_analyzer",
    sequence: 5,
    name: "Metin ve Dil Analizi Ajanı",
  },
  {
    code: "seller_entity_linker",
    sequence: 6,
    name: "Satıcı ve Varlık Eşleştirme Ajanı",
  },
  {
    code: "domain_technical_trace",
    sequence: 7,
    name: "Alan Adı ve Teknik İz Ajanı",
  },
  {
    code: "price_commercial_pattern",
    sequence: 8,
    name: "Fiyat ve Ticari Örüntü Ajanı",
  },
  {
    code: "geographic_channel_analyzer",
    sequence: 9,
    name: "Coğrafi ve Kanal Analizi Ajanı",
  },
  {
    code: "evidence_validator",
    sequence: 10,
    name: "Delil Doğrulama Ajanı",
  },
  {
    code: "risk_prioritizer",
    sequence: 11,
    name: "Risk Önceliklendirme Ajanı",
  },
  {
    code: "reporting_intervention_preparer",
    sequence: 12,
    name: "Raporlama ve Müdahale Hazırlama Ajanı",
  },
]);

const AGENT_BY_CODE = new Map(
    AGENTS.map((agent) => [agent.code, agent]),
);
const EXPECTED_AGENT_CODES = Object.freeze(
    AGENTS.map((agent) => agent.code),
);

class ResultHttpError extends Error {
  constructor(statusCode, code, message) {
    super(message);
    this.name = "ResultHttpError";
    this.statusCode = statusCode;
    this.code = code;
  }
}

function cleanString(value, maximumLength = 1000) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim().slice(0, maximumLength);
}

function requireIdentifier(value, fieldName, maximumLength = 200) {
  const cleaned = cleanString(value, maximumLength);

  if (!cleaned || cleaned.includes("/")) {
    throw new ResultHttpError(
        400,
        "invalid_payload",
        `${fieldName} geçersiz.`,
    );
  }

  return cleaned;
}

function sha256Hex(value) {
  return crypto
      .createHash("sha256")
      .update(String(value), "utf8")
      .digest("hex");
}

function constantTimeEqual(left, right) {
  const leftDigest = crypto
      .createHash("sha256")
      .update(cleanString(left, 10000), "utf8")
      .digest();
  const rightDigest = crypto
      .createHash("sha256")
      .update(cleanString(right, 10000), "utf8")
      .digest();

  return crypto.timingSafeEqual(leftDigest, rightDigest);
}

function jsonCloneWithLimit(value, maximumBytes, fieldName) {
  let serialized;

  try {
    serialized = JSON.stringify(value);
  } catch (error) {
    throw new ResultHttpError(
        400,
        "invalid_payload",
        `${fieldName} JSON olarak işlenemedi.`,
    );
  }

  if (typeof serialized !== "string" ||
      Buffer.byteLength(serialized, "utf8") > maximumBytes) {
    throw new ResultHttpError(
        413,
        "payload_too_large",
        `${fieldName} izin verilen boyutu aşıyor.`,
    );
  }

  return JSON.parse(serialized);
}

function normalizeOutput(value) {
  if (typeof value === "string") {
    const cleaned = value.trim();

    if (!cleaned) {
      throw new ResultHttpError(
          400,
          "invalid_payload",
          "output boş olamaz.",
      );
    }

    if (Buffer.byteLength(cleaned, "utf8") > MAX_OUTPUT_BYTES) {
      throw new ResultHttpError(
          413,
          "payload_too_large",
          "output izin verilen boyutu aşıyor.",
      );
    }

    return {
      output: cleaned,
      outputType: "text",
    };
  }

  if (value === null || typeof value !== "object") {
    throw new ResultHttpError(
        400,
        "invalid_payload",
        "output metin, nesne veya liste olmalıdır.",
    );
  }

  return {
    output: jsonCloneWithLimit(
        value,
        MAX_OUTPUT_BYTES,
        "output",
    ),
    outputType: Array.isArray(value) ? "list" : "object",
  };
}

function parseRequestBody(request) {
  const value = request.body;

  if (value && typeof value === "object" && !Buffer.isBuffer(value)) {
    return value;
  }

  const raw = Buffer.isBuffer(value) ?
    value.toString("utf8") :
    cleanString(value, MAX_OUTPUT_BYTES + MAX_METADATA_BYTES);

  if (!raw) {
    throw new ResultHttpError(
        400,
        "invalid_json",
        "JSON gövdesi bulunamadı.",
    );
  }

  try {
    return JSON.parse(raw);
  } catch (error) {
    throw new ResultHttpError(
        400,
        "invalid_json",
        "JSON gövdesi geçersiz.",
    );
  }
}

function normalizeResultPayload(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new ResultHttpError(
        400,
        "invalid_payload",
        "Sonuç zarfı nesne olmalıdır.",
    );
  }

  const contractVersion = cleanString(value.contractVersion, 100);

  if (contractVersion !== RESULT_CONTRACT_VERSION) {
    throw new ResultHttpError(
        400,
        "unsupported_contract",
        "Sonuç sözleşmesi desteklenmiyor.",
    );
  }

  const tenantId = requireIdentifier(value.tenantId, "tenantId");
  const brandId = requireIdentifier(value.brandId, "brandId");

  if (brandId !== tenantId) {
    throw new ResultHttpError(
        400,
        "invalid_payload",
        "brandId ile tenantId eşleşmiyor.",
    );
  }

  const taskId = requireIdentifier(value.taskId, "taskId");
  const executionId = requireIdentifier(
      String(value.executionId ?? ""),
      "executionId",
  );
  const agentCode = cleanString(value.agentCode, 100);
  const agent = AGENT_BY_CODE.get(agentCode);

  if (!agent) {
    throw new ResultHttpError(
        400,
        "invalid_agent",
        "agentCode tanınmıyor.",
    );
  }

  if (value.agentSequence !== undefined &&
      Number(value.agentSequence) !== agent.sequence) {
    throw new ResultHttpError(
        400,
        "invalid_agent",
        "agentSequence ile agentCode eşleşmiyor.",
    );
  }

  const status = cleanString(value.status, 40).toLowerCase();

  if (status !== "completed" && status !== "failed") {
    throw new ResultHttpError(
        400,
        "invalid_status",
        "status completed veya failed olmalıdır.",
    );
  }

  const normalizedOutput = normalizeOutput(value.output);
  const metadata = value.metadata === undefined ||
      value.metadata === null ?
    {} :
    jsonCloneWithLimit(
        value.metadata,
        MAX_METADATA_BYTES,
        "metadata",
    );

  if (!metadata || typeof metadata !== "object" ||
      Array.isArray(metadata)) {
    throw new ResultHttpError(
        400,
        "invalid_payload",
        "metadata nesne olmalıdır.",
    );
  }

  return {
    contractVersion,
    tenantId,
    brandId,
    taskId,
    executionId,
    agentCode: agent.code,
    agentSequence: agent.sequence,
    agentName: agent.name,
    status,
    output: normalizedOutput.output,
    outputType: normalizedOutput.outputType,
    metadata,
    workflowId: cleanString(value.workflowId, 200) || null,
    workflowName: cleanString(value.workflowName, 300) || null,
    workflowVersion: cleanString(value.workflowVersion, 200) || null,
  };
}

function getRequestHeader(request, headerName) {
  if (request && typeof request.get === "function") {
    return cleanString(request.get(headerName), 10000);
  }

  const headers = request && request.headers;
  const lowerName = headerName.toLowerCase();

  if (!headers || typeof headers !== "object") {
    return "";
  }

  const value = headers[lowerName] ?? headers[headerName];

  if (Array.isArray(value)) {
    return cleanString(value[0], 10000);
  }

  return cleanString(value, 10000);
}

function uniqueSortedCodes(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return [...new Set(
      value
          .map((item) => cleanString(item, 100))
          .filter((item) => AGENT_BY_CODE.has(item)),
  )].sort();
}

function calculateExecutionStatus({
  completedAgentCodes,
  failedAgentCodes,
}) {
  const receivedCodes = uniqueSortedCodes([
    ...completedAgentCodes,
    ...failedAgentCodes,
  ]);

  if (receivedCodes.length < EXPECTED_AGENT_CODES.length) {
    return "running";
  }

  return failedAgentCodes.length > 0 ? "failed" : "completed";
}

async function persistDigitalDetectiveResult({
  db,
  admin,
  payload,
}) {
  const fieldValue = admin.firestore.FieldValue;
  const taskRef = db
      .collection("brands")
      .doc(payload.tenantId)
      .collection("digitalDetectiveTasks")
      .doc(payload.taskId);
  const executionDocumentId = sha256Hex(payload.executionId);
  const resultDocumentId = sha256Hex(
      `${payload.executionId}|${payload.agentCode}`,
  );
  const executionRef = taskRef
      .collection("resultExecutions")
      .doc(executionDocumentId);
  const resultRef = taskRef
      .collection("agentResults")
      .doc(resultDocumentId);

  return db.runTransaction(async (transaction) => {
    const taskSnapshot = await transaction.get(taskRef);
    const resultSnapshot = await transaction.get(resultRef);
    const executionSnapshot = await transaction.get(executionRef);

    if (!taskSnapshot.exists) {
      throw new ResultHttpError(
          404,
          "task_not_found",
          "Dijital Dedektif görevi bulunamadı.",
      );
    }

    const taskData = taskSnapshot.data() || {};

    if (cleanString(taskData.ownerUid, 200) !== payload.tenantId) {
      throw new ResultHttpError(
          404,
          "task_not_found",
          "Dijital Dedektif görevi bulunamadı.",
      );
    }

    if (resultSnapshot.exists) {
      const existing = resultSnapshot.data() || {};

      if (existing.executionId !== payload.executionId ||
          existing.agentCode !== payload.agentCode) {
        throw new ResultHttpError(
            409,
            "result_collision",
            "Sonuç kimliği çakışması oluştu.",
        );
      }

      const executionData = executionSnapshot.exists ?
        executionSnapshot.data() || {} :
        {};

      return {
        duplicate: true,
        taskStatus: cleanString(taskData.status, 40) || "running",
        receivedAgentCount:
          Number.isInteger(executionData.receivedAgentCount) ?
            executionData.receivedAgentCount :
            0,
        expectedAgentCount: EXPECTED_AGENT_CODES.length,
      };
    }

    const executionData = executionSnapshot.exists ?
      executionSnapshot.data() || {} :
      {};

    if (executionSnapshot.exists &&
        executionData.executionId !== payload.executionId) {
      throw new ResultHttpError(
          409,
          "execution_collision",
          "Yürütme kimliği çakışması oluştu.",
      );
    }

    const completedAgentCodes = uniqueSortedCodes(
        executionData.completedAgentCodes,
    );
    const failedAgentCodes = uniqueSortedCodes(
        executionData.failedAgentCodes,
    );

    const nextCompletedAgentCodes = completedAgentCodes
        .filter((code) => code !== payload.agentCode);
    const nextFailedAgentCodes = failedAgentCodes
        .filter((code) => code !== payload.agentCode);

    if (payload.status === "completed") {
      nextCompletedAgentCodes.push(payload.agentCode);
    } else {
      nextFailedAgentCodes.push(payload.agentCode);
    }

    const normalizedCompletedCodes = uniqueSortedCodes(
        nextCompletedAgentCodes,
    );
    const normalizedFailedCodes = uniqueSortedCodes(
        nextFailedAgentCodes,
    );
    const receivedAgentCodes = uniqueSortedCodes([
      ...normalizedCompletedCodes,
      ...normalizedFailedCodes,
    ]);
    const executionStatus = calculateExecutionStatus({
      completedAgentCodes: normalizedCompletedCodes,
      failedAgentCodes: normalizedFailedCodes,
    });
    const isFinished = executionStatus !== "running";

    transaction.set(resultRef, {
      contractVersion: payload.contractVersion,
      tenantId: payload.tenantId,
      brandId: payload.brandId,
      taskId: payload.taskId,
      executionId: payload.executionId,
      agentCode: payload.agentCode,
      agentSequence: payload.agentSequence,
      agentName: payload.agentName,
      status: payload.status,
      outputType: payload.outputType,
      output: payload.output,
      metadata: payload.metadata,
      workflowId: payload.workflowId,
      workflowName: payload.workflowName,
      workflowVersion: payload.workflowVersion,
      receivedAt: fieldValue.serverTimestamp(),
    });

    const executionWrite = {
      contractVersion: payload.contractVersion,
      tenantId: payload.tenantId,
      brandId: payload.brandId,
      taskId: payload.taskId,
      executionId: payload.executionId,
      expectedAgentCodes: EXPECTED_AGENT_CODES,
      expectedAgentCount: EXPECTED_AGENT_CODES.length,
      receivedAgentCodes,
      receivedAgentCount: receivedAgentCodes.length,
      completedAgentCodes: normalizedCompletedCodes,
      completedAgentCount: normalizedCompletedCodes.length,
      failedAgentCodes: normalizedFailedCodes,
      failedAgentCount: normalizedFailedCodes.length,
      status: executionStatus,
      workflowId: payload.workflowId,
      workflowName: payload.workflowName,
      workflowVersion: payload.workflowVersion,
      updatedAt: fieldValue.serverTimestamp(),
    };

    if (!executionSnapshot.exists) {
      executionWrite.createdAt = fieldValue.serverTimestamp();
    }

    if (isFinished) {
      executionWrite.completedAt = fieldValue.serverTimestamp();
    }

    transaction.set(executionRef, executionWrite, {merge: true});

    const taskUpdate = {
      status: executionStatus,
      processedCount: receivedAgentCodes.length,
      resultProcessing: {
        contractVersion: payload.contractVersion,
        executionId: payload.executionId,
        expectedAgentCount: EXPECTED_AGENT_CODES.length,
        receivedAgentCount: receivedAgentCodes.length,
        completedAgentCount: normalizedCompletedCodes.length,
        failedAgentCount: normalizedFailedCodes.length,
        status: executionStatus,
        lastAgentCode: payload.agentCode,
        lastAgentStatus: payload.status,
        workflowId: payload.workflowId,
        workflowName: payload.workflowName,
        workflowVersion: payload.workflowVersion,
        updatedAt: fieldValue.serverTimestamp(),
      },
      updatedAt: fieldValue.serverTimestamp(),
    };

    if (isFinished) {
      taskUpdate.completedAt = fieldValue.serverTimestamp();
    }

    transaction.update(taskRef, taskUpdate);

    return {
      duplicate: false,
      taskStatus: executionStatus,
      receivedAgentCount: receivedAgentCodes.length,
      expectedAgentCount: EXPECTED_AGENT_CODES.length,
    };
  });
}

function sendJson(response, statusCode, body) {
  response.status(statusCode).json(body);
}

function buildReceiveDigitalDetectiveResult({
  db,
  admin,
  onRequest,
  logger,
  resultToken = N8N_DIGITAL_DETECTIVE_RESULT_TOKEN,
}) {
  return onRequest(
      {
        secrets: [resultToken],
        timeoutSeconds: 60,
        maxInstances: 5,
      },
      async (request, response) => {
        response.set("Cache-Control", "no-store");

        if (request.method !== "POST") {
          response.set("Allow", "POST");
          sendJson(response, 405, {
            ok: false,
            code: "method_not_allowed",
          });
          return;
        }

        const expectedToken = cleanString(resultToken.value(), 10000);
        const suppliedToken = getRequestHeader(
            request,
            RESULT_TOKEN_HEADER,
        );

        if (!expectedToken ||
            !suppliedToken ||
            !constantTimeEqual(expectedToken, suppliedToken)) {
          logger.warn("Digital Detective result authorization failed");
          sendJson(response, 403, {
            ok: false,
            code: "forbidden",
          });
          return;
        }

        try {
          const payload = normalizeResultPayload(
              parseRequestBody(request),
          );
          const result = await persistDigitalDetectiveResult({
            db,
            admin,
            payload,
          });

          logger.info("Digital Detective agent result accepted", {
            tenantId: payload.tenantId,
            taskId: payload.taskId,
            executionId: payload.executionId,
            agentCode: payload.agentCode,
            agentStatus: payload.status,
            duplicate: result.duplicate,
            taskStatus: result.taskStatus,
            receivedAgentCount: result.receivedAgentCount,
          });

          sendJson(response, 200, {
            ok: true,
            duplicate: result.duplicate,
            taskId: payload.taskId,
            executionId: payload.executionId,
            agentCode: payload.agentCode,
            taskStatus: result.taskStatus,
            receivedAgentCount: result.receivedAgentCount,
            expectedAgentCount: result.expectedAgentCount,
          });
        } catch (error) {
          if (error instanceof ResultHttpError) {
            logger.warn("Digital Detective result rejected", {
              code: error.code,
              message: error.message,
            });
            sendJson(response, error.statusCode, {
              ok: false,
              code: error.code,
              message: error.message,
            });
            return;
          }

          const message = error instanceof Error ?
            error.message :
            String(error);

          logger.error("Digital Detective result processing failed", {
            error: message,
          });
          sendJson(response, 500, {
            ok: false,
            code: "internal",
          });
        }
      },
  );
}

module.exports = {
  AGENTS,
  EXPECTED_AGENT_CODES,
  N8N_DIGITAL_DETECTIVE_RESULT_TOKEN,
  RESULT_CONTRACT_VERSION,
  RESULT_TOKEN_HEADER,
  ResultHttpError,
  buildReceiveDigitalDetectiveResult,
  calculateExecutionStatus,
  constantTimeEqual,
  normalizeResultPayload,
  persistDigitalDetectiveResult,
  sha256Hex,
};
