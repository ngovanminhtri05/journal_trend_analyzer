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
