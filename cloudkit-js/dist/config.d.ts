export type CloudKitEnvironment = "development" | "production";
export interface CloudKitConfig {
    readonly apiKey: string;
    readonly containerId: string;
    readonly environment: CloudKitEnvironment;
}
/** SwiftData + CloudKit이 사용하는 Core Data zone */
export declare const SWIFTDATA_ZONE_NAME: "com.apple.coredata.cloudkit.zone";
export declare function createCloudKitConfig(env: {
    APPLE_CK_API_KEY?: string;
    APPLE_CK_CONTAINER?: string;
    APPLE_CK_ENVIRONMENT?: string;
}): CloudKitConfig;
export declare function privateDatabaseUrl(config: CloudKitConfig): string;
//# sourceMappingURL=config.d.ts.map