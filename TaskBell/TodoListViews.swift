//
//  TodoListViews.swift
//  TaskBell
//

import SwiftUI
import SwiftData

struct DatedTodoListView: View {
    let todos: [TodoItem]
    let onToggleCompletion: (TodoItem) -> Void
    let onUpdateTodo: (TodoItem, TodoDraft) -> Void
    let onDelete: (IndexSet, [TodoItem]) -> Void

    @State private var selectedTodo: TodoItem?

    private let calendar = Calendar.current

    private var timelineSections: [DatedTodoSection] {
        (sections(for: .weekly) + sections(for: .monthly))
            .sorted { first, second in
                if first.startDate == second.startDate {
                    return first.grouping.sortPriority < second.grouping.sortPriority
                }

                return first.startDate < second.startDate
            }
    }

    private var hasScheduledTodos: Bool {
        !timelineSections.isEmpty
    }

    private func sections(for grouping: TodoListGrouping) -> [DatedTodoSection] {
        let groupedPairs = todos.flatMap { todo in
            todo.coveredDates(calendar: calendar).map { date in
                (sectionStartDate(for: date, grouping: grouping), todo)
            }
        }

        let grouped = Dictionary(grouping: groupedPairs, by: \.0)

        return grouped
            .map { date, pairs in
                let uniqueTodos = Dictionary(pairs.map { ($0.1.persistentModelID, $0.1) }) { first, _ in first }
                    .values

                return DatedTodoSection(
                    grouping: grouping,
                    startDate: date,
                    title: sectionTitle(for: date, grouping: grouping),
                    todos: uniqueTodos
                        .sorted { first, second in
                            let firstDate = first.relevantDate(for: date, calendar: calendar) ?? first.createdAt
                            let secondDate = second.relevantDate(for: date, calendar: calendar) ?? second.createdAt

                            if firstDate == secondDate {
                                return first.createdAt > second.createdAt
                            }

                            return firstDate < secondDate
                        }
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        Group {
            if !hasScheduledTodos {
                ContentUnavailableView(
                    "날짜가 지정된 할 일이 없습니다",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("오른쪽 아래 + 버튼으로 날짜가 있는 할 일을 추가하세요.")
                )
            } else {
                List {
                    ForEach(timelineSections) { section in
                        todoSection(section)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("투두")
        .sheet(item: $selectedTodo) { todo in
            TodoEditorSheet(title: "할 일 수정", initialDraft: TodoDraft(todo: todo)) { draft in
                onUpdateTodo(todo, draft)
            }
            .presentationDetents([.large])
        }
    }

    private func sectionStartDate(for date: Date, grouping: TodoListGrouping) -> Date {
        switch grouping {
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .monthly:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private func sectionTitle(for startDate: Date, grouping: TodoListGrouping) -> String {
        switch grouping {
        case .weekly:
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: startDate) else {
                return startDate.formatted(date: .complete, time: .omitted)
            }

            return "\(startDate.formatted(date: .abbreviated, time: .omitted)) ~ \(weekEnd.formatted(date: .abbreviated, time: .omitted))"
        case .monthly:
            return startDate.formatted(.dateTime.year().month(.wide))
        }
    }

    private func todoSection(_ section: DatedTodoSection) -> some View {
        Section {
            ForEach(section.todos) { todo in
                HStack(spacing: 12) {
                    Button {
                        onToggleCompletion(todo)
                    } label: {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(todo.isCompleted ? "완료 해제" : "완료")

                    Button {
                        selectedTodo = todo
                    } label: {
                        TodoRowView(todo: todo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete { offsets in
                onDelete(offsets, section.todos)
            }
        } header: {
            DatedTodoSectionHeader(section: section)
        }
    }
}

private struct DatedTodoSection: Identifiable {
    let grouping: TodoListGrouping
    let startDate: Date
    let title: String
    let todos: [TodoItem]

    var id: String {
        "\(grouping.rawValue)-\(startDate.timeIntervalSinceReferenceDate)"
    }
}

private struct DatedTodoSectionHeader: View {
    let section: DatedTodoSection

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(section.grouping.tintColor)
                .frame(width: 4, height: 24)

            Text(section.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Text(section.grouping.title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(section.grouping.tintColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(section.grouping.tintColor.opacity(0.12), in: Capsule())
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
        .textCase(nil)
    }
}

private extension TodoListGrouping {
    var sortPriority: Int {
        switch self {
        case .monthly:
            0
        case .weekly:
            1
        }
    }

    var tintColor: Color {
        switch self {
        case .weekly:
            .accentColor
        case .monthly:
            .orange
        }
    }
}

struct SelectedDayTodoSheet: View {
    let selectedDate: Date
    let todos: [TodoItem]
    let completedCount: Int
    let initialDraft: TodoDraft
    let onToggleCompletion: (TodoItem) -> Void
    let onUpdateTodo: (TodoItem, TodoDraft) -> Void
    let onDelete: (IndexSet) -> Void
    let onAddTodo: (TodoDraft) -> Void

    @State private var isPresentingNewTodoSheet = false
    @State private var selectedTodo: TodoItem?

    private var title: String {
        selectedDate.formatted(Date.FormatStyle(date: .complete, time: .omitted))
    }

    private var summary: String {
        todos.isEmpty ? "할 일 없음" : "\(completedCount)/\(todos.count) 완료"
    }

    var body: some View {
        NavigationStack {
            Group {
                if todos.isEmpty {
                    ContentUnavailableView(
                        "이 날짜의 할 일이 없습니다",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("오른쪽 아래 + 버튼으로 이 날짜에 할 일을 추가하세요.")
                    )
                } else {
                    todoList
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 72)
            }
            .overlay(alignment: .bottomTrailing) {
                addTodoFloatingButton
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $isPresentingNewTodoSheet) {
                TodoEditorSheet(title: "새 할 일", initialDraft: initialDraft) { draft in
                    onAddTodo(draft)
                }
                .presentationDetents([.large])
            }
            .sheet(item: $selectedTodo) { todo in
                TodoEditorSheet(title: "할 일 수정", initialDraft: TodoDraft(todo: todo)) { draft in
                    onUpdateTodo(todo, draft)
                }
                .presentationDetents([.large])
            }
        }
    }

    private var addTodoFloatingButton: some View {
        LiquidGlassAddButton {
            isPresentingNewTodoSheet = true
        }
    }

    private var todoList: some View {
        List {
            ForEach(todos) { todo in
                HStack(spacing: 12) {
                    Button {
                        onToggleCompletion(todo)
                    } label: {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(todo.isCompleted ? "완료 해제" : "완료")

                    Button {
                        selectedTodo = todo
                    } label: {
                        TodoRowView(todo: todo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(.insetGrouped)
    }
}

struct TodoRowView: View {
    let todo: TodoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todo.title.isEmpty ? "제목 없음" : todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)

            if !todo.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(todo.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let scheduleText = todo.scheduleSummary {
                Label(scheduleText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !todo.reminders.isEmpty {
                Text("\(todo.reminders.count)개의 미리알림")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
