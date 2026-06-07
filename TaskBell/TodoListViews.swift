//
//  TodoListViews.swift
//  TaskBell
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum TodoRowMetrics {
    static let checkboxContentSpacing: CGFloat = 6
    static let contentSpacing: CGFloat = 4
    static let metadataRowSpacing: CGFloat = 4
    static let metadataColumnSpacing: CGFloat = 8
    static let iconTextSpacing: CGFloat = 3
    static let checkboxSize: CGFloat = 28
    static let rowHorizontalInset: CGFloat = 16
    static let rowVerticalInset: CGFloat = 10
}

struct TodoListRowAppearance {
    enum State {
        case active
        case completed
        case overdue
    }

    let state: State

    init(isCompleted: Bool, isOverdue: Bool) {
        if isCompleted {
            state = .completed
        } else if isOverdue {
            state = .overdue
        } else {
            state = .active
        }
    }

    var checkboxColor: Color {
        switch state {
        case .active, .overdue:
            Color.secondary.opacity(0.85)
        case .completed:
            Color.green
        }
    }

    var titleColor: Color {
        switch state {
        case .active, .overdue:
            Color.primary
        case .completed:
            Color.secondary
        }
    }

    var usesStrikethrough: Bool {
        state == .completed
    }

    var contentOpacity: Double {
        state == .completed ? 0.55 : 1
    }

    var statusLabelColor: Color? {
        switch state {
        case .active:
            nil
        case .completed:
            .secondary
        case .overdue:
            .red
        }
    }

    var statusLabelTextKey: (korean: String, english: String)? {
        switch state {
        case .active:
            nil
        case .completed:
            (korean: "완료", english: "Done")
        case .overdue:
            (korean: "시간 경과", english: "Overdue")
        }
    }

    var statusLabelIcon: String? {
        switch state {
        case .active:
            nil
        case .completed:
            "checkmark"
        case .overdue:
            "clock"
        }
    }
}

private struct TodoListRowListStyleModifier: ViewModifier {
    let usesListChrome: Bool

    func body(content: Content) -> some View {
        if usesListChrome {
            content
                .listRowInsets(
                    EdgeInsets(
                        top: TodoRowMetrics.rowVerticalInset,
                        leading: TodoRowMetrics.rowHorizontalInset,
                        bottom: TodoRowMetrics.rowVerticalInset,
                        trailing: TodoRowMetrics.rowHorizontalInset
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        } else {
            content
                .padding(.vertical, TodoRowMetrics.rowVerticalInset)
                .padding(.horizontal, TodoRowMetrics.rowHorizontalInset)
        }
    }
}

struct TodoListTimelineSection: Identifiable {
    let id: String
    let referenceDate: Date?
    let todos: [TodoItem]
    let emptyMessage: String?
    var headerTitle: String?
    var priority: TodoPriorityQuadrant?
    var showsPriorityHeader: Bool = false
    var priorityCompletedCount: Int = 0
    var priorityTotalCount: Int = 0

    init(
        id: String,
        referenceDate: Date?,
        todos: [TodoItem],
        emptyMessage: String? = nil,
        headerTitle: String? = nil,
        priority: TodoPriorityQuadrant? = nil,
        showsPriorityHeader: Bool = false,
        priorityCompletedCount: Int = 0,
        priorityTotalCount: Int = 0
    ) {
        self.id = id
        self.referenceDate = referenceDate
        self.todos = todos
        self.emptyMessage = emptyMessage
        self.headerTitle = headerTitle
        self.priority = priority
        self.showsPriorityHeader = showsPriorityHeader
        self.priorityCompletedCount = priorityCompletedCount
        self.priorityTotalCount = priorityTotalCount
    }

    init(date: Date, todos: [TodoItem], emptyMessage: String? = nil) {
        self.id = "date-\(date.timeIntervalSinceReferenceDate)"
        self.referenceDate = date
        self.todos = todos
        self.emptyMessage = emptyMessage
        self.headerTitle = nil
        self.priority = nil
        self.showsPriorityHeader = false
        self.priorityCompletedCount = 0
        self.priorityTotalCount = 0
    }
}

struct TodoListRowCallbacks {
    let onToggleCompletion: (TodoItem) -> Void
    let onToggleContentCheckbox: (TodoItem, Int) -> Void
    let onSelect: (TodoItem) -> Void
    let onEdit: (TodoItem) -> Void
    let onDelete: (TodoItem, [TodoItem]) -> Void
}

struct TodoListTimelineDragDrop {
    let allTodos: [TodoItem]
    let onMove: (TodoItem, Date?, TodoItem?) -> Void
    var onDragStarted: ((TodoItem) -> Void)? = nil
    var enablesRowDrop: Bool = true

    func dragIdentifier(for todo: TodoItem) -> String {
        String(describing: todo.persistentModelID)
    }

    func resolveTodo(from draggedID: String) -> TodoItem? {
        allTodos.first { dragIdentifier(for: $0) == draggedID }
    }

    func handleDrop(
        from providers: [NSItemProvider],
        to date: Date?,
        before targetTodo: TodoItem?,
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
                if let targetTodo,
                    targetTodo.persistentModelID == draggedTodo.persistentModelID
                {
                    onComplete()
                    return
                }

                onMove(draggedTodo, date, targetTodo)
                onComplete()
            }
        }

        return true
    }
}

