import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import fs from 'node:fs';

import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const projectId = 'demo-markakalkan-case-evidence-server-only';
const caseCollections = [
  'case_files',
  'case_events',
  'case_evidence_refs',
  'case_audit_events',
];
const rules = fs.readFileSync(
  new URL('../firestore.rules', import.meta.url),
  'utf8',
);

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

async function seed(collectionName, documentId = 'record-1') {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), collectionName, documentId), {
      tenantId: 'tenant-1',
      value: 1,
    });
  });
}

before(async () => {
  requireEmulator();
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {rules},
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

test('case collections rely on the documents-scope default deny', () => {
  for (const collectionName of caseCollections) {
    const explicitMatch = new RegExp(
      `match\\s+\\/${collectionName}\\s*\\/\\s*\\{[^}]+\\}\\s*\\{`,
      'm',
    );
    assert.doesNotMatch(rules, explicitMatch);
  }

  const catchAll = rules.match(
    /match\s+\/\{document\s*=\s*\*\*\}\s*\{([^}]*)\}/m,
  );
  assert.ok(catchAll, 'documents-scope recursive catch-all must exist');
  assert.match(
    catchAll[1],
    /allow\s+read\s*,\s*write\s*:\s*if\s+false\s*;/m,
  );

  const registryMatch = rules.match(
    /match\s+\/\{serverRegistryCollection\}\s*\/\s*\{registryDocumentId\}\s*\{([\s\S]*?)\n\s*\}/m,
  );
  assert.ok(registryMatch, 'variable top-level registry match must exist');
  for (const collectionName of caseCollections) {
    assert.doesNotMatch(
      registryMatch[1],
      new RegExp(`['\"]${collectionName}['\"]`),
    );
  }
});

for (const collectionName of caseCollections) {
  test(`${collectionName}: unauthenticated create is denied`, async () => {
    const db = environment.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, collectionName, 'record-1'), {value: 1}));
  });

  test(`${collectionName}: authenticated create is denied`, async () => {
    const db = environment.authenticatedContext('tenant-1').firestore();
    await assertFails(setDoc(doc(db, collectionName, 'record-1'), {value: 1}));
  });

  test(`${collectionName}: rules-disabled seed succeeds`, async () => {
    await seed(collectionName);
    await environment.withSecurityRulesDisabled(async (context) => {
      const snapshot = await getDoc(
        doc(context.firestore(), collectionName, 'record-1'),
      );
      assert.equal(snapshot.exists(), true);
    });
  });

  test(`${collectionName}: authenticated get is denied`, async () => {
    await seed(collectionName);
    const db = environment.authenticatedContext('tenant-1').firestore();
    await assertFails(getDoc(doc(db, collectionName, 'record-1')));
  });

  test(`${collectionName}: authenticated list is denied`, async () => {
    await seed(collectionName);
    const db = environment.authenticatedContext('tenant-1').firestore();
    await assertFails(getDocs(query(
      collection(db, collectionName),
      where('tenantId', '==', 'tenant-1'),
    )));
  });

  test(`${collectionName}: authenticated update is denied`, async () => {
    await seed(collectionName);
    const db = environment.authenticatedContext('tenant-1').firestore();
    await assertFails(updateDoc(doc(db, collectionName, 'record-1'), {value: 2}));
  });

  test(`${collectionName}: authenticated delete is denied`, async () => {
    await seed(collectionName);
    const db = environment.authenticatedContext('tenant-1').firestore();
    await assertFails(deleteDoc(doc(db, collectionName, 'record-1')));
  });
}

test('case_files nested documents deny authenticated get and write', async () => {
  const nestedPath = ['case_files', 'case-1', 'nested_probe', 'record-1'];
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), ...nestedPath), {value: 1});
  });

  const db = environment.authenticatedContext('tenant-1').firestore();
  const nestedDocument = doc(db, ...nestedPath);
  await assertFails(getDoc(nestedDocument));
  await assertFails(updateDoc(nestedDocument, {value: 2}));
  await assertFails(setDoc(
    doc(db, 'case_files', 'case-1', 'nested_probe', 'record-2'),
    {value: 1},
  ));
});
