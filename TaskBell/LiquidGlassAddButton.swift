//
//  LiquidGlassAddButton.swift
//  TaskBell
//

import SwiftUI

struct LiquidGlassAddButton: View {
    @Environment(\.appLanguage) private var appLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.headline.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.regular)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .accessibilityLabel(appLanguage.text(korean: "할 일 추가", english: "Add Todo"))
    }
}
