//
//  NotificationScheduler.swift
//  TaskBell
//

import Foundation
import SwiftData
import UserNotifications

enum NotificationScheduler {
    private static let notificationIconName = "NotificationIcon"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func scheduleAll(for todo: TodoItem, language: AppLanguage) async {
        await cancelAll(for: todo)

        var candidates: [ScheduleCandidate] = []
        var seenReminderIDs = Set<UUID>()

        for reminder in todo.reminders ?? [] {
            guard seenReminderIDs.insert(reminder.id).inserted else {
                continue
            }

            if let candidate = ScheduleCandidate.reminder(reminder) {
                candidates.append(candidate)
            }
        }

        if todo.scheduleMode != .none, let scheduledStartAt = todo.scheduledStartAt {
            if let candidate = ScheduleCandidate.mainDate(at: scheduledStartAt) {
                candidates.append(candidate)
            }
        }

        for candidate in deduplicatedCandidates(candidates) {
            switch candidate.kind {
            case .mainDate:
                await addMainDate(for: todo, language: language)
            case let .reminder(reminder):
                await addReminder(
                    reminder,
                    todo: todo,
                    language: language
                )
            }
        }
    }

    static func cancel(_ reminder: Reminder) async {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminder.notificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [reminder.notificationIdentifier])
    }

    static func cancelMainDate(for todo: TodoItem) async {
        let notificationCenter = UNUserNotificationCenter.current()
        let identifier = mainDateNotificationIdentifier(for: todo)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    static func cancelAll(for todo: TodoItem) async {
        await cancelMainDate(for: todo)

        var seenReminderIDs = Set<UUID>()
        for reminder in todo.reminders ?? [] {
            guard seenReminderIDs.insert(reminder.id).inserted else {
                continue
            }
            await cancel(reminder)
        }
    }

    static func rescheduleAll(todos: [TodoItem], language: AppLanguage) async {
        for todo in todos {
            await scheduleAll(for: todo, language: language)
        }
    }

    private struct ScheduleCandidate {
        enum Kind {
            case mainDate
            case reminder(Reminder)
        }

        let kind: Kind
        let slotKey: String
        let priority: Int
        let tieBreaker: Date

        static func mainDate(at date: Date) -> ScheduleCandidate? {
            guard date > .now else {
                return nil
            }

            return ScheduleCandidate(
                kind: .mainDate,
                slotKey: notificationSlotKey(for: date, repeatRule: .once),
                priority: 1,
                tieBreaker: date
            )
        }

        static func reminder(_ reminder: Reminder) -> ScheduleCandidate? {
            guard reminder.isEnabled else {
                return nil
            }

            if reminder.repeatRule == .once, reminder.fireDate <= .now {
                return nil
            }

            return ScheduleCandidate(
                kind: .reminder(reminder),
                slotKey: notificationSlotKey(for: reminder.fireDate, repeatRule: reminder.repeatRule),
                priority: 0,
                tieBreaker: reminder.createdAt
            )
        }
    }

    private static func deduplicatedCandidates(_ candidates: [ScheduleCandidate]) -> [ScheduleCandidate] {
        var winners: [String: ScheduleCandidate] = [:]

        for candidate in candidates {
            guard let existing = winners[candidate.slotKey] else {
                winners[candidate.slotKey] = candidate
                continue
            }

            if candidate.priority < existing.priority {
                winners[candidate.slotKey] = candidate
            } else if candidate.priority == existing.priority,
                      candidate.tieBreaker < existing.tieBreaker {
                winners[candidate.slotKey] = candidate
            }
        }

        return winners.values.sorted { $0.tieBreaker < $1.tieBreaker }
    }

    private static func notificationSlotKey(for date: Date, repeatRule: ReminderRepeatRule) -> String {
        let calendar = Calendar.current

        switch repeatRule {
        case .once:
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return [
                "once",
                String(components.year ?? 0),
                String(components.month ?? 0),
                String(components.day ?? 0),
                String(components.hour ?? 0),
                String(components.minute ?? 0),
            ].joined(separator: "-")
        case .daily:
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return ["daily", String(components.hour ?? 0), String(components.minute ?? 0)].joined(separator: "-")
        case .weekly:
            let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
            return [
                "weekly",
                String(components.weekday ?? 0),
                String(components.hour ?? 0),
                String(components.minute ?? 0),
            ].joined(separator: "-")
        case .monthly:
            let components = calendar.dateComponents([.day, .hour, .minute], from: date)
            return [
                "monthly",
                String(components.day ?? 0),
                String(components.hour ?? 0),
                String(components.minute ?? 0),
            ].joined(separator: "-")
        case .yearly:
            let components = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
            return [
                "yearly",
                String(components.month ?? 0),
                String(components.day ?? 0),
                String(components.hour ?? 0),
                String(components.minute ?? 0),
            ].joined(separator: "-")
        }
    }

    private static func addMainDate(for todo: TodoItem, language: AppLanguage) async {
        guard todo.scheduleMode != .none, let scheduledStartAt = todo.scheduledStartAt else {
            return
        }

        guard scheduledStartAt > .now else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(from: todo.title, language: language)
        content.body = mainDateNotificationBody(from: todo.content, language: language)
        content.categoryIdentifier = "todo-reminder"
        content.userInfo = TodoNotificationPayload.userInfo(for: todo)
        content.attachments = notificationIconAttachments()
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledStartAt),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: mainDateNotificationIdentifier(for: todo),
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            assertionFailure("Failed to schedule main date notification: \(error)")
        }
    }

    private static func addReminder(
        _ reminder: Reminder,
        todo: TodoItem,
        language: AppLanguage
    ) async {
        let content = UNMutableNotificationContent()
        content.title = notificationTitle(from: todo.title, language: language)
        content.body = notificationBody(from: todo.content, repeatRule: reminder.repeatRule, language: language)
        content.categoryIdentifier = "todo-reminder"
        content.userInfo = TodoNotificationPayload.userInfo(for: todo)
        content.attachments = notificationIconAttachments()

        if reminder.deliveryStyle == .notificationAndVibration {
            content.sound = .default
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents(for: reminder.fireDate, repeatRule: reminder.repeatRule),
            repeats: reminder.repeatRule != .once
        )

        let request = UNNotificationRequest(
            identifier: reminder.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            assertionFailure("Failed to schedule notification: \(error)")
        }
    }

    private static func notificationTitle(from todoTitle: String, language: AppLanguage) -> String {
        let trimmedTitle = todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? language.text(korean: "할 일이 있어요", english: "You have a todo") : trimmedTitle
    }

    private static func notificationBody(from todoContent: String, repeatRule: ReminderRepeatRule, language: AppLanguage) -> String {
        let trimmedContent = todoContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedContent.isEmpty {
            return trimmedContent
        }

        return repeatRule == .once
            ? language.text(korean: "미리알림 시간입니다.", english: "It's reminder time.")
            : language.text(korean: "\(repeatRule.title(in: language)) 반복 미리알림입니다.", english: "This is a repeating \(repeatRule.title(in: language).lowercased()) reminder.")
    }

    private static func mainDateNotificationBody(from todoContent: String, language: AppLanguage) -> String {
        let trimmedContent = todoContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedContent.isEmpty ? language.text(korean: "할 일 시간입니다.", english: "It's time for your todo.") : trimmedContent
    }

    private static func mainDateNotificationIdentifier(for todo: TodoItem) -> String {
        "todo-main-\(String(describing: todo.persistentModelID))"
    }

    private static func notificationIconAttachments() -> [UNNotificationAttachment] {
        guard let iconURL = Bundle.main.url(forResource: notificationIconName, withExtension: "png") else {
            return []
        }

        do {
            return [try UNNotificationAttachment(identifier: notificationIconName, url: iconURL)]
        } catch {
            assertionFailure("Failed to attach notification icon: \(error)")
            return []
        }
    }

    private static func dateComponents(for date: Date, repeatRule: ReminderRepeatRule) -> DateComponents {
        let calendar = Calendar.current

        switch repeatRule {
        case .once:
            return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        case .daily:
            return calendar.dateComponents([.hour, .minute], from: date)
        case .weekly:
            return calendar.dateComponents([.weekday, .hour, .minute], from: date)
        case .monthly:
            return calendar.dateComponents([.day, .hour, .minute], from: date)
        case .yearly:
            return calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        }
    }
}
