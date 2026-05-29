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
                        onUpdateTodo: updateTodo,
                        onDelete: deleteTodos
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
                onUpdateTodo: updateTodo,
                onDelete: { offsets in
                    deleteTodos(offsets: offsets, from: selectedDayTodos)
                },
                onAddTodo: addTodo
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

                Task {
                    await NotificationScheduler.schedule(
                        reminder,
                        todoTitle: todo.title,
                        todoContent: todo.content
                    )
                }
            }

            refreshWidgetSnapshot(with: todos + [todo])
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
                Task {
                    await NotificationScheduler.schedule(
                        reminder,
                        todoTitle: todo.title,
                        todoContent: todo.content
                    )
                }
            } else {
                let reminder = Reminder(draft: reminderDraft, todo: todo)
                modelContext.insert(reminder)
                todo.reminders.append(reminder)

                Task {
                    await NotificationScheduler.schedule(
                        reminder,
                        todoTitle: todo.title,
                        todoContent: todo.content
                    )
                }
            }
        }
        refreshWidgetSnapshot()
    }

    private func deleteTodos(offsets: IndexSet, from visibleTodos: [TodoItem]) {
        let deletedIDs = Set(offsets.map { visibleTodos[$0].persistentModelID })

        withAnimation {
            for index in offsets {
                let todo = visibleTodos[index]

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
}

#Preview {
    ContentView()
        .modelContainer(
            for: [TodoItem.self, TodoAttachment.self, Reminder.self],
            inMemory: true
        )
}
