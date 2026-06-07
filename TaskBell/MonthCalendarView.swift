//
//  MonthCalendarView.swift
//  TaskBell
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MonthCalendarView: View {
    @Environment(\.appLanguage) private var appLanguage
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    @Binding var dropTargetDate: Date?
    let todos: [TodoItem]
    let onMoveTodoToDate: (TodoItem, Date) -> Void
    let onSelectDate: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let swipeThreshold: CGFloat = 60

    private var monthTodoCount: Int {
        monthDays.reduce(0) { total, day in
            guard day.isCurrentMonth else {
                return total
            }

            return total + todosForDay(day.date).count
        }
    }

    private var monthSummary: String {
        return monthTodoCount == 0 ? appLanguage.text(korean: "이번 달 할 일 없음", english: "No todos this month") : appLanguage.text(korean: "이번 달 할 일 \(monthTodoCount)개", english: "\(monthTodoCount) todos this month")
    }

    private var weekdaySymbols: [String] {
        appLanguage.veryShortWeekdaySymbols(calendar: calendar)
    }

    private var monthDays: [CalendarDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else {
            return []
        }

        var days: [CalendarDay] = []
        var day = firstWeekInterval.start

        while day < lastWeekInterval.end {
            days.append(
                CalendarDay(
                    date: day,
                    isCurrentMonth: calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }

            day = nextDay
        }

        return days
    }

    var body: some View {
        GeometryReader { proxy in
            let rowCount = CGFloat(max(monthDays.count / 7, 1))
            let dayHeight = max(76, (proxy.size.height - 54) / rowCount)

            VStack(spacing: 10) {
                calendarHeader

                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(weekdaySymbols.indices, id: \.self) { index in
                        Text(weekdaySymbols[index])
                            .font(.caption2.bold())
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }

                    ForEach(monthDays) { day in
                        let dayTodos = todosForDay(day.date)

                        CalendarDayButton(
                            day: day,
                            isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(day.date),
                            isDropTarget: dropTargetBinding(for: day.date),
                            todos: dayTodos,
                            minHeight: dayHeight,
                            onDrop: { providers in
                                handleDrop(from: providers, on: day.date)
                            }
                        ) {
                            onSelectDate(day.date)
                        }
                    }
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.45))
                        .frame(height: 0.5)
                        .padding(.top, 24)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipeGesture)
        }
    }

    private var calendarHeader: some View {
        HStack(spacing: 12) {
            Text(monthSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button(appLanguage.text(korean: "오늘", english: "Today")) {
                withAnimation(.snappy) {
                    selectedDate = .now
                    displayedMonth = .now
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(calendar.isDateInToday(selectedDate))

            HStack(spacing: 6) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel(appLanguage.text(korean: "이전 달", english: "Previous Month"))

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel(appLanguage.text(korean: "다음 달", english: "Next Month"))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 2)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                guard abs(horizontalDistance) > swipeThreshold,
                      abs(horizontalDistance) > abs(verticalDistance) * 1.5
                else {
                    return
                }

                moveMonth(by: horizontalDistance > 0 ? -1 : 1)
            }
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }

        withAnimation(.snappy) {
            displayedMonth = nextMonth
        }
    }

    private func todosForDay(_ date: Date) -> [TodoItem] {
        todos.filter { $0.isScheduled(on: date, calendar: calendar) }
    }

    private func isDropTarget(_ date: Date) -> Bool {
        guard let dropTargetDate else {
            return false
        }

        return calendar.isDate(dropTargetDate, inSameDayAs: date)
    }

    private func dropTargetBinding(for date: Date) -> Binding<Bool> {
        Binding(
            get: { isDropTarget(date) },
            set: { isTargeted in
                dropTargetDate = isTargeted ? calendar.startOfDay(for: date) : nil
            }
        )
    }

    private func handleDrop(from providers: [NSItemProvider], on date: Date) -> Bool {
        guard
            let provider = providers.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            })
        else {
            return false
        }

        provider.loadItem(
            forTypeIdentifier: UTType.plainText.identifier,
            options: nil
        ) { item, _ in
            let draggedID: String?
            if let data = item as? Data {
                draggedID = String(data: data, encoding: .utf8)
            } else {
                draggedID = item as? String
            }

            guard
                let draggedID,
                let draggedTodo = todos.first(where: {
                    String(describing: $0.persistentModelID) == draggedID
                })
            else {
                return
            }

            Task { @MainActor in
                onMoveTodoToDate(draggedTodo, calendar.startOfDay(for: date))
                dropTargetDate = nil
            }
        }

        return true
    }
}

private struct CalendarDay: Identifiable {
    let date: Date
    let isCurrentMonth: Bool

    var id: Date { date }
}

private struct CalendarDayButton: View {
    @Environment(\.appLanguage) private var appLanguage
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let isDropTarget: Binding<Bool>
    let todos: [TodoItem]
    let minHeight: CGFloat
    let onDrop: ([NSItemProvider]) -> Bool
    let action: () -> Void

    private var dayNumber: String {
        day.date.formatted(.dateTime.day())
    }

    private var completedCount: Int {
        todos.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(spacing: 7) {
            Text(dayNumber)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .frame(width: 32, height: 32)
                .background(selectionBackground)
                .foregroundStyle(dayNumberColor)
                .clipShape(Circle())
                .overlay(todayBorder)

            if !todos.isEmpty {
                CalendarDayActivityView(totalCount: todos.count, completedCount: completedCount, isSelected: isSelected)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .background(isDropTarget.wrappedValue ? Color.accentColor.opacity(0.14) : Color.clear)
        .opacity(day.isCurrentMonth ? 1 : 0.48)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator).opacity(0.35))
                .frame(height: 0.5)
        }
        .overlay {
            if isDropTarget.wrappedValue {
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onDrop(of: [.plainText], isTargeted: isDropTarget) { providers in
            onDrop(providers)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            action()
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            Color.accentColor
        } else if isToday {
            Color.accentColor.opacity(0.14)
        } else {
            Color.clear
        }
    }

    private var dayNumberColor: Color {
        if isSelected {
            return .white
        }

        if isToday {
            return .accentColor
        }

        return day.isCurrentMonth ? .primary : .secondary.opacity(0.65)
    }

    @ViewBuilder
    private var todayBorder: some View {
        if isToday, !isSelected {
            Circle()
                .stroke(Color.accentColor, lineWidth: 1.2)
        }
    }

    private var accessibilityLabel: String {
        let dateText = appLanguage.formattedLongDate(day.date)
        return todos.isEmpty ? dateText : appLanguage.text(korean: "\(dateText), 할 일 \(todos.count)개, 완료 \(completedCount)개", english: "\(dateText), \(todos.count) todos, \(completedCount) completed")
    }
}

private struct CalendarDayActivityView: View {
    @Environment(\.appLanguage) private var appLanguage
    let totalCount: Int
    let completedCount: Int
    let isSelected: Bool

    private var remainingCount: Int {
        totalCount - completedCount
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(0..<min(totalCount, 5), id: \.self) { index in
                    Circle()
                        .fill(indicatorColor(for: index))
                        .frame(width: 5, height: 5)
                }
            }

            if totalCount > 5 {
                Text("+\(totalCount - 5)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(appLanguage.text(korean: "추가 할 일 \(totalCount - 5)개", english: "\(totalCount - 5) more todos"))
            }
        }
    }

    private func indicatorColor(for index: Int) -> Color {
        if index < remainingCount {
            return isSelected ? .accentColor : .orange
        }

        return .secondary.opacity(0.45)
    }
}
