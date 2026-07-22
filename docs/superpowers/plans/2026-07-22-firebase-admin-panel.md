# Firebase Admin Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the signed-in admin manage Firebase-backed data (users, Remote Config, uploaded
reports, and a live crash/analytics feed) from inside the Flutter app instead of the Firebase
console.

**Architecture:** A new `functions/` Cloud Functions (Node 20, TypeScript, 2nd-gen `onCall`,
Admin SDK) project exposes 7 callables for operations a client SDK cannot do (list/disable/
delete users, edit Remote Config template, browse/delete any user's Storage files) — every
callable is guarded by an `admin: true` custom claim on the caller's ID token. Firestore is
added for two purposes: rules gate reads on that same claim, and the existing
`AnalyticsService`/`CrashlyticsService` gain a decorator that dual-writes a short mirror
record so the admin Logs screen has instant data without BigQuery export. The Flutter side
follows the app's existing MVVM/Provider conventions exactly: one `firebase/*_service.dart`
wrapper per capability behind an interface, one ViewModel + Screen pair per admin
sub-feature, `ViewState` for loading/success/error/empty.

**Tech Stack:** Flutter/Dart (existing app), `cloud_functions` + `cloud_firestore` (new
Flutter deps), Firebase Cloud Functions v2 (`firebase-functions` + `firebase-admin`,
TypeScript), Jest for functions tests, `mocktail` for Dart tests (existing dev dependency).

## Global Constraints

- Custom-claim RBAC (`admin: true` on the Firebase Auth user), not a hardcoded email check.
- Every Cloud Function must reject with `permission-denied` unless
  `request.auth?.token?.admin === true` — never trust a client-supplied admin flag.
- An admin can never disable or delete their own account (`failed-precondition`).
- Real `firebase_analytics`/`firebase_crashlytics` calls stay exactly as they are today
  (Lab03 requirement) — the Firestore mirror is additive, never a replacement.
- No BigQuery export / GA4 Data API — crash/analytics admin data comes only from the
  Firestore mirror (`admin_events`, `admin_crash_reports`).
- Every new screen follows the existing `ViewState` (idle/loading/success/error/empty)
  convention; destructive actions (disable/delete user, delete report) require a confirm
  dialog, matching the existing Crashlytics "force test crash" dialog in
  `lib/screens/profile_screen.dart`.
- `flutter analyze` must stay clean and all existing tests must keep passing after every
  task.
- User list is a single page (up to 1000 accounts via one `listUsers` call) — no pagination
  UI. This is a deliberate YAGNI simplification for a course-project user base; a "load
  more" button can be added later if the roster ever exceeds 1000.

---

### Task 1: Cloud Functions project scaffold + admin guard

**Files:**
- Create: `functions/package.json`
- Create: `functions/tsconfig.json`
- Create: `functions/jest.config.js`
- Create: `functions/.gitignore`
- Create: `functions/src/admin-guard.ts`
- Create: `functions/src/admin-guard.test.ts`
- Modify: `firebase.json`

**Interfaces:**
- Produces: `requireAdmin(auth: CallableAuth | undefined): string` — throws
  `HttpsError('permission-denied', ...)` unless `auth.uid` is set and
  `auth.token?.admin === true`; otherwise returns `auth.uid`. Every later Cloud Function
  calls this first.
- Produces: `CallableAuth` type — `{ uid?: string; token?: { admin?: boolean } }`, structurally
  compatible with the real `CallableRequest['auth']` from `firebase-functions/v2/https` so
  production code passes it straight through, while tests can build a plain object.

- [ ] **Step 1: Create `functions/package.json`**

```json
{
  "name": "functions",
  "private": true,
  "main": "lib/index.js",
  "engines": {
    "node": "20"
  },
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "serve": "npm run build && firebase emulators:start --only functions,firestore"
  },
  "dependencies": {
    "firebase-admin": "^12.7.0",
    "firebase-functions": "^6.3.0"
  },
  "devDependencies": {
    "@types/jest": "^29.5.14",
    "@types/node": "^20.17.9",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.5",
    "typescript": "^5.7.2"
  }
}
```

- [ ] **Step 2: Create `functions/tsconfig.json`**

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2020",
    "lib": ["es2020"],
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src"]
}
```

- [ ] **Step 3: Create `functions/jest.config.js`**

```js
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src"],
};
```

- [ ] **Step 4: Create `functions/.gitignore`**

```
node_modules/
lib/
*.log
```

- [ ] **Step 5: Write the failing test — `functions/src/admin-guard.test.ts`**

```ts
import { HttpsError } from "firebase-functions/v2/https";
import { requireAdmin } from "./admin-guard";

describe("requireAdmin", () => {
  it("returns the uid when the caller has the admin claim", () => {
    const uid = requireAdmin({ uid: "u1", token: { admin: true } });
    expect(uid).toBe("u1");
  });

  it("throws permission-denied when there is no auth", () => {
    expect(() => requireAdmin(undefined)).toThrow(HttpsError);
  });

  it("throws permission-denied when admin claim is missing", () => {
    expect(() => requireAdmin({ uid: "u1", token: {} })).toThrow(HttpsError);
  });

  it("throws permission-denied when admin claim is false", () => {
    expect(() =>
      requireAdmin({ uid: "u1", token: { admin: false } })
    ).toThrow(HttpsError);
  });
});
```

- [ ] **Step 6: Run `npm install` then the test to verify it fails**

```bash
cd functions && npm install && npm test
```

Expected: FAIL — `Cannot find module './admin-guard'`.

- [ ] **Step 7: Implement `functions/src/admin-guard.ts`**

```ts
import { HttpsError } from "firebase-functions/v2/https";

/** Structural subset of `CallableRequest['auth']` — real requests pass through untouched. */
export interface CallableAuth {
  uid?: string;
  token?: { admin?: boolean };
}

/** Throws `permission-denied` unless the caller carries the `admin` custom claim. */
export function requireAdmin(auth: CallableAuth | undefined): string {
  const uid = auth?.uid;
  const isAdmin = auth?.token?.admin === true;
  if (!uid || !isAdmin) {
    throw new HttpsError("permission-denied", "Admin privileges required.");
  }
  return uid;
}
```

- [ ] **Step 8: Run the test to verify it passes**

```bash
cd functions && npm test
```

Expected: PASS (4 tests).

- [ ] **Step 9: Register the functions codebase in `firebase.json`**

Read the current `firebase.json` (it only has a `storage` and `flutter` key) and add a
`functions` array so `firebase deploy --only functions` knows where the code lives:

```json
{
  "storage": {
    "rules": "storage.rules"
  },
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": ["node_modules", ".git", "firebase-debug.log", "firebase-debug.*.log"],
      "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]
    }
  ],
  "flutter": {
    "platforms": {
      "android": {
        "default": {
          "projectId": "journal-analyzer-3c319",
          "appId": "1:61025513530:android:7621fee8266ebea59a0503",
          "fileOutput": "android/app/google-services.json"
        }
      },
      "dart": {
        "lib/firebase_options.dart": {
          "projectId": "journal-analyzer-3c319",
          "configurations": { "ios": "1:61025513530:ios:953030cfb9b368aa9a0503" }
        }
      }
    }
  }
}
```

- [ ] **Step 10: Commit**

```bash
git add functions/package.json functions/tsconfig.json functions/jest.config.js functions/.gitignore functions/src/admin-guard.ts functions/src/admin-guard.test.ts firebase.json
git commit -m "feat(functions): scaffold Cloud Functions project + admin guard"
```

---

### Task 2: User management Cloud Functions

**Files:**
- Create: `functions/src/users.ts`
- Create: `functions/src/users.test.ts`

**Interfaces:**
- Consumes: `requireAdmin` from `./admin-guard` (Task 1).
- Produces: handler functions `listUsersHandler`, `setUserDisabledHandler`,
  `deleteUserHandler` (exported for testing) and the `onCall`-wrapped
  `adminListUsers`, `adminSetUserDisabled`, `adminDeleteUser` (exported for `index.ts`,
  Task 4). Response shape for `listUsersHandler`:
  `{ users: Array<{ uid, email, displayName, disabled, createdAt, isAdmin }>, nextPageToken }`.

- [ ] **Step 1: Write the failing tests — `functions/src/users.test.ts`**

```ts
import { HttpsError } from "firebase-functions/v2/https";

const listUsers = jest.fn();
const updateUser = jest.fn();
const deleteUser = jest.fn();

jest.mock("firebase-admin", () => ({
  auth: () => ({ listUsers, updateUser, deleteUser }),
}));

import {
  listUsersHandler,
  setUserDisabledHandler,
  deleteUserHandler,
} from "./users";

const adminAuth = { uid: "admin1", token: { admin: true } };

beforeEach(() => {
  listUsers.mockReset();
  updateUser.mockReset();
  deleteUser.mockReset();
});

describe("listUsersHandler", () => {
  it("maps Firebase user records into plain summaries", async () => {
    listUsers.mockResolvedValue({
      users: [
        {
          uid: "u1",
          email: "a@example.com",
          displayName: "Ada",
          disabled: false,
          metadata: { creationTime: "2026-01-01T00:00:00Z" },
          customClaims: { admin: true },
        },
      ],
      pageToken: undefined,
    });

    const result = await listUsersHandler({}, adminAuth);

    expect(result).toEqual({
      users: [
        {
          uid: "u1",
          email: "a@example.com",
          displayName: "Ada",
          disabled: false,
          createdAt: "2026-01-01T00:00:00Z",
          isAdmin: true,
        },
      ],
      nextPageToken: null,
    });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      listUsersHandler({}, { uid: "u1", token: {} })
    ).rejects.toThrow(HttpsError);
  });
});

describe("setUserDisabledHandler", () => {
  it("disables a user", async () => {
    updateUser.mockResolvedValue(undefined);
    const result = await setUserDisabledHandler(
      { uid: "u2", disabled: true },
      adminAuth
    );
    expect(updateUser).toHaveBeenCalledWith("u2", { disabled: true });
    expect(result).toEqual({ uid: "u2", disabled: true });
  });

  it("rejects disabling yourself", async () => {
    await expect(
      setUserDisabledHandler({ uid: "admin1", disabled: true }, adminAuth)
    ).rejects.toThrow(HttpsError);
  });

  it("rejects a missing uid", async () => {
    await expect(
      setUserDisabledHandler({ disabled: true } as any, adminAuth)
    ).rejects.toThrow(HttpsError);
  });
});

describe("deleteUserHandler", () => {
  it("deletes a user", async () => {
    deleteUser.mockResolvedValue(undefined);
    const result = await deleteUserHandler({ uid: "u3" }, adminAuth);
    expect(deleteUser).toHaveBeenCalledWith("u3");
    expect(result).toEqual({ uid: "u3" });
  });

  it("rejects deleting yourself", async () => {
    await expect(
      deleteUserHandler({ uid: "admin1" }, adminAuth)
    ).rejects.toThrow(HttpsError);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd functions && npm test -- users.test.ts
```

Expected: FAIL — `Cannot find module './users'`.

- [ ] **Step 3: Implement `functions/src/users.ts`**

```ts
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { requireAdmin, CallableAuth } from "./admin-guard";

export async function listUsersHandler(
  data: { pageToken?: string },
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  const result = await admin.auth().listUsers(1000, data?.pageToken);
  return {
    users: result.users.map((u) => ({
      uid: u.uid,
      email: u.email ?? null,
      displayName: u.displayName ?? null,
      disabled: u.disabled,
      createdAt: u.metadata.creationTime,
      isAdmin: u.customClaims?.admin === true,
    })),
    nextPageToken: result.pageToken ?? null,
  };
}

export async function setUserDisabledHandler(
  data: { uid?: string; disabled?: boolean },
  auth: CallableAuth | undefined
) {
  const callerUid = requireAdmin(auth);
  const targetUid = data?.uid;
  const disabled = data?.disabled;
  if (!targetUid || typeof disabled !== "boolean") {
    throw new HttpsError("invalid-argument", "uid and disabled are required.");
  }
  if (targetUid === callerUid) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot disable your own account."
    );
  }
  await admin.auth().updateUser(targetUid, { disabled });
  return { uid: targetUid, disabled };
}

export async function deleteUserHandler(
  data: { uid?: string },
  auth: CallableAuth | undefined
) {
  const callerUid = requireAdmin(auth);
  const targetUid = data?.uid;
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }
  if (targetUid === callerUid) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot delete your own account."
    );
  }
  await admin.auth().deleteUser(targetUid);
  return { uid: targetUid };
}

export const adminListUsers = onCall((request: CallableRequest) =>
  listUsersHandler(request.data, request.auth)
);

export const adminSetUserDisabled = onCall((request: CallableRequest) =>
  setUserDisabledHandler(request.data, request.auth)
);

