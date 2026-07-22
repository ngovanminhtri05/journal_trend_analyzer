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
