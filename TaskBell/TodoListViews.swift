//
//  TodoListViews.swift
//  TaskBell
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DatedTodoListView: View {
    let todos: [TodoItem]
    let onToggleCompletion: (TodoItem) -> Void
    let onToggleContentCheckbox: (TodoItem, Int) -> Void
    let onUpdateTodo: (TodoItem, TodoDraft) -> Void
    let onDelete: (IndexSet, [TodoItem]) -> Void
    let onMoveTodo: (TodoItem, Date, TodoItem?) -> Void

    @State private var selectedTodo: TodoItem?
    @State private var editingTodo: TodoItem?
    @State private var targetedDropDate: Date?

    private let calendar = Calendar.current

    private var timelineSections: [DatedTodoSection] {
        let groupedPairs = todos.flatMap { todo in
            todo.coveredDates(calendar: calendar).map { date in
                (calendar.startOfDay(for: date), todo)
            }
        }

        let grouped = Dictionary(grouping: groupedPairs, by: \.0)

        return
            grouped
            .map { date, pairs in
                let uniqueTodos = Dictionary(
                    pairs.map { ($0.1.persistentModelID, $0.1) }
                ) { first, _ in first }
                .values

                return DatedTodoSection(
                    date: date,
                    title: sectionTitle(for: date),
                    todos:
                        uniqueTodos
                        .sorted { first, second in
                            sortOrder(for: first, on: date)
                                < sortOrder(for: second, on: date)
                        }
                )
            }
            .sorted { $0.date < $1.date }
    }

    private var hasScheduledTodos: Bool {
        !timelineSections.isEmpty
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
                title: "할 일 수정",
                initialDraft: TodoDraft(todo: todo)
            ) { draft in
                onUpdateTodo(todo, draft)
            }
            .presentationDetents([.large])
        }
    }

    private func sectionTitle(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "오늘"
        }

        if calendar.isDateInTomorrow(date) {
            return "내일"
        }

        if calendar.isDateInYesterday(date) {
            return "어제"
        }

        return date.formatted(date: .complete, time: .omitted)
    }

    private func todoSection(_ section: DatedTodoSection) -> some View {
        Section {
            ForEach(section.todos) { todo in
                timelineRow(todo, in: section)
            }
            .onDelete { offsets in
                onDelete(offsets, section.todos)
            }
        } header: {
            DatedTodoSectionHeader(section: section)
                .onDrop(of: [.plainText], isTargeted: nil) { providers in
                    moveDraggedTodo(from: providers, to: section.date)
                }
        }
    }

    private func timelineRow(_ todo: TodoItem, in section: DatedTodoSection) -> some View {
        HStack(spacing: 12) {
            TodoCompletionButton(
                isCompleted: todo.isCompleted,
                action: {
                    onToggleCompletion(todo)
                }
            )

            TodoRowView(
                todo: todo,
                onToggleContentCheckbox: { lineIndex in
                    onToggleContentCheckbox(todo, lineIndex)
                }
            ) {
                selectedTodo = todo
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTodo = todo
        }
        .contextMenu {
            Button {
                editingTodo = todo
            } label: {
                Label("수정", systemImage: "pencil")
            }

            Button(role: .destructive) {
                delete(todo, from: section.todos)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .onDrag {
            NSItemProvider(object: dragIdentifier(for: todo) as NSString)
        }
        .onDrop(
            of: [.plainText],
            isTargeted: Binding(
                get: { targetedDropDate == section.date },
                set: { isTargeted in
                    targetedDropDate = isTargeted ? section.date : nil
                }
            )
        ) { providers in
            moveDraggedTodo(from: providers, to: section.date, before: todo)
        }
    }

    private func delete(_ todo: TodoItem, from visibleTodos: [TodoItem]) {
        guard let index = visibleTodos.firstIndex(where: {
            $0.persistentModelID == todo.persistentModelID
        }) else {
            return
        }

        onDelete(IndexSet(integer: index), visibleTodos)
    }

    private func dragIdentifier(for todo: TodoItem) -> String {
        String(describing: todo.persistentModelID)
    }

    private func sortOrder(for todo: TodoItem, on date: Date) -> Double {
        if todo.timelineSortOrder != 0 {
            return todo.timelineSortOrder
        }

        return (todo.relevantDate(for: date, calendar: calendar) ?? todo.createdAt)
            .timeIntervalSinceReferenceDate
    }

    private func moveDraggedTodo(
        from providers: [NSItemProvider],
        to date: Date,
        before targetTodo: TodoItem? = nil
    ) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            let draggedID: String?
            if let data = item as? Data {
                draggedID = String(data: data, encoding: .utf8)
            } else {
                draggedID = item as? String
            }

            guard let draggedID else {
                return
            }

            Task { @MainActor in
                guard let todo = todos.first(where: { dragIdentifier(for: $0) == draggedID }) else {
                    return
                }

                if let targetTodo,
                   targetTodo.persistentModelID == todo.persistentModelID {
                    targetedDropDate = nil
                    return
                }

                onMoveTodo(todo, date, targetTodo)
                targetedDropDate = nil
            }
        }

        return true
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

private struct DatedTodoSectionHeader: View {
    let section: DatedTodoSection

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)

            Text(section.title)
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
    let selectedDate: Date
    let todos: [TodoItem]
    let completedCount: Int
    let initialDraft: TodoDraft
    let onToggleCompletion: (TodoItem) -> Void
    let onToggleContentCheckbox: (TodoItem, Int) -> Void
    let onUpdateTodo: (TodoItem, TodoDraft) -> Void
    let onDelete: (IndexSet) -> Void
    let onAddTodo: (TodoDraft) -> Void
    let onMoveTodo: (TodoItem, Date, TodoItem?) -> Void

    @State private var isPresentingNewTodoSheet = false
    @State private var selectedTodo: TodoItem?
    @State private var editingTodo: TodoItem?

    private var title: String {
        selectedDate.formatted(
            Date.FormatStyle(date: .complete, time: .omitted)
        )
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
                TodoEditorSheet(title: "새 할 일", initialDraft: initialDraft) {
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
                    title: "할 일 수정",
                    initialDraft: TodoDraft(todo: todo)
                ) { draft in
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
                    TodoCompletionButton(
                        isCompleted: todo.isCompleted,
                        action: {
                            onToggleCompletion(todo)
                        }
                    )

                    TodoRowView(
                        todo: todo,
                        onToggleContentCheckbox: { lineIndex in
                            onToggleContentCheckbox(todo, lineIndex)
                        }
                    ) {
                        selectedTodo = todo
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTodo = todo
                }
                .onDrag {
                    NSItemProvider(object: dragIdentifier(for: todo) as NSString)
                }
                .onDrop(of: [.plainText], isTargeted: nil) { providers in
                    moveDraggedTodo(from: providers, before: todo)
                }
                .contextMenu {
                    Button {
                        editingTodo = todo
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        delete(todo)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: onDelete)
        }
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            moveDraggedTodo(from: providers, before: nil)
        }
        .listStyle(.insetGrouped)
    }

    private func delete(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: {
            $0.persistentModelID == todo.persistentModelID
        }) else {
            return
        }

        onDelete(IndexSet(integer: index))
    }

    private func dragIdentifier(for todo: TodoItem) -> String {
        String(describing: todo.persistentModelID)
    }

    private func moveDraggedTodo(
        from providers: [NSItemProvider],
        before targetTodo: TodoItem?
    ) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            let draggedID: String?
            if let data = item as? Data {
                draggedID = String(data: data, encoding: .utf8)
            } else {
                draggedID = item as? String
            }

            guard let draggedID else {
                return
            }

            Task { @MainActor in
                guard let todo = todos.first(where: { dragIdentifier(for: $0) == draggedID }) else {
                    return
                }

                if let targetTodo,
                   targetTodo.persistentModelID == todo.persistentModelID {
                    return
                }

                onMoveTodo(todo, selectedDate, targetTodo)
            }
        }

        return true
    }
}

