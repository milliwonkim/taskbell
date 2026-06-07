import { createCloudKitConfig, privateDatabaseUrl, SWIFTDATA_ZONE_NAME, } from "./config.js";
import { mapAnniversaryItemRecord, mapReminderRecord, mapTodoAttachmentRecord, mapTodoItemRecord, } from "./mappers.js";
import { RecordType, } from "./types.js";
export class TaskBellCloudKitClient {
    config;
    baseUrl;
    constructor(config) {
        this.config = config;
        this.baseUrl = privateDatabaseUrl(config);
    }
    static fromEnv(env = {}) {
        const resolved = Object.keys(env).length > 0
            ? env
            : globalThis.process
                ?.env ?? {};
        return new TaskBellCloudKitClient(createCloudKitConfig(resolved));
    }
    /** CloudKit Web Services 로그인 URL 조회 (서버에서 호출) */
    async getLoginRequest() {
        const url = `${this.baseUrl}/users/current?ckAPIToken=${encodeURIComponent(this.config.apiKey)}`;
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`CloudKit 로그인 요청 실패: ${response.status} ${response.statusText}`);
        }
        const json = (await response.json());
        if (!json.redirectURL) {
            throw new Error("CloudKit 로그인 응답에 redirectURL이 없습니다.");
        }
        return { redirectURL: json.redirectURL };
    }
    /** 인증 콜백 후 세션 토큰 교환 */
    async exchangeAuthCallback(callbackUrl) {
        const url = new URL(callbackUrl);
        const ckWebAuthToken = url.searchParams.get("ckWebAuthToken");
        if (!ckWebAuthToken) {
            throw new Error("콜백 URL에 ckWebAuthToken이 없습니다.");
        }
        return { ckWebAuthToken };
    }
    async queryRecords(session, options) {
        const sortBy = options.sortField
            ? [{ fieldName: options.sortField, ascending: options.ascending ?? false }]
            : undefined;
        const body = {
            zoneID: { zoneName: SWIFTDATA_ZONE_NAME },
            query: {
                recordType: options.recordType,
                ...(sortBy ? { sortBy } : {}),
            },
            ...(options.limit ? { resultsLimit: options.limit } : {}),
            ...(options.continuationMarker
                ? { continuationMarker: options.continuationMarker }
                : {}),
        };
        const url = `${this.baseUrl}/records/query` +
            `?ckAPIToken=${encodeURIComponent(this.config.apiKey)}` +
            `&ckWebAuthToken=${encodeURIComponent(session.ckWebAuthToken)}`;
        const response = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body),
        });
        if (!response.ok) {
            const text = await response.text();
            if (text.includes("recordName") && text.includes("not marked queryable")) {
                throw new Error(`CloudKit 쿼리 실패 (${options.recordType}): recordName 인덱스가 없습니다. ` +
                    `CloudKit Console → Schema → Indexes 에서 ${options.recordType}의 recordName(또는 recordID)에 QUERYABLE 인덱스를 추가하세요. ` +
                    `또는 cloudkit/scripts/fix-query-indexes.sh 를 실행하세요.`);
            }
            throw new Error(`CloudKit 쿼리 실패 (${options.recordType}): ${response.status} ${text}`);
        }
        const json = (await response.json());
        return {
            records: json.records ?? [],
            ...(json.continuationMarker ? { continuationMarker: json.continuationMarker } : {}),
        };
    }
    async fetchAllTodoItems(session) {
        return this.fetchAllRecords(session, {
            recordType: RecordType.todoItem,
            sortField: "CD_createdAt",
            ascending: false,
        }, mapTodoItemRecord);
    }
    async fetchAllAnniversaries(session) {
        return this.fetchAllRecords(session, {
            recordType: RecordType.anniversaryItem,
            sortField: "CD_targetDate",
            ascending: true,
        }, mapAnniversaryItemRecord);
    }
    async fetchAllReminders(session) {
        return this.fetchAllRecords(session, {
            recordType: RecordType.reminder,
            sortField: "CD_fireDate",
            ascending: true,
        }, mapReminderRecord);
    }
    async fetchAllAttachments(session) {
        return this.fetchAllRecords(session, {
            recordType: RecordType.todoAttachment,
            sortField: "CD_createdAt",
            ascending: false,
        }, mapTodoAttachmentRecord);
    }
    async fetchAllRecords(session, options, mapper) {
        const results = [];
        let continuationMarker;
        do {
            const page = await this.queryRecords(session, {
                ...options,
                ...(continuationMarker ? { continuationMarker } : {}),
            });
            results.push(...page.records.map(mapper));
            continuationMarker = page.continuationMarker;
        } while (continuationMarker);
        return results;
    }
}
//# sourceMappingURL=client.js.map