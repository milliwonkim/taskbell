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
    @Query(sort: \AnniversaryItem.targetDate, order: .forward) private var anniversaries:
        [AnniversaryItem]
    @AppStorage("appAppearance") private var appAppearanceRawValue =
        AppAppearance.system.rawValue
    @AppStorage("appLanguage") private var appLanguageRawValue =
        AppLanguage.defaultLanguage.rawValue
    @AppStorage("defaultTodoAutoDeletePeriod") private var defaultTodoAutoDeletePeriodRawValue =
        TodoAutoDeletePeriod.oneMonth.rawValue
    @State private var selectedTab = MainTab.calendar
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var isShowingSelectedDayPanel = false
    @State private var isPresentingNewTodoSheet = false
    @State private var expiredTodosPendingDeletion: [TodoItem] = []
    @State private var ignoredExpiredTodoIDs: Set<String> = []

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

    private var selectedDateDraft: TodoDraft {
        TodoDraft(
            autoDeletePeriod: defaultTodoAutoDeletePeriod,
            scheduledStartAt: defaultTodoDate
        )
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

    private var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRawValue) ?? .defaultLanguage }
        nonmutating set { appLanguageRawValue = newValue.rawValue }
    }

    private var defaultTodoAutoDeletePeriod: TodoAutoDeletePeriod {
        get { TodoAutoDeletePeriod(rawValue: defaultTodoAutoDeletePeriodRawValue) ?? .oneMonth }
        nonmutating set { defaultTodoAutoDeletePeriodRawValue = newValue.rawValue }
    }

    private var newTodoDraft: TodoDraft {
        TodoDraft(autoDeletePeriod: defaultTodoAutoDeletePeriod)
    }

    private var expiredTodoAlertTitle: String {
        appLanguage.text(
            korean: "\(expiredTodosPendingDeletion.count)개의 투두가 자동 삭제 대상입니다",
            english: "\(expiredTodosPendingDeletion.count) todos are ready for auto-delete"
        )
    }

    private var expiredTodoAlertMessage: String {
        appLanguage.text(
            korean: "선택한 자동 삭제 기간이 지난 투두입니다. 삭제하면 iCloud와 이 기기에서 모두 삭제되며 되돌릴 수 없습니다.",
            english: "These todos are past the selected auto-delete period. Deleting them removes them from iCloud and this device, and cannot be undone."
        )
    }

    private var calendarNavigationTitle: String {
        appLanguage.formattedMonthYear(for: displayedMonth)
    }

    private var widgetSnapshotSignature: String {
        let todoSignature = todos.map { todo in
            [
                String(describing: todo.persistentModelID),
                todo.title,
                todo.content,
                String(todo.isCompleted),
                todo.scheduleModeRawValue,
                todo.priorityRawValue,
                todo.autoDeletePeriodRawValue,
                String(todo.scheduledStartAt?.timeIntervalSinceReferenceDate ?? 0),
                String(todo.scheduledEndAt?.timeIntervalSinceReferenceDate ?? 0),
                String(todo.createdAt.timeIntervalSinceReferenceDate),
            ].joined(separator: "|")
        }
        .joined(separator: "\n")

        let anniversarySignature = anniversaries.map { anniversary in
            [
                String(describing: anniversary.persistentModelID),
                anniversary.title,
                String(anniversary.targetDate.timeIntervalSinceReferenceDate),
                String(anniversary.repeatsYearly),
                String(anniversary.createdAt.timeIntervalSinceReferenceDate),
            ].joined(separator: "|")
        }
        .joined(separator: "\n")

        return [todoSignature, anniversarySignature].joined(separator: "\n---\n")
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(appLanguage.anniversaryTabTitle, systemImage: "gift", value: .anniversaries) {
                NavigationStack {
                    AnniversaryListView(
                        anniversaries: anniversaries,
                        onAdd: addAnniversary,
                        onUpdate: updateAnniversary,
                        onDelete: deleteAnniversaries
                    )
                }
            }

            Tab(appLanguage.text(korean: "우선순위", english: "Priority"), systemImage: "square.grid.2x2", value: .priority) {
                NavigationStack {
                    PriorityTodoListView(
                        todos: todos,
                        onToggleCompletion: toggleTodoCompletion,
                        onToggleContentCheckbox: toggleTodoContentCheckbox,
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

            Tab(appLanguage.calendarTabTitle, systemImage: "calendar", value: .calendar) {
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

            Tab(appLanguage.todoListTabTitle, systemImage: "checklist", value: .todos) {
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

            Tab(appLanguage.settingsTabTitle, systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView(
                        appearance: Binding(
                            get: { appAppearance },
                            set: { appAppearance = $0 }
                        ),
                        language: Binding(
                            get: { appLanguage },
                            set: { appLanguage = $0 }
                        ),
                        defaultAutoDeletePeriod: Binding(
                            get: { defaultTodoAutoDeletePeriod },
                            set: { defaultTodoAutoDeletePeriod = $0 }
                        )
                    )
                }
            }

        }
        .preferredColorScheme(appAppearance.colorScheme)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .environment(\.appLanguage, appLanguage)
        .sheet(isPresented: $isPresentingNewTodoSheet) {
            TodoEditorSheet(title: appLanguage.text(korean: "새 할 일", english: "New Todo"), initialDraft: newTodoDraft) {
                draft in
                addTodo(draft)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingSelectedDayPanel) {
            SelectedDayTodoSheet(
                selectedDate: selectedDate,
                todos: selectedDayTodos,
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
            await NotificationScheduler.rescheduleAll(todos: todos, language: appLanguage)
            refreshWidgetSnapshot()
            prepareExpiredTodoDeletionAlert()
        }
        .onChange(of: widgetSnapshotSignature) { _, _ in
            refreshWidgetSnapshot()
            prepareExpiredTodoDeletionAlert()
        }
        .onChange(of: appLanguage) { _, _ in
            refreshWidgetSnapshot()
            scheduleAllNotifications()
        }
        .alert(
            expiredTodoAlertTitle,
            isPresented: Binding(
                get: { !expiredTodosPendingDeletion.isEmpty },
                set: { isPresented in
                    if !isPresented {
                        ignorePendingExpiredTodos()
                    }
                }
            )
        ) {
            Button(appLanguage.text(korean: "나중에", english: "Later"), role: .cancel) {
                ignorePendingExpiredTodos()
            }
            Button(appLanguage.text(korean: "영구 삭제", english: "Delete Permanently"), role: .destructive) {
                deleteExpiredTodos()
            }
        } message: {
            Text(expiredTodoAlertMessage)
        }
    }

    private var addTodoToolbarButton: some View {
        Button {
            isPresentingNewTodoSheet = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel(appLanguage.text(korean: "할 일 추가", english: "Add Todo"))
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
                priority: draft.priority,
                autoDeletePeriod: draft.autoDeletePeriod,
                scheduledStartAt: draft.scheduledStartAt,
                scheduledEndAt: draft.scheduledEndAt,
                locationLatitude: draft.locationLatitude,
                locationLongitude: draft.locationLongitude
            )
            modelContext.insert(todo)

            for attachmentDraft in draft.attachments {
                let attachment = TodoAttachment(draft: attachmentDraft, todo: todo)
                modelContext.insert(attachment)
                todo.attachments = (todo.attachments ?? []) + [attachment]
            }

            for reminderDraft in draft.reminders {
                let reminder = Reminder(draft: reminderDraft, todo: todo)
                modelContext.insert(reminder)
                todo.reminders = (todo.reminders ?? []) + [reminder]
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
        todo.priority = draft.priority
        todo.autoDeletePeriod = draft.autoDeletePeriod
        todo.scheduledStartAt = draft.scheduledStartAt
        todo.scheduledEndAt = draft.scheduledEndAt
        todo.locationLatitude = draft.locationLatitude
        todo.locationLongitude = draft.locationLongitude

        let draftAttachmentIDs = Set(draft.attachments.map(\.id))
        let existingAttachments = todo.attachments ?? []
        let existingAttachmentsByID = Dictionary(
            uniqueKeysWithValues: existingAttachments.map { ($0.id, $0) }
        )

        for attachment in existingAttachments
        where !draftAttachmentIDs.contains(attachment.id) {
            modelContext.delete(attachment)
        }
        todo.attachments = (todo.attachments ?? []).filter {
            draftAttachmentIDs.contains($0.id)
        }

        for attachmentDraft in draft.attachments {
            if let attachment = existingAttachmentsByID[attachmentDraft.id] {
                attachment.apply(attachmentDraft)
            } else {
                let attachment = TodoAttachment(draft: attachmentDraft, todo: todo)
                modelContext.insert(attachment)
                todo.attachments = (todo.attachments ?? []) + [attachment]
            }
        }

        let draftIDs = Set(draft.reminders.map(\.id))
        let existingReminders = todo.reminders ?? []
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
        todo.reminders = (todo.reminders ?? []).filter {
            draftIDs.contains($0.id)
        }

        for reminderDraft in draft.reminders {
            if let reminder = existingByID[reminderDraft.id] {
                reminder.apply(reminderDraft)
            } else {
                let reminder = Reminder(draft: reminderDraft, todo: todo)
                modelContext.insert(reminder)
                todo.reminders = (todo.reminders ?? []) + [reminder]
            }
        }
        refreshWidgetSnapshot()
        scheduleNotifications(for: todo)
    }

    private func deleteTodos(offsets: IndexSet, from visibleTodos: [TodoItem]) {
        let deletedIDs = Set(offsets.map { visibleTodos[$0].persistentModelID })

        withAnimation {
            for index in offsets {
                deleteTodo(visibleTodos[index])
            }
        }
        refreshWidgetSnapshot(
            with: todos.filter { !deletedIDs.contains($0.persistentModelID) }
        )
    }

    private func prepareExpiredTodoDeletionAlert(now: Date = .now) {
        let expiredTodos = todos.filter { todo in
            !ignoredExpiredTodoIDs.contains(todoID(todo))
                && todo.autoDeletePeriod.expirationDate(from: todo.createdAt) <= now
        }

        expiredTodosPendingDeletion = expiredTodos
    }

    private func ignorePendingExpiredTodos() {
        ignoredExpiredTodoIDs.formUnion(expiredTodosPendingDeletion.map(todoID))
        expiredTodosPendingDeletion = []
    }

    private func deleteExpiredTodos() {
        let deletedIDs = Set(expiredTodosPendingDeletion.map(\.persistentModelID))

        withAnimation {
            for todo in expiredTodosPendingDeletion {
                deleteTodo(todo)
            }
        }

        ignoredExpiredTodoIDs.subtract(expiredTodosPendingDeletion.map(todoID))
        expiredTodosPendingDeletion = []
        refreshWidgetSnapshot(
            with: todos.filter { !deletedIDs.contains($0.persistentModelID) }
        )
    }

    private func deleteTodo(_ todo: TodoItem) {
        Task {
            await NotificationScheduler.cancelMainDate(for: todo)
        }

        for reminder in todo.reminders ?? [] {
            Task {
                await NotificationScheduler.cancel(reminder)
            }
        }

        modelContext.delete(todo)
    }

    private func todoID(_ todo: TodoItem) -> String {
        String(describing: todo.persistentModelID)
    }

    private func addAnniversary(_ draft: AnniversaryDraft) {
        withAnimation {
            let anniversary = AnniversaryItem(
                title: draft.title,
                targetDate: draft.targetDate,
                repeatsYearly: draft.repeatsYearly
            )
            modelContext.insert(anniversary)
            refreshWidgetSnapshot(withAnniversaries: anniversaries + [anniversary])
        }
    }

    private func updateAnniversary(
        _ anniversary: AnniversaryItem,
        draft: AnniversaryDraft
    ) {
        anniversary.title = draft.title
        anniversary.targetDate = draft.targetDate
        anniversary.repeatsYearly = draft.repeatsYearly
        refreshWidgetSnapshot()
    }

    private func deleteAnniversaries(
        offsets: IndexSet,
        from visibleAnniversaries: [AnniversaryItem]
    ) {
        let deletedIDs = Set(offsets.map { visibleAnniversaries[$0].persistentModelID })

        withAnimation {
            for index in offsets {
                modelContext.delete(visibleAnniversaries[index])
            }
        }

        refreshWidgetSnapshot(
            withAnniversaries: anniversaries.filter {
                !deletedIDs.contains($0.persistentModelID)
            }
        )
    }

    private func refreshWidgetSnapshot(
        with snapshotTodos: [TodoItem]? = nil,
        withAnniversaries snapshotAnniversaries: [AnniversaryItem]? = nil
    ) {
        try? modelContext.save()
        WidgetSnapshotStore.save(
            todos: snapshotTodos ?? todos,
            anniversaries: snapshotAnniversaries ?? anniversaries,
            language: appLanguage
        )
    }

    private func scheduleAllNotifications() {
        Task {
            await NotificationScheduler.rescheduleAll(todos: todos, language: appLanguage)
        }
    }

    private func scheduleNotifications(for todo: TodoItem) {
        Task {
            await NotificationScheduler.scheduleMainDate(for: todo, language: appLanguage)

            for reminder in todo.reminders ?? [] {
                await NotificationScheduler.schedule(
                    reminder,
                    todoTitle: todo.title,
                    todoContent: todo.content,
                    language: appLanguage
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [TodoItem.self, TodoAttachment.self, Reminder.self, AnniversaryItem.self],
            inMemory: true
        )
}
