import { type CloudKitConfig } from "./config.js";
import { type AnniversaryItemRecord, type RecordTypeName, type ReminderRecord, type TodoAttachmentRecord, type TodoItemRecord } from "./types.js";
export interface QueryOptions {
    readonly recordType: RecordTypeName;
    readonly sortField?: string;
    readonly ascending?: boolean;
    readonly limit?: number;
    readonly continuationMarker?: string;
}
export interface CloudKitAuthSession {
    readonly ckWebAuthToken: string;
}
export declare class TaskBellCloudKitClient {
    private readonly config;
    private readonly baseUrl;
    constructor(config: CloudKitConfig);
    static fromEnv(env?: Record<string, string | undefined>): TaskBellCloudKitClient;
    /** CloudKit Web Services 로그인 URL 조회 (서버에서 호출) */
    getLoginRequest(): Promise<{
        redirectURL: string;
    }>;
    /** 인증 콜백 후 세션 토큰 교환 */
    exchangeAuthCallback(callbackUrl: string): Promise<CloudKitAuthSession>;
    private queryRecords;
    fetchAllTodoItems(session: CloudKitAuthSession): Promise<TodoItemRecord[]>;
    fetchAllAnniversaries(session: CloudKitAuthSession): Promise<AnniversaryItemRecord[]>;
    fetchAllReminders(session: CloudKitAuthSession): Promise<ReminderRecord[]>;
    fetchAllAttachments(session: CloudKitAuthSession): Promise<TodoAttachmentRecord[]>;
    private fetchAllRecords;
}
//# sourceMappingURL=client.d.ts.map