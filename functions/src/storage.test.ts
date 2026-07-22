import { HttpsError } from "firebase-functions/v2/https";

const getFiles = jest.fn();
const getSignedUrl = jest.fn();
const deleteFile = jest.fn();
const file = jest.fn(() => ({ getSignedUrl, delete: deleteFile }));
const bucket = jest.fn(() => ({ getFiles, file }));

jest.mock("firebase-admin", () => ({
  storage: () => ({ bucket }),
}));

import {
  listReportsHandler,
  getReportUrlHandler,
  deleteReportHandler,
} from "./storage";

const adminAuth = { uid: "admin1", token: { admin: true } };

beforeEach(() => {
  getFiles.mockReset();
  getSignedUrl.mockReset();
  deleteFile.mockReset();
  file.mockClear();
});

describe("listReportsHandler", () => {
  it("maps bucket files under reports/ into summaries", async () => {
    getFiles.mockResolvedValue([
      [
        {
          name: "reports/u1/2026-report.pdf",
          metadata: { size: "1024", timeCreated: "2026-01-01T00:00:00Z" },
        },
      ],
    ]);

    const result = await listReportsHandler({}, adminAuth);

    expect(getFiles).toHaveBeenCalledWith({ prefix: "reports/" });
    expect(result).toEqual({
      reports: [
        {
          path: "reports/u1/2026-report.pdf",
          size: 1024,
          uploadedAt: "2026-01-01T00:00:00Z",
          uid: "u1",
        },
      ],
    });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      listReportsHandler({}, { uid: "u1", token: {} })
    ).rejects.toThrow(HttpsError);
  });
});

describe("getReportUrlHandler", () => {
  it("returns a signed URL for a reports/ path", async () => {
    getSignedUrl.mockResolvedValue(["https://signed.example/x"]);
    const result = await getReportUrlHandler(
      { path: "reports/u1/2026-report.pdf" },
      adminAuth
    );
    expect(result).toEqual({ url: "https://signed.example/x" });
  });

  it("rejects a path outside reports/", async () => {
    await expect(
      getReportUrlHandler({ path: "other/file.pdf" }, adminAuth)
    ).rejects.toThrow(HttpsError);
  });
});

describe("deleteReportHandler", () => {
  it("deletes a report", async () => {
    deleteFile.mockResolvedValue(undefined);
    const result = await deleteReportHandler(
      { path: "reports/u1/2026-report.pdf" },
      adminAuth
    );
    expect(deleteFile).toHaveBeenCalled();
    expect(result).toEqual({ path: "reports/u1/2026-report.pdf" });
  });

  it("rejects a path outside reports/", async () => {
    await expect(
      deleteReportHandler({ path: "other/file.pdf" }, adminAuth)
    ).rejects.toThrow(HttpsError);
  });
});
