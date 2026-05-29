//
//  AppTypes.swift
//  TaskBell
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            "시스템 설정"
        case .light:
            "라이트 모드"
        case .dark:
            "다크 모드"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum TodoListGrouping: String, CaseIterable, Identifiable {
    case weekly
    case monthly

    var id: Self { self }

    var title: String {
        switch self {
        case .weekly:
            "주별"
        case .monthly:
            "월별"
        }
    }
}

enum MainTab: Hashable {
    case calendar
    case todos
    case settings
}
