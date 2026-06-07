import { TaskBellCloudKitClient } from "@taskbell/cloudkit-js";
import { requireCloudKitSessionToken } from "../../../lib/cloudkit-session.js";
import { NextResponse } from "next/server";

export async function GET(): Promise<NextResponse> {
  try {
    const client = TaskBellCloudKitClient.fromEnv();
    const ckWebAuthToken = await requireCloudKitSessionToken();
    const anniversaries = await client.fetchAllAnniversaries({ ckWebAuthToken });
    return NextResponse.json({ anniversaries });
  } catch (error) {
    const message = error instanceof Error ? error.message : "기념일 조회 실패";
    const status = message.includes("인증") ? 401 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
