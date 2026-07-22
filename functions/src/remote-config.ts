import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { requireAdmin, CallableAuth } from "./admin-guard";

export async function getRemoteConfigTemplateHandler(
  _data: unknown,
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  const template = await admin.remoteConfig().getTemplate();
  const parameters = Object.entries(template.parameters ?? {}).map(
    ([key, param]: [string, any]) => ({
      key,
      defaultValue:
        param?.defaultValue && "value" in param.defaultValue
          ? param.defaultValue.value
          : null,
    })
  );
  return { parameters };
}

export async function updateRemoteConfigParameterHandler(
  data: { key?: string; defaultValue?: string },
  auth: CallableAuth | undefined
) {
  requireAdmin(auth);
  const key = data?.key;
  const value = data?.defaultValue;
  if (!key || typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "key and defaultValue (string) are required."
    );
  }
  const template = await admin.remoteConfig().getTemplate();
  template.parameters = template.parameters ?? {};
  template.parameters[key] = { defaultValue: { value } };
  await admin.remoteConfig().validateTemplate(template);
  await admin.remoteConfig().publishTemplate(template);
  return { key, defaultValue: value };
}

export const adminGetRemoteConfigTemplate = onCall((request: CallableRequest) =>
  getRemoteConfigTemplateHandler(request.data, request.auth as CallableAuth | undefined)
);

export const adminUpdateRemoteConfigParameter = onCall(
  (request: CallableRequest) =>
    updateRemoteConfigParameterHandler(request.data, request.auth as CallableAuth | undefined)
);
