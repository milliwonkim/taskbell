//
//  TaskBellWidgetView.swift
//  TaskBellWidget
//

import SwiftUI
import WidgetKit

struct TaskBellWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TaskBellWidgetEntry

    private var calendar: Calendar { .current }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .accessoryRectangular:
            accessoryView
        default:
            weeklyView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Spacer(minLength: 0)

            Text("\(remainingCount)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())

            Text("이번 주 남은 할 일")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            compactWeekStrip
        }
        .padding(14)
    }

    private var weeklyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            weekStrip

            if entry.snapshot.todos.isEmpty {
                Spacer(minLength: 0)
                Text("이번 주 할 일이 없습니다")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else {
                todoList
            }
        }
        .padding(14)
    }

    private var accessoryView: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("이번 주")
                .font(.caption2.weight(.semibold))
            Text("\(remainingCount)개 남음")
                .font(.headline.weight(.bold))
            Text("\(entry.snapshot.todos.count)개 할 일")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("이번 주")
                    .font(.headline.weight(.bold))
                Text(weekRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(remainingCount)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.orange)
                Text("남음")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 4) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 4) {
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(day.date.formatted(.dateTime.day()))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(calendar.isDateInToday(day.date) ? .white : .primary)
                        .frame(width: 24, height: 24)
                        .background(calendar.isDateInToday(day.date) ? Color.accentColor : Color.clear, in: Circle())
                    Text("\(day.completedCount)/\(day.totalCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(day.totalCount == 0 ? Color.secondary : Color.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var compactWeekStrip: some View {
        HStack(spacing: 3) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                Capsule()
                    .fill(compactDayColor(for: day))
                    .frame(maxWidth: .infinity, minHeight: 7, maxHeight: 7)
                    .accessibilityLabel(compactDayAccessibilityLabel(for: day))
            }
        }
    }

    private var todoList: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 6 : 4) {
            ForEach(visibleTodos) { todo in
                HStack(spacing: 6) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    Text(todo.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .strikethrough(todo.isCompleted)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let dateText = scheduledDateText(for: todo) {
                        Text(dateText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var remainingCount: Int {
        entry.snapshot.todos.filter { !$0.isCompleted }.count
    }

    private var visibleTodos: [TaskBellWidgetTodoSnapshot] {
        Array(entry.snapshot.todos.prefix(family == .systemLarge ? 8 : 4))
    }

    private var weekDays: [TaskBellWidgetDaySnapshot] {
        entry.snapshot.days
    }

    private var weekRangeText: String {
        let start = entry.snapshot.weekStart.formatted(
            .dateTime.month(.abbreviated).day()
        )
        let end = entry.snapshot.weekEnd.formatted(
            .dateTime.month(.abbreviated).day()
        )

        return "\(start) - \(end)"
    }

    private func scheduledDateText(for todo: TaskBellWidgetTodoSnapshot) -> String? {
        guard let start = todo.scheduledStartAt else {
            return nil
        }

        if todo.scheduleModeRawValue == "dateRange", let end = todo.scheduledEndAt {
            return "\(start.formatted(.dateTime.day()))-\(end.formatted(.dateTime.day()))"
        }

        return start.formatted(.dateTime.weekday(.narrow).hour().minute())
    }

    private func compactDayColor(for day: TaskBellWidgetDaySnapshot) -> Color {
        if day.totalCount == 0 {
            return .secondary.opacity(0.25)
        }

        if day.completedCount == day.totalCount {
            return .green
        }

        return .orange
    }

    private func compactDayAccessibilityLabel(
        for day: TaskBellWidgetDaySnapshot
    ) -> String {
        let date = day.date.formatted(date: .abbreviated, time: .omitted)
        return "\(date), \(day.completedCount)/\(day.totalCount) 완료"
    }
}

#Preview(as: .systemSmall) {
    TaskBellWidget()
} timeline: {
    TaskBellWidgetEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .systemLarge) {
    TaskBellWidget()
} timeline: {
    TaskBellWidgetEntry(date: .now, snapshot: .placeholder)
}