export const adminDeleteUser = onCall((request: CallableRequest) =>
  deleteUserHandler(request.data, request.auth)
);
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd functions && npm test -- users.test.ts
```

Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add functions/src/users.ts functions/src/users.test.ts
git commit -m "feat(functions): admin user management (list/disable/delete)"
```

---

### Task 3: Remote Config Cloud Functions

**Files:**
- Create: `functions/src/remote-config.ts`
- Create: `functions/src/remote-config.test.ts`

**Interfaces:**
- Consumes: `requireAdmin`, `CallableAuth` from `./admin-guard` (Task 1).
- Produces: `getRemoteConfigTemplateHandler`, `updateRemoteConfigParameterHandler` and the
  `onCall`-wrapped `adminGetRemoteConfigTemplate`, `adminUpdateRemoteConfigParameter`
  (consumed by `index.ts` in Task 4). Response shape for the getter:
  `{ parameters: Array<{ key: string; defaultValue: string | null }> }`.

- [ ] **Step 1: Write the failing tests — `functions/src/remote-config.test.ts`**

```ts
import { HttpsError } from "firebase-functions/v2/https";

const getTemplate = jest.fn();
const validateTemplate = jest.fn();
const publishTemplate = jest.fn();

jest.mock("firebase-admin", () => ({
  remoteConfig: () => ({ getTemplate, validateTemplate, publishTemplate }),
}));

import {
  getRemoteConfigTemplateHandler,
  updateRemoteConfigParameterHandler,
} from "./remote-config";

const adminAuth = { uid: "admin1", token: { admin: true } };

beforeEach(() => {
  getTemplate.mockReset();
  validateTemplate.mockReset();
  publishTemplate.mockReset();
});

describe("getRemoteConfigTemplateHandler", () => {
  it("flattens the template into key/defaultValue pairs", async () => {
    getTemplate.mockResolvedValue({
      parameters: {
        max_journals: { defaultValue: { value: "15" } },
        max_keywords: { defaultValue: { value: "20" } },
      },
    });

    const result = await getRemoteConfigTemplateHandler({}, adminAuth);

    expect(result).toEqual({
      parameters: [
        { key: "max_journals", defaultValue: "15" },
        { key: "max_keywords", defaultValue: "20" },
      ],
    });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      getRemoteConfigTemplateHandler({}, { uid: "u1", token: {} })
    ).rejects.toThrow(HttpsError);
  });
});

describe("updateRemoteConfigParameterHandler", () => {
  it("publishes an updated parameter", async () => {
    getTemplate.mockResolvedValue({ parameters: {} });
    validateTemplate.mockResolvedValue(undefined);
    publishTemplate.mockResolvedValue(undefined);

    const result = await updateRemoteConfigParameterHandler(
      { key: "max_journals", defaultValue: "25" },
      adminAuth
    );

    expect(publishTemplate).toHaveBeenCalledWith({
      parameters: { max_journals: { defaultValue: { value: "25" } } },
    });
    expect(result).toEqual({ key: "max_journals", defaultValue: "25" });
  });

  it("rejects a missing key", async () => {
    await expect(
      updateRemoteConfigParameterHandler(
        { defaultValue: "25" } as any,
        adminAuth
      )
    ).rejects.toThrow(HttpsError);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd functions && npm test -- remote-config.test.ts
```

Expected: FAIL — `Cannot find module './remote-config'`.

- [ ] **Step 3: Implement `functions/src/remote-config.ts`**

```ts
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { requireAdmin, CallableAuth } from "./admin-guard";

export async function getRemoteConfigTemplateHandler(
  _data: unknown,
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  const template = await admin.remoteConfig().getTemplate();
  const parameters = Object.entries(template.parameters ?? {}).map(
    ([key, param]: [string, any]) => ({
      key,
      defaultValue:
        param?.defaultValue && "value" in param.defaultValue
          ? param.defaultValue.value
          : null,
    })
  );
  return { parameters };
}

export async function updateRemoteConfigParameterHandler(
  data: { key?: string; defaultValue?: string },
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  const key = data?.key;
  const value = data?.defaultValue;
  if (!key || typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "key and defaultValue (string) are required."
    );
  }
  const template = await admin.remoteConfig().getTemplate();
  template.parameters = template.parameters ?? {};
  template.parameters[key] = { defaultValue: { value } };
  await admin.remoteConfig().validateTemplate(template);
  await admin.remoteConfig().publishTemplate(template);
  return { key, defaultValue: value };
}

export const adminGetRemoteConfigTemplate = onCall((request: CallableRequest) =>
  getRemoteConfigTemplateHandler(request.data, request.auth)
);

export const adminUpdateRemoteConfigParameter = onCall(
  (request: CallableRequest) =>
    updateRemoteConfigParameterHandler(request.data, request.auth)
);
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd functions && npm test -- remote-config.test.ts
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add functions/src/remote-config.ts functions/src/remote-config.test.ts
git commit -m "feat(functions): admin Remote Config read/update"
```

---

### Task 4: Storage (reports) Cloud Functions + index.ts wiring

**Files:**
- Create: `functions/src/storage.ts`
- Create: `functions/src/storage.test.ts`
- Create: `functions/src/index.ts`

**Interfaces:**
- Consumes: `requireAdmin`, `CallableAuth` from `./admin-guard`.
- Produces: `listReportsHandler`, `getReportUrlHandler`, `deleteReportHandler` and the
  `onCall`-wrapped `adminListReports`, `adminGetReportUrl`, `adminDeleteReport`. Response
  shape for the list: `{ reports: Array<{ path, size, uploadedAt, uid }> }`.
- Produces (index.ts): re-exports all 7 callables so `firebase deploy --only functions`
  picks them up, and calls `admin.initializeApp()` once.

- [ ] **Step 1: Write the failing tests — `functions/src/storage.test.ts`**

```ts
import { HttpsError } from "firebase-functions/v2/https";

const getFiles = jest.fn();
const getSignedUrl = jest.fn();
const deleteFile = jest.fn();
const file = jest.fn(() => ({ getSignedUrl, delete: deleteFile }));
const bucket = jest.fn(() => ({ getFiles, file }));

jest.mock("firebase-admin", () => ({
  storage: () => ({ bucket }),
}));

import {
  listReportsHandler,
  getReportUrlHandler,
  deleteReportHandler,
} from "./storage";

const adminAuth = { uid: "admin1", token: { admin: true } };

beforeEach(() => {
  getFiles.mockReset();
  getSignedUrl.mockReset();
  deleteFile.mockReset();
  file.mockClear();
});

describe("listReportsHandler", () => {
  it("maps bucket files under reports/ into summaries", async () => {
    getFiles.mockResolvedValue([
      [
        {
          name: "reports/u1/2026-report.pdf",
          metadata: { size: "1024", timeCreated: "2026-01-01T00:00:00Z" },
        },
      ],
    ]);

    const result = await listReportsHandler({}, adminAuth);

    expect(getFiles).toHaveBeenCalledWith({ prefix: "reports/" });
    expect(result).toEqual({
      reports: [
        {
          path: "reports/u1/2026-report.pdf",
          size: 1024,
          uploadedAt: "2026-01-01T00:00:00Z",
          uid: "u1",
        },
      ],
    });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      listReportsHandler({}, { uid: "u1", token: {} })
    ).rejects.toThrow(HttpsError);
  });
});

describe("getReportUrlHandler", () => {
  it("returns a signed URL for a reports/ path", async () => {
    getSignedUrl.mockResolvedValue(["https://signed.example/x"]);
    const result = await getReportUrlHandler(
      { path: "reports/u1/2026-report.pdf" },
      adminAuth
    );
    expect(result).toEqual({ url: "https://signed.example/x" });
  });

  it("rejects a path outside reports/", async () => {
    await expect(
      getReportUrlHandler({ path: "other/file.pdf" }, adminAuth)
    ).rejects.toThrow(HttpsError);
  });
});

describe("deleteReportHandler", () => {
  it("deletes a report", async () => {
    deleteFile.mockResolvedValue(undefined);
    const result = await deleteReportHandler(
      { path: "reports/u1/2026-report.pdf" },
      adminAuth
    );
    expect(deleteFile).toHaveBeenCalled();
    expect(result).toEqual({ path: "reports/u1/2026-report.pdf" });
  });

  it("rejects a path outside reports/", async () => {
    await expect(
      deleteReportHandler({ path: "other/file.pdf" }, adminAuth)
    ).rejects.toThrow(HttpsError);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd functions && npm test -- storage.test.ts
```

Expected: FAIL — `Cannot find module './storage'`.

- [ ] **Step 3: Implement `functions/src/storage.ts`**

```ts
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { requireAdmin, CallableAuth } from "./admin-guard";

function assertReportsPath(path: string | undefined): asserts path is string {
  if (!path || !path.startsWith("reports/")) {
    throw new HttpsError(
      "invalid-argument",
      "A valid reports/ path is required."
    );
  }
}

export async function listReportsHandler(
  _data: unknown,
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  const [files] = await admin.storage().bucket().getFiles({ prefix: "reports/" });
  return {
    reports: files.map((file: any) => ({
      path: file.name as string,
      size: Number(file.metadata?.size ?? 0),
      uploadedAt: file.metadata?.timeCreated ?? null,
      uid: (file.name as string).split("/")[1] ?? null,
    })),
  };
}

export async function getReportUrlHandler(
  data: { path?: string },
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  assertReportsPath(data?.path);
  const [url] = await admin
    .storage()
    .bucket()
    .file(data.path)
    .getSignedUrl({ action: "read", expires: Date.now() + 15 * 60 * 1000 });
  return { url };
}

export async function deleteReportHandler(
  data: { path?: string },
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  assertReportsPath(data?.path);
  await admin.storage().bucket().file(data.path).delete();
  return { path: data.path };
}

export const adminListReports = onCall((request: CallableRequest) =>
  listReportsHandler(request.data, request.auth)
);

export const adminGetReportUrl = onCall((request: CallableRequest) =>
  getReportUrlHandler(request.data, request.auth)
);

export const adminDeleteReport = onCall((request: CallableRequest) =>
  deleteReportHandler(request.data, request.auth)
);
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd functions && npm test -- storage.test.ts
```

Expected: PASS (6 tests).

- [ ] **Step 5: Create `functions/src/index.ts`**

```ts
import * as admin from "firebase-admin";

admin.initializeApp();

export { adminListUsers, adminSetUserDisabled, adminDeleteUser } from "./users";
export {
  adminGetRemoteConfigTemplate,
  adminUpdateRemoteConfigParameter,
} from "./remote-config";
export {
  adminListReports,
  adminGetReportUrl,
  adminDeleteReport,
} from "./storage";
```

- [ ] **Step 6: Build the whole functions project to catch type errors**

```bash
cd functions && npm run build && npm test
```

Expected: `tsc` exits 0; all Jest suites (admin-guard, users, remote-config, storage) PASS
(21 tests total).

- [ ] **Step 7: Commit**

```bash
git add functions/src/storage.ts functions/src/storage.test.ts functions/src/index.ts
git commit -m "feat(functions): admin Storage report management + index wiring"
```

---

### Task 5: Firestore setup + admin bootstrap script

**Files:**
- Create: `firestore.rules`
- Create: `firestore.indexes.json`
- Create: `functions/scripts/set-admin-claim.js`
- Modify: `firebase.json`

**Interfaces:**
- Produces: Firestore collections `admin_events` and `admin_crash_reports`, readable only
  by callers whose ID token carries `admin: true`, writable only by the owning uid with a
  fixed field shape. Consumed by Task 8 (mirror writer) and Task 9 (`AdminLogsService`).

- [ ] **Step 1: Create `firestore.rules`**

```
rules_version = '2';

// Firestore Security Rules (Firebase Admin Panel).
//
// Two collections mirror real Analytics/Crashlytics events purely so the in-app
// admin Logs screen has instant, queryable data (see docs/superpowers/specs/
// 2026-07-22-firebase-admin-panel-design.md §5.4). Every other Firebase-console-only
// operation (users, Remote Config, cross-user Storage) goes through Cloud Functions
// instead, which check the same `admin` custom claim server-side.
service cloud.firestore {
  match /databases/{database}/documents {
    match /admin_events/{eventId} {
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.uid
        && request.resource.data.keys().hasOnly(['uid', 'name', 'timestamp', 'params']);
      allow read: if request.auth != null && request.auth.token.admin == true;
      allow update, delete: if false;
    }

    match /admin_crash_reports/{reportId} {
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.uid
        && request.resource.data.keys().hasOnly(['uid', 'message', 'reason', 'timestamp']);
      allow read: if request.auth != null && request.auth.token.admin == true;
      allow update, delete: if false;
    }

    // Deny everything else by default.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 2: Create `firestore.indexes.json`**

```json
{
  "indexes": [],
  "fieldOverrides": []
}
```

- [ ] **Step 3: Register Firestore in `firebase.json`**

Add a `"firestore"` key alongside the existing `"storage"`/`"functions"`/`"flutter"` keys
from Task 1 Step 9:

```json
"firestore": {
  "rules": "firestore.rules",
  "indexes": "firestore.indexes.json"
}
```

- [ ] **Step 4: Create the one-time admin bootstrap script — `functions/scripts/set-admin-claim.js`**

```js
// One-time bootstrap: grants the `admin` custom claim to a user so they can see
// the in-app Admin Dashboard. Not deployed — run locally once per new admin.
//
// Usage (from functions/, after `npm install`):
//   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json node scripts/set-admin-claim.js <uid-or-email>
const admin = require("firebase-admin");

