import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { requireAdmin, CallableAuth } from "./admin-guard";

const { onCall, HttpsError } = functions.https;

/** FCM topic every app install subscribes to (see MessagingService). */
export const BROADCAST_TOPIC = "broadcast";

export async function sendNotificationHandler(
  data: { title?: string; body?: string },
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  const title = data?.title?.trim();
  const body = data?.body?.trim();
  if (!title || !body) {
    throw new HttpsError(
      "invalid-argument",
      "title and body are required."
    );
  }
  const messageId = await admin.messaging().send({
    topic: BROADCAST_TOPIC,
    notification: { title, body },
  });
  return { messageId };
}

export const adminSendNotification = onCall((data, context) =>
  sendNotificationHandler(data, context.auth as CallableAuth | undefined)
);
