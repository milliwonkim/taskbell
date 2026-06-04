//
//  Item.swift
//  TaskBell
//
//  Created by 김기원 on 5/29/26.
//

import Foundation
import SwiftData

@Model
final class TodoItem {
    var title: String = ""
    var content: String = ""
    var isCompleted: Bool = false
    var scheduleModeRawValue: String = TodoScheduleMode.none.rawValue
    var priorityRawValue: String = TodoPriorityQuadrant.importantUrgent.rawValue
    var autoDeletePeriodRawValue: String = TodoAutoDeletePeriod.oneMonth.rawValue
    var scheduledStartAt: Date?
    var scheduledEndAt: Date?
    var locationLatitude: Double?
    var locationLongitude: Double?
    var createdAt: Date = Date()
    var timelineSortOrder: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \Reminder.todo)
    var reminders: [Reminder]? = []

    @Relationship(deleteRule: .cascade, inverse: \TodoAttachment.todo)
    var attachments: [TodoAttachment]? = []

    init(
        title: String,
        content: String = "",
        isCompleted: Bool = false,
        scheduleMode: TodoScheduleMode = .none,
        priority: TodoPriorityQuadrant = .importantUrgent,
        autoDeletePeriod: TodoAutoDeletePeriod = .oneMonth,
        scheduledStartAt: Date? = nil,
        scheduledEndAt: Date? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        createdAt: Date = .now,
        timelineSortOrder: Double = 0,
        reminders: [Reminder] = [],
        attachments: [TodoAttachment] = []
    ) {
        self.title = title
        self.content = content
        self.isCompleted = isCompleted
        self.scheduleModeRawValue = scheduleMode.rawValue
        self.priorityRawValue = priority.rawValue
        self.autoDeletePeriodRawValue = autoDeletePeriod.rawValue
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.createdAt = createdAt
        self.timelineSortOrder = timelineSortOrder == 0
            ? createdAt.timeIntervalSinceReferenceDate
            : timelineSortOrder
        self.reminders = reminders
        self.attachments = attachments
    }

    var scheduleMode: TodoScheduleMode {
        get { TodoScheduleMode(rawValue: scheduleModeRawValue) ?? .none }
        set { scheduleModeRawValue = newValue.rawValue }
    }

    var priority: TodoPriorityQuadrant {
        get { TodoPriorityQuadrant(rawValue: priorityRawValue) ?? .importantUrgent }
        set { priorityRawValue = newValue.rawValue }
    }

    var autoDeletePeriod: TodoAutoDeletePeriod {
        get { TodoAutoDeletePeriod(rawValue: autoDeletePeriodRawValue) ?? .oneMonth }
        set { autoDeletePeriodRawValue = newValue.rawValue }
    }
}

@Model
final class TodoAttachment {
    var id: UUID = UUID()
    var kindRawValue: String = TodoAttachmentKind.photo.rawValue
    var contentType: String = ""
    var fileName: String = ""
    var createdAt: Date = Date()

    @Attribute(.externalStorage)
    var data: Data = Data()

    var todo: TodoItem?

    init(
        id: UUID = UUID(),
        kind: TodoAttachmentKind,
        contentType: String,
        fileName: String,
        data: Data,
        createdAt: Date = .now,
        todo: TodoItem? = nil
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.contentType = contentType
        self.fileName = fileName
        self.data = data
        self.createdAt = createdAt
        self.todo = todo
    }

    var kind: TodoAttachmentKind {
        get { TodoAttachmentKind(rawValue: kindRawValue) ?? .photo }
        set { kindRawValue = newValue.rawValue }
    }
}

enum TodoAttachmentKind: String, Codable {
    case photo
    case video

    var title: String {
        title(in: .korean)
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .photo:
            language.text(korean: "사진", english: "Photo")
        case .video:
            language.text(korean: "동영상", english: "Video")
        }
    }
}

enum TodoScheduleMode: String, CaseIterable, Identifiable, Codable {
    case none
    case singleDay
    case dateRange

    var id: Self { self }

