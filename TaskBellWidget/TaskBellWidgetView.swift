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
    private var language: WidgetLanguage {
        WidgetLanguage(rawValue: entry.snapshot.languageRawValue) ?? .korean
    }

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

            Text(language.text(korean: "이번 주 남은 할 일", english: "Todos left this week"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if let anniversary = nextAnniversary {
                VStack(alignment: .leading, spacing: 2) {
                    Text(daysText(for: anniversary))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.pink)
                    Text(anniversary.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            compactWeekStrip
        }
        .padding(14)
    }

    private var weeklyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            weekStrip

            if !entry.snapshot.anniversaries.isEmpty {
                anniversarySection
            }

            if entry.snapshot.todos.isEmpty {
                Spacer(minLength: 0)
                Text(language.text(korean: "이번 주 할 일이 없습니다", english: "No todos this week"))
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
            Text(nextAnniversary == nil ? language.text(korean: "이번 주", english: "This Week") : language.text(korean: "다음 기념일", english: "Next Anniversary"))
                .font(.caption2.weight(.semibold))
            Text(accessoryPrimaryText)
                .font(.headline.weight(.bold))
            Text(accessorySecondaryText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text(korean: "이번 주", english: "This Week"))
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
                Text(language.text(korean: "남음", english: "Left"))
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

    private var anniversarySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(language.text(korean: "기념일", english: "Anniversary"), systemImage: "gift")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.pink)
                Spacer()
            }

            ForEach(visibleAnniversaries) { anniversary in
                HStack(spacing: 6) {
                    Text(daysText(for: anniversary))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.pink)
                        .frame(width: 46, alignment: .leading)
                    Text(anniversary.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(nextDateText(for: anniversary))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var remainingCount: Int {
        entry.snapshot.todos.filter { !$0.isCompleted }.count
    }

    private var visibleTodos: [TaskBellWidgetTodoSnapshot] {
        let limit: Int

        if entry.snapshot.anniversaries.isEmpty {
            limit = family == .systemLarge ? 8 : 4
        } else {
            limit = family == .systemLarge ? 5 : 3
        }

        return Array(entry.snapshot.todos.prefix(limit))
    }

    private var visibleAnniversaries: [TaskBellWidgetAnniversarySnapshot] {
        Array(sortedAnniversaries.prefix(family == .systemLarge ? 3 : 2))
    }

    private var sortedAnniversaries: [TaskBellWidgetAnniversarySnapshot] {
        entry.snapshot.anniversaries.sorted {
            nextOccurrence(for: $0) < nextOccurrence(for: $1)
        }
    }

    private var nextAnniversary: TaskBellWidgetAnniversarySnapshot? {
        sortedAnniversaries.first
    }

    private var accessoryPrimaryText: String {
        guard let nextAnniversary else {
            return language.text(korean: "\(remainingCount)개 남음", english: "\(remainingCount) left")
        }

        return daysText(for: nextAnniversary)
    }

    private var accessorySecondaryText: String {
        guard let nextAnniversary else {
            return language.text(korean: "\(entry.snapshot.todos.count)개 할 일", english: "\(entry.snapshot.todos.count) todos")
        }

        return nextAnniversary.title
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

    private func nextOccurrence(for anniversary: TaskBellWidgetAnniversarySnapshot) -> Date {
        let startOfToday = calendar.startOfDay(for: entry.date)

        guard anniversary.repeatsYearly else {
            return calendar.startOfDay(for: anniversary.targetDate)
        }

        let targetComponents = calendar.dateComponents([.month, .day], from: anniversary.targetDate)
        let currentYear = calendar.component(.year, from: entry.date)
        var nextComponents = DateComponents()
        nextComponents.year = currentYear
        nextComponents.month = targetComponents.month
        nextComponents.day = targetComponents.day

        let occurrenceThisYear = calendar.date(from: nextComponents) ?? anniversary.targetDate
        if occurrenceThisYear >= startOfToday {
            return occurrenceThisYear
        }

        nextComponents.year = currentYear + 1
        return calendar.date(from: nextComponents) ?? occurrenceThisYear
    }

    private func daysText(for anniversary: TaskBellWidgetAnniversarySnapshot) -> String {
        let startOfToday = calendar.startOfDay(for: entry.date)
        let target = nextOccurrence(for: anniversary)
        let days = calendar.dateComponents([.day], from: startOfToday, to: target).day ?? 0

        if days == 0 {
            return "D-Day"
        }

        if days > 0 {
            return "D-\(days)"
        }

        return "D+\(abs(days))"
    }

    private func nextDateText(for anniversary: TaskBellWidgetAnniversarySnapshot) -> String {
        nextOccurrence(for: anniversary).formatted(.dateTime.month(.abbreviated).day())
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
        return language.text(korean: "\(date), \(day.completedCount)/\(day.totalCount) 완료", english: "\(date), \(day.completedCount)/\(day.totalCount) completed")
    }
}

private enum WidgetLanguage: String {
    case korean = "ko"
    case english = "en"

    func text(korean: String, english: String) -> String {
        switch self {
        case .korean:
            korean
        case .english:
            english
        }
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
