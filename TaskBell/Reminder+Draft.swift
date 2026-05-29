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
