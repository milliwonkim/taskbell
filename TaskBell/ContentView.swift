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

    var body: some View {
        TabView(selection: $selectedTab) {
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
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label("캘린더", systemImage: "calendar")
            }
            .tag(MainTab.calendar)

            NavigationStack {
                DatedTodoListView(
                    todos: todos,
                    onToggleCompletion: toggleTodoCompletion,
                    onUpdateTodo: updateTodo,
                    onDelete: deleteTodos
                )
            }
            .tabItem {
                Label("투두", systemImage: "checklist")
            }
            .tag(MainTab.todos)

            NavigationStack {
                SettingsView(
                    appearance: Binding(
                        get: { appAppearance },
                        set: { appAppearance = $0 }
                    )
                )
            }
            .tabItem {
                Label("설정", systemImage: "gearshape")
            }
            .tag(MainTab.settings)
        }
        .preferredColorScheme(appAppearance.colorScheme)
        .overlay(alignment: .bottomTrailing) {
            addTodoFloatingButton
                .padding(.trailing, 24)
                .padding(.bottom, 82)
        }
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
        }
    }

    private var addTodoFloatingButton: some View {
        LiquidGlassAddButton {
            isPresentingNewTodoSheet = true
        }
    }

    private func toggleTodoCompletion(_ todo: TodoItem) {
        withAnimation {
            todo.isCompleted.toggle()
        }
    }

    private func addTodo(_ draft: TodoDraft) {
        withAnimation {
            let todo = TodoItem(
                title: draft.title,
                content: draft.content,
                isCompleted: draft.isCompleted,
                scheduleMode: draft.scheduleMode,
                scheduledStartAt: draft.scheduledStartAt,
                scheduledEndAt: draft.scheduledEndAt
            )
            modelContext.insert(todo)

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
        }
    }

    private func updateTodo(_ todo: TodoItem, draft: TodoDraft) {
        todo.title = draft.title
        todo.content = draft.content
        todo.isCompleted = draft.isCompleted
        todo.scheduleMode = draft.scheduleMode
        todo.scheduledStartAt = draft.scheduledStartAt
        todo.scheduledEndAt = draft.scheduledEndAt

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
    }

    private func deleteTodos(offsets: IndexSet, from visibleTodos: [TodoItem]) {
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TodoItem.self, Reminder.self], inMemory: true)
}
