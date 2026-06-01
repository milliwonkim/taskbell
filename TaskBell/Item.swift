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
    var scheduledStartAt: Date?
    var scheduledEndAt: Date?
    var locationLatitude: Double?
    var locationLongitude: Double?
    var createdAt: Date = Date()
    var timelineSortOrder: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \Reminder.todo)
    var reminders: [Reminder] = []

    @Relationship(deleteRule: .cascade, inverse: \TodoAttachment.todo)
    var attachments: [TodoAttachment] = []

    init(
        title: String,
        content: String = "",
        isCompleted: Bool = false,
        scheduleMode: TodoScheduleMode = .none,
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
        switch self {
        case .photo:
            "사진"
        case .video:
            "동영상"
        }
    }
}

enum TodoScheduleMode: String, CaseIterable, Identifiable, Codable {
    case none
    case singleDay
    case dateRange

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            "없음"
        case .singleDay:
            "하루"
        case .dateRange:
            "기간"
        }
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

enum ReminderRepeatRule: String, CaseIterable, Identifiable, Codable {
    case once
    case daily
    case weekly
    case monthly
    case yearly

    var id: Self { self }

    var title: String {
        switch self {
        case .once:
            "한 번"
        case .daily:
            "매일"
        case .weekly:
            "매주"
        case .monthly:
            "매월"
        case .yearly:
            "매년"
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
        switch self {
        case .notificationOnly:
            "푸시 알림"
        case .notificationAndVibration:
            "푸시 알림 + 진동"
        }
    }

    func title(repeatRule: ReminderRepeatRule) -> String {
        var components = [title]

        if repeatRule != .once {
            components.append("\(repeatRule.title) 반복")
        }

        return components.joined(separator: " + ")
    }

    var subtitle: String {
        switch self {
        case .notificationOnly:
            "소리와 진동 없이 알림만 표시"
        case .notificationAndVibration:
            "기기 설정에 따라 소리와 진동 사용"
        }
    }
}
