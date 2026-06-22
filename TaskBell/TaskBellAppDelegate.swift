import UIKit
import UserNotifications

final class TaskBellAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AdMobConfiguration.prepare()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let todoID = TodoNotificationPayload.todoID(from: response.notification.request) {
            NotificationCenter.default.post(
                name: TodoNotificationPayload.openTodoDetailNotification,
                object: nil,
                userInfo: [TodoNotificationPayload.todoIDKey: todoID]
            )
        }
        completionHandler()
    }
}