private struct TodoListRowItemView: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.editMode) private var editMode

    let todo: TodoItem
    let sectionDate: Date?
    let visibleTodos: [TodoItem]
    let callbacks: TodoListRowCallbacks
    let calendar: Calendar
    let dragDrop: TodoListTimelineDragDrop?
    @Binding var targetedDropSectionID: String?
    let sectionID: String
    var usesListChrome: Bool = true

    private var isEditModeActive: Bool {
        editMode?.wrappedValue == .active
    }

    private var isOverdue: Bool {
        if let sectionDate {
            return todo.isScheduleElapsed(forSectionDate: sectionDate, calendar: calendar)
        }

        return todo.isScheduleElapsed(calendar: calendar)
    }

    private var appearance: TodoListRowAppearance {
        TodoListRowAppearance(
            isCompleted: todo.isCompleted,
            isOverdue: isOverdue
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: TodoRowMetrics.checkboxContentSpacing) {
            if isEditModeActive {
                Button {
                    callbacks.onDelete(todo, visibleTodos)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(appLanguage.text(korean: "삭제", english: "Delete"))
            }

            TodoCompletionButton(appearance: appearance) {
                guard !isEditModeActive else {
                    return
                }

                callbacks.onToggleCompletion(todo)
            }

            TodoRowView(
                todo: todo,
                isOverdue: isOverdue,
                onToggleContentCheckbox: { lineIndex in
                    callbacks.onToggleContentCheckbox(todo, lineIndex)
                }
            ) {
                guard !isEditModeActive else {
                    return
                }

                callbacks.onSelect(todo)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(appearance.contentOpacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isEditModeActive else {
                return
            }

            callbacks.onSelect(todo)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                callbacks.onDelete(todo, visibleTodos)
            } label: {
                Label(appLanguage.text(korean: "삭제", english: "Delete"), systemImage: "trash")
            }
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
        .modifier(
            TodoListRowDragDropModifier(
                todo: todo,
                sectionDate: sectionDate,
                sectionID: sectionID,
                dragDrop: dragDrop,
                targetedDropSectionID: $targetedDropSectionID
            )
        )
        .modifier(TodoListRowListStyleModifier(usesListChrome: usesListChrome))
    }
}

private struct TodoListRowDragDropModifier: ViewModifier {
    @Environment(\.editMode) private var editMode

    let todo: TodoItem
    let sectionDate: Date?
    let sectionID: String
    let dragDrop: TodoListTimelineDragDrop?
    @Binding var targetedDropSectionID: String?

    func body(content: Content) -> some View {
        if let dragDrop, editMode?.wrappedValue != .active {
            content
                .onDrag {
                    dragDrop.onDragStarted?(todo)
                    return NSItemProvider(
                        object: dragDrop.dragIdentifier(for: todo) as NSString
                    )
                }
                .modifier(
                    TodoListRowDropModifier(
                        todo: todo,
                        sectionDate: sectionDate,
                        sectionID: sectionID,
                        dragDrop: dragDrop,
                        targetedDropSectionID: $targetedDropSectionID
                    )
                )
        } else {
            content
        }
    }
}

private struct TodoListRowDropModifier: ViewModifier {
    let todo: TodoItem
    let sectionDate: Date?
    let sectionID: String
    let dragDrop: TodoListTimelineDragDrop
    @Binding var targetedDropSectionID: String?

    func body(content: Content) -> some View {
        if dragDrop.enablesRowDrop {
            content
                .background {
                    if targetedDropSectionID == sectionID {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.08))
                    }
                }
                .onDrop(
                of: [.plainText],
                isTargeted: Binding(
                    get: { targetedDropSectionID == sectionID },
                    set: { isTargeted in
                        targetedDropSectionID = isTargeted ? sectionID : nil
                    }
                )
            ) { providers in
                dragDrop.handleDrop(
                    from: providers,
                    to: sectionDate,
                    before: todo
                ) {
                    targetedDropSectionID = nil
                }
            }
        } else {
            content
        }
    }
}

