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
    var sharedModelContainer: ModelContainer =
        TaskBellModelContainer.makeCloudContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

enum TaskBellModelContainer {
    private static let cloudKitContainerIdentifier = "iCloud.kiwonkim.TaskBell"

    private static let schema = Schema([
        TodoItem.self,
        TodoAttachment.self,
        Reminder.self,
    ])

    static func makeCloudContainer() -> ModelContainer {
        let cloudContainer: ModelContainer

        do {
            cloudContainer = try ModelContainer(
                for: schema,
                configurations: [cloudConfiguration]
            )
        } catch {
            fatalError("Could not create iCloud-backed ModelContainer: \(error)")
        }

        importLegacyLocalStoreIfNeeded(into: cloudContainer)
        return cloudContainer
    }

    private static var cloudConfiguration: ModelConfiguration {
        ModelConfiguration(
            "TaskBellCloud",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )
    }

    private static var legacyLocalConfiguration: ModelConfiguration {
        ModelConfiguration(
            "TaskBellLocal",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
    }

    private static func importLegacyLocalStoreIfNeeded(into cloudContainer: ModelContainer) {
        do {
            let cloudContext = ModelContext(cloudContainer)
            let cloudTodoCount = try cloudContext.fetchCount(FetchDescriptor<TodoItem>())
            guard cloudTodoCount == 0 else { return }

            let legacyLocalContainer = try ModelContainer(
                for: schema,
                configurations: [legacyLocalConfiguration]
            )
            let legacyContext = ModelContext(legacyLocalContainer)
            let legacyTodos = try legacyContext.fetch(
                FetchDescriptor<TodoItem>(sortBy: [SortDescriptor(\.createdAt)])
            )
            guard !legacyTodos.isEmpty else { return }

            for legacyTodo in legacyTodos {
                let cloudTodo = TodoItem(cloudImporting: legacyTodo)
                cloudContext.insert(cloudTodo)

                for attachment in cloudTodo.attachments ?? [] {
                    cloudContext.insert(attachment)
                }

                for reminder in cloudTodo.reminders ?? [] {
                    cloudContext.insert(reminder)
                }
            }

            try cloudContext.save()
        } catch {
            assertionFailure(
                "Could not import legacy local TaskBell data into iCloud store: \(error)"
            )
        }
    }
}
