//
//  Reminder+Draft.swift
//  TaskBell
//

import Foundation

extension Reminder {
    convenience init(draft: ReminderDraft, todo: TodoItem) {
        self.init(
            id: draft.id,
            fireDate: draft.fireDate,
            repeatRule: draft.repeatRule,
            deliveryStyle: draft.deliveryStyle,
            isEnabled: draft.isEnabled,
            todo: todo
        )
    }

    func apply(_ draft: ReminderDraft) {
        fireDate = draft.fireDate
        repeatRule = draft.repeatRule
        deliveryStyle = draft.deliveryStyle
        isEnabled = draft.isEnabled
    }
}

extension TodoAttachment {
    convenience init(draft: TodoAttachmentDraft, todo: TodoItem? = nil) {
        self.init(
            id: draft.id,
            kind: draft.kind,
            contentType: draft.contentType,
            fileName: draft.fileName,
            data: draft.data,
            createdAt: draft.createdAt,
            todo: todo
        )
    }

    func apply(_ draft: TodoAttachmentDraft) {
        id = draft.id
        kind = draft.kind
        contentType = draft.contentType
        fileName = draft.fileName
        data = draft.data
        createdAt = draft.createdAt
    }
}
