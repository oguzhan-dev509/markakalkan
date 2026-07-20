import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase/app';
import {CustomProvider, initializeAppCheck} from 'firebase/app-check';
import {connectAuthEmulator, createUserWithEmailAndPassword, getAuth}
  from 'firebase/auth';
import {connectFunctionsEmulator, getFunctions, httpsCallable}
  from 'firebase/functions';

const projectId = 'demo-markakalkan-rst-0l';
const functionName = 'provisionInternalTenantBrandPilot';
const pilotCode = 'MK-RST-0J-INTERNAL-001';

function endpoint(name, fallback) {
  const value = process.env[name] || fallback;
  if (!/^(127\.0\.0\.1|localhost|\[?::1\]?):\d+$/.test(value)) {
    throw new Error(`${name} loopback endpoint required`);
  }
  return value;
}

async function expectCallableRejection(call) {
  await assert.rejects(call({pilotCode, dryRun: true}), (error) => {
    assert.notEqual(error?.code, 'functions/not-found');
    return error?.code === 'functions/unauthenticated';
  });
}

assert.equal(process.env.GCLOUD_PROJECT, projectId);
assert.equal(process.env.GOOGLE_CLOUD_PROJECT, projectId);
assert.equal(process.env.FIREBASE_TOKEN, undefined);
assert.equal(process.env.GOOGLE_APPLICATION_CREDENTIALS, undefined);
const authHost = endpoint('FIREBASE_AUTH_EMULATOR_HOST', '127.0.0.1:9099');
const functionsHost = endpoint('FUNCTIONS_EMULATOR_HOST', '127.0.0.1:5001');
endpoint('FIRESTORE_EMULATOR_HOST', '127.0.0.1:8080');
const storageSentinel = endpoint('FIREBASE_STORAGE_EMULATOR_HOST',
  '127.0.0.1:1');

function client(name) {
  const app = initializeApp({projectId, apiKey: 'demo-key'}, name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${authHost}`, {disableWarnings: true});
  const functions = getFunctions(app, 'europe-west3');
  const [host, port] = functionsHost.split(':');
  connectFunctionsEmulator(functions, host, Number(port));
  return {app, auth, call: httpsCallable(functions, functionName)};
}

const anonymous = client('rst-0l-no-app-check');
const malformed = client('rst-0l-malformed-app-check');
try {
  await assert.rejects(fetch(`http://${storageSentinel}/v0/b/${projectId}`));
  await expectCallableRejection(anonymous.call);
  await createUserWithEmailAndPassword(anonymous.auth,
    'rst-0l-authenticated@app-check.invalid', 'emulator-only-password');
  await expectCallableRejection(anonymous.call);

  initializeAppCheck(malformed.app, {isTokenAutoRefreshEnabled: false,
    provider: new CustomProvider({getToken: async () => ({
      token: 'intentionally-malformed-local-token',
      expireTimeMillis: Date.now() + 60000,
    })})});
  await createUserWithEmailAndPassword(malformed.auth,
    'rst-0l-malformed@app-check.invalid', 'emulator-only-password');
  await expectCallableRejection(malformed.call);
  console.log('MK-RST-0L-R2 negative App Check callable protocol: PASS (3/3)');
} finally {
  await Promise.all([deleteApp(anonymous.app), deleteApp(malformed.app)]);
}
