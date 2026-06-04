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
        reminders: [ReminderDraft] = []
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
