//
//  TodoRoutineSeriesUpdate.swift
//  TaskBell
//

import Foundation

struct RoutineReminderTemplate: Equatable {
    let offset: TimeInterval
    let repeatRule: ReminderRepeatRule
    let deliveryStyle: ReminderDeliveryStyle
    let isEnabled: Bool
}

enum TodoRoutineSeriesUpdate {
    static func hasScheduleOrReminderChanges(
        draft: TodoDraft,
        comparedTo original: TodoDraft
    ) -> Bool {
        if draft.scheduleMode != original.scheduleMode {
            return true
        }

        if draft.scheduledStartAt != original.scheduledStartAt {
            return true
        }

        if draft.scheduledEndAt != original.scheduledEndAt {
            return true
        }

        return reminderTemplates(from: draft, anchorStart: draft.scheduledStartAt)
            != reminderTemplates(from: original, anchorStart: original.scheduledStartAt)
    }

    static func reminderTemplates(from draft: TodoDraft) -> [RoutineReminderTemplate] {
        reminderTemplates(from: draft, anchorStart: draft.scheduledStartAt)
    }

    static func reminderTemplates(
        from draft: TodoDraft,
        anchorStart: Date?
    ) -> [RoutineReminderTemplate] {
        let anchor = anchorStart ?? .distantPast

        return draft.reminders
            .sorted { $0.fireDate < $1.fireDate }
            .map { reminder in
                RoutineReminderTemplate(
                    offset: reminder.fireDate.timeIntervalSince(anchor),
                    repeatRule: reminder.repeatRule,
                    deliveryStyle: reminder.deliveryStyle,
                    isEnabled: reminder.isEnabled
                )
            }
    }

    static func reminderDrafts(
        from draft: TodoDraft,
        targetStart: Date,
        anchorStart: Date? = nil
    ) -> [ReminderDraft] {
        let anchor = anchorStart ?? draft.scheduledStartAt ?? targetStart

        return reminderTemplates(from: draft, anchorStart: anchor).map { template in
            ReminderDraft(
                fireDate: targetStart.addingTimeInterval(template.offset),
                repeatRule: template.repeatRule,
                deliveryStyle: template.deliveryStyle,
                isEnabled: template.isEnabled
            )
        }
    }

    static func mergedStartDate(
        for target: TodoItem,
        seedNewStart: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        guard let seedNewStart else {
            return nil
        }

        guard let targetStart = target.scheduledStartAt else {
            return seedNewStart
        }

        let newTime = calendar.dateComponents([.hour, .minute, .second], from: seedNewStart)
        var targetDate = calendar.dateComponents([.year, .month, .day], from: targetStart)
        targetDate.hour = newTime.hour
        targetDate.minute = newTime.minute
        targetDate.second = newTime.second ?? 0
        return calendar.date(from: targetDate)
    }

    static func mergedEndDate(
        for target: TodoItem,
        scheduleMode: TodoScheduleMode,
        seedNewStart: Date?,
        seedNewEnd: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        guard scheduleMode == .dateRange,
              let seedNewStart,
              let seedNewEnd,
              let targetStart = mergedStartDate(for: target, seedNewStart: seedNewStart, calendar: calendar)
        else {
            return nil
        }

        let duration = seedNewEnd.timeIntervalSince(seedNewStart)
        return targetStart.addingTimeInterval(max(duration, 0))
    }
}
