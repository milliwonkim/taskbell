import { cookies } from "next/headers";

export const CK_WEB_AUTH_COOKIE = "ckWebAuthToken";

export async function getCloudKitSessionToken(): Promise<string | null> {
  const cookieStore = await cookies();
  return cookieStore.get(CK_WEB_AUTH_COOKIE)?.value ?? null;
}

export async function requireCloudKitSessionToken(): Promise<string> {
  const token = await getCloudKitSessionToken();
  if (!token) {
    throw new Error("CloudKit 인증이 필요합니다. /api/auth/login 으로 로그인하세요.");
  }
  return token;
}
