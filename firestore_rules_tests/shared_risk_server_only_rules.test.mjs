import {after, before, beforeEach, test} from 'node:test';
import fs from 'node:fs';

import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';

const projectId = 'demo-markakalkan-rst-0h';
const collections = [
  'shared_risk_signals',
  'shared_risk_assessments',
  'shared_case_candidates',
  'shared_risk_persistence_receipts',
  'shared_risk_persistence_audit_events',
];

let environment;

function requireEmulator() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || '';
  if (!/^(127\.0\.0\.1|localhost|\[?::1\]?):\d+$/.test(host)) {
    throw new Error('FIRESTORE_EMULATOR_HOST loopback endpoint is required');
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('Production credentials are forbidden in emulator tests');
  }
}

before(async () => {
  requireEmulator();
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        new URL('../firestore.rules', import.meta.url),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

for (const collection of collections) {
  test(`${collection}: unauthenticated create is denied`, async () => {
    const db = environment.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, collection, 'record-1'), {value: 1}));
  });

  test(`${collection}: authenticated create is denied`, async () => {
    const db = environment.authenticatedContext('tenant-1').firestore();
    await assertFails(setDoc(doc(db, collection, 'record-1'), {value: 1}));
  });

  test(`${collection}: authenticated read is denied`, async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), collection, 'record-1'),
        {tenantId: 'tenant-1'});
    });
    const db = environment.authenticatedContext('tenant-1').firestore();
    await assertFails(getDoc(doc(db, collection, 'record-1')));
  });

  test(`${collection}: authenticated update is denied`, async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), collection, 'record-1'),
        {tenantId: 'tenant-1'});
    });
    const db = environment.authenticatedContext('tenant-1').firestore();
    await assertFails(updateDoc(doc(db, collection, 'record-1'), {value: 2}));
  });

  test(`${collection}: authenticated delete is denied`, async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), collection, 'record-1'),
        {tenantId: 'tenant-1'});
    });
    const db = environment.authenticatedContext('tenant-1').firestore();
    await assertFails(deleteDoc(doc(db, collection, 'record-1')));
  });
}
