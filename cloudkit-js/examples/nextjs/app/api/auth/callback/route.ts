import { TaskBellCloudKitClient } from "@taskbell/cloudkit-js";
import { CK_WEB_AUTH_COOKIE } from "../../../../lib/cloudkit-session.js";
import { NextRequest, NextResponse } from "next/server";

export async function GET(request: NextRequest): Promise<NextResponse> {
  try {
    const client = TaskBellCloudKitClient.fromEnv();
    const session = await client.exchangeAuthCallback(request.url);

    const response = NextResponse.redirect(new URL("/", request.url));
    response.cookies.set(CK_WEB_AUTH_COOKIE, session.ckWebAuthToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: 60 * 60 * 24 * 30,
    });
    return response;
  } catch (error) {
    const message = error instanceof Error ? error.message : "CloudKit 콜백 처리 실패";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
