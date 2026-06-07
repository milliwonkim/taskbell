/** SwiftData → CloudKit 레코드 타입 (CD_ 접두사) */
export declare const RecordType: {
    readonly todoItem: "CD_TodoItem";
    readonly todoAttachment: "CD_TodoAttachment";
    readonly reminder: "CD_Reminder";
    readonly anniversaryItem: "CD_AnniversaryItem";
};
export type RecordTypeName = (typeof RecordType)[keyof typeof RecordType];
export type CloudKitFieldValue = {
    value: string;
    type: "STRING";
} | {
    value: number;
    type: "INT64";
} | {
    value: number;
    type: "DOUBLE";
} | {
    value: string;
    type: "TIMESTAMP";
} | {
    value: string;
    type: "REFERENCE";
} | {
    value: string;
    type: "ASSET";
} | {
    value: string;
    type: "BYTES";
};
export interface CloudKitRecord {
    recordName: string;
    recordType: RecordTypeName;
    recordChangeTag?: string;
    fields: Record<string, CloudKitFieldValue>;
    created?: {
        timestamp: number;
        userRecordName: string;
    };
    modified?: {
        timestamp: number;
        userRecordName: string;
    };
}
export interface CloudKitQueryResponse {
    records: CloudKitRecord[];
    continuationMarker?: string;
}
/** CloudKit Web Services 필드 → 앱 도메인 타입 */
export interface TodoItemRecord {
    recordName: string;
    title: string;
    content: string;
    isCompleted: boolean;
    scheduleModeRawValue: string;
    priorityRawValue: string;
    autoDeletePeriodRawValue: string;
    scheduledStartAt: Date | null;
    scheduledEndAt: Date | null;
    locationLatitude: number | null;
    locationLongitude: number | null;
    createdAt: Date;
    timelineSortOrder: number;
    routineSeriesID: string | null;
    routineFrequencyRawValue: string;
    routineWeekdaysRawValue: string;
}
export interface AnniversaryItemRecord {
    recordName: string;
    id: string;
    title: string;
    targetDate: Date;
    repeatsYearly: boolean;
    createdAt: Date;
}
export interface ReminderRecord {
    recordName: string;
    id: string;
    fireDate: Date;
    repeatRuleRawValue: string;
    deliveryStyleRawValue: string;
    isEnabled: boolean;
    createdAt: Date;
    todoRecordName: string | null;
}
export interface TodoAttachmentRecord {
    recordName: string;
    id: string;
    kindRawValue: string;
    contentType: string;
    fileName: string;
    createdAt: Date;
    todoRecordName: string | null;
}
//# sourceMappingURL=types.d.ts.map