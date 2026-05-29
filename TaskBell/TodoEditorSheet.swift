//
//  TodoEditorSheet.swift
//  TaskBell
//

import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
    @State private var attachments: [TodoAttachmentDraft]
    @State private var selectedMediaItems: [PhotosPickerItem] = []
    @State private var isImportingMedia = false
    @State private var locationLatitude: Double?
    @State private var locationLongitude: Double?
    @State private var isPresentingLocationPicker = false
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
        _attachments = State(initialValue: initialDraft.attachments)
        _locationLatitude = State(initialValue: initialDraft.locationLatitude)
        _locationLongitude = State(initialValue: initialDraft.locationLongitude)
        _reminders = State(initialValue: initialDraft.reminders)
    }

    private var trimmedTitle: String {
        todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sortedReminders: [ReminderDraft] {
        reminders.sorted { $0.fireDate < $1.fireDate }
    }

    private var sortedAttachments: [TodoAttachmentDraft] {
        attachments.sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedLocation: TodoLocationCoordinate? {
        guard let locationLatitude, let locationLongitude else {
            return nil
        }

        return TodoLocationCoordinate(
            latitude: locationLatitude,
            longitude: locationLongitude
        )
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

                Section("사진 및 동영상") {
                    if sortedAttachments.isEmpty {
                        Text("첨부된 사진이나 동영상이 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedAttachments) { attachment in
                            AttachmentDraftRow(attachment: attachment) {
                                deleteAttachment(attachment)
                            }
                        }
                    }

                    PhotosPicker(
                        selection: $selectedMediaItems,
                        maxSelectionCount: 10,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label("사진 또는 동영상 추가", systemImage: "photo.badge.plus")
                    }

                    if isImportingMedia {
                        ProgressView("불러오는 중")
                    }
                }

                Section("위치") {
                    if let selectedLocation {
                        TodoLocationSummaryView(coordinate: selectedLocation)

                        Button(role: .destructive) {
                            locationLatitude = nil
                            locationLongitude = nil
                        } label: {
                            Label("위치 삭제", systemImage: "mappin.slash")
                        }
                    } else {
                        Text("선택한 위치가 없습니다.")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isPresentingLocationPicker = true
                    } label: {
                        Label(
                            selectedLocation == nil ? "지도에서 위치 선택" : "지도에서 위치 변경",
                            systemImage: "map"
                        )
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
                                locationLatitude: locationLatitude,
                                locationLongitude: locationLongitude,
                                attachments: attachments.sorted { $0.createdAt < $1.createdAt },
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
            .sheet(isPresented: $isPresentingLocationPicker) {
                TodoLocationPickerSheet(initialCoordinate: selectedLocation) {
                    coordinate in
                    locationLatitude = coordinate.latitude
                    locationLongitude = coordinate.longitude
                }
            }
            .onChange(of: selectedMediaItems) { _, newItems in
                Task {
                    await importMedia(from: newItems)
                    selectedMediaItems = []
                }
            }
        }
    }

    private func importMedia(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            return
        }

        isImportingMedia = true
        defer { isImportingMedia = false }

        for item in items {
            guard let contentType = item.supportedContentTypes.first(where: {
                $0.conforms(to: .image) || $0.conforms(to: .movie)
            }) else {
                continue
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    continue
                }

                let kind: TodoAttachmentKind = contentType.conforms(to: .movie) ? .video : .photo
                let fileExtension = contentType.preferredFilenameExtension ?? (kind == .photo ? "jpg" : "mov")
                attachments.append(
                    TodoAttachmentDraft(
                        kind: kind,
                        contentType: contentType.identifier,
                        fileName: "\(kind.rawValue)-\(UUID().uuidString).\(fileExtension)",
                        data: data
                    )
                )
            } catch {
                continue
            }
        }
    }

    private func deleteAttachment(_ attachment: TodoAttachmentDraft) {
        attachments.removeAll { $0.id == attachment.id }
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

private struct AttachmentDraftRow: View {
    let attachment: TodoAttachmentDraft
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AttachmentThumbnail(attachment: attachment)

            VStack(alignment: .leading, spacing: 3) {
                Label(attachment.kind.title, systemImage: attachment.kind == .photo ? "photo" : "video")
                    .font(.subheadline.weight(.semibold))

                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.data.count), countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("첨부 삭제")
        }
    }
}

struct AttachmentThumbnail: View {
    let attachment: TodoAttachmentDraft

    var body: some View {
        Group {
            if attachment.kind == .photo, let image = UIImage(data: attachment.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.18))
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
