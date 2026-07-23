# Firestore rules tests

Emulator-backed unit tests for [`../firestore.rules`](../firestore.rules) — the
admin-panel collections `admin_events` and `admin_crash_reports`. They prove the
rules behave correctly without a real Firebase project, sign-in, or console:

- a signed-in user can write an event/crash record **for their own uid only**,
- extra/forged fields are rejected,
- **only** an admin (custom claim `admin: true`) can read the collections,
- records are immutable, and every other collection is denied.

## Run

Needs the Firebase CLI (`firebase`) and Java (for the Firestore emulator).

```bash
cd firestore-rules-test
npm install
npm test        # wraps jest in `firebase emulators:exec --only firestore`
```

The `demo-journal` project id keeps the emulator fully offline (no credentials).
