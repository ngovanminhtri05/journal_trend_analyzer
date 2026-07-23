import * as admin from "firebase-admin";

admin.initializeApp();

export { adminListUsers, adminSetUserDisabled, adminDeleteUser } from "./users";
export {
  adminGetRemoteConfigTemplate,
  adminUpdateRemoteConfigParameter,
} from "./remote-config";
export {
  adminListReports,
  adminGetReportUrl,
  adminDeleteReport,
} from "./storage";
export { adminSendNotification } from "./notifications";
