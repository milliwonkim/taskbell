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

    static func scheduleMainDate(for todo: TodoItem) async {
        guard todo.scheduleMode != .none, let scheduledStartAt = todo.scheduledStartAt else {
            await cancelMainDate(for: todo)
            return
        }

        guard scheduledStartAt > .now else {
            await cancelMainDate(for: todo)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(from: todo.title)
        content.body = mainDateNotificationBody(from: todo.content)
        content.categoryIdentifier = "todo-reminder"
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
            await cancelMainDate(for: todo)
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            assertionFailure("Failed to schedule main date notification: \(error)")
        }
    }

    static func schedule(_ reminder: Reminder, todoTitle: String, todoContent: String) async {
        guard reminder.isEnabled else {
            await cancel(reminder)
            return
        }

        if reminder.repeatRule == .once, reminder.fireDate <= .now {
            await cancel(reminder)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(from: todoTitle)
        content.body = notificationBody(from: todoContent, repeatRule: reminder.repeatRule)
        content.categoryIdentifier = "todo-reminder"
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
            await cancel(reminder)
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            assertionFailure("Failed to schedule notification: \(error)")
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

    static func rescheduleAll(todos: [TodoItem]) async {
        for todo in todos {
            await scheduleMainDate(for: todo)

            for reminder in todo.reminders {
                await schedule(reminder, todoTitle: todo.title, todoContent: todo.content)
            }
        }
    }

    private static func notificationTitle(from todoTitle: String) -> String {
        let trimmedTitle = todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "할 일이 있어요" : trimmedTitle
    }

    private static func notificationBody(from todoContent: String, repeatRule: ReminderRepeatRule) -> String {
        let trimmedContent = todoContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedContent.isEmpty {
            return trimmedContent
        }

        return repeatRule == .once ? "미리알림 시간입니다." : "\(repeatRule.title) 반복 미리알림입니다."
    }

    private static func mainDateNotificationBody(from todoContent: String) -> String {
        let trimmedContent = todoContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedContent.isEmpty ? "할 일 시간입니다." : trimmedContent
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
