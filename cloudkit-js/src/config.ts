export type CloudKitEnvironment = "development" | "production";

export interface CloudKitConfig {
  readonly apiKey: string;
  readonly containerId: string;
  readonly environment: CloudKitEnvironment;
}

/** SwiftData + CloudKit이 사용하는 Core Data zone */
export const SWIFTDATA_ZONE_NAME = "com.apple.coredata.cloudkit.zone" as const;

export function createCloudKitConfig(env: {
  APPLE_CK_API_KEY?: string;
  APPLE_CK_CONTAINER?: string;
  APPLE_CK_ENVIRONMENT?: string;
}): CloudKitConfig {
  const apiKey = env.APPLE_CK_API_KEY;
  const containerId = env.APPLE_CK_CONTAINER ?? "iCloud.kiwonkim.TaskBell";
  const environment = env.APPLE_CK_ENVIRONMENT ?? "development";

  if (!apiKey) {
    throw new Error("APPLE_CK_API_KEY 환경 변수가 필요합니다.");
  }

  if (environment !== "development" && environment !== "production") {
    throw new Error(`APPLE_CK_ENVIRONMENT은 development 또는 production 이어야 합니다: ${environment}`);
  }

  return { apiKey, containerId, environment };
}

export function privateDatabaseUrl(config: CloudKitConfig): string {
  return `https://api.apple-cloudkit.com/database/1/${config.containerId}/${config.environment}/private`;
}
