//
//  AnniversaryViews.swift
//  TaskBell
//

import SwiftUI

struct AnniversaryDraft {
    var title: String
    var targetDate: Date
    var repeatsYearly: Bool

    init(
        title: String = "",
        targetDate: Date = .now,
        repeatsYearly: Bool = true
    ) {
        self.title = title
        self.targetDate = targetDate
        self.repeatsYearly = repeatsYearly
    }

    init(anniversary: AnniversaryItem) {
        self.init(
            title: anniversary.title,
            targetDate: anniversary.targetDate,
            repeatsYearly: anniversary.repeatsYearly
        )
    }
}

struct AnniversaryListView: View {
    @Environment(\.appLanguage) private var appLanguage
    let anniversaries: [AnniversaryItem]
    let onAdd: (AnniversaryDraft) -> Void
    let onUpdate: (AnniversaryItem, AnniversaryDraft) -> Void
    let onDelete: (IndexSet, [AnniversaryItem]) -> Void

    @State private var isPresentingNewAnniversarySheet = false
    @State private var editingAnniversary: AnniversaryItem?

    private let calendar = Calendar.current

    private var sortedAnniversaries: [AnniversaryItem] {
        anniversaries.sorted { first, second in
            let firstDate = first.nextOccurrence(from: .now, calendar: calendar)
            let secondDate = second.nextOccurrence(from: .now, calendar: calendar)

            if firstDate == secondDate {
                return first.createdAt > second.createdAt
            }

            return firstDate < secondDate
        }
    }

    var body: some View {
        Group {
            if anniversaries.isEmpty {
                ContentUnavailableView(
                    appLanguage.text(korean: "등록된 기념일이 없습니다", english: "No Anniversaries"),
                    systemImage: "gift",
                    description: Text(appLanguage.text(korean: "오른쪽 위 + 버튼으로 기념일이나 카운트다운을 추가하세요.", english: "Use the + button at the top right to add an anniversary or countdown."))
                )
            } else {
                List {
                    Section {
                        ForEach(sortedAnniversaries) { anniversary in
                            AnniversaryRowView(anniversary: anniversary) {
                                editingAnniversary = anniversary
                            }
                        }
                        .onDelete { offsets in
                            onDelete(offsets, sortedAnniversaries)
                        }
                    } footer: {
                        Text(appLanguage.text(korean: "반복 기념일은 매년 돌아오는 날짜 기준으로, 카운트다운은 지정한 날짜 기준으로 표시됩니다.", english: "Recurring anniversaries are shown by the date that returns each year, while countdowns are shown by the selected target date."))
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(appLanguage.text(korean: "기념일", english: "Anniversary"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingNewAnniversarySheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(appLanguage.text(korean: "기념일 추가", english: "Add Anniversary"))
            }
        }
        .sheet(isPresented: $isPresentingNewAnniversarySheet) {
            AnniversaryEditorSheet(title: appLanguage.text(korean: "새 기념일", english: "New Anniversary")) { draft in
                onAdd(draft)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingAnniversary) { anniversary in
            AnniversaryEditorSheet(
                title: appLanguage.text(korean: "기념일 수정", english: "Edit Anniversary"),
                initialDraft: AnniversaryDraft(anniversary: anniversary)
            ) { draft in
                onUpdate(anniversary, draft)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct AnniversaryRowView: View {
    @Environment(\.appLanguage) private var appLanguage
    let anniversary: AnniversaryItem
    let onEdit: () -> Void

    private let calendar = Calendar.current

    private var daysText: String {
        let days = anniversary.daysUntilNextOccurrence(from: .now, calendar: calendar)

        if days == 0 {
            return "D-Day"
        }

        if days > 0 {
            return "D-\(days)"
        }

        return "D+\(abs(days))"
    }

    private var nextDateText: String {
        anniversary.nextOccurrence(from: .now, calendar: calendar)
            .formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(daysText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.orange)
                    Text(anniversary.repeatsYearly ? appLanguage.text(korean: "매년", english: "Yearly") : appLanguage.text(korean: "목표일", english: "Target"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(anniversary.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(nextDateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct AnniversaryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage

    let title: String
    let onSave: (AnniversaryDraft) -> Void

    @State private var anniversaryTitle: String
    @State private var targetDate: Date
    @State private var repeatsYearly: Bool

    init(
        title: String,
        initialDraft: AnniversaryDraft = AnniversaryDraft(),
        onSave: @escaping (AnniversaryDraft) -> Void
    ) {
        self.title = title
        self.onSave = onSave
        _anniversaryTitle = State(initialValue: initialDraft.title)
        _targetDate = State(initialValue: initialDraft.targetDate)
        _repeatsYearly = State(initialValue: initialDraft.repeatsYearly)
    }

    private var trimmedTitle: String {
        anniversaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(appLanguage.text(korean: "기념일", english: "Anniversary")) {
                    TextField(appLanguage.text(korean: "이름", english: "Name"), text: $anniversaryTitle)

                    DatePicker(
                        repeatsYearly ? appLanguage.text(korean: "기념일 날짜", english: "Anniversary Date") : appLanguage.text(korean: "목표 날짜", english: "Target Date"),
                        selection: $targetDate,
                        displayedComponents: [.date]
                    )

                    Toggle(appLanguage.text(korean: "매년 반복", english: "Repeat Yearly"), isOn: $repeatsYearly)
                }

                Section {
                    Text(repeatsYearly ? appLanguage.text(korean: "매년 같은 월/일이 돌아올 때까지 D-day로 표시됩니다.", english: "Shown as a D-day until the same month and day returns each year.") : appLanguage.text(korean: "지정한 날짜까지의 카운트다운으로 표시됩니다.", english: "Shown as a countdown to the selected date."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                            AnniversaryDraft(
                                title: trimmedTitle,
                                targetDate: targetDate,
                                repeatsYearly: repeatsYearly
                            )
                        )
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }
}

extension AnniversaryItem {
    func nextOccurrence(from now: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: now)

        guard repeatsYearly else {
            return calendar.startOfDay(for: targetDate)
        }

        let targetComponents = calendar.dateComponents([.month, .day], from: targetDate)
        let currentYear = calendar.component(.year, from: now)
        var nextComponents = DateComponents()
        nextComponents.year = currentYear
        nextComponents.month = targetComponents.month
        nextComponents.day = targetComponents.day

        let occurrenceThisYear = calendar.date(from: nextComponents) ?? targetDate
        if occurrenceThisYear >= startOfToday {
            return occurrenceThisYear
        }

        nextComponents.year = currentYear + 1
        return calendar.date(from: nextComponents) ?? occurrenceThisYear
    }

    func daysUntilNextOccurrence(from now: Date, calendar: Calendar) -> Int {
        let startOfToday = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: nextOccurrence(from: now, calendar: calendar))
        let components = calendar.dateComponents([.day], from: startOfToday, to: target)

        return components.day ?? 0
    }
}
