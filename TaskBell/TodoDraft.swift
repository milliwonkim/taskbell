//
//  TodoDraft.swift
//  TaskBell
//

import Foundation

struct TodoDraft {
    var title: String
    var content: String
    var isCompleted: Bool
    var scheduleMode: TodoScheduleMode
    var priority: TodoPriorityQuadrant
    var autoDeletePeriod: TodoAutoDeletePeriod
    var scheduledStartAt: Date?
    var scheduledEndAt: Date?
    var locationLatitude: Double?
    var locationLongitude: Double?
    var attachments: [TodoAttachmentDraft]
    var reminders: [ReminderDraft]
    var routine: TodoRoutineDraft

    init(
        title: String = "",
        content: String = "",
        isCompleted: Bool = false,
        scheduleMode: TodoScheduleMode = .singleDay,
        priority: TodoPriorityQuadrant = .importantUrgent,
        autoDeletePeriod: TodoAutoDeletePeriod = .oneMonth,
        scheduledStartAt: Date? = .now,
        scheduledEndAt: Date? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        attachments: [TodoAttachmentDraft] = [],
        reminders: [ReminderDraft] = [],
        routine: TodoRoutineDraft = TodoRoutineDraft()
    ) {
        self.title = title
        self.content = content
        self.isCompleted = isCompleted
        self.scheduleMode = scheduleMode
        self.priority = priority
        self.autoDeletePeriod = autoDeletePeriod
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.attachments = attachments
        self.reminders = reminders
        self.routine = routine
    }

    init(todo: TodoItem) {
        self.init(
            title: todo.title,
            content: todo.content,
            isCompleted: todo.isCompleted,
            scheduleMode: todo.scheduleMode,
            priority: todo.priority,
            autoDeletePeriod: todo.autoDeletePeriod,
            scheduledStartAt: todo.scheduledStartAt,
            scheduledEndAt: todo.scheduledEndAt,
            locationLatitude: todo.locationLatitude,
            locationLongitude: todo.locationLongitude,
            attachments: (todo.attachments ?? [])
                .sorted { $0.createdAt < $1.createdAt }
                .map { attachment in
                    TodoAttachmentDraft(attachment: attachment)
                },
            reminders: (todo.reminders ?? [])
                .sorted { $0.fireDate < $1.fireDate }
                .map { reminder in
                    ReminderDraft(reminder: reminder)
                }
        )
    }
}

struct TodoRoutineDraft: Equatable {
    var frequency: TodoRoutineFrequency
    var occurrenceCount: Int
    var customInterval: Int
    var customUnit: TodoRoutineIntervalUnit

    init(
        frequency: TodoRoutineFrequency = .none,
        occurrenceCount: Int = 7,
        customInterval: Int = 2,
        customUnit: TodoRoutineIntervalUnit = .day
    ) {
        self.frequency = frequency
        self.occurrenceCount = occurrenceCount
        self.customInterval = customInterval
        self.customUnit = customUnit
    }

    var isEnabled: Bool {
        frequency != .none
    }

    var normalizedOccurrenceCount: Int {
        max(1, min(occurrenceCount, 365))
    }

    var normalizedCustomInterval: Int {
        max(1, min(customInterval, 365))
    }
}

enum TodoRoutineFrequency: String, CaseIterable, Identifiable, Codable {
    case none
    case daily
    case weekly
    case monthly
    case yearly
    case custom

    var id: Self { self }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .none:
            language.text(korean: "반복 없음", english: "No Routine")
        case .daily:
            language.text(korean: "매일", english: "Daily")
        case .weekly:
            language.text(korean: "매주", english: "Weekly")
        case .monthly:
            language.text(korean: "매달", english: "Monthly")
        case .yearly:
            language.text(korean: "매년", english: "Yearly")
        case .custom:
            language.text(korean: "커스텀", english: "Custom")
        }
    }

    var dateComponent: Calendar.Component? {
        switch self {
        case .none, .custom:
            nil
        case .daily:
            .day
        case .weekly:
            .weekOfYear
        case .monthly:
            .month
        case .yearly:
            .year
        }
    }
}

enum TodoRoutineIntervalUnit: String, CaseIterable, Identifiable, Codable {
    case day
    case week
    case month
    case year

    var id: Self { self }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .day:
            language.text(korean: "일", english: "Days")
        case .week:
            language.text(korean: "주", english: "Weeks")
        case .month:
            language.text(korean: "개월", english: "Months")
        case .year:
            language.text(korean: "년", english: "Years")
        }
    }

    var dateComponent: Calendar.Component {
        switch self {
        case .day:
            .day
        case .week:
            .weekOfYear
        case .month:
            .month
        case .year:
            .year
        }
    }
}

struct TodoAttachmentDraft: Identifiable, Equatable {
    var id: UUID
    var kind: TodoAttachmentKind
    var contentType: String
    var fileName: String
    var data: Data
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: TodoAttachmentKind,
        contentType: String,
        fileName: String,
        data: Data,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.contentType = contentType
        self.fileName = fileName
        self.data = data
        self.createdAt = createdAt
    }

    init(attachment: TodoAttachment) {
        self.init(
            id: attachment.id,
            kind: attachment.kind,
            contentType: attachment.contentType,
            fileName: attachment.fileName,
            data: attachment.data,
            createdAt: attachment.createdAt
        )
    }
}

struct ReminderDraft: Identifiable, Equatable {
    var id: UUID
    var fireDate: Date
    var repeatRule: ReminderRepeatRule
    var deliveryStyle: ReminderDeliveryStyle
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        fireDate: Date = .now.addingTimeInterval(3600),
        repeatRule: ReminderRepeatRule = .once,
        deliveryStyle: ReminderDeliveryStyle = .notificationAndVibration,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.fireDate = fireDate
        self.repeatRule = repeatRule
        self.deliveryStyle = deliveryStyle
        self.isEnabled = isEnabled
    }

    init(reminder: Reminder) {
        self.init(
            id: reminder.id,
            fireDate: reminder.fireDate,
            repeatRule: reminder.repeatRule,
            deliveryStyle: reminder.deliveryStyle,
            isEnabled: reminder.isEnabled
        )
    }
}
