import { HttpsError } from "firebase-functions/v2/https";

const send = jest.fn();

jest.mock("firebase-admin", () => ({
  messaging: () => ({ send }),
}));

import {
  sendNotificationHandler,
  sendNotificationToUserHandler,
  BROADCAST_TOPIC,
  userTopic,
} from "./notifications";

const adminAuth = { uid: "admin1", token: { admin: true } };

beforeEach(() => send.mockReset());

describe("sendNotificationHandler", () => {
  it("broadcasts a notification to the topic", async () => {
    send.mockResolvedValue("projects/x/messages/123");

    const result = await sendNotificationHandler(
      { title: "Hello", body: "World" },
      adminAuth
    );

    expect(send).toHaveBeenCalledWith({
      topic: BROADCAST_TOPIC,
      notification: { title: "Hello", body: "World" },
    });
    expect(result).toEqual({ messageId: "projects/x/messages/123" });
  });

  it("trims title/body before sending", async () => {
    send.mockResolvedValue("id");
    await sendNotificationHandler(
      { title: "  Hi  ", body: "  there  " },
      adminAuth
    );
    expect(send).toHaveBeenCalledWith({
      topic: BROADCAST_TOPIC,
      notification: { title: "Hi", body: "there" },
    });
  });

  it("rejects an empty title or body", async () => {
    await expect(
      sendNotificationHandler({ title: "", body: "x" }, adminAuth)
    ).rejects.toThrow(HttpsError);
    await expect(
      sendNotificationHandler({ title: "x", body: "   " }, adminAuth)
    ).rejects.toThrow(HttpsError);
    expect(send).not.toHaveBeenCalled();
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      sendNotificationHandler({ title: "a", body: "b" }, { uid: "u1", token: {} })
    ).rejects.toThrow(HttpsError);
    expect(send).not.toHaveBeenCalled();
  });
});

describe("sendNotificationToUserHandler", () => {
  it("sends to the target user's per-user topic", async () => {
    send.mockResolvedValue("id");

    await sendNotificationToUserHandler(
      { uid: "u1", title: "Hi", body: "there" },
      adminAuth
    );

    expect(send).toHaveBeenCalledWith({
      topic: userTopic("u1"),
      notification: { title: "Hi", body: "there" },
    });
  });

  it("rejects when uid, title, or body is missing", async () => {
    await expect(
      sendNotificationToUserHandler({ title: "a", body: "b" }, adminAuth)
    ).rejects.toThrow(HttpsError);
    await expect(
      sendNotificationToUserHandler({ uid: "u1", body: "b" }, adminAuth)
    ).rejects.toThrow(HttpsError);
    expect(send).not.toHaveBeenCalled();
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      sendNotificationToUserHandler(
        { uid: "u1", title: "a", body: "b" },
        { uid: "u2", token: {} }
      )
    ).rejects.toThrow(HttpsError);
    expect(send).not.toHaveBeenCalled();
  });
});
