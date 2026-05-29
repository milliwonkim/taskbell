//
//  WidgetSnapshotStore.swift
//  TaskBell
//

import Foundation
import WidgetKit

enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.kiwonkim.TaskBell"

    private static let fileName = "taskbell-weekly-widget.json"

    static func save(todos: [TodoItem], now: Date = .now, calendar: Calendar = .current) {
        guard let url = snapshotURL else {
            return
        }

        let snapshot = TaskBellWidgetSnapshot(todos: todos, now: now, calendar: calendar)

        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            assertionFailure("Failed to save widget snapshot: \(error)")
        }
    }

    private static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }
}

private struct TaskBellWidgetSnapshot: Codable {
    let generatedAt: Date
    let weekStart: Date
    let weekEnd: Date
    let days: [TaskBellWidgetDaySnapshot]
    let todos: [TaskBellWidgetTodoSnapshot]

    init(todos: [TodoItem], now: Date, calendar: Calendar) {
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekStart = weekInterval?.start ?? calendar.startOfDay(for: now)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let weekDates = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
        let weekTodos = todos
            .filter { todo in
                weekDates.contains { todo.isScheduled(on: $0, calendar: calendar) }
            }
            .sorted { first, second in
                let firstDate =
                    first.firstScheduledDate(in: weekDates, calendar: calendar)
                    ?? first.createdAt
                let secondDate =
                    second.firstScheduledDate(in: weekDates, calendar: calendar)
                    ?? second.createdAt

                if firstDate == secondDate {
                    return first.createdAt > second.createdAt
                }

                return firstDate < secondDate
            }

        self.generatedAt = now
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.days = weekDates.map { date in
            let dayTodos = weekTodos.filter { $0.isScheduled(on: date, calendar: calendar) }

            return TaskBellWidgetDaySnapshot(
                date: date,
                totalCount: dayTodos.count,
                completedCount: dayTodos.filter(\.isCompleted).count
            )
        }
        self.todos = weekTodos.map { TaskBellWidgetTodoSnapshot(todo: $0, calendar: calendar) }
    }
}

private extension TodoItem {
    func firstScheduledDate(in dates: [Date], calendar: Calendar) -> Date? {
        dates.compactMap { relevantDate(for: $0, calendar: calendar) }.min()
    }
}

private struct TaskBellWidgetDaySnapshot: Codable {
    let date: Date
    let totalCount: Int
    let completedCount: Int
}

private struct TaskBellWidgetTodoSnapshot: Codable {
    let title: String
    let isCompleted: Bool
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    let scheduleModeRawValue: String

    init(todo: TodoItem, calendar: Calendar) {
        self.title = todo.title
        self.isCompleted = todo.isCompleted
        self.scheduledStartAt = todo.scheduledStartAt
        self.scheduledEndAt = todo.scheduledEndAt
        self.scheduleModeRawValue = todo.scheduleModeRawValue
    }
}
