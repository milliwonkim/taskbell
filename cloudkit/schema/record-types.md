# TaskBell CloudKit 스키마 (SwiftData 매핑)

SwiftData + CloudKit은 Core Data 규칙을 따릅니다. 레코드 타입과 필드에 `CD_` 접두사가 붙습니다.

## Zone

| 항목 | 값 |
|------|-----|
| Database | Private |
| Zone | `com.apple.coredata.cloudkit.zone` |
| Container | `iCloud.kiwonkim.TaskBell` |

## 레코드 타입

### CD_TodoItem

| CloudKit 필드 | SwiftData 속성 | 타입 |
|---------------|----------------|------|
| CD_entityName | (시스템) | STRING = "TodoItem" |
| CD_title | title | STRING |
| CD_content | content | STRING |
| CD_isCompleted | isCompleted | INT64 (0/1) |
| CD_scheduleModeRawValue | scheduleModeRawValue | STRING |
| CD_priorityRawValue | priorityRawValue | STRING |
| CD_autoDeletePeriodRawValue | autoDeletePeriodRawValue | STRING |
| CD_scheduledStartAt | scheduledStartAt | TIMESTAMP (optional) |
| CD_scheduledEndAt | scheduledEndAt | TIMESTAMP (optional) |
| CD_locationLatitude | locationLatitude | DOUBLE (optional) |
| CD_locationLongitude | locationLongitude | DOUBLE (optional) |
| CD_createdAt | createdAt | TIMESTAMP |
| CD_timelineSortOrder | timelineSortOrder | DOUBLE |
| CD_routineSeriesID | routineSeriesID | BYTES/STRING (optional) |
| CD_routineFrequencyRawValue | routineFrequencyRawValue | STRING |
| CD_routineWeekdaysRawValue | routineWeekdaysRawValue | STRING |
| CD_reminders | reminders | LIST&lt;REFERENCE&gt; |
| CD_attachments | attachments | LIST&lt;REFERENCE&gt; |

### CD_AnniversaryItem

| CloudKit 필드 | SwiftData 속성 | 타입 |
|---------------|----------------|------|
| CD_entityName | (시스템) | STRING = "AnniversaryItem" |
| CD_id | id | BYTES/STRING |
| CD_title | title | STRING |
| CD_targetDate | targetDate | TIMESTAMP |
| CD_repeatsYearly | repeatsYearly | INT64 (0/1) |
| CD_createdAt | createdAt | TIMESTAMP |

### CD_Reminder

| CloudKit 필드 | SwiftData 속성 | 타입 |
|---------------|----------------|------|
| CD_entityName | (시스템) | STRING = "Reminder" |
| CD_id | id | BYTES/STRING |
| CD_fireDate | fireDate | TIMESTAMP |
| CD_repeatRuleRawValue | repeatRuleRawValue | STRING |
| CD_deliveryStyleRawValue | deliveryStyleRawValue | STRING |
| CD_isEnabled | isEnabled | INT64 (0/1) |
| CD_createdAt | createdAt | TIMESTAMP |
| CD_todo | todo | REFERENCE |

### CD_TodoAttachment

| CloudKit 필드 | SwiftData 속성 | 타입 |
|---------------|----------------|------|
| CD_entityName | (시스템) | STRING = "TodoAttachment" |
| CD_id | id | BYTES/STRING |
| CD_kindRawValue | kindRawValue | STRING |
| CD_contentType | contentType | STRING |
| CD_fileName | fileName | STRING |
| CD_createdAt | createdAt | TIMESTAMP |
| CD_data | data | ASSET |
| CD_todo | todo | REFERENCE |

## CloudKit JS 쿼리에 필요한 인덱스

CloudKit은 기본적으로 필드 인덱스를 만들지 않습니다. 웹에서 쿼리하려면 아래 인덱스가 필요합니다.

| Record Type | Field | Index Type |
|-------------|-------|------------|
| CD_TodoItem | ___recordID | QUERYABLE |
| CD_TodoItem | CD_createdAt | QUERYABLE, SORTABLE |
| CD_TodoItem | CD_title | QUERYABLE |
| CD_AnniversaryItem | ___recordID | QUERYABLE |
| CD_AnniversaryItem | CD_targetDate | QUERYABLE, SORTABLE |
| CD_Reminder | ___recordID | QUERYABLE |
| CD_Reminder | CD_fireDate | QUERYABLE, SORTABLE |
| CD_TodoAttachment | ___recordID | QUERYABLE |
