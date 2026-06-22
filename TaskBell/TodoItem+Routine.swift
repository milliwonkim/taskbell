//
//  TodoItem+Routine.swift
//  TaskBell
//

import Foundation

extension TodoItem {
    func routineAnchorDate(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: scheduledStartAt ?? createdAt)
    }

    func routineSeriesTodosIncludingFuture(
        in allTodos: [TodoItem],
        calendar: Calendar = .current
    ) -> [TodoItem] {
        guard let seriesID = routineSeriesID else {
            return [self]
        }

        let anchorDate = routineAnchorDate(calendar: calendar)

        return allTodos.filter { candidate in
            candidate.routineSeriesID == seriesID
                && candidate.routineAnchorDate(calendar: calendar) >= anchorDate
        }
    }

    func routineSeriesTodos(in allTodos: [TodoItem]) -> [TodoItem] {
        guard let seriesID = routineSeriesID else {
            return [self]
        }

        return allTodos
            .filter { $0.routineSeriesID == seriesID }
            .sorted {
                ($0.scheduledStartAt ?? $0.createdAt) < ($1.scheduledStartAt ?? $1.createdAt)
            }
    }
}
