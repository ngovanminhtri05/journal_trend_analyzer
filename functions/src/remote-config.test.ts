import { HttpsError } from "firebase-functions/v2/https";

const getTemplate = jest.fn();
const validateTemplate = jest.fn();
const publishTemplate = jest.fn();

jest.mock("firebase-admin", () => ({
  remoteConfig: () => ({ getTemplate, validateTemplate, publishTemplate }),
}));

import {
  getRemoteConfigTemplateHandler,
  updateRemoteConfigParameterHandler,
} from "./remote-config";

const adminAuth = { uid: "admin1", token: { admin: true } };

beforeEach(() => {
  getTemplate.mockReset();
  validateTemplate.mockReset();
  publishTemplate.mockReset();
});

describe("getRemoteConfigTemplateHandler", () => {
  it("flattens the template into key/defaultValue pairs", async () => {
    getTemplate.mockResolvedValue({
      parameters: {
        max_journals: { defaultValue: { value: "15" } },
        max_keywords: { defaultValue: { value: "20" } },
      },
    });

    const result = await getRemoteConfigTemplateHandler({}, adminAuth);

    expect(result).toEqual({
      parameters: [
        { key: "max_journals", defaultValue: "15" },
        { key: "max_keywords", defaultValue: "20" },
      ],
    });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      getRemoteConfigTemplateHandler({}, { uid: "u1", token: {} })
    ).rejects.toThrow(HttpsError);
  });
});

describe("updateRemoteConfigParameterHandler", () => {
  it("publishes an updated parameter", async () => {
    getTemplate.mockResolvedValue({ parameters: {} });
    validateTemplate.mockResolvedValue(undefined);
    publishTemplate.mockResolvedValue(undefined);

    const result = await updateRemoteConfigParameterHandler(
      { key: "max_journals", defaultValue: "25" },
      adminAuth
    );

    expect(publishTemplate).toHaveBeenCalledWith({
      parameters: { max_journals: { defaultValue: { value: "25" } } },
    });
    expect(result).toEqual({ key: "max_journals", defaultValue: "25" });
  });

  it("rejects a missing key", async () => {
    await expect(
      updateRemoteConfigParameterHandler(
        { defaultValue: "25" } as any,
        adminAuth
      )
    ).rejects.toThrow(HttpsError);
  });
});
