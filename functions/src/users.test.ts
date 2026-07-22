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
