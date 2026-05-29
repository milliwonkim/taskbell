//
//  SettingsView.swift
//  TaskBell
//

import SwiftUI

struct SettingsView: View {
    @Binding var appearance: AppAppearance

    var body: some View {
        Form {
            Section("화면 모드") {
                Picker("표시 방식", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("설정")
    }
}
