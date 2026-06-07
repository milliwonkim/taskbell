/** SwiftData + CloudKit이 사용하는 Core Data zone */
export const SWIFTDATA_ZONE_NAME = "com.apple.coredata.cloudkit.zone";
export function createCloudKitConfig(env) {
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
export function privateDatabaseUrl(config) {
    return `https://api.apple-cloudkit.com/database/1/${config.containerId}/${config.environment}/private`;
}
//# sourceMappingURL=config.js.map