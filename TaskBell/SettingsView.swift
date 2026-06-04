//
//  SettingsView.swift
//  TaskBell
//

import SwiftUI
import CloudKit

struct SettingsView: View {
    @Environment(\.appLanguage) private var appLanguage
    @Binding var appearance: AppAppearance
    @Binding var language: AppLanguage
    @Binding var defaultAutoDeletePeriod: TodoAutoDeletePeriod
    @State private var iCloudStatus = ICloudSyncStatus.checking

    private let iCloudContainerIdentifier = "iCloud.kiwonkim.TaskBell"

    var body: some View {
        Form {
            Section(appLanguage.text(korean: "화면 모드", english: "Appearance")) {
                Picker(appLanguage.text(korean: "표시 방식", english: "Display Mode"), selection: $appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title(in: appLanguage)).tag(appearance)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Picker(appLanguage.text(korean: "언어 선택", english: "Language"), selection: $language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(appLanguage.text(korean: "언어", english: "Language"))
            } footer: {
                Text(appLanguage.text(korean: "처음 실행할 때 기기 언어가 한국어이거나 지역이 한국이면 한국어가 기본값으로 선택됩니다. 그 외에는 영어가 기본값입니다.", english: "On first launch, Korean is selected by default when the device language is Korean or the region is Korea. Otherwise, English is selected by default."))
            }

            Section {
                Picker(appLanguage.text(korean: "기본 삭제 기간", english: "Default Delete Period"), selection: $defaultAutoDeletePeriod) {
                    ForEach(TodoAutoDeletePeriod.allCases) { period in
                        Text(period.title(in: appLanguage)).tag(period)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(appLanguage.text(korean: "투두 자동 삭제", english: "Todo Auto-Delete"))
            } footer: {
                Text(appLanguage.text(korean: "새 투두를 만들 때 기본으로 적용되는 기간입니다. 각 투두 생성/수정 화면에서 따로 변경할 수 있습니다. 삭제된 투두는 iCloud와 이 기기에서 모두 삭제되며 되돌릴 수 없습니다.", english: "This period is applied by default when creating a new todo. You can change it for each todo in the create/edit screen. Deleted todos are removed from iCloud and this device, and cannot be undone."))
            }

            Section {
                NavigationLink {
                    ICloudDetailView(
                        status: iCloudStatus,
                        containerIdentifier: iCloudContainerIdentifier,
                        onRefresh: refreshICloudStatus
                    )
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: iCloudStatus.systemImage)
                            .foregroundStyle(iCloudStatus.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(appLanguage.text(korean: "iCloud 연동", english: "iCloud Sync"))
                            Text(iCloudStatus.summary(in: appLanguage))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(iCloudStatus.badgeTitle(in: appLanguage))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(iCloudStatus.tint)
                    }
                }
            } header: {
                Text("iCloud")
            } footer: {
                Text(appLanguage.text(korean: "할 일과 미리알림은 사용자의 개인 iCloud 데이터베이스에 저장되어 같은 Apple 계정의 기기와 동기화됩니다.", english: "Todos and reminders are saved in your private iCloud database and sync across devices using the same Apple account."))
            }
        }
        .navigationTitle(appLanguage.text(korean: "설정", english: "Settings"))
        .task {
            await refreshICloudStatus()
        }
    }

    @MainActor
    private func refreshICloudStatus() async {
        iCloudStatus = .checking

        do {
            let accountStatus = try await CKContainer(identifier: iCloudContainerIdentifier).accountStatus()
            iCloudStatus = .resolved(accountStatus, checkedAt: .now)
        } catch {
            iCloudStatus = .failed(error.localizedDescription, checkedAt: .now)
        }
    }
}

private struct ICloudDetailView: View {
    @Environment(\.appLanguage) private var appLanguage
    let status: ICloudSyncStatus
    let containerIdentifier: String
    let onRefresh: () async -> Void

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: status.systemImage)
                        .font(.title2)
                        .foregroundStyle(status.tint)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.title(in: appLanguage))
                            .font(.headline)
                        Text(status.detail(in: appLanguage))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(appLanguage.text(korean: "연동 정보", english: "Sync Information")) {
                LabeledContent(appLanguage.text(korean: "상태", english: "Status"), value: status.badgeTitle(in: appLanguage))
                LabeledContent(appLanguage.text(korean: "CloudKit 데이터베이스", english: "CloudKit Database"), value: "Private")
                LabeledContent(appLanguage.text(korean: "컨테이너", english: "Container"), value: containerIdentifier)

                if let checkedAt = status.checkedAt {
                    LabeledContent(appLanguage.text(korean: "마지막 확인", english: "Last Checked"), value: checkedAt.formatted(date: .abbreviated, time: .standard))
                }
            }

