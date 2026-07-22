import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { requireAdmin, CallableAuth } from "./admin-guard";

const { onCall, HttpsError } = functions.https;

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

export const adminListUsers = onCall((data, context) =>
  listUsersHandler(data, context.auth as CallableAuth | undefined)
);

export const adminSetUserDisabled = onCall((data, context) =>
  setUserDisabledHandler(data, context.auth as CallableAuth | undefined)
);

export const adminDeleteUser = onCall((data, context) =>
  deleteUserHandler(data, context.auth as CallableAuth | undefined)
);
