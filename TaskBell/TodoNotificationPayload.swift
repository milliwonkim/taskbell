//
//  TodoNotificationPayload.swift
//  TaskBell
//

import Foundation
import SwiftData
import UserNotifications

enum TodoNotificationPayload {
    static let todoIDKey = "todoID"

    static let openTodoDetailNotification = Notification.Name("openTodoDetailFromNotification")

    static func userInfo(for todo: TodoItem) -> [AnyHashable: Any] {
        [todoIDKey: String(describing: todo.persistentModelID)]
    }

    static func todoID(from request: UNNotificationRequest) -> String? {
        if let todoID = request.content.userInfo[todoIDKey] as? String {
            return todoID
        }

        let mainDatePrefix = "todo-main-"
        if request.identifier.hasPrefix(mainDatePrefix) {
            return String(request.identifier.dropFirst(mainDatePrefix.count))
        }

        return nil
    }
}