private struct TodoListSectionCardView: View {
    let section: TodoListTimelineSection
    let callbacks: TodoListRowCallbacks
    let calendar: Calendar
    let dragDrop: TodoListTimelineDragDrop?
    @Binding var targetedDropSectionID: String?
    var usesListChrome: Bool = true

    var body: some View {
        if section.todos.isEmpty, let emptyMessage = section.emptyMessage {
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .modifier(TodoListRowListStyleModifier(usesListChrome: usesListChrome))
        } else if usesListChrome {
            ForEach(section.todos) { todo in
                TodoListRowItemView(
                    todo: todo,
                    sectionDate: section.referenceDate,
                    visibleTodos: section.todos,
                    callbacks: callbacks,
                    calendar: calendar,
                    dragDrop: dragDrop,
                    targetedDropSectionID: $targetedDropSectionID,
                    sectionID: section.id,
                    usesListChrome: true
                )
            }
        } else {
            ForEach(section.todos) { todo in
                TodoListRowItemView(
                    todo: todo,
                    sectionDate: section.referenceDate,
                    visibleTodos: section.todos,
                    callbacks: callbacks,
                    calendar: calendar,
                    dragDrop: dragDrop,
                    targetedDropSectionID: $targetedDropSectionID,
                    sectionID: section.id,
                    usesListChrome: false
                )
            }
        }
    }
}

struct TodoListTimelineView<SectionHeader: View>: View {
    let sections: [TodoListTimelineSection]
    let callbacks: TodoListRowCallbacks
    let calendar: Calendar
    var dragDrop: TodoListTimelineDragDrop? = nil
    var alwaysUseListLayout: Bool = false
    var showsSectionHeaders: Bool = true
    @ViewBuilder let sectionHeader: (TodoListTimelineSection) -> SectionHeader

    @Environment(\.editMode) private var editMode
    @State private var targetedDropSectionID: String?

    private var usesScrollLayout: Bool {
        if alwaysUseListLayout {
            return false
        }

        guard dragDrop != nil else {
            return false
        }

        return editMode?.wrappedValue != .active
    }

    var body: some View {
        if usesScrollLayout {
            scrollTimeline
        } else {
            listTimeline
        }
    }

