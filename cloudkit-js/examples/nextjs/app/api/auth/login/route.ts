import { TaskBellCloudKitClient } from "@taskbell/cloudkit-js";
import { NextResponse } from "next/server";

export async function GET(): Promise<NextResponse> {
  try {
    const client = TaskBellCloudKitClient.fromEnv();
    const { redirectURL } = await client.getLoginRequest();
    return NextResponse.redirect(redirectURL);
  } catch (error) {
    const message = error instanceof Error ? error.message : "CloudKit 로그인 실패";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
