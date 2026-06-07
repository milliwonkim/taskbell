import {
  createCloudKitConfig,
  privateDatabaseUrl,
  SWIFTDATA_ZONE_NAME,
  type CloudKitConfig,
} from "./config.js";
import {
  mapAnniversaryItemRecord,
  mapReminderRecord,
  mapTodoAttachmentRecord,
  mapTodoItemRecord,
} from "./mappers.js";
import {
  RecordType,
  type AnniversaryItemRecord,
  type CloudKitQueryResponse,
  type CloudKitRecord,
  type RecordTypeName,
  type ReminderRecord,
  type TodoAttachmentRecord,
  type TodoItemRecord,
} from "./types.js";

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

export class TaskBellCloudKitClient {
  private readonly config: CloudKitConfig;
  private readonly baseUrl: string;

  constructor(config: CloudKitConfig) {
    this.config = config;
    this.baseUrl = privateDatabaseUrl(config);
  }

  static fromEnv(env: Record<string, string | undefined> = {}): TaskBellCloudKitClient {
    const resolved =
      Object.keys(env).length > 0
        ? env
        : (globalThis as { process?: { env: Record<string, string | undefined> } }).process
            ?.env ?? {};
    return new TaskBellCloudKitClient(createCloudKitConfig(resolved));
  }

  /** CloudKit Web Services 로그인 URL 조회 (서버에서 호출) */
  async getLoginRequest(): Promise<{ redirectURL: string }> {
    const url = `${this.baseUrl}/users/current?ckAPIToken=${encodeURIComponent(this.config.apiKey)}`;
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`CloudKit 로그인 요청 실패: ${response.status} ${response.statusText}`);
    }
    const json = (await response.json()) as { redirectURL?: string };
    if (!json.redirectURL) {
      throw new Error("CloudKit 로그인 응답에 redirectURL이 없습니다.");
    }
    return { redirectURL: json.redirectURL };
  }

  /** 인증 콜백 후 세션 토큰 교환 */
  async exchangeAuthCallback(callbackUrl: string): Promise<CloudKitAuthSession> {
    const url = new URL(callbackUrl);
    const ckWebAuthToken = url.searchParams.get("ckWebAuthToken");
    if (!ckWebAuthToken) {
      throw new Error("콜백 URL에 ckWebAuthToken이 없습니다.");
    }
    return { ckWebAuthToken };
  }

  private async queryRecords(
    session: CloudKitAuthSession,
    options: QueryOptions,
  ): Promise<CloudKitQueryResponse> {
    const sortBy = options.sortField
      ? [{ fieldName: options.sortField, ascending: options.ascending ?? false }]
      : undefined;

    const body: Record<string, unknown> = {
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

    const url =
      `${this.baseUrl}/records/query` +
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
        throw new Error(
          `CloudKit 쿼리 실패 (${options.recordType}): recordName 인덱스가 없습니다. ` +
            `CloudKit Console → Schema → Indexes 에서 ${options.recordType}의 recordName(또는 recordID)에 QUERYABLE 인덱스를 추가하세요. ` +
            `또는 cloudkit/scripts/fix-query-indexes.sh 를 실행하세요.`,
        );
      }
      throw new Error(`CloudKit 쿼리 실패 (${options.recordType}): ${response.status} ${text}`);
    }

    const json = (await response.json()) as {
      records?: CloudKitRecord[];
      continuationMarker?: string;
    };

    return {
      records: json.records ?? [],
      ...(json.continuationMarker ? { continuationMarker: json.continuationMarker } : {}),
    };
  }

  async fetchAllTodoItems(session: CloudKitAuthSession): Promise<TodoItemRecord[]> {
    return this.fetchAllRecords(session, {
      recordType: RecordType.todoItem,
      sortField: "CD_createdAt",
      ascending: false,
    }, mapTodoItemRecord);
  }

  async fetchAllAnniversaries(session: CloudKitAuthSession): Promise<AnniversaryItemRecord[]> {
    return this.fetchAllRecords(session, {
      recordType: RecordType.anniversaryItem,
      sortField: "CD_targetDate",
      ascending: true,
    }, mapAnniversaryItemRecord);
  }

  async fetchAllReminders(session: CloudKitAuthSession): Promise<ReminderRecord[]> {
    return this.fetchAllRecords(session, {
      recordType: RecordType.reminder,
      sortField: "CD_fireDate",
      ascending: true,
    }, mapReminderRecord);
  }

  async fetchAllAttachments(session: CloudKitAuthSession): Promise<TodoAttachmentRecord[]> {
    return this.fetchAllRecords(session, {
      recordType: RecordType.todoAttachment,
      sortField: "CD_createdAt",
      ascending: false,
    }, mapTodoAttachmentRecord);
  }

  private async fetchAllRecords<T>(
    session: CloudKitAuthSession,
    options: QueryOptions,
    mapper: (record: CloudKitRecord) => T,
  ): Promise<T[]> {
    const results: T[] = [];
    let continuationMarker: string | undefined;

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
