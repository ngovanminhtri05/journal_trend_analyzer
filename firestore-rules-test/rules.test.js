/**
 * Emulator-backed unit tests for ../firestore.rules — the admin-panel
 * collections (admin_events / admin_crash_reports). Run headless via
 * `npm test` (which wraps jest in `firebase emulators:exec --only firestore`),
 * so no real Firebase project, sign-in, or console is needed.
 */
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  collection,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} = require("firebase/firestore");

let testEnv;

const eventDoc = (uid) => ({
  uid,
  name: "login",
  timestamp: serverTimestamp(),
  params: {},
});

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-journal",
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "..", "firestore.rules"),
        "utf8"
      ),
    },
  });
});

afterAll(() => testEnv.cleanup());
beforeEach(() => testEnv.clearFirestore());

/** Seed a doc bypassing rules, so read/update/delete rules can be exercised. */
async function seed(collectionName, id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), collectionName, id), data);
  });
}

describe("admin_events", () => {
  test("a signed-in user can create an event for their own uid", async () => {
    const db = testEnv.authenticatedContext("u1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "admin_events", "e1"), eventDoc("u1"))
    );
  });

  test("a signed-in user cannot forge another user's uid", async () => {
    const db = testEnv.authenticatedContext("u1").firestore();
    await assertFails(
      setDoc(doc(db, "admin_events", "e1"), eventDoc("someone-else"))
    );
  });

  test("an event with an unexpected extra field is rejected", async () => {
    const db = testEnv.authenticatedContext("u1").firestore();
    await assertFails(
      setDoc(doc(db, "admin_events", "e1"), {
        ...eventDoc("u1"),
        injected: true,
      })
    );
  });

  test("an unauthenticated user cannot create an event", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(db, "admin_events", "e1"), eventDoc("u1"))
    );
  });

  test("an admin can read the events collection", async () => {
    await seed("admin_events", "e1", { uid: "u1", name: "login", params: {} });
    const db = testEnv
      .authenticatedContext("admin1", { admin: true })
      .firestore();
    await assertSucceeds(getDocs(collection(db, "admin_events")));
  });

  test("a non-admin cannot read events", async () => {
    await seed("admin_events", "e1", { uid: "u1", name: "login", params: {} });
    const db = testEnv.authenticatedContext("u1").firestore();
    await assertFails(getDoc(doc(db, "admin_events", "e1")));
  });

  test("events are immutable (no update or delete)", async () => {
    await seed("admin_events", "e1", { uid: "u1", name: "login", params: {} });
    const admin = testEnv
      .authenticatedContext("admin1", { admin: true })
      .firestore();
    await assertFails(updateDoc(doc(admin, "admin_events", "e1"), { name: "x" }));
    await assertFails(deleteDoc(doc(admin, "admin_events", "e1")));
  });
});

describe("everything else is locked down", () => {
  test("admin_crash_reports is no longer writable (feature removed)", async () => {
    const db = testEnv.authenticatedContext("u1").firestore();
    await assertFails(
      setDoc(doc(db, "admin_crash_reports", "c1"), {
        uid: "u1",
        message: "boom",
      })
    );
  });

  test("an arbitrary collection denies reads and writes", async () => {
    const db = testEnv
      .authenticatedContext("admin1", { admin: true })
      .firestore();
    await assertFails(getDoc(doc(db, "secrets", "s1")));
    await assertFails(setDoc(doc(db, "secrets", "s1"), { x: 1 }));
  });
});
