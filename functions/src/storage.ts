import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { requireAdmin, CallableAuth } from "./admin-guard";

const { onCall, HttpsError } = functions.https;

function assertReportsPath(path: string | undefined): asserts path is string {
  if (!path || !path.startsWith("reports/")) {
    throw new HttpsError(
      "invalid-argument",
      "A valid reports/ path is required."
    );
  }
}

export async function listReportsHandler(
  data: { uid?: string },
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  // Scope to one user's folder when a uid is given, else list all reports.
  const uid = data?.uid?.trim();
  const prefix = uid ? `reports/${uid}/` : "reports/";
  const [files] = await admin.storage().bucket().getFiles({ prefix });
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

export const adminListReports = onCall((data, context) =>
  listReportsHandler(data, context.auth as CallableAuth | undefined)
);

export const adminGetReportUrl = onCall((data, context) =>
  getReportUrlHandler(data, context.auth as CallableAuth | undefined)
);

export const adminDeleteReport = onCall((data, context) =>
  deleteReportHandler(data, context.auth as CallableAuth | undefined)
);