    var title: String {
        title(in: .korean)
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .none:
            language.text(korean: "없음", english: "None")
        case .singleDay:
            language.text(korean: "하루", english: "Single Day")
        case .dateRange:
            language.text(korean: "기간", english: "Date Range")
        }
    }
}

enum TodoPriorityQuadrant: String, CaseIterable, Identifiable, Codable {
    case importantUrgent
    case importantNotUrgent
    case notImportantUrgent
    case notImportantNotUrgent

    var id: Self { self }

    var title: String {
        switch self {
        case .importantUrgent:
            "Important & Urgent"
        case .importantNotUrgent:
            "Important, Not Urgent"
        case .notImportantUrgent:
            "Not Important, Urgent"
        case .notImportantNotUrgent:
            "Not Important, Not Urgent"
        }
    }

    var shortTitle: String {
        switch self {
        case .importantUrgent:
            "Important · Urgent"
        case .importantNotUrgent:
            "Important · Not Urgent"
        case .notImportantUrgent:
            "Not Important · Urgent"
        case .notImportantNotUrgent:
            "Not Important · Not Urgent"
        }
    }

    var systemImage: String {
        switch self {
        case .importantUrgent:
            "flame.fill"
        case .importantNotUrgent:
            "star.fill"
        case .notImportantUrgent:
            "bolt.fill"
        case .notImportantNotUrgent:
            "tray.fill"
        }
    }
}

enum TodoAutoDeletePeriod: String, CaseIterable, Identifiable, Codable {
    case oneWeek
    case oneMonth
    case sixMonths
    case oneYear

    var id: Self { self }

    var title: String {
        title(in: .korean)
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .oneWeek:
            language.text(korean: "일주일", english: "1 Week")
        case .oneMonth:
            language.text(korean: "한 달", english: "1 Month")
        case .sixMonths:
            language.text(korean: "6개월", english: "6 Months")
        case .oneYear:
            language.text(korean: "1년", english: "1 Year")
        }
    }

    var dateComponent: DateComponents {
        switch self {
        case .oneWeek:
            DateComponents(day: 7)
        case .oneMonth:
            DateComponents(month: 1)
        case .sixMonths:
            DateComponents(month: 6)
        case .oneYear:
            DateComponents(year: 1)
        }
    }

    func expirationDate(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: dateComponent, to: date) ?? date
    }
}

@Model
final class Reminder {
    var id: UUID = UUID()
    var fireDate: Date = Date()
    var repeatRuleRawValue: String = ReminderRepeatRule.once.rawValue
    var deliveryStyleRawValue: String = ReminderDeliveryStyle.notificationAndVibration.rawValue
    var isEnabled: Bool = true
    var createdAt: Date = Date()

    var todo: TodoItem?

    init(
        id: UUID = UUID(),
        fireDate: Date = .now.addingTimeInterval(3600),
        repeatRule: ReminderRepeatRule = .once,
        deliveryStyle: ReminderDeliveryStyle = .notificationAndVibration,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        todo: TodoItem? = nil
    ) {
        self.id = id
        self.fireDate = fireDate
        self.repeatRuleRawValue = repeatRule.rawValue
        self.deliveryStyleRawValue = deliveryStyle.rawValue
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.todo = todo
    }

    var repeatRule: ReminderRepeatRule {
        get { ReminderRepeatRule(rawValue: repeatRuleRawValue) ?? .once }
        set { repeatRuleRawValue = newValue.rawValue }
    }

    var deliveryStyle: ReminderDeliveryStyle {
        get { ReminderDeliveryStyle(rawValue: deliveryStyleRawValue) ?? .notificationAndVibration }
        set { deliveryStyleRawValue = newValue.rawValue }
    }

    var notificationIdentifier: String {
        "reminder-\(id.uuidString)"
    }
}

@Model
final class AnniversaryItem {
    var id: UUID = UUID()
    var title: String = ""
    var targetDate: Date = Date()
    var repeatsYearly: Bool = true
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String,
        targetDate: Date,
        repeatsYearly: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.repeatsYearly = repeatsYearly
        self.createdAt = createdAt
    }
}

