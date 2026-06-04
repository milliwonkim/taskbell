//
//  TaskBellWidgetData.swift
//  TaskBellWidget
//

import Foundation

enum TaskBellWidgetSnapshotStore {
    static let appGroupIdentifier = "group.kiwonkim.TaskBell"

    private static let fileName = "taskbell-weekly-widget.json"

    static func load() -> TaskBellWidgetSnapshot {
        guard
            let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
                .appendingPathComponent(fileName),
            let data = try? Data(contentsOf: url),
            let snapshot = try? JSONDecoder().decode(TaskBellWidgetSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }
}

struct TaskBellWidgetSnapshot: Codable {
    let generatedAt: Date
    let weekStart: Date
    let weekEnd: Date
    let days: [TaskBellWidgetDaySnapshot]
    let todos: [TaskBellWidgetTodoSnapshot]
    let anniversaries: [TaskBellWidgetAnniversarySnapshot]
    let languageRawValue: String

    enum CodingKeys: String, CodingKey {
        case generatedAt
        case weekStart
        case weekEnd
        case days
        case todos
        case anniversaries
        case languageRawValue
    }

    init(
        generatedAt: Date,
        weekStart: Date,
        weekEnd: Date,
        days: [TaskBellWidgetDaySnapshot],
        todos: [TaskBellWidgetTodoSnapshot],
        anniversaries: [TaskBellWidgetAnniversarySnapshot],
        languageRawValue: String = "ko"
    ) {
        self.generatedAt = generatedAt
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.days = days
        self.todos = todos
        self.anniversaries = anniversaries
        self.languageRawValue = languageRawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        weekStart = try container.decode(Date.self, forKey: .weekStart)
        weekEnd = try container.decode(Date.self, forKey: .weekEnd)
        days = try container.decode([TaskBellWidgetDaySnapshot].self, forKey: .days)
        todos = try container.decode([TaskBellWidgetTodoSnapshot].self, forKey: .todos)
        anniversaries = try container.decodeIfPresent(
            [TaskBellWidgetAnniversarySnapshot].self,
            forKey: .anniversaries
        ) ?? []
        languageRawValue = try container.decodeIfPresent(
            String.self,
            forKey: .languageRawValue
        ) ?? "ko"
    }

    static var empty: TaskBellWidgetSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let days = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart).map {
                TaskBellWidgetDaySnapshot(date: $0, totalCount: 0, completedCount: 0)
            }
        }

        return TaskBellWidgetSnapshot(
            generatedAt: now,
            weekStart: weekStart,
            weekEnd: weekEnd,
            days: days,
            todos: [],
            anniversaries: [],
            languageRawValue: "ko"
        )
    }

    static var placeholder: TaskBellWidgetSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let days = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart).map {
                TaskBellWidgetDaySnapshot(
                    date: $0,
                    totalCount: offset.isMultiple(of: 2) ? 2 : 1,
                    completedCount: offset == 0 ? 1 : 0
                )
            }
        }

        return TaskBellWidgetSnapshot(
            generatedAt: now,
            weekStart: weekStart,
            weekEnd: weekEnd,
            days: days,
            todos: [
                TaskBellWidgetTodoSnapshot(
                    title: "Planning Notes",
                    isCompleted: false,
                    scheduledStartAt: now,
                    scheduledEndAt: nil,
                    scheduleModeRawValue: "singleDay"
                ),
                TaskBellWidgetTodoSnapshot(
                    title: "Check Reminders",
                    isCompleted: true,
                    scheduledStartAt: now,
                    scheduledEndAt: nil,
                    scheduleModeRawValue: "singleDay"
                )
            ],
            anniversaries: [
                TaskBellWidgetAnniversarySnapshot(
                    title: "Project Launch",
                    targetDate: now.addingTimeInterval(86400 * 12),
                    repeatsYearly: false
                ),
                TaskBellWidgetAnniversarySnapshot(
                    title: "Anniversary",
                    targetDate: now.addingTimeInterval(86400 * 36),
                    repeatsYearly: true
                )
            ],
            languageRawValue: "en"
        )
    }
}

struct TaskBellWidgetDaySnapshot: Codable, Identifiable {
    let date: Date
    let totalCount: Int
    let completedCount: Int

    var id: Date { date }
}

struct TaskBellWidgetTodoSnapshot: Codable, Identifiable {
    let title: String
    let isCompleted: Bool
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    let scheduleModeRawValue: String

    var id: String {
        "\(title)-\(scheduledStartAt?.timeIntervalSinceReferenceDate ?? 0)-\(scheduledEndAt?.timeIntervalSinceReferenceDate ?? 0)"
    }
}

struct TaskBellWidgetAnniversarySnapshot: Codable, Identifiable {
    let title: String
    let targetDate: Date
    let repeatsYearly: Bool

    var id: String {
        "\(title)-\(targetDate.timeIntervalSinceReferenceDate)-\(repeatsYearly)"
    }
}
