//
//  TaskBellWidget.swift
//  TaskBellWidget
//

import SwiftUI
import WidgetKit

struct TaskBellWidget: Widget {
    let kind = "TaskBellWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskBellWidgetProvider()) {
            entry in
            TaskBellWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("TaskBell")
        .description("View this week's dates and todos at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular
        ])
    }
}

struct TaskBellWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TaskBellWidgetSnapshot
}

struct TaskBellWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskBellWidgetEntry {
        TaskBellWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (TaskBellWidgetEntry) -> Void
    ) {
        completion(
            TaskBellWidgetEntry(
                date: .now,
                snapshot: TaskBellWidgetSnapshotStore.load()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<TaskBellWidgetEntry>) -> Void
    ) {
        let entry = TaskBellWidgetEntry(
            date: .now,
            snapshot: TaskBellWidgetSnapshotStore.load()
        )
        let nextRefresh =
            Calendar.current.date(byAdding: .minute, value: 30, to: .now)
            ?? .now.addingTimeInterval(1800)

        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
