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
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let onSave: (TodoDraft) -> Void

    @State private var todoTitle: String
    @State private var content: String
    @State private var isCompleted: Bool
    @State private var isScheduleEnabled: Bool
    @State private var scheduleMode: TodoScheduleMode
    @State private var priority: TodoPriorityQuadrant
    @State private var autoDeletePeriod: TodoAutoDeletePeriod
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
    @State private var selectedPhotoPreview: PhotoAttachmentPreview?
    @State private var selectedVideoPreview: VideoAttachmentPreview?

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
        _priority = State(initialValue: initialDraft.priority)
        _autoDeletePeriod = State(initialValue: initialDraft.autoDeletePeriod)
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
                Section(appLanguage.text(korean: "할 일", english: "Todo")) {
                    TextField(appLanguage.text(korean: "제목", english: "Title"), text: $todoTitle)

                    RichTodoEditor(content: $content)

                    Toggle(appLanguage.text(korean: "완료", english: "Completed"), isOn: $isCompleted)
                }

                Section(appLanguage.text(korean: "우선순위", english: "Priority")) {
                    Picker(appLanguage.text(korean: "분류", english: "Category"), selection: $priority) {
                        ForEach(TodoPriorityQuadrant.allCases) { priority in
                            Label(priority.title, systemImage: priority.systemImage)
                                .tag(priority)
                        }
                    }
                }

                Section {
                    Picker(appLanguage.text(korean: "삭제 시점", english: "Delete After"), selection: $autoDeletePeriod) {
                        ForEach(TodoAutoDeletePeriod.allCases) { period in
                            Text(period.title(in: appLanguage)).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(appLanguage.text(korean: "자동 삭제", english: "Auto-Delete"))
                } footer: {
                    Text(appLanguage.text(korean: "생성일로부터 선택한 기간이 지나면 삭제 대상이 됩니다. 삭제하면 iCloud와 이 기기에서 모두 삭제되며 되돌릴 수 없습니다.", english: "After the selected period from the creation date, this todo becomes eligible for deletion. Deleting it removes it from iCloud and this device, and cannot be undone."))
                }

                Section(appLanguage.text(korean: "언제 할까요", english: "Schedule")) {
                    Toggle(appLanguage.text(korean: "일정 설정", english: "Set Schedule"), isOn: $isScheduleEnabled)

                    if isScheduleEnabled {
                        Picker(appLanguage.text(korean: "선택 방식", english: "Selection Mode"), selection: $scheduleMode) {
                            Text(TodoScheduleMode.singleDay.title(in: appLanguage)).tag(TodoScheduleMode.singleDay)
                            Text(TodoScheduleMode.dateRange.title(in: appLanguage)).tag(TodoScheduleMode.dateRange)
                        }
                        .pickerStyle(.segmented)

                        DatePicker(
                            scheduleMode == .singleDay ? appLanguage.text(korean: "할 날짜와 시간", english: "Todo Date and Time") : appLanguage.text(korean: "시작 날짜와 시간", english: "Start Date and Time"),
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
                                appLanguage.text(korean: "종료 날짜와 시간", english: "End Date and Time"),
                                selection: $scheduledEndAt,
                                in: scheduledStartAt...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }
                }

                Section(appLanguage.text(korean: "마감 전 미리알림", english: "Reminders Before Due")) {
                    if sortedReminders.isEmpty {
                        Text(appLanguage.text(korean: "마감 전 미리알림이 없습니다.", english: "No reminders before due."))
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
                        Label(appLanguage.text(korean: "마감 전 미리알림", english: "Reminder Before Due"), systemImage: "bell.badge")
                    }
                }

                Section(appLanguage.text(korean: "사진 및 동영상", english: "Photos and Videos")) {
                    if sortedAttachments.isEmpty {
                        Text(appLanguage.text(korean: "첨부된 사진이나 동영상이 없습니다.", english: "No attached photos or videos."))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedAttachments) { attachment in
                            AttachmentDraftRow(attachment: attachment) {
                                if let preview = PhotoAttachmentPreview(attachment: attachment) {
                                    selectedPhotoPreview = preview
                                } else if let preview = VideoAttachmentPreview(attachment: attachment) {
                                    selectedVideoPreview = preview
                                }
                            } onDelete: {
                                deleteAttachment(attachment)
                            }
                        }
                    }

                    PhotosPicker(
                        selection: $selectedMediaItems,
                        maxSelectionCount: 10,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label(appLanguage.text(korean: "사진 또는 동영상 추가", english: "Add Photo or Video"), systemImage: "photo.badge.plus")
                    }

                    if isImportingMedia {
                        ProgressView(appLanguage.text(korean: "불러오는 중", english: "Loading"))
                    }
                }

                Section(appLanguage.text(korean: "위치", english: "Location")) {
                    if let selectedLocation {
                        TodoLocationSummaryView(coordinate: selectedLocation)

                        Button(role: .destructive) {
                            locationLatitude = nil
                            locationLongitude = nil
                        } label: {
                            Label(appLanguage.text(korean: "위치 삭제", english: "Remove Location"), systemImage: "mappin.slash")
                        }
                    } else {
                        Text(appLanguage.text(korean: "선택한 위치가 없습니다.", english: "No location selected."))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isPresentingLocationPicker = true
                    } label: {
                        Label(
                            selectedLocation == nil ? appLanguage.text(korean: "지도에서 위치 선택", english: "Select Location on Map") : appLanguage.text(korean: "지도에서 위치 변경", english: "Change Location on Map"),
                            systemImage: "map"
                        )
                    }
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
                            TodoDraft(
                                title: trimmedTitle,
                                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                                isCompleted: isCompleted,
                                scheduleMode: isScheduleEnabled ? scheduleMode : .none,
                                priority: priority,
                                autoDeletePeriod: autoDeletePeriod,
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
                ReminderSheet(title: appLanguage.text(korean: "마감 전 미리알림", english: "Reminder Before Due")) { draft in
                    reminders.append(draft)
                }
                .presentationDetents([.large])
            }
            .sheet(item: $selectedReminder) { reminder in
                ReminderSheet(title: appLanguage.text(korean: "미리알림 편집", english: "Edit Reminder"), initialDraft: reminder) { draft in
                    replaceReminder(draft)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedPhotoPreview) { preview in
                PhotoAttachmentPreviewSheet(preview: preview)
            }
            .sheet(item: $selectedVideoPreview) { preview in
                VideoAttachmentPreviewSheet(preview: preview)
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
    @Environment(\.appLanguage) private var appLanguage
    let attachment: TodoAttachmentDraft
    let onPreview: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if attachment.kind == .photo || attachment.kind == .video {
                Button(action: onPreview) {
                    AttachmentThumbnail(attachment: attachment)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(attachment.kind == .photo ? appLanguage.text(korean: "사진 크게 보기", english: "View Photo") : appLanguage.text(korean: "동영상 재생", english: "Play Video"))
            } else {
                AttachmentThumbnail(attachment: attachment)
            }

            VStack(alignment: .leading, spacing: 3) {
                Label(attachment.kind.title(in: appLanguage), systemImage: attachment.kind == .photo ? "photo" : "video")
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
            .accessibilityLabel(appLanguage.text(korean: "첨부 삭제", english: "Delete Attachment"))
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