enum ReminderRepeatRule: String, CaseIterable, Identifiable, Codable {
    case once
    case daily
    case weekly
    case monthly
    case yearly

    var id: Self { self }

    var title: String {
        title(in: .korean)
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .once:
            language.text(korean: "한 번", english: "Once")
        case .daily:
            language.text(korean: "매일", english: "Daily")
        case .weekly:
            language.text(korean: "매주", english: "Weekly")
        case .monthly:
            language.text(korean: "매월", english: "Monthly")
        case .yearly:
            language.text(korean: "매년", english: "Yearly")
        }
    }
}

enum ReminderDeliveryStyle: String, CaseIterable, Identifiable, Codable {
    case notificationOnly
    case notificationAndVibration

    var id: Self { self }

    var includesVibration: Bool {
        self == .notificationAndVibration
    }

    static func style(includesVibration: Bool) -> Self {
        includesVibration ? .notificationAndVibration : .notificationOnly
    }

    var title: String {
        title(in: .korean)
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .notificationOnly:
            language.text(korean: "푸시 알림", english: "Push Notification")
        case .notificationAndVibration:
            language.text(korean: "푸시 알림 + 진동", english: "Push Notification + Vibration")
        }
    }

    func title(repeatRule: ReminderRepeatRule, language: AppLanguage = .korean) -> String {
        var components = [title(in: language)]

        if repeatRule != .once {
            components.append(
                language.text(
                    korean: "\(repeatRule.title(in: language)) 반복",
                    english: "Repeats \(repeatRule.title(in: language))"
                )
            )
        }

        return components.joined(separator: " + ")
    }

    var subtitle: String {
        subtitle(in: .korean)
    }

    func subtitle(in language: AppLanguage) -> String {
        switch self {
        case .notificationOnly:
            language.text(korean: "소리와 진동 없이 알림만 표시", english: "Shows notifications without sound or vibration")
        case .notificationAndVibration:
            language.text(korean: "기기 설정에 따라 소리와 진동 사용", english: "Uses sound and vibration based on device settings")
        }
    }
}

extension TodoItem {
    convenience init(cloudImporting legacyTodo: TodoItem) {
        self.init(
            title: legacyTodo.title,
            content: legacyTodo.content,
            isCompleted: legacyTodo.isCompleted,
            scheduleMode: legacyTodo.scheduleMode,
            priority: legacyTodo.priority,
            autoDeletePeriod: legacyTodo.autoDeletePeriod,
            scheduledStartAt: legacyTodo.scheduledStartAt,
            scheduledEndAt: legacyTodo.scheduledEndAt,
            locationLatitude: legacyTodo.locationLatitude,
            locationLongitude: legacyTodo.locationLongitude,
            createdAt: legacyTodo.createdAt,
            timelineSortOrder: legacyTodo.timelineSortOrder
        )

        attachments = (legacyTodo.attachments ?? []).map {
            TodoAttachment(cloudImporting: $0, todo: self)
        }
        reminders = (legacyTodo.reminders ?? []).map {
            Reminder(cloudImporting: $0, todo: self)
        }
    }
}

extension TodoAttachment {
    convenience init(cloudImporting legacyAttachment: TodoAttachment, todo: TodoItem) {
        self.init(
            id: legacyAttachment.id,
            kind: legacyAttachment.kind,
            contentType: legacyAttachment.contentType,
            fileName: legacyAttachment.fileName,
            data: legacyAttachment.data,
            createdAt: legacyAttachment.createdAt,
            todo: todo
        )
    }
}

extension Reminder {
    convenience init(cloudImporting legacyReminder: Reminder, todo: TodoItem) {
        self.init(
            id: legacyReminder.id,
            fireDate: legacyReminder.fireDate,
            repeatRule: legacyReminder.repeatRule,
            deliveryStyle: legacyReminder.deliveryStyle,
            isEnabled: legacyReminder.isEnabled,
            createdAt: legacyReminder.createdAt,
            todo: todo
        )
    }
}
