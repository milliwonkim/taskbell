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
    var scheduledStartAt: Date?
    var scheduledEndAt: Date?
    var reminders: [ReminderDraft]

    init(
        title: String = "",
        content: String = "",
        isCompleted: Bool = false,
        scheduleMode: TodoScheduleMode = .singleDay,
        scheduledStartAt: Date? = .now,
        scheduledEndAt: Date? = nil,
        reminders: [ReminderDraft] = []
    ) {
        self.title = title
        self.content = content
        self.isCompleted = isCompleted
        self.scheduleMode = scheduleMode
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.reminders = reminders
    }

    init(todo: TodoItem) {
        self.init(
            title: todo.title,
            content: todo.content,
            isCompleted: todo.isCompleted,
            scheduleMode: todo.scheduleMode,
            scheduledStartAt: todo.scheduledStartAt,
            scheduledEndAt: todo.scheduledEndAt,
            reminders: todo.reminders
                .sorted { $0.fireDate < $1.fireDate }
                .map { reminder in
                    ReminderDraft(reminder: reminder)
                }
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
