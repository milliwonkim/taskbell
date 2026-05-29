//
//  MonthCalendarView.swift
//  TaskBell
//

import SwiftUI

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    let todos: [TodoItem]
    let onSelectDate: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.year().month(.wide))
    }

    private var monthSummary: String {
        let monthTodoCount = monthDays.reduce(0) { total, day in
            guard day.isCurrentMonth else {
                return total
            }

            return total + todosForDay(day.date).count
        }

        return monthTodoCount == 0 ? "이번 달 할 일 없음" : "이번 달 할 일 \(monthTodoCount)개"
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
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
            let dayHeight = max(76, (proxy.size.height - 96) / rowCount)

            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(monthTitle)
                            .font(.largeTitle.bold())
                            .minimumScaleFactor(0.8)

                        Text(monthSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("오늘") {
                        withAnimation(.snappy) {
                            selectedDate = .now
                            displayedMonth = .now
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(calendar.isDateInToday(selectedDate))

                    HStack(spacing: 8) {
                        Button {
                            moveMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                        }
                        .accessibilityLabel("이전 달")

                        Button {
                            moveMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.headline)
                        }
                        .accessibilityLabel("다음 달")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 2)

                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { weekday in
                        Text(weekday)
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
                            todos: dayTodos,
                            minHeight: dayHeight
                        ) {
                            onSelectDate(day.date)
                        }
                    }
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                        .padding(.top, 24)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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
}

private struct CalendarDay: Identifiable {
    let date: Date
    let isCurrentMonth: Bool

    var id: Date { date }
}

private struct CalendarDayButton: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let todos: [TodoItem]
    let minHeight: CGFloat
    let action: () -> Void

    private var dayNumber: String {
        day.date.formatted(.dateTime.day())
    }

    private var completedCount: Int {
        todos.filter(\.isCompleted).count
    }

    var body: some View {
        Button(action: action) {
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
            .background(dayCellBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(.separator).opacity(0.55))
                    .frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            Color.accentColor
        } else if isToday {
            Color.accentColor.opacity(0.16)
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

    private var dayCellBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.08)
        }

        return Color.clear
    }

    @ViewBuilder
    private var todayBorder: some View {
        if isToday, !isSelected {
            Circle()
                .stroke(Color.accentColor, lineWidth: 1.2)
        }
    }

    private var accessibilityLabel: String {
        let dateText = day.date.formatted(date: .long, time: .omitted)
        return todos.isEmpty ? dateText : "\(dateText), 할 일 \(todos.count)개"
    }
}

private struct CalendarDayActivityView: View {
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
                    .accessibilityLabel("추가 할 일 \(totalCount - 5)개")
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
