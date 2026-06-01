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
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let swipeThreshold: CGFloat = 60

    private var monthTodoCount: Int {
        monthDays.reduce(0) { total, day in
            guard day.isCurrentMonth else {
                return total
            }

            return total + todosForDay(day.date).count
        }
    }

    private var completedMonthTodoCount: Int {
        monthDays.reduce(0) { total, day in
            guard day.isCurrentMonth else {
                return total
            }

            return total + todosForDay(day.date).filter(\.isCompleted).count
        }
    }

    private var monthSummary: String {
        return monthTodoCount == 0 ? "이번 달 할 일 없음" : "이번 달 할 일 \(monthTodoCount)개"
    }

    private var monthCompletionSummary: String {
        guard monthTodoCount > 0 else {
            return "가볍게 시작해볼까요?"
        }

        return "\(completedMonthTodoCount)개 완료"
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
            let dayHeight = max(74, (proxy.size.height - 122) / rowCount)

            VStack(spacing: 14) {
                calendarHeader

                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption2.bold())
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary.opacity(0.82))
                            .frame(maxWidth: .infinity, minHeight: 28)
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
                .padding(8)
                .background(calendarGridBackground)
            }
            .padding(10)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipeGesture)
        }
    }

    private var calendarHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))

                Image(systemName: "calendar")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(monthSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(monthCompletionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer()

            Button("오늘") {
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
                .accessibilityLabel("이전 달")

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("다음 달")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color(.secondarySystemBackground).opacity(0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.26), lineWidth: 1)
        }
        .shadow(color: Color.accentColor.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    private var calendarGridBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color(.secondarySystemBackground).opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.16), lineWidth: 1)
            }
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
        VStack(spacing: 7) {
            Text(dayNumber)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .frame(width: 34, height: 34)
                .background(selectionBackground)
                .foregroundStyle(dayNumberColor)
                .clipShape(Circle())
                .overlay(todayBorder)

            if !todos.isEmpty {
                CalendarDayActivityView(totalCount: todos.count, completedCount: completedCount, isSelected: isSelected)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 7)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .background(dayCellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(day.isCurrentMonth ? 1 : 0.48)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            action()
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
    private var dayCellBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
                }
        } else if isToday {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentColor.opacity(0.05))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground).opacity(day.isCurrentMonth ? 0.54 : 0.28))
        }
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
        return todos.isEmpty ? dateText : "\(dateText), 할 일 \(todos.count)개, 완료 \(completedCount)개"
    }
}

private struct CalendarDayActivityView: View {
    let totalCount: Int
    let completedCount: Int
    let isSelected: Bool

    private var remainingCount: Int {
        totalCount - completedCount
    }

    private var completionRatio: CGFloat {
        guard totalCount > 0 else {
            return 0
        }

        return CGFloat(completedCount) / CGFloat(totalCount)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(0..<min(totalCount, 5), id: \.self) { index in
                    Circle()
                        .fill(indicatorColor(for: index))
                        .frame(width: 5.5, height: 5.5)
                }
            }

            ProgressView(value: completionRatio)
                .progressViewStyle(.linear)
                .tint(isSelected ? Color.accentColor : Color.orange)
                .frame(width: 28)
                .scaleEffect(x: 1, y: 0.45, anchor: .center)
                .accessibilityHidden(true)

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
