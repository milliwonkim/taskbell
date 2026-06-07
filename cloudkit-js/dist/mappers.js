function fieldString(record, key, fallback = "") {
    const field = record.fields[key];
    if (!field || field.type !== "STRING")
        return fallback;
    return field.value;
}
function fieldInt64(record, key, fallback = 0) {
    const field = record.fields[key];
    if (!field || field.type !== "INT64")
        return fallback;
    return field.value;
}
function fieldDouble(record, key) {
    const field = record.fields[key];
    if (!field || field.type !== "DOUBLE")
        return null;
    return field.value;
}
function fieldTimestamp(record, key) {
    const field = record.fields[key];
    if (!field || field.type !== "TIMESTAMP")
        return null;
    const parsed = new Date(field.value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
}
function fieldReference(record, key) {
    const field = record.fields[key];
    if (!field || field.type !== "REFERENCE")
        return null;
    return field.value;
}
function fieldBytesAsUuid(record, key) {
    const field = record.fields[key];
    if (!field)
        return null;
    if (field.type === "STRING" && field.value.length > 0)
        return field.value;
    if (field.type === "BYTES" && field.value.length > 0)
        return field.value;
    return null;
}
export function mapTodoItemRecord(record) {
    return {
        recordName: record.recordName,
        title: fieldString(record, "CD_title"),
        content: fieldString(record, "CD_content"),
        isCompleted: fieldInt64(record, "CD_isCompleted") !== 0,
        scheduleModeRawValue: fieldString(record, "CD_scheduleModeRawValue"),
        priorityRawValue: fieldString(record, "CD_priorityRawValue"),
        autoDeletePeriodRawValue: fieldString(record, "CD_autoDeletePeriodRawValue"),
        scheduledStartAt: fieldTimestamp(record, "CD_scheduledStartAt"),
        scheduledEndAt: fieldTimestamp(record, "CD_scheduledEndAt"),
        locationLatitude: fieldDouble(record, "CD_locationLatitude"),
        locationLongitude: fieldDouble(record, "CD_locationLongitude"),
        createdAt: fieldTimestamp(record, "CD_createdAt") ?? new Date(0),
        timelineSortOrder: fieldDouble(record, "CD_timelineSortOrder") ?? 0,
        routineSeriesID: fieldBytesAsUuid(record, "CD_routineSeriesID"),
        routineFrequencyRawValue: fieldString(record, "CD_routineFrequencyRawValue"),
        routineWeekdaysRawValue: fieldString(record, "CD_routineWeekdaysRawValue"),
    };
}
export function mapAnniversaryItemRecord(record) {
    return {
        recordName: record.recordName,
        id: fieldBytesAsUuid(record, "CD_id") ?? record.recordName,
        title: fieldString(record, "CD_title"),
        targetDate: fieldTimestamp(record, "CD_targetDate") ?? new Date(0),
        repeatsYearly: fieldInt64(record, "CD_repeatsYearly") !== 0,
        createdAt: fieldTimestamp(record, "CD_createdAt") ?? new Date(0),
    };
}
export function mapReminderRecord(record) {
    return {
        recordName: record.recordName,
        id: fieldBytesAsUuid(record, "CD_id") ?? record.recordName,
        fireDate: fieldTimestamp(record, "CD_fireDate") ?? new Date(0),
        repeatRuleRawValue: fieldString(record, "CD_repeatRuleRawValue"),
        deliveryStyleRawValue: fieldString(record, "CD_deliveryStyleRawValue"),
        isEnabled: fieldInt64(record, "CD_isEnabled") !== 0,
        createdAt: fieldTimestamp(record, "CD_createdAt") ?? new Date(0),
        todoRecordName: fieldReference(record, "CD_todo"),
    };
}
export function mapTodoAttachmentRecord(record) {
    return {
        recordName: record.recordName,
        id: fieldBytesAsUuid(record, "CD_id") ?? record.recordName,
        kindRawValue: fieldString(record, "CD_kindRawValue"),
        contentType: fieldString(record, "CD_contentType"),
        fileName: fieldString(record, "CD_fileName"),
        createdAt: fieldTimestamp(record, "CD_createdAt") ?? new Date(0),
        todoRecordName: fieldReference(record, "CD_todo"),
    };
}
//# sourceMappingURL=mappers.js.map