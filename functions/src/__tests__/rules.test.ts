// Rules unit tests for AI-08 (D-17 path locks).
//
// Requires Firestore emulator on port 8080:
//   firebase emulators:start --only firestore
//
// Run:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 npm test -- --testPathPattern=rules
//
// Coverage (D-17):
//   1. Owner CAN read their own /users/{uid}/usage/{date}
//   2. Owner CANNOT write to their own /users/{uid}/usage/{date}
//   3. Other user CANNOT read another user's /users/{uid}/usage/{date}
//   4. Client CANNOT read /system/quota_{YYYY-MM}
//   5. Client CANNOT write /system/quota_{YYYY-MM}
//   6. Client CANNOT read /system/usage_log_{YYYY-MM-DD}
//   7. Client CANNOT write /system/usage_log_{YYYY-MM-DD}

import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  getDoc,
  setLogLevel,
} from 'firebase/firestore';

const PROJECT_ID = 'mentor-mind-aa765-rules-test';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  setLogLevel('error'); // mute the noisy default
  const rulesPath = path.resolve(__dirname, '../../../firestore.rules');
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(rulesPath, 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe('AI-08: /users/{uid}/usage/{date} client access (D-17)', () => {
  it('1. Owner CAN read their own usage doc', async () => {
    // Seed via admin context (bypasses rules)
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/alice/usage/2026-05-19'), {
        messageCount: 5,
        imageCount: 0,
        burstWindow: [],
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(getDoc(doc(aliceDb, 'users/alice/usage/2026-05-19')));
  });

  it('2. Owner CANNOT write to their own usage doc (admin-only)', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(aliceDb, 'users/alice/usage/2026-05-19'), { messageCount: 0 }),
    );
  });

  it('3. Other user CANNOT read alice usage doc', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/alice/usage/2026-05-19'), {
        messageCount: 5,
      });
    });
    const bobDb = testEnv.authenticatedContext('bob').firestore();
    await assertFails(getDoc(doc(bobDb, 'users/alice/usage/2026-05-19')));
  });
});

describe('AI-08: /system/quota_* client access (D-17)', () => {
  it('4. Client CANNOT read /system/quota_2026-05', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'system/quota_2026-05'), {
        calls: 100,
        ceiling: 10000,
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(aliceDb, 'system/quota_2026-05')));
  });

  it('5. Client CANNOT write /system/quota_2026-05', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(aliceDb, 'system/quota_2026-05'), { ceiling: 999999 }),
    );
  });
});

describe('AI-08: /system/usage_log_* client access (D-17)', () => {
  it('6. Client CANNOT read /system/usage_log_2026-05-19', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'system/usage_log_2026-05-19'), {
        calls: 50,
        promptTokens: 10_000,
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(aliceDb, 'system/usage_log_2026-05-19')));
  });

  it('7. Client CANNOT write /system/usage_log_2026-05-19', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(aliceDb, 'system/usage_log_2026-05-19'), { calls: 0 }),
    );
  });
});