            Section(appLanguage.text(korean: "상세 설명", english: "Details")) {
                Text(status.explanation(in: appLanguage))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task {
                        await onRefresh()
                    }
                } label: {
                    Label(appLanguage.text(korean: "상태 다시 확인", english: "Check Status Again"), systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationTitle(appLanguage.text(korean: "iCloud 상세정보", english: "iCloud Details"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum ICloudSyncStatus: Equatable {
    case checking
    case resolved(CKAccountStatus, checkedAt: Date)
    case failed(String, checkedAt: Date)

    func title(in language: AppLanguage) -> String {
        switch self {
        case .checking:
            language.text(korean: "iCloud 상태 확인 중", english: "Checking iCloud Status")
        case .resolved(.available, _):
            language.text(korean: "iCloud와 연동됨", english: "Synced with iCloud")
        case .resolved(.noAccount, _):
            language.text(korean: "iCloud 계정 없음", english: "No iCloud Account")
        case .resolved(.restricted, _):
            language.text(korean: "iCloud 사용 제한됨", english: "iCloud Restricted")
        case .resolved(.couldNotDetermine, _):
            language.text(korean: "iCloud 상태 확인 불가", english: "Cannot Determine iCloud Status")
        case .resolved(.temporarilyUnavailable, _):
            language.text(korean: "iCloud 일시 사용 불가", english: "iCloud Temporarily Unavailable")
        case .resolved(_, _):
            language.text(korean: "iCloud 상태 확인 필요", english: "iCloud Status Needs Review")
        case .failed:
            language.text(korean: "iCloud 확인 실패", english: "iCloud Check Failed")
        }
    }

    func badgeTitle(in language: AppLanguage) -> String {
        switch self {
        case .checking:
            language.text(korean: "확인 중", english: "Checking")
        case .resolved(.available, _):
            language.text(korean: "연동됨", english: "Synced")
        case .resolved(.noAccount, _):
            language.text(korean: "미연동", english: "Not Synced")
        case .resolved(.restricted, _):
            language.text(korean: "제한됨", english: "Restricted")
        case .resolved(.couldNotDetermine, _):
            language.text(korean: "확인 불가", english: "Unknown")
        case .resolved(.temporarilyUnavailable, _):
            language.text(korean: "일시 중단", english: "Paused")
        case .resolved(_, _):
            language.text(korean: "알 수 없음", english: "Unknown")
        case .failed:
            language.text(korean: "오류", english: "Error")
        }
    }

    func summary(in language: AppLanguage) -> String {
        switch self {
        case .checking:
            language.text(korean: "현재 기기의 iCloud 계정 상태를 확인하고 있습니다.", english: "Checking the iCloud account status on this device.")
        case .resolved(.available, _):
            language.text(korean: "개인 iCloud 데이터베이스를 사용할 수 있습니다.", english: "Your private iCloud database is available.")
        case .resolved(.noAccount, _):
            language.text(korean: "설정 앱에서 iCloud에 로그인해야 동기화됩니다.", english: "Sign in to iCloud in Settings to sync.")
        case .resolved(.restricted, _):
            language.text(korean: "기기 또는 계정 제한으로 iCloud를 사용할 수 없습니다.", english: "iCloud cannot be used because of device or account restrictions.")
        case .resolved(.couldNotDetermine, _):
            language.text(korean: "네트워크 또는 시스템 상태 때문에 확인하지 못했습니다.", english: "The status could not be checked because of network or system conditions.")
        case .resolved(.temporarilyUnavailable, _):
            language.text(korean: "iCloud 서비스가 잠시 사용할 수 없는 상태입니다.", english: "iCloud is temporarily unavailable.")
        case .resolved(_, _):
            language.text(korean: "알 수 없는 iCloud 상태입니다.", english: "The iCloud status is unknown.")
        case .failed:
            language.text(korean: "iCloud 상태 확인 중 오류가 발생했습니다.", english: "An error occurred while checking iCloud status.")
        }
    }

    func detail(in language: AppLanguage) -> String {
        switch self {
        case .failed(let message, _):
            message
        default:
            summary(in: language)
        }
    }

    func explanation(in language: AppLanguage) -> String {
        switch self {
        case .checking:
            language.text(korean: "상태 확인이 끝나면 이 화면에 현재 iCloud 사용 가능 여부가 표시됩니다.", english: "When the status check finishes, this screen will show whether iCloud is available.")
        case .resolved(.available, _):
            language.text(korean: "TaskBell은 CloudKit의 Private Database를 사용합니다. 데이터는 현재 Apple 계정의 개인 iCloud 영역에 저장되며, 같은 앱과 같은 iCloud 계정을 사용하는 기기 사이에서 동기화됩니다.", english: "TaskBell uses the CloudKit Private Database. Your data is stored in the private iCloud area of the current Apple account and syncs between devices using the same app and iCloud account.")
        case .resolved(.noAccount, _):
            language.text(korean: "이 기기에 iCloud 계정이 설정되어 있지 않습니다. iOS 설정 앱에서 Apple 계정으로 로그인한 뒤 iCloud Drive가 켜져 있는지 확인해 주세요.", english: "No iCloud account is configured on this device. Sign in with your Apple account in iOS Settings and make sure iCloud Drive is enabled.")
        case .resolved(.restricted, _):
            language.text(korean: "스크린 타임, 관리형 기기 정책, 보호자 제한 등으로 iCloud 접근이 막혀 있을 수 있습니다. 기기 설정의 제한 항목을 확인해 주세요.", english: "iCloud access may be blocked by Screen Time, managed device policies, or parental restrictions. Check the restriction settings on this device.")
        case .resolved(.couldNotDetermine, _):
            language.text(korean: "현재 네트워크 상태나 iCloud 서비스 응답 때문에 계정 상태를 판별하지 못했습니다. 잠시 후 다시 확인해 주세요.", english: "The account status could not be determined because of the current network state or iCloud service response. Try again later.")
        case .resolved(.temporarilyUnavailable, _):
            language.text(korean: "iCloud가 일시적으로 사용할 수 없는 상태입니다. 네트워크 연결과 Apple 시스템 상태를 확인한 뒤 다시 시도해 주세요.", english: "iCloud is temporarily unavailable. Check your network connection and Apple system status, then try again.")
        case .resolved(_, _):
            language.text(korean: "시스템에서 예상하지 못한 iCloud 상태를 반환했습니다. 앱을 다시 실행하거나 잠시 후 다시 확인해 주세요.", english: "The system returned an unexpected iCloud status. Restart the app or check again later.")
        case .failed(let message, _):
            language.text(korean: "CloudKit 상태 확인 요청이 실패했습니다. 오류 메시지: \(message)", english: "The CloudKit status check failed. Error message: \(message)")
        }
    }

    var systemImage: String {
        switch self {
        case .checking:
            "icloud"
        case .resolved(.available, _):
            "icloud.fill"
        case .resolved(.noAccount, _):
            "person.crop.circle.badge.exclamationmark"
        case .resolved(.restricted, _):
            "lock.icloud"
        case .resolved(.couldNotDetermine, _), .resolved(.temporarilyUnavailable, _), .resolved(_, _):
            "icloud.slash"
        case .failed:
            "exclamationmark.icloud"
        }
    }

    var tint: Color {
        switch self {
        case .checking:
            .secondary
        case .resolved(.available, _):
            .green
        case .resolved(.noAccount, _), .resolved(.restricted, _), .failed:
            .red
        case .resolved(.couldNotDetermine, _), .resolved(.temporarilyUnavailable, _), .resolved(_, _):
            .orange
        }
    }

    var checkedAt: Date? {
        switch self {
        case .checking:
            nil
        case .resolved(_, let checkedAt), .failed(_, let checkedAt):
            checkedAt
        }
    }
}