private struct TodoCompletionButton: View {
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isCompleted ? .green : .secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleted ? "완료 해제" : "완료")
    }
}

private struct TodoDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let todo: TodoItem
    let onToggleCompletion: () -> Void
    let onToggleContentCheckbox: (Int) -> Void
    let onUpdateTodo: (TodoDraft) -> Void

    @State private var isPresentingEditor = false
    @State private var selectedPhotoPreview: PhotoAttachmentPreview?
    @State private var selectedVideoPreview: VideoAttachmentPreview?

    private var displayTitle: String {
        todo.title.isEmpty ? "제목 없음" : todo.title
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
                        detailCard(title: "내용", systemImage: "text.alignleft") {
                            RichTodoContentView(content: todo.content, compact: false) { lineIndex in
                                onToggleContentCheckbox(lineIndex)
                            }
                        }
                    }

                    if !sortedReminders.isEmpty {
                        detailCard(title: "미리알림", systemImage: "bell.badge") {
                            VStack(spacing: 10) {
                                ForEach(sortedReminders) { reminder in
                                    ReminderRowView(reminder: reminder)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    if !sortedAttachments.isEmpty {
                        detailCard(title: "첨부", systemImage: "paperclip") {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 72), spacing: 10)],
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
                        detailCard(title: "위치", systemImage: "mappin.and.ellipse") {
                            Text(locationText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("할 일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("편집") {
                        isPresentingEditor = true
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                TodoEditorSheet(title: "할 일 수정", initialDraft: TodoDraft(todo: todo)) { draft in
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
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 44))
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todo.isCompleted ? "완료 해제" : "완료")

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .strikethrough(todo.isCompleted)

                    Text(todo.isCompleted ? "완료됨" : "진행 중")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(todo.isCompleted ? .green : .orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((todo.isCompleted ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                }

                Spacer()
            }

            if let scheduleText = todo.scheduleSummary {
                Label(scheduleText, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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

        return "\(latitude.formatted(.number.precision(.fractionLength(5)))), \(longitude.formatted(.number.precision(.fractionLength(5))))"
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
        .accessibilityLabel(attachment.kind == .photo ? "사진 크게 보기" : "동영상 재생")
    }
}

struct TodoRowView: View {
    let todo: TodoItem
    var onToggleContentCheckbox: ((Int) -> Void)?
    var onSelect: (() -> Void)?
    @State private var selectedPhotoPreview: PhotoAttachmentPreview?
    @State private var selectedVideoPreview: VideoAttachmentPreview?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todo.title.isEmpty ? "제목 없음" : todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)

            if !todo.content.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            {
                RichTodoContentView(content: todo.content, compact: true) { lineIndex in
                    onToggleContentCheckbox?(lineIndex)
                }
            }

            if let scheduleText = todo.scheduleSummary {
                Label(scheduleText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let reminders = todo.reminders, !reminders.isEmpty {
                Text("\(reminders.count)개의 미리알림")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let attachments = todo.attachments, !attachments.isEmpty {
                HStack(spacing: 8) {
                    ForEach(attachments.sorted { $0.createdAt < $1.createdAt }.prefix(3)) { attachment in
                        let draft = TodoAttachmentDraft(attachment: attachment)

                        if attachment.kind == .photo || attachment.kind == .video {
                            Button {
                                if let preview = PhotoAttachmentPreview(attachment: draft) {
                                    selectedPhotoPreview = preview
                                } else if let preview = VideoAttachmentPreview(attachment: draft) {
                                    selectedVideoPreview = preview
                                }
                            } label: {
                                AttachmentThumbnail(attachment: draft)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(attachment.kind == .photo ? "사진 크게 보기" : "동영상 재생")
                        } else {
                            AttachmentThumbnail(attachment: draft)
                        }
                    }

                    if attachments.count > 3 {
                        Text("+\(attachments.count - 3)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 56)
                            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 4)
            }

            if let latitude = todo.locationLatitude,
               let longitude = todo.locationLongitude
            {
                Label(
                    "\(latitude.formatted(.number.precision(.fractionLength(5)))), \(longitude.formatted(.number.precision(.fractionLength(5))))",
                    systemImage: "mappin.and.ellipse"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
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
}
