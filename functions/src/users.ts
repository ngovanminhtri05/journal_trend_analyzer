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
  listUsersHandler(request.data, request.auth as CallableAuth | undefined)
);

export const adminSetUserDisabled = onCall((request: CallableRequest) =>
  setUserDisabledHandler(request.data, request.auth as CallableAuth | undefined)
);

export const adminDeleteUser = onCall((request: CallableRequest) =>
  deleteUserHandler(request.data, request.auth as CallableAuth | undefined)
);