admin.initializeApp({ credential: admin.credential.applicationDefault() });

async function main() {
  const identifier = process.argv[2];
  if (!identifier) {
    console.error("Usage: node scripts/set-admin-claim.js <uid-or-email>");
    process.exitCode = 1;
    return;
  }
  const user = identifier.includes("@")
    ? await admin.auth().getUserByEmail(identifier)
    : await admin.auth().getUser(identifier);
  await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  console.log(`Granted admin claim to ${user.email ?? user.uid}. Sign the user out and back in (or force-refresh the ID token) for it to take effect.`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
```

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firestore.indexes.json firebase.json functions/scripts/set-admin-claim.js
git commit -m "feat(functions): Firestore rules for the admin log mirror + admin bootstrap script"
```

---

### Task 6: Flutter dependencies

**Files:**
- Modify: `pubspec.yaml` (via `flutter pub add`, not hand-edited)

- [ ] **Step 1: Add the two new Firebase packages**

```bash
flutter pub add cloud_firestore cloud_functions
```

Expected: `pubspec.yaml` gains `cloud_firestore: ^<resolved>` and
`cloud_functions: ^<resolved>` under `dependencies`, and `flutter pub get` finishes with
no version-solve errors.

- [ ] **Step 2: Confirm the app still analyzes clean**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add cloud_firestore and cloud_functions dependencies"
```

---

### Task 7: Admin access check + AuthViewModel wiring

**Files:**
- Create: `lib/firebase/admin_access_service.dart`
- Create: `test/admin_access_service_test.dart`
- Modify: `lib/viewmodels/auth_viewmodel.dart`
- Modify: `test/auth_viewmodel_test.dart` (add coverage, do not remove existing tests)
- Modify: `lib/firebase/firebase.dart` (export the new file)

**Interfaces:**
- Produces: `AdminAccessApi` (`Future<bool> isCurrentUserAdmin()`), `AdminAccessService`
  (Firebase-backed), consumed by `AuthViewModel` and, in Task 13, by `main.dart`.
- Produces: `AuthViewModel.isAdmin` (`bool`, defaults `false`), refreshed whenever the
  signed-in user changes. Consumed by the Profile tile gating in Task 13.
- Consumes: nothing new from other tasks — this is additive to the existing
  `AuthViewModel(AuthApi, {AnalyticsApi? analytics})` constructor.

- [ ] **Step 1: Write the failing test — `test/admin_access_service_test.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_access_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockIdTokenResult extends Mock implements IdTokenResult {}

void main() {
  group('AdminAccessService', () {
    test('returns false when nobody is signed in', () async {
      final auth = _MockFirebaseAuth();
      when(() => auth.currentUser).thenReturn(null);
      final service = AdminAccessService(auth: auth);

      expect(await service.isCurrentUserAdmin(), isFalse);
    });

    test('returns true when the forced-refresh token carries admin: true', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      final tokenResult = _MockIdTokenResult();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.getIdTokenResult(true)).thenAnswer((_) async => tokenResult);
      when(() => tokenResult.claims).thenReturn({'admin': true});
      final service = AdminAccessService(auth: auth);

      expect(await service.isCurrentUserAdmin(), isTrue);
    });

    test('returns false when the claim is absent', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      final tokenResult = _MockIdTokenResult();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.getIdTokenResult(true)).thenAnswer((_) async => tokenResult);
      when(() => tokenResult.claims).thenReturn(<String, dynamic>{});
      final service = AdminAccessService(auth: auth);

      expect(await service.isCurrentUserAdmin(), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/admin_access_service_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:journal_trend_analyzer/firebase/admin_access_service.dart'`.

- [ ] **Step 3: Implement `lib/firebase/admin_access_service.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';

/// Contract for checking whether the signed-in user is an admin (custom claim).
///
/// ViewModels depend on this, never on `firebase_auth` directly, so the admin
/// gating stays testable ([StaticAdminAccess] for tests/previews).
abstract interface class AdminAccessApi {
  /// Whether the currently signed-in user carries the `admin` custom claim.
  /// Returns `false` (never throws) when nobody is signed in.
  Future<bool> isCurrentUserAdmin();
}

/// Firebase-backed [AdminAccessApi]. [FirebaseAuth.instance] is resolved lazily
/// so constructing this never requires Firebase.
///
/// Custom claims only appear on a *forced* ID token refresh — a claim granted
/// after the user's last sign-in would not show up on the cached token
/// otherwise — so this always calls `getIdTokenResult(true)`.
class AdminAccessService implements AdminAccessApi {
  AdminAccessService({FirebaseAuth? auth}) : _injected = auth;

  final FirebaseAuth? _injected;
  FirebaseAuth get _auth => _injected ?? FirebaseAuth.instance;

  @override
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult(true);
    return result.claims?['admin'] == true;
  }
}

/// Fixed [AdminAccessApi] for tests, previews, or Firebase-free contexts.
class StaticAdminAccess implements AdminAccessApi {
  const StaticAdminAccess({this.isAdmin = false});

  final bool isAdmin;

  @override
  Future<bool> isCurrentUserAdmin() async => isAdmin;
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/admin_access_service_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Export the new file from the firebase barrel — `lib/firebase/firebase.dart`**

Add one line (alphabetical, matching the existing list):

```dart
export 'admin_access_service.dart';
```

- [ ] **Step 6: Write the failing test for AuthViewModel's admin refresh — append to `test/auth_viewmodel_test.dart`**

First read `test/auth_viewmodel_test.dart` to match its existing `_FakeAuthApi` and import
style, then add:

```dart
  group('AuthViewModel admin status', () {
    test('defaults isAdmin to false with no AdminAccessApi supplied', () async {
      final api = _FakeAuthApi()..signInResult = _ada;
      final vm = AuthViewModel(api);
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });
      api.emit(_ada);
      await Future<void>.delayed(Duration.zero);

      expect(vm.isAdmin, isFalse);
    });

    test('refreshes isAdmin from AdminAccessApi when a user signs in', () async {
      final api = _FakeAuthApi();
      final vm = AuthViewModel(
        api,
        adminAccess: const StaticAdminAccess(isAdmin: true),
      );
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      api.emit(_ada);
      await Future<void>.delayed(Duration.zero);

      expect(vm.isAdmin, isTrue);
    });

    test('resets isAdmin to false on sign-out', () async {
      final api = _FakeAuthApi();
      final vm = AuthViewModel(
        api,
        adminAccess: const StaticAdminAccess(isAdmin: true),
      );
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      api.emit(_ada);
      await Future<void>.delayed(Duration.zero);
      expect(vm.isAdmin, isTrue);

      api.emit(null);
      await Future<void>.delayed(Duration.zero);
      expect(vm.isAdmin, isFalse);
    });
  });
```

Add the import `package:journal_trend_analyzer/firebase/admin_access_service.dart` at the
top of the file alongside the other imports. Reuse the file's existing `_ada` constant and
`_FakeAuthApi` class — do not redeclare them.

- [ ] **Step 7: Run the test to verify it fails**

```bash
flutter test test/auth_viewmodel_test.dart
```

Expected: FAIL — `The named parameter 'adminAccess' isn't defined` / `isAdmin` getter
missing.

- [ ] **Step 8: Modify `lib/viewmodels/auth_viewmodel.dart`**

Add the import and change the constructor/fields/`_onUserChanged` as follows (full
resulting file):

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../firebase/admin_access_service.dart';
import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/app_user.dart';

/// High-level auth state the router (auth gate) switches on.
///
/// `unknown` covers the brief window before the first `authStateChanges` event
/// arrives, so the app can show a splash instead of flashing the login screen.
enum AuthStatus { unknown, signedOut, signedIn }

/// Drives the Login screen and the auth gate.
///
/// Subscribes to [AuthApi.authStateChanges] and mirrors it into [status] /
/// [user]. Holds the transient sign-in progress + error for the View. Contains
/// no Firebase types — it depends only on [AuthApi] (and optionally
/// [AdminAccessApi]), so it is fully unit testable with fakes.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(
    this._auth, {
    AnalyticsApi? analytics,
    AdminAccessApi? adminAccess,
  }) : _analytics = analytics,
       _adminAccess = adminAccess {
    _sub = _auth.authStateChanges.listen(_onUserChanged);
  }

  final AuthApi _auth;
  final AnalyticsApi? _analytics;
  final AdminAccessApi? _adminAccess;
  late final StreamSubscription<AppUser?> _sub;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  /// True while the Google chooser / Firebase exchange is in flight.
  bool isSigningIn = false;

  /// Last sign-in error message, or null. Cleared on a new attempt.
  String? errorMessage;

  /// Whether the signed-in user carries the `admin` custom claim. Always
  /// `false` when signed out or when no [AdminAccessApi] was supplied.
  bool isAdmin = false;

  Future<void> signInWithGoogle() async {
    if (isSigningIn) return;
    isSigningIn = true;
    errorMessage = null;
    notifyListeners();

    try {
      final signedIn = await _auth.signInWithGoogle();
      // A successful sign-in flows back through authStateChanges → _onUserChanged.
      if (signedIn != null) _analytics?.logLogin();
    } on AuthException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Sign-in failed. Please try again.';
    } finally {
      isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Only count a logout that actually succeeded.
      _analytics?.logLogout();
    } on AuthException catch (e) {
      errorMessage = e.message;
      notifyListeners();
    }
    // Sign-out likewise propagates via authStateChanges.
  }

  void _onUserChanged(AppUser? next) {
    user = next;
    status = next == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    if (next == null) {
      isAdmin = false;
    } else {
      unawaited(_refreshAdminStatus());
    }
    notifyListeners();
  }

  Future<void> _refreshAdminStatus() async {
    final access = _adminAccess;
    if (access == null) return;
    bool admin;
    try {
      admin = await access.isCurrentUserAdmin();
    } catch (_) {
      admin = false;
    }
    isAdmin = admin;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 9: Run the tests to verify they pass**

```bash
flutter test test/auth_viewmodel_test.dart test/admin_access_service_test.dart
```

Expected: PASS, and no previously-passing test in `auth_viewmodel_test.dart` regresses.

- [ ] **Step 10: Run the full suite + analyze to confirm nothing else broke**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`; all tests PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/firebase/admin_access_service.dart lib/firebase/firebase.dart lib/viewmodels/auth_viewmodel.dart test/admin_access_service_test.dart test/auth_viewmodel_test.dart
git commit -m "feat: admin custom-claim check surfaced on AuthViewModel.isAdmin"
```

---

### Task 8: Analytics/Crashlytics Firestore mirror (write side)

**Files:**
- Create: `lib/firebase/admin_logs_mirror.dart`
- Create: `test/admin_logs_mirror_test.dart`
- Modify: `lib/firebase/firebase.dart` (export the new file)

**Interfaces:**
- Produces: `MirroringAnalytics implements AnalyticsApi`, `MirroringCrashReporter implements
  CrashReporterApi` — both decorators: `MirroringAnalytics(AnalyticsApi inner, {FirebaseAuth?
  auth, AdminEventWriter? writer})` and `MirroringCrashReporter(CrashReporterApi inner,
  {FirebaseAuth? auth, AdminEventWriter? writer})`. `typedef AdminEventWriter =
  Future<void> Function(String collection, Map<String, dynamic> data);`
- Consumes: nothing from earlier tasks (Firestore collection names `admin_events` /
  `admin_crash_reports` are the same ones Task 5's rules and Task 9's reader use — keep
  these three in sync if ever renamed).

- [ ] **Step 1: Write the failing test — `test/admin_logs_mirror_test.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_logs_mirror.dart';
import 'package:journal_trend_analyzer/firebase/analytics_service.dart';
import 'package:journal_trend_analyzer/firebase/crash_reporter_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _RecordingAnalytics implements AnalyticsApi {
  int logins = 0;
  final List<String> searches = [];

  @override
  Future<void> logLogin() async => logins++;
  @override
  Future<void> logSearchTopic(String keyword) async => searches.add(keyword);
  @override
  Future<void> logViewPublication({required String title, int? year}) async {}
  @override
  Future<void> logViewJournal(String name) async {}
  @override
  Future<void> logViewKeyword(String keyword) async {}
  @override
  Future<void> logExportPdf(String topic) async {}
  @override
  Future<void> logLogout() async {}
}

class _RecordingCrashReporter implements CrashReporterApi {
  int handledErrors = 0;

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) async =>
      handledErrors++;
  @override
  Future<void> log(String message) async {}
  @override
  void forceCrash() {}
}

void main() {
  group('MirroringAnalytics', () {
    test('forwards to the inner analytics and mirrors when signed in', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');
      final inner = _RecordingAnalytics();
      final written = <MapEntry<String, Map<String, dynamic>>>[];
      final mirroring = MirroringAnalytics(
        inner,
        auth: auth,
        writer: (collection, data) async {
          written.add(MapEntry(collection, data));
        },
      );

      await mirroring.logSearchTopic('robotics');

      expect(inner.searches, ['robotics']);
      expect(written, hasLength(1));
      expect(written.single.key, 'admin_events');
      expect(written.single.value['uid'], 'u1');
      expect(written.single.value['name'], 'search_topic');
      expect(written.single.value['params'], {'keyword': 'robotics'});
    });

    test('still forwards to the inner analytics when signed out (no mirror write)', () async {
      final auth = _MockFirebaseAuth();
      when(() => auth.currentUser).thenReturn(null);
      final inner = _RecordingAnalytics();
      var writes = 0;
      final mirroring = MirroringAnalytics(
        inner,
        auth: auth,
        writer: (_, __) async => writes++,
      );

      await mirroring.logLogin();

      expect(inner.logins, 1);
      expect(writes, 0);
    });

    test('a failing writer never breaks the real analytics call', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');
      final inner = _RecordingAnalytics();
      final mirroring = MirroringAnalytics(
        inner,
        auth: auth,
        writer: (_, __) async => throw Exception('offline'),
      );

      await mirroring.logLogin();

      expect(inner.logins, 1);
    });
  });

  group('MirroringCrashReporter', () {
    test('forwards to the inner reporter and mirrors when signed in', () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');
      final inner = _RecordingCrashReporter();
      final written = <MapEntry<String, Map<String, dynamic>>>[];
      final mirroring = MirroringCrashReporter(
        inner,
        auth: auth,
        writer: (collection, data) async {
          written.add(MapEntry(collection, data));
        },
      );

      await mirroring.recordError(Exception('boom'), StackTrace.current, reason: 'demo');

      expect(inner.handledErrors, 1);
      expect(written.single.key, 'admin_crash_reports');
      expect(written.single.value['uid'], 'u1');
      expect(written.single.value['reason'], 'demo');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/admin_logs_mirror_test.dart
```

Expected: FAIL — `Target of URI doesn't exist:
'package:journal_trend_analyzer/firebase/admin_logs_mirror.dart'`.

- [ ] **Step 3: Implement `lib/firebase/admin_logs_mirror.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'analytics_service.dart';
import 'crash_reporter_service.dart';

/// Writes one mirrored record to a Firestore collection. Overridable in tests;
/// the default targets the real Firestore project.
typedef AdminEventWriter = Future<void> Function(
  String collection,
  Map<String, dynamic> data,
);

Future<void> _defaultWriter(String collection, Map<String, dynamic> data) =>
    FirebaseFirestore.instance.collection(collection).add(data);

/// Decorates an [AnalyticsApi] so every real event also writes a short record
/// to the `admin_events` Firestore collection, purely so the in-app admin Logs
/// screen has instant data (see design §5.4) — the real Analytics call is
/// untouched and always runs first.
///
/// The mirror write is best-effort: a Firestore failure (offline, rules,
/// anything) is swallowed so it can never break the real analytics event it
/// wraps. Nothing is written while signed out — there is no uid to attribute
/// the event to, and the security rules would reject it anyway.
class MirroringAnalytics implements AnalyticsApi {
  MirroringAnalytics(this._inner, {FirebaseAuth? auth, AdminEventWriter? writer})
    : _authInjected = auth,
      _writer = writer ?? _defaultWriter;

  final AnalyticsApi _inner;
  final FirebaseAuth? _authInjected;
  final AdminEventWriter _writer;

  FirebaseAuth get _auth => _authInjected ?? FirebaseAuth.instance;

  Future<void> _mirror(String name, Map<String, dynamic> params) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _writer('admin_events', {
        'uid': uid,
        'name': name,
        'timestamp': FieldValue.serverTimestamp(),
        'params': params,
      });
    } catch (_) {
      // Best-effort mirror only.
    }
  }

  @override
  Future<void> logLogin() async {
    await _inner.logLogin();
    await _mirror('login', const {});
  }

  @override
  Future<void> logSearchTopic(String keyword) async {
    await _inner.logSearchTopic(keyword);
    await _mirror('search_topic', {'keyword': keyword});
  }

  @override
  Future<void> logViewPublication({required String title, int? year}) async {
    await _inner.logViewPublication(title: title, year: year);
    await _mirror('view_publication', {
      'title': title,
      if (year != null) 'year': year,
    });
  }

  @override
  Future<void> logViewJournal(String name) async {
    await _inner.logViewJournal(name);
    await _mirror('view_journal', {'name': name});
  }

  @override
  Future<void> logViewKeyword(String keyword) async {
    await _inner.logViewKeyword(keyword);
    await _mirror('view_keyword', {'keyword': keyword});
  }

  @override
  Future<void> logExportPdf(String topic) async {
    await _inner.logExportPdf(topic);
    await _mirror('export_pdf', {'topic': topic});
  }

  @override
  Future<void> logLogout() async {
    await _inner.logLogout();
    await _mirror('logout', const {});
  }
}

/// Decorates a [CrashReporterApi] so every non-fatal [recordError] also writes
/// a short record to the `admin_crash_reports` Firestore collection. Same
/// best-effort/offline-safe behavior as [MirroringAnalytics]; [log] and
/// [forceCrash] pass straight through (there is nothing to mirror before a
/// forced crash kills the process).
class MirroringCrashReporter implements CrashReporterApi {
  MirroringCrashReporter(
    this._inner, {
    FirebaseAuth? auth,
    AdminEventWriter? writer,
  }) : _authInjected = auth,
       _writer = writer ?? _defaultWriter;

  final CrashReporterApi _inner;
  final FirebaseAuth? _authInjected;
  final AdminEventWriter _writer;

  FirebaseAuth get _auth => _authInjected ?? FirebaseAuth.instance;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    await _inner.recordError(error, stack, reason: reason);
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _writer('admin_crash_reports', {
        'uid': uid,
        'message': error.toString(),
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort mirror only.
    }
  }

  @override
  Future<void> log(String message) => _inner.log(message);

  @override
  void forceCrash() => _inner.forceCrash();
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/admin_logs_mirror_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 5: Export from `lib/firebase/firebase.dart`**

```dart
export 'admin_logs_mirror.dart';
```

- [ ] **Step 6: Commit**

```bash
git add lib/firebase/admin_logs_mirror.dart lib/firebase/firebase.dart test/admin_logs_mirror_test.dart
git commit -m "feat: mirror Analytics/Crashlytics events into Firestore for the admin Logs screen"
```

---

### Task 9: Admin Logs read API + ViewModel

**Files:**
- Create: `lib/firebase/admin_logs_service.dart`
- Create: `test/admin_logs_service_test.dart`
- Create: `lib/viewmodels/admin_logs_viewmodel.dart`
- Create: `test/admin_logs_viewmodel_test.dart`
- Modify: `lib/firebase/firebase.dart`, `lib/viewmodels/viewmodels.dart`

**Interfaces:**
- Produces: `AdminEventLog`, `AdminCrashLog` models; `AdminLogsApi`
  (`Future<List<AdminEventLog>> recentEvents({int limit = 100})`,
  `Future<List<AdminCrashLog>> recentCrashes({int limit = 100})`); `AdminLogsService`
  (Firestore-backed). `AdminLogsViewModel` with `ViewState state`, `List<AdminEventLog>
  events`, `List<AdminCrashLog> crashes`, `Future<void> load()`, `Future<void> retry()`.
- Consumes: the `admin_events`/`admin_crash_reports` collections written by Task 8.

- [ ] **Step 1: Write the failing test — `test/admin_logs_service_test.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_logs_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollectionRef extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDocSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late _MockFirestore db;
  late _MockCollectionRef collection;
  late _MockQuery ordered;
  late _MockQuery limited;
  late _MockQuerySnapshot snapshot;
  late _MockQueryDocSnapshot doc;

  setUp(() {
    db = _MockFirestore();
    collection = _MockCollectionRef();
    ordered = _MockQuery();
    limited = _MockQuery();
    snapshot = _MockQuerySnapshot();
    doc = _MockQueryDocSnapshot();

    when(() => db.collection(any())).thenReturn(collection);
    when(() => collection.orderBy('timestamp', descending: true))
        .thenReturn(ordered);
    when(() => ordered.limit(any())).thenReturn(limited);
    when(() => limited.get()).thenAnswer((_) async => snapshot);
    when(() => snapshot.docs).thenReturn([doc]);
  });

  test('recentEvents maps documents into AdminEventLog', () async {
    when(() => doc.data()).thenReturn({
      'uid': 'u1',
      'name': 'search_topic',
      'timestamp': Timestamp.fromMillisecondsSinceEpoch(0),
      'params': {'keyword': 'robotics'},
    });
    final service = AdminLogsService(firestore: db);

    final events = await service.recentEvents(limit: 50);

    expect(collection.toString, isNotNull);
    verify(() => db.collection('admin_events')).called(1);
    verify(() => ordered.limit(50)).called(1);
    expect(events, hasLength(1));
    expect(events.single.uid, 'u1');
    expect(events.single.name, 'search_topic');
    expect(events.single.params, {'keyword': 'robotics'});
  });

  test('recentCrashes maps documents into AdminCrashLog', () async {
    when(() => doc.data()).thenReturn({
      'uid': 'u1',
      'message': 'Exception: boom',
      'reason': 'demo',
      'timestamp': Timestamp.fromMillisecondsSinceEpoch(0),
    });
    final service = AdminLogsService(firestore: db);

    final crashes = await service.recentCrashes();

    verify(() => db.collection('admin_crash_reports')).called(1);
    expect(crashes.single.uid, 'u1');
    expect(crashes.single.message, 'Exception: boom');
    expect(crashes.single.reason, 'demo');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/admin_logs_service_test.dart
```

Expected: FAIL — `Target of URI doesn't exist:
'package:journal_trend_analyzer/firebase/admin_logs_service.dart'`.

- [ ] **Step 3: Implement `lib/firebase/admin_logs_service.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A mirrored analytics event, read back for the admin Logs screen.
class AdminEventLog {
  const AdminEventLog({
    required this.uid,
    required this.name,
    required this.timestamp,
    this.params = const {},
  });

  final String uid;
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> params;

  factory AdminEventLog.fromMap(Map<String, dynamic> map) => AdminEventLog(
    uid: map['uid'] as String? ?? '',
    name: map['name'] as String? ?? '',
    timestamp:
        (map['timestamp'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    params: Map<String, dynamic>.from(map['params'] as Map? ?? const {}),
  );
}

/// A mirrored crash/error record, read back for the admin Logs screen.
class AdminCrashLog {
  const AdminCrashLog({
    required this.uid,
    required this.message,
    required this.timestamp,
    this.reason,
  });

  final String uid;
  final String message;
  final DateTime timestamp;
  final String? reason;

  factory AdminCrashLog.fromMap(Map<String, dynamic> map) => AdminCrashLog(
    uid: map['uid'] as String? ?? '',
    message: map['message'] as String? ?? '',
    timestamp:
        (map['timestamp'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    reason: map['reason'] as String?,
  );
}

/// Contract for reading the mirrored admin logs (Firestore-backed). Only an
/// admin's Firestore rules allow these reads — see `firestore.rules`.
abstract interface class AdminLogsApi {
  Future<List<AdminEventLog>> recentEvents({int limit = 100});
  Future<List<AdminCrashLog>> recentCrashes({int limit = 100});
}

/// Firebase-backed [AdminLogsApi]. [FirebaseFirestore.instance] is resolved
/// lazily so constructing this never requires Firebase.
class AdminLogsService implements AdminLogsApi {
  AdminLogsService({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  @override
  Future<List<AdminEventLog>> recentEvents({int limit = 100}) async {
    final snapshot = await _db
        .collection('admin_events')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => AdminEventLog.fromMap(d.data())).toList();
  }

  @override
  Future<List<AdminCrashLog>> recentCrashes({int limit = 100}) async {
    final snapshot = await _db
        .collection('admin_crash_reports')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => AdminCrashLog.fromMap(d.data())).toList();
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/admin_logs_service_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Export from `lib/firebase/firebase.dart`**

```dart
export 'admin_logs_service.dart';
```

- [ ] **Step 6: Write the failing test — `test/admin_logs_viewmodel_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_logs_service.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_logs_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/view_state.dart';

class _FakeAdminLogsApi implements AdminLogsApi {
  List<AdminEventLog> events = const [];
  List<AdminCrashLog> crashes = const [];
  Object? error;

  @override
  Future<List<AdminEventLog>> recentEvents({int limit = 100}) async {
    if (error != null) throw error!;
    return events;
  }

  @override
  Future<List<AdminCrashLog>> recentCrashes({int limit = 100}) async {
    if (error != null) throw error!;
    return crashes;
  }
}

void main() {
  group('AdminLogsViewModel', () {
    test('loads events and crashes together', () async {
      final api = _FakeAdminLogsApi()
        ..events = [
          AdminEventLog(uid: 'u1', name: 'login', timestamp: DateTime(2026)),
        ]
        ..crashes = [
          AdminCrashLog(
            uid: 'u1',
            message: 'boom',
            timestamp: DateTime(2026),
          ),
        ];
      final vm = AdminLogsViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.events, hasLength(1));
      expect(vm.crashes, hasLength(1));
    });

    test('reports empty when both lists are empty', () async {
      final vm = AdminLogsViewModel(_FakeAdminLogsApi());

      await vm.load();

      expect(vm.state, ViewState.empty);
    });

    test('reports an error and retry reloads', () async {
      final api = _FakeAdminLogsApi()..error = Exception('offline');
      final vm = AdminLogsViewModel(api);

      await vm.load();
      expect(vm.state, ViewState.error);

      api.error = null;
      api.events = [
        AdminEventLog(uid: 'u1', name: 'login', timestamp: DateTime(2026)),
      ];
      await vm.retry();
      expect(vm.state, ViewState.success);
    });
  });
}
```

- [ ] **Step 7: Run the test to verify it fails**

```bash
flutter test test/admin_logs_viewmodel_test.dart
```

Expected: FAIL — `Target of URI doesn't exist:
'package:journal_trend_analyzer/viewmodels/admin_logs_viewmodel.dart'`.

- [ ] **Step 8: Implement `lib/viewmodels/admin_logs_viewmodel.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../firebase/admin_logs_service.dart';
import 'view_state.dart';

/// Drives the admin Logs screen: the mirrored Analytics/Crashlytics feed.
class AdminLogsViewModel extends ChangeNotifier {
  AdminLogsViewModel(this._api);

  final AdminLogsApi _api;

  ViewState state = ViewState.idle;
  String? errorMessage;
  List<AdminEventLog> events = const [];
  List<AdminCrashLog> crashes = const [];

  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.recentEvents(),
        _api.recentCrashes(),
      ]);
      events = results[0] as List<AdminEventLog>;
      crashes = results[1] as List<AdminCrashLog>;
      state = (events.isEmpty && crashes.isEmpty)
          ? ViewState.empty
          : ViewState.success;
    } catch (_) {
      errorMessage = 'Could not load logs. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();
}
```

- [ ] **Step 9: Run the test to verify it passes**

```bash
flutter test test/admin_logs_viewmodel_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 10: Export from `lib/viewmodels/viewmodels.dart`**

```dart
export 'admin_logs_viewmodel.dart';
```

- [ ] **Step 11: Commit**

```bash
git add lib/firebase/admin_logs_service.dart lib/firebase/firebase.dart lib/viewmodels/admin_logs_viewmodel.dart lib/viewmodels/viewmodels.dart test/admin_logs_service_test.dart test/admin_logs_viewmodel_test.dart
git commit -m "feat: admin Logs read API + ViewModel"
```

---

### Task 10: Admin Users service + ViewModel

**Files:**
- Create: `lib/firebase/admin_users_service.dart`
- Create: `test/admin_users_service_test.dart`
- Create: `lib/viewmodels/admin_users_viewmodel.dart`
- Create: `test/admin_users_viewmodel_test.dart`
- Modify: `lib/firebase/firebase.dart`, `lib/viewmodels/viewmodels.dart`

**Interfaces:**
- Produces: `AdminUserSummary`, `AdminUsersPage`, `AdminException`, `AdminUsersApi`
  (`Future<AdminUsersPage> listUsers({String? pageToken})`, `Future<void> setUserDisabled({
  required String uid, required bool disabled})`, `Future<void> deleteUser(String uid)`),
  `AdminUsersService` (calls the `adminListUsers`/`adminSetUserDisabled`/`adminDeleteUser`
  Cloud Functions from Task 2). `AdminUsersViewModel` with `ViewState state`,
  `List<AdminUserSummary> users`, `bool isBusy(String uid)`, `Future<void> load()`,
  `Future<void> retry()`, `Future<void> setDisabled(String uid, bool disabled)`,
  `Future<void> delete(String uid)`.
- Consumes: nothing from earlier tasks besides the Cloud Function names, which must match
  Task 2 exactly: `adminListUsers`, `adminSetUserDisabled`, `adminDeleteUser`.

- [ ] **Step 1: Write the failing test — `test/admin_users_service_test.dart`**

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late _MockResult result;

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    result = _MockResult();
    registerFallbackValue(<String, dynamic>{});
  });

  test('listUsers maps the callable response', () async {
    when(() => functions.httpsCallable('adminListUsers')).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({
      'users': [
        {
          'uid': 'u1',
          'email': 'a@example.com',
          'displayName': 'Ada',
          'disabled': false,
          'createdAt': '2026-01-01T00:00:00Z',
          'isAdmin': true,
        },
      ],
      'nextPageToken': null,
    });
    final service = AdminUsersService(functions: functions);

    final page = await service.listUsers();

    expect(page.users, hasLength(1));
    expect(page.users.single.uid, 'u1');
    expect(page.users.single.isAdmin, isTrue);
    expect(page.nextPageToken, isNull);
  });

  test('setUserDisabled calls the callable with uid and disabled', () async {
    when(
      () => functions.httpsCallable('adminSetUserDisabled'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'uid': 'u1', 'disabled': true});
    final service = AdminUsersService(functions: functions);

    await service.setUserDisabled(uid: 'u1', disabled: true);

    verify(
      () => callable.call<dynamic>({'uid': 'u1', 'disabled': true}),
    ).called(1);
  });

  test('a FirebaseFunctionsException becomes an AdminException', () async {
    when(() => functions.httpsCallable('adminDeleteUser')).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'Admin privileges required.',
        code: 'permission-denied',
      ),
    );
    final service = AdminUsersService(functions: functions);

    expect(() => service.deleteUser('u1'), throwsA(isA<AdminException>()));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/admin_users_service_test.dart
```

Expected: FAIL — `Target of URI doesn't exist:
'package:journal_trend_analyzer/firebase/admin_users_service.dart'`.

- [ ] **Step 3: Implement `lib/firebase/admin_users_service.dart`**

```dart
import 'package:cloud_functions/cloud_functions.dart';

/// One row in the admin Users list.
class AdminUserSummary {
  const AdminUserSummary({
    required this.uid,
    this.email,
    this.displayName,
    required this.disabled,
    this.createdAt,
    required this.isAdmin,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool disabled;
  final String? createdAt;
  final bool isAdmin;

  factory AdminUserSummary.fromMap(Map<String, dynamic> map) => AdminUserSummary(
    uid: map['uid'] as String,
    email: map['email'] as String?,
    displayName: map['displayName'] as String?,
    disabled: map['disabled'] as bool? ?? false,
    createdAt: map['createdAt'] as String?,
    isAdmin: map['isAdmin'] as bool? ?? false,
  );

  /// Best-effort human label (name → email → uid), matching [AppUser.label].
  String get label => (displayName?.isNotEmpty ?? false)
      ? displayName!
      : (email?.isNotEmpty ?? false)
      ? email!
      : uid;
}

/// A page of admin users (single page for this app — see plan's Global
/// Constraints; up to 1000 accounts).
class AdminUsersPage {
  const AdminUsersPage({required this.users, this.nextPageToken});

  final List<AdminUserSummary> users;
  final String? nextPageToken;
}

/// A typed admin-operation failure, safe to show to the UI.
class AdminException implements Exception {
  const AdminException(this.message);

  final String message;

  @override
  String toString() => 'AdminException: $message';
}

/// Contract for the admin user-management Cloud Functions.
abstract interface class AdminUsersApi {
  Future<AdminUsersPage> listUsers({String? pageToken});
  Future<void> setUserDisabled({required String uid, required bool disabled});
  Future<void> deleteUser(String uid);
}

/// Calls the `adminListUsers` / `adminSetUserDisabled` / `adminDeleteUser`
/// Cloud Functions (`functions/src/users.ts`). [FirebaseFunctions.instance] is
/// resolved lazily so constructing this never requires Firebase.
class AdminUsersService implements AdminUsersApi {
  AdminUsersService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;
  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  @override
  Future<AdminUsersPage> listUsers({String? pageToken}) async {
    try {
      final result = await _functions
          .httpsCallable('adminListUsers')
          .call<dynamic>({if (pageToken != null) 'pageToken': pageToken});
      final data = Map<String, dynamic>.from(result.data as Map);
      final users = (data['users'] as List)
          .map(
            (u) => AdminUserSummary.fromMap(Map<String, dynamic>.from(u as Map)),
          )
          .toList();
      return AdminUsersPage(
        users: users,
        nextPageToken: data['nextPageToken'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to list users.');
    }
  }

  @override
  Future<void> setUserDisabled({
    required String uid,
    required bool disabled,
  }) async {
    try {
      await _functions.httpsCallable('adminSetUserDisabled').call<dynamic>({
        'uid': uid,
        'disabled': disabled,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to update the user.');
    }
  }

  @override
  Future<void> deleteUser(String uid) async {
    try {
      await _functions.httpsCallable('adminDeleteUser').call<dynamic>({
        'uid': uid,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to delete the user.');
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/admin_users_service_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Export from `lib/firebase/firebase.dart`**

```dart
export 'admin_users_service.dart';
```

- [ ] **Step 6: Write the failing test — `test/admin_users_viewmodel_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_users_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/view_state.dart';

class _FakeAdminUsersApi implements AdminUsersApi {
  List<AdminUserSummary> users = const [];
  Object? error;
  final List<String> disabledCalls = [];
  final List<String> deletedCalls = [];

  @override
  Future<AdminUsersPage> listUsers({String? pageToken}) async {
    if (error != null) throw error!;
    return AdminUsersPage(users: users);
  }

  @override
  Future<void> setUserDisabled({
    required String uid,
    required bool disabled,
  }) async {
    if (error != null) throw error!;
    disabledCalls.add(uid);
  }

  @override
  Future<void> deleteUser(String uid) async {
    if (error != null) throw error!;
    deletedCalls.add(uid);
  }
}

const _ada = AdminUserSummary(
  uid: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  disabled: false,
  isAdmin: false,
);

void main() {
  group('AdminUsersViewModel', () {
    test('loads users', () async {
      final api = _FakeAdminUsersApi()..users = [_ada];
      final vm = AdminUsersViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.users, [_ada]);
    });

    test('reports empty when there are no users', () async {
      final vm = AdminUsersViewModel(_FakeAdminUsersApi());

      await vm.load();

      expect(vm.state, ViewState.empty);
    });

    test('reports an error via AdminException message', () async {
      final api = _FakeAdminUsersApi()..error = const AdminException('nope');
      final vm = AdminUsersViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.error);
      expect(vm.errorMessage, 'nope');
    });

    test('setDisabled updates the local user and clears busy state', () async {
      final api = _FakeAdminUsersApi()..users = [_ada];
      final vm = AdminUsersViewModel(api);
      await vm.load();

      await vm.setDisabled('u1', true);

      expect(api.disabledCalls, ['u1']);
      expect(vm.users.single.disabled, isTrue);
      expect(vm.isBusy('u1'), isFalse);
    });

    test('delete removes the user from the local list', () async {
      final api = _FakeAdminUsersApi()..users = [_ada];
      final vm = AdminUsersViewModel(api);
      await vm.load();

      await vm.delete('u1');

      expect(api.deletedCalls, ['u1']);
      expect(vm.users, isEmpty);
    });
  });
}
```

- [ ] **Step 7: Run the test to verify it fails**

```bash
flutter test test/admin_users_viewmodel_test.dart
```

Expected: FAIL — `Target of URI doesn't exist:
'package:journal_trend_analyzer/viewmodels/admin_users_viewmodel.dart'`.

- [ ] **Step 8: Implement `lib/viewmodels/admin_users_viewmodel.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../firebase/admin_users_service.dart';
import 'view_state.dart';

/// Drives the admin Users screen: list, disable/enable, delete.
class AdminUsersViewModel extends ChangeNotifier {
  AdminUsersViewModel(this._api);

  final AdminUsersApi _api;

  ViewState state = ViewState.idle;
  String? errorMessage;
  List<AdminUserSummary> users = const [];

  final Set<String> _busyUids = {};

  /// Whether a disable/delete action for [uid] is currently in flight.
  bool isBusy(String uid) => _busyUids.contains(uid);

  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final page = await _api.listUsers();
      users = page.users;
      state = users.isEmpty ? ViewState.empty : ViewState.success;
    } on AdminException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();

  Future<void> setDisabled(String uid, bool disabled) async {
    _busyUids.add(uid);
    notifyListeners();
    try {
      await _api.setUserDisabled(uid: uid, disabled: disabled);
      users = [
        for (final u in users)
          if (u.uid == uid)
            AdminUserSummary(
              uid: u.uid,
              email: u.email,
              displayName: u.displayName,
              disabled: disabled,
              createdAt: u.createdAt,
              isAdmin: u.isAdmin,
            )
          else
            u,
      ];
    } on AdminException catch (e) {
      errorMessage = e.message;
    } finally {
      _busyUids.remove(uid);
      notifyListeners();
    }
  }

  Future<void> delete(String uid) async {
    _busyUids.add(uid);
    notifyListeners();
    try {
      await _api.deleteUser(uid);
      users = users.where((u) => u.uid != uid).toList();
    } on AdminException catch (e) {
      errorMessage = e.message;
    } finally {
      _busyUids.remove(uid);
      notifyListeners();
    }
  }
}
```

Note: `AdminUserSummary` needs value equality for the `expect(vm.users, [_ada])` test
assertion in Step 6 to work by content rather than identity. Add `==`/`hashCode` to it now:
reopen `lib/firebase/admin_users_service.dart` and add, inside `AdminUserSummary`:

```dart
  @override
  bool operator ==(Object other) =>
      other is AdminUserSummary &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.disabled == disabled &&
      other.createdAt == createdAt &&
      other.isAdmin == isAdmin;

  @override
  int get hashCode =>
      Object.hash(uid, email, displayName, disabled, createdAt, isAdmin);
```

- [ ] **Step 9: Run the tests to verify they pass**

```bash
flutter test test/admin_users_service_test.dart test/admin_users_viewmodel_test.dart
```

Expected: PASS (3 + 5 tests).

- [ ] **Step 10: Export from `lib/viewmodels/viewmodels.dart`**

```dart
export 'admin_users_viewmodel.dart';
```

- [ ] **Step 11: Commit**

```bash
git add lib/firebase/admin_users_service.dart lib/firebase/firebase.dart lib/viewmodels/admin_users_viewmodel.dart lib/viewmodels/viewmodels.dart test/admin_users_service_test.dart test/admin_users_viewmodel_test.dart
git commit -m "feat: admin Users service + ViewModel"
```

---

### Task 11: Admin Remote Config service + ViewModel

**Files:**
- Create: `lib/firebase/admin_remote_config_service.dart`
- Create: `test/admin_remote_config_service_test.dart`
- Create: `lib/viewmodels/admin_remote_config_viewmodel.dart`
- Create: `test/admin_remote_config_viewmodel_test.dart`
- Modify: `lib/firebase/firebase.dart`, `lib/viewmodels/viewmodels.dart`

**Interfaces:**
- Produces: `RemoteConfigParam` (`{key, defaultValue}`), `AdminRemoteConfigApi`
  (`Future<List<RemoteConfigParam>> getTemplate()`, `Future<void> updateParameter({required
  String key, required String defaultValue})`), `AdminRemoteConfigService` (calls
  `adminGetRemoteConfigTemplate`/`adminUpdateRemoteConfigParameter` from Task 3).
  `AdminRemoteConfigViewModel` with `ViewState state`, `List<RemoteConfigParam> parameters`,
  `Future<void> load()`, `Future<void> retry()`, `Future<void> updateParameter(String key,
  String defaultValue)`.
- Consumes: `AdminException` from `lib/firebase/admin_users_service.dart` (Task 10) — reused
  rather than redefined, since it is a generic "admin operation failed" type.

- [ ] **Step 1: Write the failing test — `test/admin_remote_config_service_test.dart`**

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_remote_config_service.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart'
    show AdminException;
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late _MockResult result;

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    result = _MockResult();
    registerFallbackValue(<String, dynamic>{});
  });

  test('getTemplate maps the callable response', () async {
    when(
      () => functions.httpsCallable('adminGetRemoteConfigTemplate'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({
      'parameters': [
        {'key': 'max_journals', 'defaultValue': '15'},
      ],
    });
    final service = AdminRemoteConfigService(functions: functions);

    final params = await service.getTemplate();

    expect(params.single.key, 'max_journals');
    expect(params.single.defaultValue, '15');
  });

  test('updateParameter calls the callable with key and defaultValue', () async {
    when(
      () => functions.httpsCallable('adminUpdateRemoteConfigParameter'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(
      () => result.data,
    ).thenReturn({'key': 'max_journals', 'defaultValue': '25'});
    final service = AdminRemoteConfigService(functions: functions);

    await service.updateParameter(key: 'max_journals', defaultValue: '25');

    verify(
      () => callable.call<dynamic>({
        'key': 'max_journals',
        'defaultValue': '25',
      }),
    ).called(1);
  });

  test('a FirebaseFunctionsException becomes an AdminException', () async {
    when(
      () => functions.httpsCallable('adminGetRemoteConfigTemplate'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'Admin privileges required.',
        code: 'permission-denied',
      ),
    );
    final service = AdminRemoteConfigService(functions: functions);

    expect(() => service.getTemplate(), throwsA(isA<AdminException>()));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/admin_remote_config_service_test.dart
```

Expected: FAIL — `Target of URI doesn't exist:
'package:journal_trend_analyzer/firebase/admin_remote_config_service.dart'`.

- [ ] **Step 3: Implement `lib/firebase/admin_remote_config_service.dart`**

```dart
import 'package:cloud_functions/cloud_functions.dart';

import 'admin_users_service.dart' show AdminException;

/// One Remote Config parameter, as shown/edited on the admin screen.
class RemoteConfigParam {
  const RemoteConfigParam({required this.key, required this.defaultValue});

  final String key;
  final String defaultValue;

  factory RemoteConfigParam.fromMap(Map<String, dynamic> map) =>
      RemoteConfigParam(
        key: map['key'] as String,
        defaultValue: (map['defaultValue'] as String?) ?? '',
      );
}

/// Contract for the admin Remote Config Cloud Functions.
abstract interface class AdminRemoteConfigApi {
  Future<List<RemoteConfigParam>> getTemplate();
  Future<void> updateParameter({
    required String key,
    required String defaultValue,
  });
}

/// Calls the `adminGetRemoteConfigTemplate` / `adminUpdateRemoteConfigParameter`
/// Cloud Functions (`functions/src/remote-config.ts`).
class AdminRemoteConfigService implements AdminRemoteConfigApi {
  AdminRemoteConfigService({FirebaseFunctions? functions})
    : _injected = functions;

  final FirebaseFunctions? _injected;
  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  @override
  Future<List<RemoteConfigParam>> getTemplate() async {
    try {
      final result = await _functions
          .httpsCallable('adminGetRemoteConfigTemplate')
          .call<dynamic>();
      final data = Map<String, dynamic>.from(result.data as Map);
      return (data['parameters'] as List)
          .map(
            (p) => RemoteConfigParam.fromMap(Map<String, dynamic>.from(p as Map)),
          )
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to load Remote Config.');
    }
  }

  @override
  Future<void> updateParameter({
    required String key,
    required String defaultValue,
  }) async {
    try {
      await _functions
          .httpsCallable('adminUpdateRemoteConfigParameter')
          .call<dynamic>({'key': key, 'defaultValue': defaultValue});
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to update the parameter.');
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/admin_remote_config_service_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Export from `lib/firebase/firebase.dart`**

```dart
export 'admin_remote_config_service.dart';
```

- [ ] **Step 6: Write the failing test — `test/admin_remote_config_viewmodel_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_remote_config_service.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart'
    show AdminException;
import 'package:journal_trend_analyzer/viewmodels/admin_remote_config_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/view_state.dart';

class _FakeAdminRemoteConfigApi implements AdminRemoteConfigApi {
  List<RemoteConfigParam> parameters = const [];
  Object? error;
  final List<RemoteConfigParam> updated = [];

  @override
  Future<List<RemoteConfigParam>> getTemplate() async {
    if (error != null) throw error!;
    return parameters;
  }

  @override
  Future<void> updateParameter({
    required String key,
    required String defaultValue,
  }) async {
    if (error != null) throw error!;
    updated.add(RemoteConfigParam(key: key, defaultValue: defaultValue));
  }
}

void main() {
  group('AdminRemoteConfigViewModel', () {
    test('loads parameters', () async {
      final api = _FakeAdminRemoteConfigApi()
        ..parameters = [
          const RemoteConfigParam(key: 'max_journals', defaultValue: '15'),
        ];
      final vm = AdminRemoteConfigViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.parameters.single.key, 'max_journals');
    });

    test('reports empty when there are no parameters', () async {
      final vm = AdminRemoteConfigViewModel(_FakeAdminRemoteConfigApi());

      await vm.load();

      expect(vm.state, ViewState.empty);
    });

    test('updateParameter refreshes the local list on success', () async {
      final api = _FakeAdminRemoteConfigApi()
        ..parameters = [
          const RemoteConfigParam(key: 'max_journals', defaultValue: '15'),
        ];
      final vm = AdminRemoteConfigViewModel(api);
      await vm.load();

      await vm.updateParameter('max_journals', '25');

      expect(api.updated.single.defaultValue, '25');
      expect(vm.parameters.single.defaultValue, '25');
    });

    test('an update failure surfaces via errorMessage', () async {
      final api = _FakeAdminRemoteConfigApi()
        ..parameters = [
          const RemoteConfigParam(key: 'max_journals', defaultValue: '15'),
        ];
      final vm = AdminRemoteConfigViewModel(api);
      await vm.load();
      api.error = const AdminException('publish failed');

      await vm.updateParameter('max_journals', '25');

      expect(vm.errorMessage, 'publish failed');
      // The optimistic value is not applied when the call failed.
      expect(vm.parameters.single.defaultValue, '15');
    });
  });
}
```

- [ ] **Step 7: Run the test to verify it fails**

```bash
flutter test test/admin_remote_config_viewmodel_test.dart
```

Expected: FAIL — `Target of URI doesn't exist:
'package:journal_trend_analyzer/viewmodels/admin_remote_config_viewmodel.dart'`.

- [ ] **Step 8: Implement `lib/viewmodels/admin_remote_config_viewmodel.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../firebase/admin_remote_config_service.dart';
import '../firebase/admin_users_service.dart' show AdminException;
import 'view_state.dart';

/// Drives the admin Remote Config screen: view + edit parameters.
class AdminRemoteConfigViewModel extends ChangeNotifier {
  AdminRemoteConfigViewModel(this._api);

  final AdminRemoteConfigApi _api;

  ViewState state = ViewState.idle;
  String? errorMessage;
  List<RemoteConfigParam> parameters = const [];

  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      parameters = await _api.getTemplate();
      state = parameters.isEmpty ? ViewState.empty : ViewState.success;
    } on AdminException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();

  Future<void> updateParameter(String key, String defaultValue) async {
    errorMessage = null;
    try {
      await _api.updateParameter(key: key, defaultValue: defaultValue);
      parameters = [
        for (final p in parameters)
          if (p.key == key)
            RemoteConfigParam(key: key, defaultValue: defaultValue)
          else
            p,
        if (!parameters.any((p) => p.key == key))
          RemoteConfigParam(key: key, defaultValue: defaultValue),
      ];
    } on AdminException catch (e) {
      errorMessage = e.message;
    }
    notifyListeners();
  }
}
```

- [ ] **Step 9: Run the tests to verify they pass**

```bash
flutter test test/admin_remote_config_service_test.dart test/admin_remote_config_viewmodel_test.dart
```

Expected: PASS (3 + 4 tests).

- [ ] **Step 10: Export from `lib/viewmodels/viewmodels.dart`**

```dart
export 'admin_remote_config_viewmodel.dart';
```

- [ ] **Step 11: Commit**

```bash
git add lib/firebase/admin_remote_config_service.dart lib/firebase/firebase.dart lib/viewmodels/admin_remote_config_viewmodel.dart lib/viewmodels/viewmodels.dart test/admin_remote_config_service_test.dart test/admin_remote_config_viewmodel_test.dart
git commit -m "feat: admin Remote Config service + ViewModel"
```

---

### Task 12: Admin Storage (reports) service + ViewModel

**Files:**
- Create: `lib/firebase/admin_storage_service.dart`
- Create: `test/admin_storage_service_test.dart`
- Create: `lib/viewmodels/admin_storage_viewmodel.dart`
- Create: `test/admin_storage_viewmodel_test.dart`
- Modify: `lib/firebase/firebase.dart`, `lib/viewmodels/viewmodels.dart`

**Interfaces:**
- Produces: `AdminReportFile` (`{path, size, uploadedAt, uid}`), `AdminStorageApi`
  (`Future<List<AdminReportFile>> listReports()`, `Future<String> getReportUrl(String path)`,
  `Future<void> deleteReport(String path)`), `AdminStorageService` (calls
  `adminListReports`/`adminGetReportUrl`/`adminDeleteReport` from Task 4).
  `AdminStorageViewModel` with `ViewState state`, `List<AdminReportFile> reports`,
  `Future<void> load()`, `Future<void> retry()`, `Future<String> openReport(String path)`,
  `Future<void> delete(String path)`.
- Consumes: `AdminException` from `lib/firebase/admin_users_service.dart` (Task 10).

- [ ] **Step 1: Write the failing test — `test/admin_storage_service_test.dart`**

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_storage_service.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart'
    show AdminException;
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late _MockResult result;

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    result = _MockResult();
    registerFallbackValue(<String, dynamic>{});
  });

  test('listReports maps the callable response', () async {
    when(() => functions.httpsCallable('adminListReports')).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({
      'reports': [
        {
          'path': 'reports/u1/2026-report.pdf',
          'size': 1024,
          'uploadedAt': '2026-01-01T00:00:00Z',
          'uid': 'u1',
        },
      ],
    });
    final service = AdminStorageService(functions: functions);

    final reports = await service.listReports();

    expect(reports.single.path, 'reports/u1/2026-report.pdf');
    expect(reports.single.size, 1024);
    expect(reports.single.uid, 'u1');
  });

  test('getReportUrl calls the callable with the path', () async {
    when(
      () => functions.httpsCallable('adminGetReportUrl'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'url': 'https://signed.example/x'});
    final service = AdminStorageService(functions: functions);

    final url = await service.getReportUrl('reports/u1/2026-report.pdf');

    expect(url, 'https://signed.example/x');
    verify(
      () => callable.call<dynamic>({'path': 'reports/u1/2026-report.pdf'}),
    ).called(1);
  });

  test('a FirebaseFunctionsException becomes an AdminException', () async {
    when(
      () => functions.httpsCallable('adminDeleteReport'),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'Admin privileges required.',
        code: 'permission-denied',
      ),
    );
    final service = AdminStorageService(functions: functions);

    expect(
      () => service.deleteReport('reports/u1/x.pdf'),
      throwsA(isA<AdminException>()),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/admin_storage_service_test.dart
```

Expected: FAIL — `Target of URI doesn't exist:
'package:journal_trend_analyzer/firebase/admin_storage_service.dart'`.

- [ ] **Step 3: Implement `lib/firebase/admin_storage_service.dart`**

```dart
import 'package:cloud_functions/cloud_functions.dart';

import 'admin_users_service.dart' show AdminException;

/// One uploaded report, as shown on the admin Storage screen.
class AdminReportFile {
  const AdminReportFile({
    required this.path,
    required this.size,
    this.uploadedAt,
    this.uid,
  });

  final String path;
  final int size;
  final String? uploadedAt;
  final String? uid;

  factory AdminReportFile.fromMap(Map<String, dynamic> map) => AdminReportFile(
    path: map['path'] as String,
    size: (map['size'] as num?)?.toInt() ?? 0,
    uploadedAt: map['uploadedAt'] as String?,
    uid: map['uid'] as String?,
  );
}

/// Contract for the admin Storage (reports) Cloud Functions.
abstract interface class AdminStorageApi {
  Future<List<AdminReportFile>> listReports();
  Future<String> getReportUrl(String path);
  Future<void> deleteReport(String path);
}

/// Calls the `adminListReports` / `adminGetReportUrl` / `adminDeleteReport`
/// Cloud Functions (`functions/src/storage.ts`).
class AdminStorageService implements AdminStorageApi {
  AdminStorageService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;
  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  @override
  Future<List<AdminReportFile>> listReports() async {
    try {
      final result = await _functions
          .httpsCallable('adminListReports')
          .call<dynamic>();
      final data = Map<String, dynamic>.from(result.data as Map);
      return (data['reports'] as List)
          .map(
            (r) => AdminReportFile.fromMap(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to list reports.');
    }
  }

  @override
  Future<String> getReportUrl(String path) async {
    try {
      final result = await _functions
          .httpsCallable('adminGetReportUrl')
          .call<dynamic>({'path': path});
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['url'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to get a download link.');
    }
  }

  @override
  Future<void> deleteReport(String path) async {
    try {
      await _functions.httpsCallable('adminDeleteReport').call<dynamic>({
        'path': path,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to delete the report.');
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/admin_storage_service_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Export from `lib/firebase/firebase.dart`**

```dart
export 'admin_storage_service.dart';
```

- [ ] **Step 6: Write the failing test — `test/admin_storage_viewmodel_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_storage_service.dart';
import 'package:journal_trend_analyzer/firebase/admin_users_service.dart'
    show AdminException;
import 'package:journal_trend_analyzer/viewmodels/admin_storage_viewmodel.dart';
import 'package:journal_trend_analyzer/viewmodels/view_state.dart';

class _FakeAdminStorageApi implements AdminStorageApi {
  List<AdminReportFile> reports = const [];
  Object? error;
  final List<String> deleted = [];

  @override
  Future<List<AdminReportFile>> listReports() async {
    if (error != null) throw error!;
    return reports;
  }

  @override
  Future<String> getReportUrl(String path) async {
    if (error != null) throw error!;
    return 'https://signed.example/$path';
  }

  @override
  Future<void> deleteReport(String path) async {
    if (error != null) throw error!;
    deleted.add(path);
  }
}

const _report = AdminReportFile(
  path: 'reports/u1/2026-report.pdf',
  size: 1024,
  uid: 'u1',
);

void main() {
  group('AdminStorageViewModel', () {
    test('loads reports', () async {
      final api = _FakeAdminStorageApi()..reports = [_report];
      final vm = AdminStorageViewModel(api);

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.reports.single.path, _report.path);
    });

    test('reports empty when there are no reports', () async {
      final vm = AdminStorageViewModel(_FakeAdminStorageApi());

      await vm.load();

      expect(vm.state, ViewState.empty);
    });

    test('openReport returns a signed URL', () async {
      final vm = AdminStorageViewModel(_FakeAdminStorageApi());

      final url = await vm.openReport(_report.path);

      expect(url, 'https://signed.example/${_report.path}');
    });

    test('delete removes the report from the local list', () async {
      final api = _FakeAdminStorageApi()..reports = [_report];
      final vm = AdminStorageViewModel(api);
      await vm.load();

      await vm.delete(_report.path);

      expect(api.deleted, [_report.path]);
      expect(vm.reports, isEmpty);
    });
  });
}
```

- [ ] **Step 7: Run the test to verify it fails**

```bash
flutter test test/admin_storage_viewmodel_test.dart
```

Expected: FAIL — `Target of URI doesn't exist:
'package:journal_trend_analyzer/viewmodels/admin_storage_viewmodel.dart'`.

- [ ] **Step 8: Implement `lib/viewmodels/admin_storage_viewmodel.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../firebase/admin_storage_service.dart';
import '../firebase/admin_users_service.dart' show AdminException;
import 'view_state.dart';

/// Drives the admin Storage screen: browse/download/delete uploaded reports
/// across all users.
class AdminStorageViewModel extends ChangeNotifier {
  AdminStorageViewModel(this._api);

  final AdminStorageApi _api;

  ViewState state = ViewState.idle;
  String? errorMessage;
  List<AdminReportFile> reports = const [];

  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      reports = await _api.listReports();
      state = reports.isEmpty ? ViewState.empty : ViewState.success;
    } on AdminException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();

  Future<String> openReport(String path) => _api.getReportUrl(path);

  Future<void> delete(String path) async {
    try {
      await _api.deleteReport(path);
      reports = reports.where((r) => r.path != path).toList();
    } on AdminException catch (e) {
      errorMessage = e.message;
    }
    notifyListeners();
  }
}
```

Note: `AdminReportFile` needs value equality for the `expect(vm.reports.single.path, ...)`
comparisons to be unambiguous in Step 6 — it already compares `.path`/`.size` directly by
field, so no `==` override is required here (unlike Task 10's `AdminUserSummary`, which is
compared whole-object).

- [ ] **Step 9: Run the tests to verify they pass**

```bash
flutter test test/admin_storage_service_test.dart test/admin_storage_viewmodel_test.dart
```

Expected: PASS (3 + 4 tests).

- [ ] **Step 10: Export from `lib/viewmodels/viewmodels.dart`**

```dart
export 'admin_storage_viewmodel.dart';
```

- [ ] **Step 11: Commit**

```bash
git add lib/firebase/admin_storage_service.dart lib/firebase/firebase.dart lib/viewmodels/admin_storage_viewmodel.dart lib/viewmodels/viewmodels.dart test/admin_storage_service_test.dart test/admin_storage_viewmodel_test.dart
git commit -m "feat: admin Storage (reports) service + ViewModel"
```

---

### Task 13: Admin screens, Profile gating, and app wiring

**Files:**
- Create: `lib/screens/admin_dashboard_screen.dart`
- Create: `lib/screens/admin_users_screen.dart`
- Create: `lib/screens/admin_remote_config_screen.dart`
- Create: `lib/screens/admin_storage_screen.dart`
- Create: `lib/screens/admin_logs_screen.dart`
- Create: `test/admin_dashboard_screen_test.dart`
- Modify: `lib/screens/screens.dart`
- Modify: `lib/screens/profile_screen.dart`
- Modify: `test/profile_screen_test.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: every ViewModel/Api produced in Tasks 7–12 (`AuthViewModel.isAdmin`,
  `AdminUsersViewModel`, `AdminRemoteConfigViewModel`, `AdminStorageViewModel`,
  `AdminLogsViewModel`, and the four `AdminXxxApi`/`AdminXxxService` pairs plus
  `AdminAccessService`, `MirroringAnalytics`, `MirroringCrashReporter`).
- Produces: nothing further downstream — this is the final integration task.

- [ ] **Step 1: Write the failing widget test — `test/admin_dashboard_screen_test.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/app_user.dart';
import 'package:journal_trend_analyzer/firebase/auth_service.dart';
import 'package:journal_trend_analyzer/screens/profile_screen.dart';
import 'package:journal_trend_analyzer/viewmodels/auth_viewmodel.dart';
import 'package:provider/provider.dart';

class _FakeAuthApi implements AuthApi {
  final _controller = StreamController<AppUser?>.broadcast();

  void emit(AppUser? user) => _controller.add(user);

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;
  @override
  AppUser? currentUser;
  @override
  Future<AppUser?> signInWithGoogle() async => null;
  @override
  Future<void> signOut() async {}

  void dispose() => _controller.close();
}

const _ada = AppUser(uid: 'u1', displayName: 'Ada', email: 'ada@example.com');

void main() {
  group('ProfileScreen admin tile', () {
    testWidgets('hidden for a non-admin user', (tester) async {
      final api = _FakeAuthApi();
      final vm = AuthViewModel(api);
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      api.emit(_ada);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthViewModel>.value(
            value: vm,
            child: const Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Admin Dashboard'), findsNothing);
    });

    testWidgets('shown for an admin user', (tester) async {
      final api = _FakeAuthApi();
      final vm = AuthViewModel(api);
      addTearDown(() {
        vm.dispose();
        api.dispose();
      });

      api.emit(_ada);
      await tester.pump();
      vm.isAdmin = true;
      vm.notifyListeners();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthViewModel>.value(
            value: vm,
            child: const Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Admin Dashboard'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/admin_dashboard_screen_test.dart
```

Expected: FAIL — `find.text('Admin Dashboard')` finds nothing in either case (the tile does
not exist yet), so the "shown for an admin user" case fails.

- [ ] **Step 3: Create `lib/screens/admin_dashboard_screen.dart`**

```dart
import 'package:flutter/material.dart';

import 'admin_logs_screen.dart';
import 'admin_remote_config_screen.dart';
import 'admin_storage_screen.dart';
import 'admin_users_screen.dart';

/// Entry point for the in-app Firebase admin panel (reached from the Profile
/// tab's "Admin Dashboard" tile, gated on [AuthViewModel.isAdmin]). A 4-card
/// menu, matching the app's list→detail navigation pattern.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminCard(
            icon: Icons.people_outline,
            title: 'Users',
            subtitle: 'List, disable, or delete accounts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            icon: Icons.tune,
            title: 'Remote Config',
            subtitle: 'View and edit server-tunable parameters',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminRemoteConfigScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            icon: Icons.folder_outlined,
            title: 'Storage',
            subtitle: "Browse and manage every user's reports",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminStorageScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminCard(
            icon: Icons.receipt_long_outlined,
            title: 'Logs',
            subtitle: 'Recent analytics events and crash reports',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminLogsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
```

- [ ] **Step 4: Create `lib/screens/admin_users_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/admin_users_service.dart';
import '../viewmodels/admin_users_viewmodel.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// Admin Users screen: list every account, disable/enable, or delete it.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminUsersViewModel>(
      create: (_) => AdminUsersViewModel(AdminUsersService())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Users')),
        body: Consumer<AdminUsersViewModel>(
          builder: (context, vm, _) => _buildBody(context, vm),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminUsersViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading users…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(message: 'No users found.');
      case ViewState.success:
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vm.users.length,
          itemBuilder: (context, i) =>
              _UserTile(user: vm.users[i], vm: vm),
        );
    }
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.vm});

  final AdminUserSummary user;
  final AdminUsersViewModel vm;

  @override
  Widget build(BuildContext context) {
    final busy = vm.isBusy(user.uid);
    return Card(
      child: ListTile(
        leading: Icon(
          user.isAdmin ? Icons.shield_outlined : Icons.person_outline,
        ),
        title: Text(user.label),
        subtitle: Text(
          user.disabled ? 'Disabled' : 'Active',
          style: TextStyle(
            color: user.disabled
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        ),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                onSelected: (value) => value == 'delete'
                    ? _confirmDelete(context)
                    : vm.setDisabled(user.uid, !user.disabled),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(user.disabled ? 'Enable' : 'Disable'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this account?'),
        content: Text(
          '${user.label} will be permanently removed from Firebase Auth. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) vm.delete(user.uid);
  }
}
```

- [ ] **Step 5: Create `lib/screens/admin_remote_config_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/admin_remote_config_service.dart';
import '../viewmodels/admin_remote_config_viewmodel.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// Admin Remote Config screen: view every parameter and edit its default
/// value — the in-app replacement for hand-editing values in the console.
class AdminRemoteConfigScreen extends StatelessWidget {
  const AdminRemoteConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminRemoteConfigViewModel>(
      create: (_) =>
          AdminRemoteConfigViewModel(AdminRemoteConfigService())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Remote Config')),
        body: Consumer<AdminRemoteConfigViewModel>(
          builder: (context, vm, _) => _buildBody(context, vm),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminRemoteConfigViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading parameters…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(message: 'No Remote Config parameters yet.');
      case ViewState.success:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final param in vm.parameters)
              _ParamTile(param: param, vm: vm),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showEditDialog(context, vm),
              icon: const Icon(Icons.add),
              label: const Text('Add parameter'),
            ),
          ],
        );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AdminRemoteConfigViewModel vm, {
    RemoteConfigParam? existing,
  }) async {
    final keyController = TextEditingController(text: existing?.key ?? '');
    final valueController = TextEditingController(
      text: existing?.defaultValue ?? '',
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add parameter' : 'Edit parameter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              enabled: existing == null,
              decoration: const InputDecoration(labelText: 'Key'),
            ),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: 'Default value'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result ?? false) {
      final key = keyController.text.trim();
      if (key.isNotEmpty) {
        vm.updateParameter(key, valueController.text.trim());
      }
    }
  }
}

class _ParamTile extends StatelessWidget {
  const _ParamTile({required this.param, required this.vm});

  final RemoteConfigParam param;
  final AdminRemoteConfigViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.tune),
        title: Text(param.key),
        subtitle: Text(param.defaultValue),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _edit(context),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final screen = context
        .findAncestorWidgetOfExactType<AdminRemoteConfigScreen>();
    if (screen != null) {
      await screen._showEditDialog(context, vm, existing: param);
    }
  }
}
```

- [ ] **Step 6: Create `lib/screens/admin_storage_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase/admin_storage_service.dart';
import '../viewmodels/admin_storage_viewmodel.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// Admin Storage screen: browse, download, or delete uploaded PDF reports
/// across every user's `reports/{uid}/…` folder.
class AdminStorageScreen extends StatelessWidget {
  const AdminStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminStorageViewModel>(
      create: (_) => AdminStorageViewModel(AdminStorageService())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Storage')),
        body: Consumer<AdminStorageViewModel>(
          builder: (context, vm, _) => _buildBody(context, vm),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminStorageViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading reports…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(message: 'No reports uploaded yet.');
      case ViewState.success:
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vm.reports.length,
          itemBuilder: (context, i) => _ReportTile(
            report: vm.reports[i],
            vm: vm,
          ),
        );
    }
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.vm});

  final AdminReportFile report;
  final AdminStorageViewModel vm;

  @override
  Widget build(BuildContext context) {
    final kb = (report.size / 1024).toStringAsFixed(1);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf_outlined),
        title: Text(report.path.split('/').last),
        subtitle: Text('${report.uid ?? 'unknown user'} • $kb KB'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) =>
              value == 'download' ? _download(context) : _confirmDelete(context),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'download', child: Text('Download')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await vm.openReport(report.path);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the report.')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this report?'),
        content: Text(
          '${report.path} will be permanently removed from Storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) vm.delete(report.path);
  }
}
```

- [ ] **Step 7: Create `lib/screens/admin_logs_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/admin_logs_service.dart';
import '../viewmodels/admin_logs_viewmodel.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// Admin Logs screen: the mirrored Analytics/Crashlytics feed (see design
/// §5.4 — real events still go to Firebase Analytics/Crashlytics; this is a
/// live, queryable mirror for instant in-app viewing).
class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminLogsViewModel>(
      create: (_) => AdminLogsViewModel(AdminLogsService())..load(),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Logs'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Events'), Tab(text: 'Crashes')],
            ),
          ),
          body: Consumer<AdminLogsViewModel>(
            builder: (context, vm, _) => _buildBody(context, vm),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminLogsViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading logs…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(message: 'No events or crashes recorded yet.');
      case ViewState.success:
        return TabBarView(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vm.events.length,
              itemBuilder: (context, i) {
                final e = vm.events[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(e.name),
                    subtitle: Text('${e.uid} • ${e.timestamp}'),
                  ),
                );
              },
            ),
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vm.crashes.length,
              itemBuilder: (context, i) {
                final c = vm.crashes[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.report_gmailerrorred_outlined),
                    title: Text(c.message),
                    subtitle: Text('${c.uid} • ${c.timestamp}'),
                  ),
                );
              },
            ),
          ],
        );
    }
  }
}
```

- [ ] **Step 8: Export the new screens from `lib/screens/screens.dart`**

```dart
export 'admin_dashboard_screen.dart';
export 'admin_logs_screen.dart';
export 'admin_remote_config_screen.dart';
export 'admin_storage_screen.dart';
export 'admin_users_screen.dart';
```

- [ ] **Step 9: Add the "Admin Dashboard" tile to `lib/screens/profile_screen.dart`**

Add the import:

```dart
import 'admin_dashboard_screen.dart';
```

Insert a new private widget after `_CrashlyticsCard` and reference it from `build`, right
after `const _CrashlyticsCard(),`:

```dart
        const _CrashlyticsCard(),
        const SizedBox(height: 16),
        const _AdminDashboardTile(),
        const SizedBox(height: 24),
```

And the widget itself, alongside the other private widgets in the same file:

```dart
/// Admin Dashboard entry (in-app Firebase management): shown only when the
/// signed-in user carries the `admin` custom claim ([AuthViewModel.isAdmin]).
class _AdminDashboardTile extends StatelessWidget {
  const _AdminDashboardTile();

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthViewModel?>()?.isAdmin ?? false;
    if (!isAdmin) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.admin_panel_settings_outlined),
        title: const Text('Admin Dashboard'),
        subtitle: const Text('Manage users, Remote Config, Storage, and logs'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
      ),
    );
  }
}
```

- [ ] **Step 10: Run the widget test to verify it passes**

```bash
flutter test test/admin_dashboard_screen_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 11: Extend the Patrol profile test to assert the tile stays hidden for the
      fake E2E session — append to `integration_test/profile_test.dart`**

`pumpSignedInShell` (in `integration_test/helpers.dart`) wires a fake `AuthApi` with no
`AdminAccessApi`, so `AuthViewModel.isAdmin` stays `false` — this case needs no deployed
Cloud Functions or real admin claim. Append this case inside the existing `main()`:

```dart
  patrolTest('TC8b: Profile hides the Admin Dashboard for a non-admin session', (
    $,
  ) async {
    await pumpSignedInShell($);
    await openTab($, 'Profile');

    expect($('Admin Dashboard'), findsNothing);
  });
```

(Actually exercising the tile *shown* case would require a deployed Cloud Functions project
and a real granted claim — left as a manual on-device check per Step 14 below, matching the
design's note that destructive/admin-only E2E flows are too risky to automate against real
data.)

- [ ] **Step 12: Wire the admin services into `lib/main.dart`**

Add imports:

```dart
import 'firebase/admin_access_service.dart';
import 'firebase/admin_logs_mirror.dart';
```

Change the `_analytics`/`_crashReporter` fields so production defaults go through the
mirroring decorators, and add an `AdminAccessApi` used by `AuthViewModel`:

```dart
  late final AnalyticsApi _analytics =
      widget.analytics ?? MirroringAnalytics(AnalyticsService());

  late final RemoteConfigApi _remoteConfig =
      widget.remoteConfig ?? RemoteConfigService();

  late final CrashReporterApi _crashReporter =
      widget.crashReporter ?? MirroringCrashReporter(CrashlyticsService());

  late final AdminAccessApi _adminAccess = AdminAccessService();
```

`AuthGate` currently constructs its own `AuthViewModel` — locate it (`lib/screens/
auth_gate.dart`) and pass `adminAccess: _adminAccess` the same way `analytics` is already
threaded through, if `AuthGate` takes a constructor parameter for it; otherwise expose
`_adminAccess` the same way the other services are exposed and read it inside `AuthGate` via
`context.read<AdminAccessApi>()`. Add the provider:

```dart
        Provider<AdminAccessApi>.value(value: _adminAccess),
```

to the `providers:` list in `_JournalTrendAppState.build`, right after
`Provider<CrashReporterApi>.value(value: _crashReporter),`. Then open
`lib/screens/auth_gate.dart`, read its current `AuthViewModel` construction, and change it
to pass `adminAccess: context.read<AdminAccessApi>()`.

- [ ] **Step 13: Run the full test suite and analyzer**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`; every test file (existing + all new admin ones) PASSES with
no regressions.

- [ ] **Step 14: Manual smoke check (see Session-specific guidance: for UI changes, exercise
      the feature in a real app before calling it done)**

```bash
flutter run -d <device-or-emulator-id>
```

Sign in, confirm the Profile tab shows no "Admin Dashboard" tile for a non-admin account,
then (after running `functions/scripts/set-admin-claim.js` for your own account and signing
out/in) confirm the tile appears and each of the four admin screens loads without crashing.
Note in the PR/report that Cloud Functions must be deployed
(`cd functions && npm run build && firebase deploy --only functions,firestore`) before this
smoke check can succeed end-to-end.

- [ ] **Step 15: Commit**

```bash
git add lib/screens/admin_dashboard_screen.dart lib/screens/admin_users_screen.dart lib/screens/admin_remote_config_screen.dart lib/screens/admin_storage_screen.dart lib/screens/admin_logs_screen.dart lib/screens/screens.dart lib/screens/profile_screen.dart lib/main.dart lib/screens/auth_gate.dart test/admin_dashboard_screen_test.dart test/profile_screen_test.dart
git commit -m "feat: wire the admin dashboard into Profile + app providers"
```

---

## After this plan

- **Patrol stabilization** is a separate, parallel stream (see design §8) — approached via
  `superpowers:systematic-debugging` per failing case, not part of this plan's tasks.
- **Deploying** the Cloud Functions/Firestore rules to the real `journal-analyzer-3c319`
  project (`firebase deploy --only functions,firestore`) and running
  `functions/scripts/set-admin-claim.js` for the first real admin account are manual,
  environment-specific steps outside this plan's automated tasks.
