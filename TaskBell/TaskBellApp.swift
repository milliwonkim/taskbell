//
//  TaskBellApp.swift
//  TaskBell
//
//  Created by 김기원 on 5/29/26.
//

import SwiftUI
import SwiftData

@main
struct TaskBellApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TodoItem.self,
            Reminder.self,
        ])
        let cloudConfiguration = ModelConfiguration(
            "TaskBellCloud",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.kiwonkim.TaskBell")
        )
        let localConfiguration = ModelConfiguration(
            "TaskBellLocal",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        let emergencyConfiguration = ModelConfiguration(
            "TaskBellTemporary",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                do {
                    return try ModelContainer(for: schema, configurations: [emergencyConfiguration])
                } catch {
                    fatalError("Could not create ModelContainer: \(error)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
