//
//  AppTypes.swift
//  TaskBell
//

import Foundation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .system:
            language.text(korean: "시스템 설정", english: "System")
        case .light:
            language.text(korean: "라이트 모드", english: "Light Mode")
        case .dark:
            language.text(korean: "다크 모드", english: "Dark Mode")
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

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: Self { self }

    static var defaultLanguage: Self {
        let locale = Locale.current
        let languageCode = locale.language.languageCode?.identifier
        let regionCode = locale.region?.identifier

        return languageCode == "ko" || regionCode == "KR" ? .korean : .english
    }

    var title: String {
        switch self {
        case .korean:
            "한국어"
        case .english:
            "English"
        }
    }

    var localeIdentifier: String {
        rawValue
    }

    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    func calendarWithLocale(_ base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.locale = locale
        return calendar
    }

    func formattedMonthYear(for date: Date, calendar: Calendar = .current) -> String {
        let calendar = calendarWithLocale(calendar)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        switch self {
        case .korean:
            return "\(year)년 \(month)월"
        case .english:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            return formatter.string(from: date)
        }
    }

    func formattedListDayTitle(for date: Date, calendar: Calendar = .current) -> String {
        let calendar = calendarWithLocale(calendar)

        if calendar.isDateInToday(date) {
            return text(korean: "오늘", english: "Today")
        }

        if calendar.isDateInTomorrow(date) {
            return text(korean: "내일", english: "Tomorrow")
        }

        if calendar.isDateInYesterday(date) {
            return text(korean: "어제", english: "Yesterday")
        }

        return formattedLongDate(date, calendar: calendar)
    }

    func formattedLongDate(_ date: Date, calendar: Calendar = .current) -> String {
        let calendar = calendarWithLocale(calendar)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        switch self {
        case .korean:
            return "\(year)년 \(month)월 \(day)일"
        case .english:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    func formattedScheduleDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func veryShortWeekdaySymbols(calendar: Calendar = .current) -> [String] {
        let calendar = calendarWithLocale(calendar)
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    func text(korean: String, english: String) -> String {
        switch self {
        case .korean:
            korean
        case .english:
            english
        }
    }

    var anniversaryTabTitle: String {
        switch self {
        case .korean:
            "기념일"
        case .english:
            "Anniversary"
        }
    }

    var calendarTabTitle: String {
        switch self {
        case .korean:
            "캘린더"
        case .english:
            "Calendar"
        }
    }

    var todoListTabTitle: String {
        switch self {
        case .korean:
            "투두리스트"
        case .english:
            "Todo List"
        }
    }

    var settingsTabTitle: String {
        switch self {
        case .korean:
            "설정"
        case .english:
            "Settings"
        }
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.defaultLanguage
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

enum MainTab: Hashable {
    case calendar
    case todos
    case anniversaries
    case priority
    case settings
}