    private var scrollTimeline: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sections) { section in
                    if showsSectionHeaders {
                        scrollSectionHeader(section)
                    }
                    scrollSectionContent(section)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    private var listTimeline: some View {
        List {
            ForEach(sections) { section in
                if showsSectionHeaders {
                    Section {
                        sectionContent(section, usesListChrome: true)
                    } header: {
                        sectionHeader(section)
                    }
                } else {
                    Section {
                        sectionContent(section, usesListChrome: true)
                    }
                }
            }
        }
        .listStyle(.plain)
        .listSectionSeparator(.hidden)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func scrollSectionHeader(_ section: TodoListTimelineSection) -> some View {
        sectionHeader(section)
            .modifier(
                TodoListSectionHeaderDropModifier(
                    section: section,
                    dragDrop: dragDrop,
                    targetedDropSectionID: $targetedDropSectionID
                )
            )
            .padding(.top, 10)
            .padding(.bottom, 4)
            .padding(.horizontal, TodoRowMetrics.rowHorizontalInset)
    }

    @ViewBuilder
    private func scrollSectionContent(_ section: TodoListTimelineSection) -> some View {
        TodoListSectionCardView(
            section: section,
            callbacks: callbacks,
            calendar: calendar,
            dragDrop: dragDrop,
            targetedDropSectionID: $targetedDropSectionID,
            usesListChrome: false
        )
    }

    private func sectionContent(_ section: TodoListTimelineSection, usesListChrome: Bool) -> some View {
        TodoListSectionCardView(
            section: section,
            callbacks: callbacks,
            calendar: calendar,
            dragDrop: dragDrop,
            targetedDropSectionID: $targetedDropSectionID,
            usesListChrome: usesListChrome
        )
    }
}

private struct TodoListSectionHeaderDropModifier: ViewModifier {
    let section: TodoListTimelineSection
    let dragDrop: TodoListTimelineDragDrop?
    @Binding var targetedDropSectionID: String?

    private var isDropTarget: Bool {
        targetedDropSectionID == section.id
    }

    func body(content: Content) -> some View {
        if let dragDrop, section.referenceDate != nil {
            content
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isDropTarget ? Color.accentColor.opacity(0.14) : Color.clear)
                }
                .overlay {
                    if isDropTarget {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .contentShape(Rectangle())
                .onDrop(
                    of: [.plainText],
                    isTargeted: Binding(
                        get: { isDropTarget },
                        set: { isTargeted in
                            targetedDropSectionID = isTargeted ? section.id : nil
                        }
                    )
                ) { providers in
                    dragDrop.handleDrop(
                        from: providers,
                        to: section.referenceDate,
                        before: nil
                    ) {
                        targetedDropSectionID = nil
                    }
                }
        } else {
            content
        }
    }
}

struct DatedTodoListView: View {
    @Environment(\.appLanguage) private var appLanguage
    let todos: [TodoItem]
    let onToggleCompletion: (TodoItem) -> Void
    let onToggleContentCheckbox: (TodoItem, Int) -> Void
    let onUpdateTodo: (TodoItem, TodoDraft) -> Void
    let onDelete: (IndexSet, [TodoItem]) -> Void
    let onMoveTodo: (TodoItem, Date, TodoItem?) -> Void

    @State private var selectedTodo: TodoItem?
    @State private var editingTodo: TodoItem?
    @State private var timelineSections: [DatedTodoSection] = []

    private let calendar = Calendar.current

    private var timelineRevision: UInt64 {
        var hasher = Hasher()
        for todo in todos {
            hasher.combine(todo.persistentModelID)
            hasher.combine(todo.isCompleted)
            hasher.combine(todo.scheduledStartAt)
            hasher.combine(todo.scheduledEndAt)
            hasher.combine(todo.scheduleModeRawValue)
            hasher.combine(todo.timelineSortOrder)
        }
        hasher.combine(appLanguage.rawValue)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    private var hasScheduledTodos: Bool {
        !timelineSections.isEmpty
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

    private var dragDropConfig: TodoListTimelineDragDrop {
        TodoListTimelineDragDrop(allTodos: todos) { todo, date, targetTodo in
            guard let date else { return }

            withAnimation(.snappy) {
                onMoveTodo(todo, date, targetTodo)
            }
        }
    }

    var body: some View {
        Group {
            if !hasScheduledTodos {
                ContentUnavailableView(
                    appLanguage.text(korean: "날짜가 지정된 할 일이 없습니다", english: "No Scheduled Todos"),
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(appLanguage.text(korean: "오른쪽 아래 + 버튼으로 날짜가 있는 할 일을 추가하세요.", english: "Use the + button at the bottom right to add a todo with a date."))
                )
            } else {
                TodoListTimelineView(
                    sections: timelineSections.map {
                        TodoListTimelineSection(
                            id: $0.id,
                            referenceDate: $0.date,
                            todos: $0.todos
                        )
                    },
                    callbacks: rowCallbacks,
                    calendar: calendar,
                    dragDrop: dragDropConfig
                ) { section in
                    if let datedSection = timelineSections.first(where: { $0.id == section.id }) {
                        DatedTodoSectionHeader(section: datedSection)
                    }
                }
            }
        }
        .onAppear {
            rebuildTimelineSections()
        }
        .onChange(of: timelineRevision) { _, _ in
            rebuildTimelineSections()
        }
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
    }

    private func rebuildTimelineSections() {
        timelineSections = DatedTodoTimelineBuilder.makeSections(
            from: todos,
            calendar: calendar,
            language: appLanguage
        )
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

private struct DatedTodoSection: Identifiable {
    let date: Date
    let title: String
    let todos: [TodoItem]

    var id: String {
        "\(date.timeIntervalSinceReferenceDate)"
    }
}

private enum DatedTodoTimelineBuilder {
    static func makeSections(
        from todos: [TodoItem],
        calendar: Calendar,
        language: AppLanguage
    ) -> [DatedTodoSection] {
        let groupedPairs = todos.flatMap { todo in
            todo.coveredDates(calendar: calendar).map { date in
                (calendar.startOfDay(for: date), todo)
            }
        }

        let grouped = Dictionary(grouping: groupedPairs, by: \.0)

        return grouped
            .map { date, pairs in
                let uniqueTodos = Dictionary(
                    pairs.map { ($0.1.persistentModelID, $0.1) }
                ) { first, _ in first }
                .values

                return DatedTodoSection(
                    date: date,
                    title: language.formattedListDayTitle(for: date, calendar: calendar),
                    todos: uniqueTodos.sorted { first, second in
                        sortOrder(for: first, on: date, calendar: calendar)
                            < sortOrder(for: second, on: date, calendar: calendar)
                    }
                )
            }
            .sorted { $0.date < $1.date }
    }

    private static func sortOrder(
        for todo: TodoItem,
        on date: Date,
        calendar: Calendar
    ) -> Double {
        if todo.timelineSortOrder != 0 {
            return todo.timelineSortOrder
        }

        return (todo.relevantDate(for: date, calendar: calendar) ?? todo.createdAt)
            .timeIntervalSinceReferenceDate
    }
}

private struct DatedTodoSectionHeader: View {
    let section: DatedTodoSection

    var body: some View {
        TodoListDateSectionHeader(title: section.title)
    }
}

struct TodoListDateSectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
        .textCase(nil)
    }
}

struct SelectedDayTodoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage

    let selectedDate: Date
    let todos: [TodoItem]
    let initialDraft: TodoDraft
    let onToggleCompletion: (TodoItem) -> Void
    let onToggleContentCheckbox: (TodoItem, Int) -> Void
    let onUpdateTodo: (TodoItem, TodoDraft) -> Void
    let onDelete: (IndexSet) -> Void
    let onAddTodo: (TodoDraft) -> Void
    let onMoveTodo: (TodoItem, Date, TodoItem?) -> Void
    let onTodoDragStarted: () -> Void
    let onTodoDragExitedSheet: () -> Void

    @State private var isPresentingNewTodoSheet = false
    @State private var selectedTodo: TodoItem?
    @State private var editingTodo: TodoItem?
    @State private var editMode: EditMode = .inactive
    @State private var isDraggingTodoFromSheet = false
    @State private var isSheetDragBoundaryMonitoring = false
    @State private var isDragHoveringSheetContent = false

    private var title: String {
        appLanguage.formattedLongDate(selectedDate)
    }

    var body: some View {
        NavigationStack {
            Group {
                if todos.isEmpty {
                    emptyState
                } else {
                    todoList
                }
            }
            .overlay {
                if isSheetDragBoundaryMonitoring {
                    Color.clear
                        .contentShape(Rectangle())
                        .onDrop(of: [.plainText], isTargeted: $isDragHoveringSheetContent) { _ in
                            false
                        }
                }
            }
            .onChange(of: isDragHoveringSheetContent) { wasHovering, isHovering in
                guard isDraggingTodoFromSheet, isSheetDragBoundaryMonitoring else {
                    return
                }

                guard wasHovering, !isHovering else {
                    return
                }

                isDraggingTodoFromSheet = false
                isSheetDragBoundaryMonitoring = false
                onTodoDragExitedSheet()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(korean: "닫기", english: "Close")) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewTodoSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel(appLanguage.text(korean: "이 날짜에 할 일 추가", english: "Add Todo on This Date"))

                    if !todos.isEmpty {
                        Button {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        } label: {
                            Text(
                                editMode == .active
                                    ? appLanguage.text(korean: "완료", english: "Done")
                                    : appLanguage.text(korean: "편집", english: "Edit")
                            )
                        }
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewTodoSheet) {
                TodoEditorSheet(title: appLanguage.text(korean: "새 할 일", english: "New Todo"), initialDraft: initialDraft) {
                    draft in
                    onAddTodo(draft)
                }
                .presentationDetents([.large])
            }
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
        }
        .environment(\.locale, appLanguage.locale)
        .onDisappear {
            editMode = .inactive
            isDraggingTodoFromSheet = false
            isSheetDragBoundaryMonitoring = false
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(appLanguage.text(korean: "이 날짜의 할 일이 없습니다", english: "No Todos on This Date"), systemImage: "calendar.badge.plus")
        } description: {
            Text(appLanguage.text(korean: "오른쪽 위 + 버튼으로 이 날짜에 할 일을 추가하세요.", english: "Use the + button at the top right to add a todo on this date."))
        } actions: {
            Button {
                isPresentingNewTodoSheet = true
            } label: {
                Label(appLanguage.text(korean: "할 일 추가", english: "Add Todo"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private let calendar = Calendar.current

    private var rowCallbacks: TodoListRowCallbacks {
        TodoListRowCallbacks(
            onToggleCompletion: onToggleCompletion,
            onToggleContentCheckbox: onToggleContentCheckbox,
            onSelect: { selectedTodo = $0 },
            onEdit: { editingTodo = $0 },
            onDelete: delete
        )
    }

    private var dragDropConfig: TodoListTimelineDragDrop {
        TodoListTimelineDragDrop(
            allTodos: todos,
            onMove: { _, _, _ in },
            onDragStarted: { _ in
                isDraggingTodoFromSheet = true
                isSheetDragBoundaryMonitoring = false
                isDragHoveringSheetContent = false
                onTodoDragStarted()

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    guard isDraggingTodoFromSheet else {
                        return
                    }

                    isSheetDragBoundaryMonitoring = true
                }
            },
            enablesRowDrop: false
        )
    }

    private var todoList: some View {
        TodoListTimelineView(
            sections: [
                TodoListTimelineSection(date: selectedDate, todos: todos),
            ],
            callbacks: rowCallbacks,
            calendar: calendar,
            dragDrop: dragDropConfig,
            alwaysUseListLayout: true,
            showsSectionHeaders: false
        ) { _ in
            EmptyView()
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

        onDelete(IndexSet(integer: index))
    }
}

struct TodoCompletionButton: View {
    @Environment(\.appLanguage) private var appLanguage
    let appearance: TodoListRowAppearance
    let action: () -> Void

    init(isCompleted: Bool, action: @escaping () -> Void) {
        appearance = TodoListRowAppearance(isCompleted: isCompleted, isOverdue: false)
        self.action = action
    }

    init(appearance: TodoListRowAppearance, action: @escaping () -> Void) {
        self.appearance = appearance
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            checkboxImage
                .frame(
                    width: TodoRowMetrics.checkboxSize,
                    height: TodoRowMetrics.checkboxSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            appearance.state == .completed
                ? appLanguage.text(korean: "완료 해제", english: "Mark Incomplete")
                : appLanguage.text(korean: "완료", english: "Complete")
        )
    }

    @ViewBuilder
    private var checkboxImage: some View {
        switch appearance.state {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, appearance.checkboxColor)
        case .active, .overdue:
            Image(systemName: "circle")
                .font(.system(size: 24))
                .foregroundStyle(appearance.checkboxColor)
        }
    }
}

struct TodoDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    let todo: TodoItem
    let onToggleCompletion: () -> Void
    let onToggleContentCheckbox: (Int) -> Void
    let onUpdateTodo: (TodoDraft) -> Void

    @State private var isPresentingEditor = false
    @State private var selectedPhotoPreview: PhotoAttachmentPreview?
    @State private var selectedVideoPreview: VideoAttachmentPreview?

    private var displayTitle: String {
        todo.title.isEmpty ? appLanguage.text(korean: "제목 없음", english: "Untitled") : todo.title
    }

    private var trimmedContent: String {
        todo.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sortedReminders: [Reminder] {
        (todo.reminders ?? []).sorted { $0.fireDate < $1.fireDate }
    }

    private var sortedAttachments: [TodoAttachment] {
        (todo.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    if !trimmedContent.isEmpty {
                        detailCard(title: appLanguage.text(korean: "내용", english: "Content"), systemImage: "text.alignleft") {
                            RichTodoContentView(
                                content: todo.content,
                                compact: false
                            ) { lineIndex in
                                onToggleContentCheckbox(lineIndex)
                            }
                        }
                    }

                    if !sortedReminders.isEmpty {
                        detailCard(title: appLanguage.text(korean: "미리알림", english: "Reminders"), systemImage: "bell.badge") {
                            VStack(spacing: 10) {
                                ForEach(sortedReminders) { reminder in
                                    ReminderRowView(reminder: reminder)
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: .leading
                                        )
                                }
                            }
                        }
                    }

                    if !sortedAttachments.isEmpty {
                        detailCard(title: appLanguage.text(korean: "첨부", english: "Attachments"), systemImage: "paperclip") {
                            LazyVGrid(
                                columns: [
                                    GridItem(
                                        .adaptive(minimum: 72),
                                        spacing: 10
                                    )
                                ],
                                alignment: .leading,
                                spacing: 10
                            ) {
                                ForEach(sortedAttachments) { attachment in
                                    attachmentButton(for: attachment)
                                }
                            }
                        }
                    }

                    if let locationText {
                        detailCard(
                            title: appLanguage.text(korean: "위치", english: "Location"),
                            systemImage: "mappin.and.ellipse"
                        ) {
                            Text(locationText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appLanguage.text(korean: "할 일", english: "Todo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appLanguage.text(korean: "닫기", english: "Close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appLanguage.text(korean: "편집", english: "Edit")) {
                        isPresentingEditor = true
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                TodoEditorSheet(
                    title: appLanguage.text(korean: "할 일 수정", english: "Edit Todo"),
                    initialDraft: TodoDraft(todo: todo),
                    allowsRoutineBulkCreation: false
                ) { draft in
                    onUpdateTodo(draft)
                }
                .presentationDetents([.large])
            }
            .sheet(item: $selectedPhotoPreview) { preview in
                PhotoAttachmentPreviewSheet(preview: preview)
            }
            .sheet(item: $selectedVideoPreview) { preview in
                VideoAttachmentPreviewSheet(preview: preview)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggleCompletion) {
                    Image(
                        systemName: todo.isCompleted
                            ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.system(size: 44))
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todo.isCompleted ? appLanguage.text(korean: "완료 해제", english: "Mark Incomplete") : appLanguage.text(korean: "완료", english: "Complete"))

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(
                            todo.isCompleted ? .secondary : .primary
                        )
                        .strikethrough(todo.isCompleted)

                    Text(todo.isCompleted ? appLanguage.text(korean: "완료됨", english: "Completed") : appLanguage.text(korean: "진행 중", english: "In Progress"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(todo.isCompleted ? .green : .orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (todo.isCompleted ? Color.green : Color.orange)
                                .opacity(0.12),
                            in: Capsule()
                        )
                }

                Spacer()
            }

            if let scheduleText = todo.scheduleSummary(in: appLanguage) {
                Label(scheduleText, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Label(todo.priority.title, systemImage: todo.priority.systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }

    private var locationText: String? {
        guard let latitude = todo.locationLatitude,
            let longitude = todo.locationLongitude
        else {
            return nil
        }

        return
            "\(latitude.formatted(.number.precision(.fractionLength(5)))), \(longitude.formatted(.number.precision(.fractionLength(5))))"
    }

    private func detailCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func attachmentButton(for attachment: TodoAttachment) -> some View {
        let draft = TodoAttachmentDraft(attachment: attachment)

        return Button {
            if let preview = PhotoAttachmentPreview(attachment: draft) {
                selectedPhotoPreview = preview
            } else if let preview = VideoAttachmentPreview(attachment: draft) {
                selectedVideoPreview = preview
            }
        } label: {
            AttachmentThumbnail(attachment: draft)
                .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(attachment.kind == .photo ? appLanguage.text(korean: "사진 크게 보기", english: "View Photo") : appLanguage.text(korean: "동영상 재생", english: "Play Video"))
    }
}

struct TodoRowView: View {
    @Environment(\.appLanguage) private var appLanguage
    let todo: TodoItem
    var isOverdue: Bool = false
    var onToggleContentCheckbox: ((Int) -> Void)?
    var onSelect: (() -> Void)?
    @State private var selectedPhotoPreview: PhotoAttachmentPreview?
    @State private var selectedVideoPreview: VideoAttachmentPreview?

    private var appearance: TodoListRowAppearance {
        TodoListRowAppearance(isCompleted: todo.isCompleted, isOverdue: isOverdue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodoRowMetrics.contentSpacing) {
            Text(todo.title.isEmpty ? appLanguage.text(korean: "제목 없음", english: "Untitled") : todo.title)
                .font(.body)
                .strikethrough(appearance.usesStrikethrough)
                .foregroundStyle(appearance.titleColor)

            if !todo.content.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            {
                RichTodoContentView(content: todo.content, compact: true) {
                    lineIndex in
                    onToggleContentCheckbox?(lineIndex)
                }
            }

            metadataRows

            if let attachments = todo.attachments, !attachments.isEmpty {
                HStack(spacing: 8) {
                    ForEach(
                        attachments.sorted { $0.createdAt < $1.createdAt }
                            .prefix(3)
                    ) { attachment in
                        let draft = TodoAttachmentDraft(attachment: attachment)

                        if attachment.kind == .photo
                            || attachment.kind == .video
                        {
                            Button {
                                if let preview = PhotoAttachmentPreview(
                                    attachment: draft
                                ) {
                                    selectedPhotoPreview = preview
                                } else if let preview = VideoAttachmentPreview(
                                    attachment: draft
                                ) {
                                    selectedVideoPreview = preview
                                }
                            } label: {
                                AttachmentThumbnail(attachment: draft)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                attachment.kind == .photo
                                    ? appLanguage.text(korean: "사진 크게 보기", english: "View Photo") : appLanguage.text(korean: "동영상 재생", english: "Play Video")
                            )
                        } else {
                            AttachmentThumbnail(attachment: draft)
                        }
                    }

                    if attachments.count > 3 {
                        Text("+\(attachments.count - 3)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 56)
                            .background(
                                .secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }
                .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
        .sheet(item: $selectedPhotoPreview) { preview in
            PhotoAttachmentPreviewSheet(preview: preview)
        }
        .sheet(item: $selectedVideoPreview) { preview in
            VideoAttachmentPreviewSheet(preview: preview)
        }
    }

    @ViewBuilder
    private var metadataRows: some View {
        VStack(alignment: .leading, spacing: TodoRowMetrics.metadataRowSpacing) {
            HStack(spacing: TodoRowMetrics.metadataColumnSpacing) {
                if let statusColor = appearance.statusLabelColor,
                    let statusText = appearance.statusLabelTextKey,
                    let statusIcon = appearance.statusLabelIcon
                {
                    statusLabel(
                        appLanguage.text(
                            korean: statusText.korean,
                            english: statusText.english
                        ),
                        systemImage: statusIcon,
                        foreground: statusColor
                    )
                }

                if let scheduleText = todo.scheduleSummary(in: appLanguage) {
                    metadataLabel(scheduleText, systemImage: "calendar")
                }

                metadataLabel(
                    todo.priority.shortTitle,
                    systemImage: todo.priority.systemImage
                )
            }

            if hasSecondaryMetadata {
                HStack(spacing: TodoRowMetrics.metadataColumnSpacing) {
                    if let reminders = todo.reminders, !reminders.isEmpty {
                        metadataLabel(
                            appLanguage.text(korean: "\(reminders.count)개의 미리알림", english: "\(reminders.count) reminders"),
                            systemImage: "bell"
                        )
                    }

                    if let locationText {
                        metadataLabel(
                            locationText,
                            systemImage: "mappin.and.ellipse"
                        )
                    }
                }
            }
        }
    }

    private func statusLabel(
        _ text: String,
        systemImage: String,
        foreground: Color
    ) -> some View {
        CompactIconLabel(
            text: text,
            systemImage: systemImage,
            foreground: foreground
        )
    }

    private var hasSecondaryMetadata: Bool {
        let hasReminders = !(todo.reminders ?? []).isEmpty
        return hasReminders || locationText != nil
    }

    private var locationText: String? {
        guard let latitude = todo.locationLatitude,
            let longitude = todo.locationLongitude
        else {
            return nil
        }

        return
            "\(latitude.formatted(.number.precision(.fractionLength(5)))), \(longitude.formatted(.number.precision(.fractionLength(5))))"
    }

    private func metadataLabel(_ text: String, systemImage: String) -> some View
    {
        CompactIconLabel(text: text, systemImage: systemImage)
    }
}

private struct CompactIconLabel: View {
    let text: String
    let systemImage: String
    var foreground: Color = .secondary

    var body: some View {
        HStack(spacing: TodoRowMetrics.iconTextSpacing) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(foreground)
        .lineLimit(1)
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                TodoItem.self, TodoAttachment.self, Reminder.self,
                AnniversaryItem.self,
            ],
            inMemory: true
        )
}
