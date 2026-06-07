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
    var routineSeriesID: UUID?

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
        routine: TodoRoutineDraft = TodoRoutineDraft(),
        routineSeriesID: UUID? = nil
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
        self.routineSeriesID = routineSeriesID
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
    var selectedWeekdays: Set<TodoRoutineWeekday>

    init(
        frequency: TodoRoutineFrequency = .none,
        selectedWeekdays: Set<TodoRoutineWeekday> = []
    ) {
        self.frequency = frequency
        self.selectedWeekdays = selectedWeekdays
    }

    var isEnabled: Bool {
        frequency != .none
    }

    var hasValidCustomWeekdays: Bool {
        frequency != .custom || !selectedWeekdays.isEmpty
    }

    func occurrenceDates(
        startDate: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        switch frequency {
        case .none:
            [startDate]
        case .daily:
            indexedOccurrenceDates(
                startDate: startDate,
                component: .day,
                count: 365,
                calendar: calendar
            )
        case .weekly:
            indexedOccurrenceDates(
                startDate: startDate,
                component: .weekOfYear,
                count: 104,
                calendar: calendar
            )
        case .monthly:
            indexedOccurrenceDates(
                startDate: startDate,
                component: .month,
                count: 24,
                calendar: calendar
            )
        case .yearly:
            indexedOccurrenceDates(
                startDate: startDate,
                component: .year,
                count: 10,
                calendar: calendar
            )
        case .custom:
            customWeekdayOccurrenceDates(
                startDate: startDate,
                calendar: calendar
            )
        }
    }

    private func indexedOccurrenceDates(
        startDate: Date,
        component: Calendar.Component,
        count: Int,
        calendar: Calendar
    ) -> [Date] {
        (0..<count).compactMap { index in
            calendar.date(byAdding: component, value: index, to: startDate)
        }
    }

    private func customWeekdayOccurrenceDates(
        startDate: Date,
        calendar: Calendar
    ) -> [Date] {
        guard !selectedWeekdays.isEmpty else {
            return [startDate]
        }

        let startOfStart = calendar.startOfDay(for: startDate)
        let timeComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: startDate
        )

        return (0..<365).compactMap { offset -> Date? in
            guard let day = calendar.date(
                byAdding: .day,
                value: offset,
                to: startOfStart
            ) else {
                return nil
            }

            let weekdayValue = calendar.component(.weekday, from: day)
            guard let weekday = TodoRoutineWeekday(rawValue: weekdayValue),
                  selectedWeekdays.contains(weekday) else {
                return nil
            }

            var components = calendar.dateComponents(
                [.year, .month, .day],
                from: day
            )
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            components.second = timeComponents.second
            return calendar.date(from: components)
        }
    }
}

enum TodoRoutineWeekday: Int, CaseIterable, Identifiable, Codable, Hashable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    static let displayOrder: [TodoRoutineWeekday] = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
        .sunday,
    ]

    func shortTitle(in language: AppLanguage) -> String {
        switch self {
        case .sunday:
            language.text(korean: "일", english: "Sun")
        case .monday:
            language.text(korean: "월", english: "Mon")
        case .tuesday:
            language.text(korean: "화", english: "Tue")
        case .wednesday:
            language.text(korean: "수", english: "Wed")
        case .thursday:
            language.text(korean: "목", english: "Thu")
        case .friday:
            language.text(korean: "금", english: "Fri")
        case .saturday:
            language.text(korean: "토", english: "Sat")
        }
    }

    init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday)
    }
}

extension Set where Element == TodoRoutineWeekday {
    var encodedRawValue: String {
        map(\.rawValue)
            .sorted()
            .map(String.init)
            .joined(separator: ",")
    }

    init(encodedRawValue: String) {
        self = Set(
            encodedRawValue
                .split(separator: ",")
                .compactMap { Int($0) }
                .compactMap(TodoRoutineWeekday.init(rawValue:))
        )
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
