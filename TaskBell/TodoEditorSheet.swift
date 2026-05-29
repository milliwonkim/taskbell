//
//  TodoEditorSheet.swift
//  TaskBell
//

import SwiftUI

struct TodoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onSave: (TodoDraft) -> Void

    @State private var todoTitle: String
    @State private var content: String
    @State private var isCompleted: Bool
    @State private var isScheduleEnabled: Bool
    @State private var scheduleMode: TodoScheduleMode
    @State private var scheduledStartAt: Date
    @State private var scheduledEndAt: Date
    @State private var reminders: [ReminderDraft]
    @State private var isPresentingNewReminderSheet = false
    @State private var selectedReminder: ReminderDraft?

    init(
        title: String,
        initialDraft: TodoDraft = TodoDraft(),
        onSave: @escaping (TodoDraft) -> Void
    ) {
        self.title = title
        self.onSave = onSave
        _todoTitle = State(initialValue: initialDraft.title)
        _content = State(initialValue: initialDraft.content)
        _isCompleted = State(initialValue: initialDraft.isCompleted)
        _isScheduleEnabled = State(initialValue: initialDraft.scheduleMode != .none)
        _scheduleMode = State(initialValue: initialDraft.scheduleMode == .dateRange ? .dateRange : .singleDay)
        _scheduledStartAt = State(initialValue: initialDraft.scheduledStartAt ?? .now)
        _scheduledEndAt = State(initialValue: initialDraft.scheduledEndAt ?? initialDraft.scheduledStartAt?.addingTimeInterval(3600) ?? .now.addingTimeInterval(3600))
        _reminders = State(initialValue: initialDraft.reminders)
    }

    private var trimmedTitle: String {
        todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sortedReminders: [ReminderDraft] {
        reminders.sorted { $0.fireDate < $1.fireDate }
    }

    private var normalizedScheduleEndAt: Date {
        max(scheduledEndAt, scheduledStartAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("할 일") {
                    TextField("제목", text: $todoTitle)

                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("내용")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }

                        TextEditor(text: $content)
                            .frame(minHeight: 140)
                    }

                    Toggle("완료", isOn: $isCompleted)
                }

                Section("언제 할까요") {
                    Toggle("일정 설정", isOn: $isScheduleEnabled)

                    if isScheduleEnabled {
                        Picker("선택 방식", selection: $scheduleMode) {
                            Text(TodoScheduleMode.singleDay.title).tag(TodoScheduleMode.singleDay)
                            Text(TodoScheduleMode.dateRange.title).tag(TodoScheduleMode.dateRange)
                        }
                        .pickerStyle(.segmented)

                        DatePicker(
                            scheduleMode == .singleDay ? "할 날짜와 시간" : "시작 날짜와 시간",
                            selection: $scheduledStartAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .onChange(of: scheduledStartAt) { _, newStartAt in
                            if scheduledEndAt < newStartAt {
                                scheduledEndAt = newStartAt
                            }
                        }

                        if scheduleMode == .dateRange {
                            DatePicker(
                                "종료 날짜와 시간",
                                selection: $scheduledEndAt,
                                in: scheduledStartAt...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }
                }

                Section("미리알림") {
                    if sortedReminders.isEmpty {
                        Text("미리알림이 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedReminders) { reminder in
                            Button {
                                selectedReminder = reminder
                            } label: {
                                ReminderRowView(reminder: reminder)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteReminders)
                    }

                    Button {
                        isPresentingNewReminderSheet = true
                    } label: {
                        Label("미리알림 추가", systemImage: "bell.badge")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(
                            TodoDraft(
                                title: trimmedTitle,
                                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                                isCompleted: isCompleted,
                                scheduleMode: isScheduleEnabled ? scheduleMode : .none,
                                scheduledStartAt: isScheduleEnabled ? scheduledStartAt : nil,
                                scheduledEndAt: isScheduleEnabled && scheduleMode == .dateRange ? normalizedScheduleEndAt : nil,
                                reminders: reminders.sorted { $0.fireDate < $1.fireDate }
                            )
                        )
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
            .sheet(isPresented: $isPresentingNewReminderSheet) {
                ReminderSheet(title: "미리알림 추가") { draft in
                    reminders.append(draft)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedReminder) { reminder in
                ReminderSheet(title: "미리알림 편집", initialDraft: reminder) { draft in
                    replaceReminder(draft)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func replaceReminder(_ draft: ReminderDraft) {
        guard let index = reminders.firstIndex(where: { $0.id == draft.id }) else {
            return
        }

        reminders[index] = draft
    }

    private func deleteReminders(offsets: IndexSet) {
        let sorted = sortedReminders
        let idsToDelete = offsets.map { sorted[$0].id }
        reminders.removeAll { idsToDelete.contains($0.id) }
    }
}
