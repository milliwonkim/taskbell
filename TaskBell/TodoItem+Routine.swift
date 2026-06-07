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
}
