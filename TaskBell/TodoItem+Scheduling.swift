//
//  TodoItem+Scheduling.swift
//  TaskBell
//

import Foundation

extension TodoItem {
    func coveredDates(calendar: Calendar) -> [Date] {
        switch scheduleMode {
        case .none:
            return []
        case .singleDay:
            guard let start = scheduledStartAt else {
                return []
            }

            return [calendar.startOfDay(for: start)]
        case .dateRange:
            guard let start = scheduledStartAt else {
                return []
            }

            let end = scheduledEndAt ?? start
            var currentDay = calendar.startOfDay(for: min(start, end))
            let finalDay = calendar.startOfDay(for: max(start, end))
            var dates: [Date] = []

            while currentDay <= finalDay, dates.count < 370 {
                dates.append(currentDay)

                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else {
                    break
                }

                currentDay = nextDay
            }

            return dates
        }
    }

    func isScheduled(on date: Date, calendar: Calendar) -> Bool {
        switch scheduleMode {
        case .none:
            return false
        case .singleDay:
            guard let start = scheduledStartAt else {
                return false
            }

            return calendar.isDate(start, inSameDayAs: date)
        case .dateRange:
            guard let start = scheduledStartAt else {
                return false
            }

            let end = scheduledEndAt ?? start
            let normalizedStart = min(start, end)
            let normalizedEnd = max(start, end)
            let dayStart = calendar.startOfDay(for: date)
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return false
            }
            let dayEnd = nextDayStart.addingTimeInterval(-1)

            return normalizedStart <= dayEnd && normalizedEnd >= dayStart
        }
    }

    func relevantDate(for date: Date, calendar: Calendar) -> Date? {
        switch scheduleMode {
        case .none:
            return nil
        case .singleDay:
            return scheduledStartAt
        case .dateRange:
            guard let start = scheduledStartAt else {
                return nil
            }

            return max(start, calendar.startOfDay(for: date))
        }
    }

    var scheduleSummary: String? {
        guard let start = scheduledStartAt else {
            return nil
        }

        switch scheduleMode {
        case .none:
            return nil
        case .singleDay:
            return start.formatted(date: .abbreviated, time: .shortened)
        case .dateRange:
            guard let end = scheduledEndAt else {
                return start.formatted(date: .abbreviated, time: .shortened)
            }

            return "\(start.formatted(date: .abbreviated, time: .shortened)) ~ \(end.formatted(date: .abbreviated, time: .shortened))"
        }
    }
}
