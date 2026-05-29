//
//  ReminderViews.swift
//  TaskBell
//

import SwiftUI

struct ReminderRowView: View {
    let fireDate: Date
    let repeatRule: ReminderRepeatRule
    let deliveryStyle: ReminderDeliveryStyle
    let isEnabled: Bool

    init(reminder: Reminder) {
        self.fireDate = reminder.fireDate
        self.repeatRule = reminder.repeatRule
        self.deliveryStyle = reminder.deliveryStyle
        self.isEnabled = reminder.isEnabled
    }

    init(reminder: ReminderDraft) {
        self.fireDate = reminder.fireDate
        self.repeatRule = reminder.repeatRule
        self.deliveryStyle = reminder.deliveryStyle
        self.isEnabled = reminder.isEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fireDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                Spacer()
                Text(repeatRule.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: isEnabled ? "bell.fill" : "bell.slash")
                Text(deliveryStyle.title)
            }
            .font(.caption)
            .foregroundStyle(isEnabled ? Color.secondary : Color.red)
        }
        .padding(.vertical, 4)
    }
}

struct ReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let reminderID: UUID
    let onSave: (ReminderDraft) -> Void

    @State private var fireDate: Date
    @State private var repeatRule: ReminderRepeatRule
    @State private var deliveryStyle: ReminderDeliveryStyle
    @State private var isEnabled: Bool

    init(
        title: String,
        initialDraft: ReminderDraft = ReminderDraft(),
        onSave: @escaping (ReminderDraft) -> Void
    ) {
        self.title = title
        self.reminderID = initialDraft.id
        self.onSave = onSave
        _fireDate = State(initialValue: Self.editableFireDate(for: initialDraft))
        _repeatRule = State(initialValue: initialDraft.repeatRule)
        _deliveryStyle = State(initialValue: initialDraft.deliveryStyle)
        _isEnabled = State(initialValue: initialDraft.isEnabled)
    }

    private static func editableFireDate(for draft: ReminderDraft) -> Date {
        if draft.repeatRule == .once, draft.fireDate <= .now {
            return .now.addingTimeInterval(3600)
        }

        return draft.fireDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("날짜") {
                    DatePicker(
                        "알림 날짜",
                        selection: $fireDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                }

                Section("시간") {
                    DatePicker(
                        "알림 시간",
                        selection: $fireDate,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }

                Section("반복") {
                    Picker("반복", selection: $repeatRule) {
                        ForEach(ReminderRepeatRule.allCases) { repeatRule in
                            Text(repeatRule.title).tag(repeatRule)
                        }
                    }
                }

                Section("알림 방식") {
                    Picker("방식", selection: $deliveryStyle) {
                        ForEach(ReminderDeliveryStyle.allCases) { style in
                            VStack(alignment: .leading) {
                                Text(style.title)
                                Text(style.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(style)
                        }
                    }

                    Toggle("활성화", isOn: $isEnabled)
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
                            ReminderDraft(
                                id: reminderID,
                                fireDate: fireDate,
                                repeatRule: repeatRule,
                                deliveryStyle: deliveryStyle,
                                isEnabled: isEnabled
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
