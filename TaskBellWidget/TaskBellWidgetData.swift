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
            todos: []
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
                    title: "기획 정리",
                    isCompleted: false,
                    scheduledStartAt: now,
                    scheduledEndAt: nil,
                    scheduleModeRawValue: "singleDay"
                ),
                TaskBellWidgetTodoSnapshot(
                    title: "리마인더 확인",
                    isCompleted: true,
                    scheduledStartAt: now,
                    scheduledEndAt: nil,
                    scheduleModeRawValue: "singleDay"
                )
            ]
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
