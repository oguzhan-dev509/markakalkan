'use strict';

const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {assertAuthenticatedRequest} = require('./authorization');
const {createOdlaFirestoreAdapter} = require('./firestore_adapter');
const {createOdlaWorkspaceService} = require('./workspace_service');

const CALLABLE_OPTIONS = Object.freeze({
  region: 'europe-west3',
  enforceAppCheck: true,
});

const WRITE_OPERATIONS = new Set([
  'createOdlaVerificationCase',
  'appendOdlaChainOfCustodyEvent',
  'createOdlaTestRequest',
  'recordOdlaTestResult',
  'adjudicateOdlaFinding',
  'openOdlaAppeal',
  'resolveOdlaAppeal',
]);

function plainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function validateEnvelope(operation, data) {
  if (!plainObject(data)) throw new HttpsError('invalid-argument', 'ODLA request object required');
  if (Object.keys(data).length > 48) {
    throw new HttpsError('invalid-argument', 'ODLA request envelope too large');
  }
  if (WRITE_OPERATIONS.has(operation) &&
      (typeof data.operationId !== 'string' || !data.operationId || data.operationId.length > 160)) {
    throw new HttpsError('invalid-argument', 'Valid operationId required');
  }
  return data;
}

function mapError(error) {
  if (error instanceof HttpsError) return error;
  const code = error && typeof error.code === 'string' ? error.code : 'internal';
  const allowed = new Set([
    'unauthenticated', 'permission-denied', 'invalid-argument',
    'failed-precondition', 'not-found', 'already-exists',
    'resource-exhausted', 'aborted',
  ]);
  const mapped = allowed.has(code) ? code : 'internal';
  return new HttpsError(mapped, mapped === 'internal' ? 'ODLA operation failed closed' :
    (error.message || mapped));
}

async function execute(operation, request) {
  try {
    const authority = assertAuthenticatedRequest(request);
    const data = validateEnvelope(operation, request.data);
    const db = getFirestore();
    const adapter = createOdlaFirestoreAdapter({db, FieldValue});
    const service = createOdlaWorkspaceService({adapter});
    if (typeof service[operation] !== 'function') {
      throw Object.assign(new Error('Unknown ODLA operation'), {code: 'permission-denied'});
    }
    return await service[operation]({authority, data});
  } catch (error) {
    throw mapError(error);
  }
}

const createOdlaVerificationCase = onCall(
  CALLABLE_OPTIONS, (request) => execute('createOdlaVerificationCase', request)
);
const getOdlaVerificationWorkspace = onCall(
  CALLABLE_OPTIONS, (request) => execute('getOdlaVerificationWorkspace', request)
);
const appendOdlaChainOfCustodyEvent = onCall(
  CALLABLE_OPTIONS, (request) => execute('appendOdlaChainOfCustodyEvent', request)
);
const createOdlaTestRequest = onCall(
  CALLABLE_OPTIONS, (request) => execute('createOdlaTestRequest', request)
);
const recordOdlaTestResult = onCall(
  CALLABLE_OPTIONS, (request) => execute('recordOdlaTestResult', request)
);
const adjudicateOdlaFinding = onCall(
  CALLABLE_OPTIONS, (request) => execute('adjudicateOdlaFinding', request)
);
const openOdlaAppeal = onCall(
  CALLABLE_OPTIONS, (request) => execute('openOdlaAppeal', request)
);
const resolveOdlaAppeal = onCall(
  CALLABLE_OPTIONS, (request) => execute('resolveOdlaAppeal', request)
);

module.exports = {
  createOdlaVerificationCase,
  getOdlaVerificationWorkspace,
  appendOdlaChainOfCustodyEvent,
  createOdlaTestRequest,
  recordOdlaTestResult,
  adjudicateOdlaFinding,
  openOdlaAppeal,
  resolveOdlaAppeal,
};
