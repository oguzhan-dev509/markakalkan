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
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-markakalkan-hrt-1d-1f';
const rules = fs.readFileSync(
  new URL('../firestore.rules', import.meta.url),
  'utf8',
);

const pathSpecs = [
  {
    label: 'risk_scan_runs root',
    documentPath: ['risk_scan_runs', 'run-1'],
    collectionPath: ['risk_scan_runs'],
  },
  {
    label: 'risk_scan_runs channels',
    documentPath: ['risk_scan_runs', 'run-1', 'channels', 'marketplaces'],
    collectionPath: ['risk_scan_runs', 'run-1', 'channels'],
  },
  {
    label: 'risk_scan_runs observations',
    documentPath: ['risk_scan_runs', 'run-1', 'observations', 'observation-1'],
    collectionPath: ['risk_scan_runs', 'run-1', 'observations'],
  },
  {
    label: 'risk_scan_runs findings',
    documentPath: ['risk_scan_runs', 'run-1', 'findings', 'finding-1'],
    collectionPath: ['risk_scan_runs', 'run-1', 'findings'],
  },
  {
    label: 'risk_scan_reports',
    documentPath: ['risk_scan_reports', 'report-1'],
    collectionPath: ['risk_scan_reports'],
  },
  {
    label: 'risk_scan_claims',
    documentPath: ['risk_scan_claims', 'claim-1'],
    collectionPath: ['risk_scan_claims'],
  },
  {
    label: 'risk_scan_rate_limits',
    documentPath: ['risk_scan_rate_limits', 'bucket-1'],
    collectionPath: ['risk_scan_rate_limits'],
  },
  {
    label: 'risk_scan_public_lite_provider_handoffs',
    documentPath: [
      'risk_scan_public_lite_provider_handoffs',
      'a'.repeat(64),
    ],
    collectionPath: ['risk_scan_public_lite_provider_handoffs'],
  },
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

function occurrenceCount(text, needle) {
  return text.split(needle).length - 1;
}

async function seed(documentPath) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), ...documentPath), {
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

test(
  'provider handoff collection remains protected by global default deny',
  () => {
    assert.equal(
      occurrenceCount(
        rules,
        'match /risk_scan_public_lite_provider_handoffs/',
      ),
      0,
    );
    assert.equal(
      occurrenceCount(rules, 'match /{document=**} {') > 0,
      true,
    );
  },
);

test('HRT collections have exact explicit server-only Rules boundaries', () => {
  const runNeedle = 'match /risk_scan_runs/{runId} {';
  const reportNeedle = 'match /risk_scan_reports/{reportId} {';
  const claimNeedle = 'match /risk_scan_claims/{claimId} {';
  const rateNeedle = 'match /risk_scan_rate_limits/{bucketId} {';

  for (const needle of [runNeedle, reportNeedle, claimNeedle, rateNeedle]) {
    assert.equal(occurrenceCount(rules, needle), 1);
  }

  const runStart = rules.indexOf(runNeedle);
  const reportStart = rules.indexOf(reportNeedle, runStart);
  assert.notEqual(runStart, -1);
  assert.ok(reportStart > runStart);

  const runBlock = rules.slice(runStart, reportStart);
  assert.equal(
    occurrenceCount(runBlock, 'allow read, write: if false;'),
    2,
  );
  assert.equal(
    occurrenceCount(runBlock, 'match /{document=**} {'),
    1,
  );

  for (const [needle, nextNeedle] of [
    [reportNeedle, claimNeedle],
    [claimNeedle, rateNeedle],
  ]) {
    const start = rules.indexOf(needle);
    const end = rules.indexOf(nextNeedle, start);
    const block = rules.slice(start, end);
    assert.equal(
      occurrenceCount(block, 'allow read, write: if false;'),
      1,
    );
  }

  const rateStart = rules.indexOf(rateNeedle);
  const rateBlock = rules.slice(rateStart);
  assert.equal(
    occurrenceCount(rateBlock, 'allow read, write: if false;'),
    1,
  );
});

for (const spec of pathSpecs) {
  test(`${spec.label}: all client access is denied`, async () => {
    const unauthenticated =
      environment.unauthenticatedContext().firestore();
    const authenticated =
      environment.authenticatedContext('tenant-1').firestore();

    await assertFails(setDoc(
      doc(unauthenticated, ...spec.documentPath),
      {value: 1},
    ));
    await assertFails(setDoc(
      doc(authenticated, ...spec.documentPath),
      {value: 1},
    ));

    await seed(spec.documentPath);

    await assertFails(getDoc(
      doc(authenticated, ...spec.documentPath),
    ));
    await assertFails(getDocs(
      collection(authenticated, ...spec.collectionPath),
    ));
    await assertFails(updateDoc(
      doc(authenticated, ...spec.documentPath),
      {value: 2},
    ));
    await assertFails(deleteDoc(
      doc(authenticated, ...spec.documentPath),
    ));
  });
}

test('risk_scan_runs arbitrary deeper descendants remain denied', async () => {
  const existingPath = [
    'risk_scan_runs',
    'run-1',
    'channels',
    'marketplaces',
    'nested_probe',
    'record-1',
  ];
  const newPath = [
    'risk_scan_runs',
    'run-1',
    'channels',
    'marketplaces',
    'nested_probe',
    'record-2',
  ];

  await seed(existingPath);

  const db = environment.authenticatedContext('tenant-1').firestore();
  await assertFails(getDoc(doc(db, ...existingPath)));
  await assertFails(updateDoc(doc(db, ...existingPath), {value: 2}));
  await assertFails(deleteDoc(doc(db, ...existingPath)));
  await assertFails(setDoc(doc(db, ...newPath), {value: 1}));
});
