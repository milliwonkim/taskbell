//
//  PriorityTodoListView.swift
//  TaskBell
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PriorityTodoListView: View {
    @Environment(\.appLanguage) private var appLanguage
    let todos: [TodoItem]
    let onToggleCompletion: (TodoItem) -> Void
    let onToggleContentCheckbox: (TodoItem, Int) -> Void
    let onUpdateTodo: (TodoItem, TodoDraft) -> Void
    let onDelete: (IndexSet, [TodoItem]) -> Void
    let onMovePriority: (TodoItem, TodoPriorityQuadrant) -> Void

    @State private var selectedTodo: TodoItem?
    @State private var editingTodo: TodoItem?
    @State private var expandedPriority: TodoPriorityQuadrant?
    @State private var targetedPriority: TodoPriorityQuadrant?

    private let calendar = Calendar.current
    private let gridSpacing: CGFloat = 8
    private let panelPadding: CGFloat = 8

    private var dragDropConfig: PriorityMatrixDragDrop {
        PriorityMatrixDragDrop(allTodos: todos, onMove: onMovePriority)
    }

    private var rowCallbacks: TodoListRowCallbacks {
        TodoListRowCallbacks(
            onToggleCompletion: onToggleCompletion,
            onToggleContentCheckbox: onToggleContentCheckbox,
            onSelect: { selectedTodo = $0 },
            onEdit: { editingTodo = $0 },
            onDelete: delete
        )
    }

    var body: some View {
        Group {
            if todos.isEmpty {
                ContentUnavailableView(
                    appLanguage.text(korean: "분류할 할 일이 없습니다", english: "No Todos to Categorize"),
                    systemImage: "square.grid.2x2",
                    description: Text(appLanguage.text(korean: "오른쪽 위 + 버튼으로 할 일을 만들고 우선순위를 선택하세요.", english: "Use the + button at the top right to create a todo and choose a priority."))
                )
            } else {
                priorityMatrix
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTodo) { todo in
            TodoDetailSheet(
                todo: todo,
                onToggleCompletion: {
                    onToggleCompletion(todo)
                },
                onToggleContentCheckbox: { lineIndex in
                    onToggleContentCheckbox(todo, lineIndex)
                },
                onUpdateTodo: { draft in
                    onUpdateTodo(todo, draft)
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $editingTodo) { todo in
            TodoEditorSheet(
                title: appLanguage.text(korean: "할 일 수정", english: "Edit Todo"),
                initialDraft: TodoDraft(todo: todo),
                allowsRoutineBulkCreation: false
            ) { draft in
                onUpdateTodo(todo, draft)
            }
            .presentationDetents([.large])
        }
        .sheet(item: $expandedPriority) { priority in
            PriorityQuadrantDetailSheet(
                priority: priority,
                sections: makeDateSections(for: priority),
                callbacks: rowCallbacks,
                calendar: calendar
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var priorityMatrix: some View {
        GeometryReader { proxy in
            let columnTitles = matrixColumnTitles
            let rowTitles = matrixRowTitles
            let horizontalLabelWidth: CGFloat = 28
            let verticalHeaderHeight: CGFloat = 22
            let cellWidth = max(
                (proxy.size.width - gridSpacing - horizontalLabelWidth - panelPadding * 2) / 2,
                0
            )
            let cellHeight = max(
                (proxy.size.height - gridSpacing - verticalHeaderHeight - panelPadding * 2) / 2,
                0
            )

            VStack(spacing: gridSpacing) {
                HStack(spacing: gridSpacing) {
                    Color.clear
                        .frame(width: horizontalLabelWidth)

                    matrixColumnTitle(columnTitles.urgent)
                        .frame(width: cellWidth)

                    matrixColumnTitle(columnTitles.notUrgent)
                        .frame(width: cellWidth)
                }

                HStack(alignment: .top, spacing: gridSpacing) {
                    VStack(spacing: gridSpacing) {
                        matrixRowTitle(rowTitles.important)
                            .frame(height: cellHeight)

                        matrixRowTitle(rowTitles.notImportant)
                            .frame(height: cellHeight)
                    }
                    .frame(width: horizontalLabelWidth)

                    VStack(spacing: gridSpacing) {
                        HStack(spacing: gridSpacing) {
                            priorityPanel(
                                .importantUrgent,
                                size: CGSize(width: cellWidth, height: cellHeight)
                            )
                            priorityPanel(
                                .importantNotUrgent,
                                size: CGSize(width: cellWidth, height: cellHeight)
                            )
                        }

                        HStack(spacing: gridSpacing) {
                            priorityPanel(
                                .notImportantUrgent,
                                size: CGSize(width: cellWidth, height: cellHeight)
                            )
                            priorityPanel(
                                .notImportantNotUrgent,
                                size: CGSize(width: cellWidth, height: cellHeight)
                            )
                        }
                    }
                }
            }
            .padding(panelPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .background(Color(.systemBackground))
    }

    private var matrixColumnTitles: (urgent: String, notUrgent: String) {
        (
            urgent: appLanguage.text(korean: "긴급", english: "Urgent"),
            notUrgent: appLanguage.text(korean: "긴급하지 않음", english: "Not Urgent")
        )
    }

    private var matrixRowTitles: (important: String, notImportant: String) {
        (
            important: appLanguage.text(korean: "중요", english: "Important"),
            notImportant: appLanguage.text(korean: "중요하지 않음", english: "Not Important")
        )
    }

    private func matrixColumnTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }

    private func matrixRowTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotationEffect(.degrees(-90))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func priorityPanel(
        _ priority: TodoPriorityQuadrant,
        size: CGSize
    ) -> some View {
        PriorityQuadrantPanel(
            priority: priority,
            dateGroups: dateGroups(for: priority),
            visibleTodos: visibleTodos(for: priority),
            callbacks: rowCallbacks,
            calendar: calendar,
            dragDrop: dragDropConfig,
            targetedPriority: $targetedPriority,
            onExpand: {
                expandedPriority = priority
            }
        )
        .frame(width: size.width, height: size.height)
    }

    private func visibleTodos(for priority: TodoPriorityQuadrant) -> [TodoItem] {
        makeDateSections(for: priority).flatMap(\.todos)
    }

    private func dateGroups(for priority: TodoPriorityQuadrant) -> [PriorityDateGroup] {
        makeDateSections(for: priority).compactMap { section in
            guard !section.todos.isEmpty else {
                return nil
            }

            return PriorityDateGroup(
                id: section.id,
                title: section.headerTitle
                    ?? appLanguage.text(korean: "날짜 미지정", english: "No Date"),
                referenceDate: section.referenceDate,
                todos: section.todos
            )
        }
    }

    private func makeDateSections(for priority: TodoPriorityQuadrant) -> [TodoListTimelineSection] {
        let priorityTodos = todos.filter { $0.priority == priority }
        let completedCount = priorityTodos.filter(\.isCompleted).count

        guard !priorityTodos.isEmpty else {
            return []
        }

        let grouped = Dictionary(grouping: priorityTodos, by: groupingDate(for:))

        let sortedDateKeys = grouped.keys.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case (nil, nil):
                false
            case (nil, _):
                false
            case (_, nil):
                true
            case (let left?, let right?):
                left < right
            }
        }

        return sortedDateKeys.map { dateKey in
            let sectionTodos = sortedTodos(grouped[dateKey] ?? [], on: dateKey)
            let headerTitle =
                dateKey.map {
                    appLanguage.formattedListDayTitle(for: $0, calendar: calendar)
                }
                ?? appLanguage.text(korean: "날짜 미지정", english: "No Date")

            return TodoListTimelineSection(
                id: "\(priority.rawValue)-\(dateKey?.timeIntervalSinceReferenceDate ?? -1)",
                referenceDate: dateKey,
                todos: sectionTodos,
                headerTitle: headerTitle,
                priority: priority,
                priorityCompletedCount: completedCount,
                priorityTotalCount: priorityTodos.count
            )
        }
    }

    private func groupingDate(for todo: TodoItem) -> Date? {
        guard let start = todo.scheduledStartAt else {
            return nil
        }

        return calendar.startOfDay(for: start)
    }

    private func sortedTodos(_ todos: [TodoItem], on date: Date?) -> [TodoItem] {
        todos.sorted { first, second in
            if first.isCompleted != second.isCompleted {
                return !first.isCompleted
            }

            if let date {
                let firstDate =
                    first.relevantDate(for: date, calendar: calendar) ?? first.createdAt
                let secondDate =
                    second.relevantDate(for: date, calendar: calendar) ?? second.createdAt

                if firstDate != secondDate {
                    return firstDate < secondDate
                }
            } else if first.createdAt != second.createdAt {
                return first.createdAt < second.createdAt
            }

            return first.createdAt < second.createdAt
        }
    }

    private func delete(_ todo: TodoItem, from visibleTodos: [TodoItem]) {
        guard
            let index = visibleTodos.firstIndex(where: {
                $0.persistentModelID == todo.persistentModelID
            })
        else {
            return
        }

        onDelete(IndexSet(integer: index), visibleTodos)
    }
}

private struct PriorityDateGroup: Identifiable {
    let id: String
    let title: String
    let referenceDate: Date?
    let todos: [TodoItem]
}

private struct PriorityMatrixDragDrop {
    let allTodos: [TodoItem]
    let onMove: (TodoItem, TodoPriorityQuadrant) -> Void

    func dragIdentifier(for todo: TodoItem) -> String {
        String(describing: todo.persistentModelID)
    }

    func resolveTodo(from draggedID: String) -> TodoItem? {
        allTodos.first { dragIdentifier(for: $0) == draggedID }
    }

    func handleDrop(
        from providers: [NSItemProvider],
        into priority: TodoPriorityQuadrant,
        onComplete: @escaping () -> Void
    ) -> Bool {
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

            guard let draggedID, let draggedTodo = resolveTodo(from: draggedID) else {
                return
            }

            Task { @MainActor in
                if draggedTodo.priority != priority {
                    onMove(draggedTodo, priority)
                }
                onComplete()
            }
        }

        return true
    }
}

private struct PriorityQuadrantPanel: View {
    @Environment(\.appLanguage) private var appLanguage

    let priority: TodoPriorityQuadrant
    let dateGroups: [PriorityDateGroup]
    let visibleTodos: [TodoItem]
    let callbacks: TodoListRowCallbacks
    let calendar: Calendar
    let dragDrop: PriorityMatrixDragDrop
    @Binding var targetedPriority: TodoPriorityQuadrant?
    let onExpand: () -> Void

    private var isDropTarget: Bool {
        targetedPriority == priority
    }

    private var completedCount: Int {
        visibleTodos.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onExpand) {
                HStack(spacing: 6) {
                    Image(systemName: priority.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(priority.accentColor)

                    Text(priority.shortTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    Text("\(completedCount)/\(visibleTodos.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if dateGroups.isEmpty {
                Spacer(minLength: 0)

                Text(appLanguage.text(korean: "할 일 없음", english: "No todos"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(dateGroups) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                ForEach(group.todos) { todo in
                                    PriorityQuadrantTodoRow(
                                        todo: todo,
                                        sectionDate: group.referenceDate,
                                        visibleTodos: visibleTodos,
                                        callbacks: callbacks,
                                        calendar: calendar,
                                        dragDrop: dragDrop
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isDropTarget ? priority.panelDropTargetColor : priority.panelBackgroundColor)
        .overlay {
            Rectangle()
                .strokeBorder(
                    isDropTarget ? priority.accentColor : Color(.separator).opacity(0.35),
                    lineWidth: isDropTarget ? 1.5 : 0.5
                )
        }
        .onDrop(
            of: [.plainText],
            isTargeted: Binding(
                get: { targetedPriority == priority },
                set: { isTargeted in
                    targetedPriority = isTargeted ? priority : nil
                }
            )
        ) { providers in
            dragDrop.handleDrop(from: providers, into: priority) {
                targetedPriority = nil
            }
        }
    }
}

private struct PriorityQuadrantTodoRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let todo: TodoItem
    let sectionDate: Date?
    let visibleTodos: [TodoItem]
    let callbacks: TodoListRowCallbacks
    let calendar: Calendar
    let dragDrop: PriorityMatrixDragDrop

    private var isOverdue: Bool {
        if let sectionDate {
            return todo.isScheduleElapsed(forSectionDate: sectionDate, calendar: calendar)
        }

        return todo.isScheduleElapsed(calendar: calendar)
    }

    private var appearance: TodoListRowAppearance {
        TodoListRowAppearance(isCompleted: todo.isCompleted, isOverdue: isOverdue)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            TodoCompletionButton(appearance: appearance) {
                callbacks.onToggleCompletion(todo)
            }

            Text(todo.title.isEmpty ? appLanguage.text(korean: "제목 없음", english: "Untitled") : todo.title)
                .font(.caption)
                .foregroundStyle(appearance.titleColor)
                .strikethrough(appearance.usesStrikethrough)
                .opacity(appearance.contentOpacity)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onDrag {
            NSItemProvider(object: dragDrop.dragIdentifier(for: todo) as NSString)
        }
        .onTapGesture {
            callbacks.onSelect(todo)
        }
        .contextMenu {
            Button {
                callbacks.onEdit(todo)
            } label: {
                Label(appLanguage.text(korean: "수정", english: "Edit"), systemImage: "pencil")
            }

            Button(role: .destructive) {
                callbacks.onDelete(todo, visibleTodos)
            } label: {
                Label(appLanguage.text(korean: "삭제", english: "Delete"), systemImage: "trash")
            }
        }
    }
}

private struct PriorityQuadrantDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage

    let priority: TodoPriorityQuadrant
    let sections: [TodoListTimelineSection]
    let callbacks: TodoListRowCallbacks
    let calendar: Calendar

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    ContentUnavailableView(
                        appLanguage.text(korean: "할 일 없음", english: "No Todos"),
                        systemImage: priority.systemImage,
                        description: Text(appLanguage.text(korean: "이 분류의 할 일이 없습니다.", english: "No todos in this category."))
                    )
                } else {
                    TodoListTimelineView(
                        sections: sections,
                        callbacks: callbacks,
                        calendar: calendar
                    ) { section in
                        if let headerTitle = section.headerTitle {
                            TodoListDateSectionHeader(title: headerTitle)
                        }
                    }
                }
            }
            .navigationTitle(priority.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(korean: "닫기", english: "Close")) {
                        dismiss()
                    }
                }

                if !sections.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }
}

private extension TodoPriorityQuadrant {
    var accentColor: Color {
        switch self {
        case .importantUrgent:
            .red
        case .importantNotUrgent:
            .blue
        case .notImportantUrgent:
            .orange
        case .notImportantNotUrgent:
            .secondary
        }
    }

    var panelBackgroundColor: Color {
        switch self {
        case .importantUrgent:
            Color.red.opacity(0.07)
        case .importantNotUrgent:
            Color.blue.opacity(0.07)
        case .notImportantUrgent:
            Color.orange.opacity(0.07)
        case .notImportantNotUrgent:
            Color(.secondarySystemBackground)
        }
    }

    var panelDropTargetColor: Color {
        switch self {
        case .importantUrgent:
            Color.red.opacity(0.16)
        case .importantNotUrgent:
            Color.blue.opacity(0.16)
        case .notImportantUrgent:
            Color.orange.opacity(0.16)
        case .notImportantNotUrgent:
            Color(.tertiarySystemBackground)
        }
    }
}
