//
//  ContentView.swift
//  TaskBell
//
//  Created by 김기원 on 5/29/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todos:
        [TodoItem]
    @AppStorage("appAppearance") private var appAppearanceRawValue =
        AppAppearance.system.rawValue
    @State private var selectedTab = MainTab.calendar
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var isShowingSelectedDayPanel = false
    @State private var isPresentingNewTodoSheet = false

    private var selectedDayTodos: [TodoItem] {
        let calendar = Calendar.current

        return
            todos
            .filter { $0.isScheduled(on: selectedDate, calendar: calendar) }
            .sorted { first, second in
                let firstDate =
                    first.relevantDate(for: selectedDate, calendar: calendar)
                    ?? first.createdAt
                let secondDate =
                    second.relevantDate(for: selectedDate, calendar: calendar)
                    ?? second.createdAt

                if firstDate == secondDate {
                    return first.createdAt > second.createdAt
                }

                return firstDate < secondDate
            }
    }

    private var selectedDayCompletedCount: Int {
        selectedDayTodos.filter(\.isCompleted).count
    }

    private var selectedDateDraft: TodoDraft {
        TodoDraft(scheduledStartAt: defaultTodoDate)
    }

    private var defaultTodoDate: Date {
        let calendar = Calendar.current

        if calendar.isDateInToday(selectedDate) {
            return .now
        }

        return calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate
    }

    private var appAppearance: AppAppearance {
        get { AppAppearance(rawValue: appAppearanceRawValue) ?? .system }
        nonmutating set { appAppearanceRawValue = newValue.rawValue }
    }

    private var calendarNavigationTitle: String {
        displayedMonth.formatted(.dateTime.year().month(.wide))
    }

    private var widgetSnapshotSignature: String {
        todos.map { todo in
            [
                String(describing: todo.persistentModelID),
                todo.title,
                todo.content,
                String(todo.isCompleted),
                todo.scheduleModeRawValue,
                String(todo.scheduledStartAt?.timeIntervalSinceReferenceDate ?? 0),
                String(todo.scheduledEndAt?.timeIntervalSinceReferenceDate ?? 0),
                String(todo.createdAt.timeIntervalSinceReferenceDate),
            ].joined(separator: "|")
        }
        .joined(separator: "\n")
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                NavigationStack {
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()

                        MonthCalendarView(
                            selectedDate: $selectedDate,
                            displayedMonth: $displayedMonth,
                            todos: todos
                        ) { date in
                            withAnimation(.snappy) {
                                selectedDate = date
                                displayedMonth = date
                                isShowingSelectedDayPanel = true
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .navigationTitle(calendarNavigationTitle)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            addTodoToolbarButton
                        }
                    }
                }
            }

            Tab("TodoList", systemImage: "checklist", value: .todos) {
                NavigationStack {
                    DatedTodoListView(
                        todos: todos,
                        onToggleCompletion: toggleTodoCompletion,
                        onToggleContentCheckbox: toggleTodoContentCheckbox,
                        onUpdateTodo: updateTodo,
                        onDelete: deleteTodos,
                        onMoveTodo: moveTodo
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            addTodoToolbarButton
                        }
                    }
                }
            }

            Tab("Setting", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView(
                        appearance: Binding(
                            get: { appAppearance },
                            set: { appAppearance = $0 }
                        )
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            addTodoToolbarButton
                        }
                    }
                }
            }

        }
        .preferredColorScheme(appAppearance.colorScheme)
        .sheet(isPresented: $isPresentingNewTodoSheet) {
            TodoEditorSheet(title: "새 할 일", initialDraft: selectedDateDraft) {
                draft in
                addTodo(draft)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingSelectedDayPanel) {
            SelectedDayTodoSheet(
                selectedDate: selectedDate,
                todos: selectedDayTodos,
                completedCount: selectedDayCompletedCount,
                initialDraft: selectedDateDraft,
                onToggleCompletion: toggleTodoCompletion,
                onToggleContentCheckbox: toggleTodoContentCheckbox,
                onUpdateTodo: updateTodo,
                onDelete: { offsets in
                    deleteTodos(offsets: offsets, from: selectedDayTodos)
                },
                onAddTodo: addTodo,
                onMoveTodo: moveTodo
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            _ = await NotificationScheduler.requestAuthorization()
            await NotificationScheduler.rescheduleAll(todos: todos)
            refreshWidgetSnapshot()
        }
        .onChange(of: widgetSnapshotSignature) { _, _ in
            refreshWidgetSnapshot()
        }
    }

    private var addTodoToolbarButton: some View {
        Button {
            isPresentingNewTodoSheet = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("할 일 추가")
    }

    private func toggleTodoCompletion(_ todo: TodoItem) {
        withAnimation {
            todo.isCompleted.toggle()
        }
        refreshWidgetSnapshot()
    }

    private func toggleTodoContentCheckbox(_ todo: TodoItem, lineIndex: Int) {
        withAnimation {
            todo.content = RichTodoContentFormatter.toggledCheckbox(
                in: todo.content,
                lineIndex: lineIndex
            )
        }
        refreshWidgetSnapshot()
    }

    private func moveTodo(_ todo: TodoItem, date: Date, before targetTodo: TodoItem?) {
        var draft = TodoDraft(todo: todo)
        let calendar = Calendar.current
        let sourceStart = draft.scheduledStartAt ?? todo.createdAt
        let targetStart = calendar.date(
            bySettingHour: calendar.component(.hour, from: sourceStart),
            minute: calendar.component(.minute, from: sourceStart),
            second: calendar.component(.second, from: sourceStart),
            of: date
        ) ?? date

        if draft.scheduleMode == .none {
            draft.scheduleMode = .singleDay
        }

        if draft.scheduleMode == .dateRange, let sourceEnd = draft.scheduledEndAt {
            let duration = sourceEnd.timeIntervalSince(sourceStart)
            draft.scheduledEndAt = targetStart.addingTimeInterval(max(duration, 0))
        }

        draft.scheduledStartAt = targetStart
        updateTodo(todo, draft: draft)
        todo.timelineSortOrder = sortOrder(forMoving: todo, to: date, before: targetTodo)
        refreshWidgetSnapshot()
    }

    private func sortOrder(
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

    private func sortOrder(
        forMoving todo: TodoItem,
        to date: Date,
        before targetTodo: TodoItem?
    ) -> Double {
        let calendar = Calendar.current
        let destinationTodos = todos
            .filter { candidate in
                candidate.persistentModelID != todo.persistentModelID
                    && candidate.isScheduled(on: date, calendar: calendar)
            }
            .sorted {
                sortOrder(for: $0, on: date, calendar: calendar)
                    < sortOrder(for: $1, on: date, calendar: calendar)
            }

        guard let targetTodo,
              let targetIndex = destinationTodos.firstIndex(where: {
                  $0.persistentModelID == targetTodo.persistentModelID
              })
        else {
            let lastOrder = destinationTodos
                .last
                .map { sortOrder(for: $0, on: date, calendar: calendar) }
            return (lastOrder ?? date.timeIntervalSinceReferenceDate) + 1
        }

        let targetOrder = sortOrder(for: targetTodo, on: date, calendar: calendar)
        guard targetIndex > 0 else {
            return targetOrder - 1
        }

        let previousOrder = sortOrder(
            for: destinationTodos[targetIndex - 1],
            on: date,
            calendar: calendar
        )
        return (previousOrder + targetOrder) / 2
    }

    private func addTodo(_ draft: TodoDraft) {
        withAnimation {
            let todo = TodoItem(
                title: draft.title,
                content: draft.content,
                isCompleted: draft.isCompleted,
                scheduleMode: draft.scheduleMode,
                scheduledStartAt: draft.scheduledStartAt,
                scheduledEndAt: draft.scheduledEndAt,
                locationLatitude: draft.locationLatitude,
                locationLongitude: draft.locationLongitude
            )
            modelContext.insert(todo)

            for attachmentDraft in draft.attachments {
                let attachment = TodoAttachment(draft: attachmentDraft, todo: todo)
                modelContext.insert(attachment)
                todo.attachments.append(attachment)
            }

            for reminderDraft in draft.reminders {
                let reminder = Reminder(draft: reminderDraft, todo: todo)
                modelContext.insert(reminder)
                todo.reminders.append(reminder)
            }

            refreshWidgetSnapshot(with: todos + [todo])
            scheduleNotifications(for: todo)
        }
    }

    private func updateTodo(_ todo: TodoItem, draft: TodoDraft) {
        todo.title = draft.title
        todo.content = draft.content
        todo.isCompleted = draft.isCompleted
        todo.scheduleMode = draft.scheduleMode
        todo.scheduledStartAt = draft.scheduledStartAt
        todo.scheduledEndAt = draft.scheduledEndAt
        todo.locationLatitude = draft.locationLatitude
        todo.locationLongitude = draft.locationLongitude

        let draftAttachmentIDs = Set(draft.attachments.map(\.id))
        let existingAttachments = todo.attachments
        let existingAttachmentsByID = Dictionary(
            uniqueKeysWithValues: existingAttachments.map { ($0.id, $0) }
        )

        for attachment in existingAttachments
        where !draftAttachmentIDs.contains(attachment.id) {
            modelContext.delete(attachment)
        }
        todo.attachments.removeAll { !draftAttachmentIDs.contains($0.id) }

        for attachmentDraft in draft.attachments {
            if let attachment = existingAttachmentsByID[attachmentDraft.id] {
                attachment.apply(attachmentDraft)
            } else {
                let attachment = TodoAttachment(draft: attachmentDraft, todo: todo)
                modelContext.insert(attachment)
                todo.attachments.append(attachment)
            }
        }

        let draftIDs = Set(draft.reminders.map(\.id))
        let existingReminders = todo.reminders
        let existingByID = Dictionary(
            uniqueKeysWithValues: existingReminders.map { ($0.id, $0) }
        )

        for reminder in existingReminders where !draftIDs.contains(reminder.id)
        {
            Task {
                await NotificationScheduler.cancel(reminder)
            }
            modelContext.delete(reminder)
        }
        todo.reminders.removeAll { !draftIDs.contains($0.id) }

        for reminderDraft in draft.reminders {
            if let reminder = existingByID[reminderDraft.id] {
                reminder.apply(reminderDraft)
            } else {
                let reminder = Reminder(draft: reminderDraft, todo: todo)
                modelContext.insert(reminder)
                todo.reminders.append(reminder)
            }
        }
        refreshWidgetSnapshot()
        scheduleNotifications(for: todo)
    }

    private func deleteTodos(offsets: IndexSet, from visibleTodos: [TodoItem]) {
        let deletedIDs = Set(offsets.map { visibleTodos[$0].persistentModelID })

        withAnimation {
            for index in offsets {
                let todo = visibleTodos[index]

                Task {
                    await NotificationScheduler.cancelMainDate(for: todo)
                }

                for reminder in todo.reminders {
                    Task {
                        await NotificationScheduler.cancel(reminder)
                    }
                }

                modelContext.delete(todo)
            }
        }
        refreshWidgetSnapshot(
            with: todos.filter { !deletedIDs.contains($0.persistentModelID) }
        )
    }

    private func refreshWidgetSnapshot(with snapshotTodos: [TodoItem]? = nil) {
        try? modelContext.save()
        WidgetSnapshotStore.save(todos: snapshotTodos ?? todos)
    }

    private func scheduleNotifications(for todo: TodoItem) {
        Task {
            await NotificationScheduler.scheduleMainDate(for: todo)

            for reminder in todo.reminders {
                await NotificationScheduler.schedule(
                    reminder,
                    todoTitle: todo.title,
                    todoContent: todo.content
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [TodoItem.self, TodoAttachment.self, Reminder.self],
            inMemory: true
        )
}
