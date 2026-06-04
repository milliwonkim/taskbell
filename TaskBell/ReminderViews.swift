//
//  ReminderViews.swift
//  TaskBell
//

import SwiftUI

struct ReminderRowView: View {
    @Environment(\.appLanguage) private var appLanguage
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
                Text(repeatRule.title(in: appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: isEnabled ? "bell.fill" : "bell.slash")
                Text(deliveryStyle.title(repeatRule: repeatRule, language: appLanguage))
            }
            .font(.caption)
            .foregroundStyle(isEnabled ? Color.secondary : Color.red)
        }
        .padding(.vertical, 4)
    }
}

struct ReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let reminderID: UUID
    let onSave: (ReminderDraft) -> Void

    @State private var fireDate: Date
    @State private var repeatRule: ReminderRepeatRule
    @State private var isVibrationEnabled: Bool
    @State private var isEnabled: Bool

    private var deliveryStyle: ReminderDeliveryStyle {
        .style(includesVibration: isVibrationEnabled)
    }

    private var deliverySummary: String {
        guard isEnabled else {
            return appLanguage.text(korean: "알림 꺼짐", english: "Notifications Off")
        }

        return deliveryStyle.title(repeatRule: repeatRule, language: appLanguage)
    }

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
        _isVibrationEnabled = State(initialValue: initialDraft.deliveryStyle.includesVibration)
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
                Section(appLanguage.text(korean: "날짜", english: "Date")) {
                    DatePicker(
                        appLanguage.text(korean: "알림 날짜", english: "Reminder Date"),
                        selection: $fireDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                }

                Section(appLanguage.text(korean: "시간", english: "Time")) {
                    DatePicker(
                        appLanguage.text(korean: "알림 시간", english: "Reminder Time"),
                        selection: $fireDate,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }

                Section(appLanguage.text(korean: "알림 조합", english: "Notification Options")) {
                    Toggle(appLanguage.text(korean: "푸시 알림", english: "Push Notification"), isOn: $isEnabled)

                    Toggle(appLanguage.text(korean: "진동", english: "Vibration"), isOn: $isVibrationEnabled)
                        .disabled(!isEnabled)

                    Picker(appLanguage.text(korean: "반복", english: "Repeat"), selection: $repeatRule) {
                        ForEach(ReminderRepeatRule.allCases) { repeatRule in
                            Text(repeatRule.title(in: appLanguage)).tag(repeatRule)
                        }
                    }

                    LabeledContent(appLanguage.text(korean: "선택한 조합", english: "Selected Options"), value: deliverySummary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appLanguage.text(korean: "취소", english: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appLanguage.text(korean: "저장", english: "Save")) {
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
