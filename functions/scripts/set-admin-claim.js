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
