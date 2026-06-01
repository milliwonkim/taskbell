//
//  SettingsView.swift
//  TaskBell
//

import SwiftUI
import CloudKit

struct SettingsView: View {
    @Binding var appearance: AppAppearance
    @State private var iCloudStatus = ICloudSyncStatus.checking

    private let iCloudContainerIdentifier = "iCloud.kiwonkim.TaskBell"

    var body: some View {
        Form {
            Section("화면 모드") {
                Picker("표시 방식", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.menu)
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
                            Text("iCloud 연동")
                            Text(iCloudStatus.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(iCloudStatus.badgeTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(iCloudStatus.tint)
                    }
                }
            } header: {
                Text("iCloud")
            } footer: {
                Text("할 일과 미리알림은 사용자의 개인 iCloud 데이터베이스에 저장되어 같은 Apple 계정의 기기와 동기화됩니다.")
            }
        }
        .navigationTitle("설정")
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
                        Text(status.title)
                            .font(.headline)
                        Text(status.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("연동 정보") {
                LabeledContent("상태", value: status.badgeTitle)
                LabeledContent("CloudKit 데이터베이스", value: "Private")
                LabeledContent("컨테이너", value: containerIdentifier)

                if let checkedAt = status.checkedAt {
                    LabeledContent("마지막 확인", value: checkedAt.formatted(date: .abbreviated, time: .standard))
                }
            }

            Section("상세 설명") {
                Text(status.explanation)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task {
                        await onRefresh()
                    }
                } label: {
                    Label("상태 다시 확인", systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationTitle("iCloud 상세정보")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum ICloudSyncStatus: Equatable {
    case checking
    case resolved(CKAccountStatus, checkedAt: Date)
    case failed(String, checkedAt: Date)

    var title: String {
        switch self {
        case .checking:
            "iCloud 상태 확인 중"
        case .resolved(.available, _):
            "iCloud와 연동됨"
        case .resolved(.noAccount, _):
            "iCloud 계정 없음"
        case .resolved(.restricted, _):
            "iCloud 사용 제한됨"
        case .resolved(.couldNotDetermine, _):
            "iCloud 상태 확인 불가"
        case .resolved(.temporarilyUnavailable, _):
            "iCloud 일시 사용 불가"
        case .resolved(_, _):
            "iCloud 상태 확인 필요"
        case .failed:
            "iCloud 확인 실패"
        }
    }

    var badgeTitle: String {
        switch self {
        case .checking:
            "확인 중"
        case .resolved(.available, _):
            "연동됨"
        case .resolved(.noAccount, _):
            "미연동"
        case .resolved(.restricted, _):
            "제한됨"
        case .resolved(.couldNotDetermine, _):
            "확인 불가"
        case .resolved(.temporarilyUnavailable, _):
            "일시 중단"
        case .resolved(_, _):
            "알 수 없음"
        case .failed:
            "오류"
        }
    }

    var summary: String {
        switch self {
        case .checking:
            "현재 기기의 iCloud 계정 상태를 확인하고 있습니다."
        case .resolved(.available, _):
            "개인 iCloud 데이터베이스를 사용할 수 있습니다."
        case .resolved(.noAccount, _):
            "설정 앱에서 iCloud에 로그인해야 동기화됩니다."
        case .resolved(.restricted, _):
            "기기 또는 계정 제한으로 iCloud를 사용할 수 없습니다."
        case .resolved(.couldNotDetermine, _):
            "네트워크 또는 시스템 상태 때문에 확인하지 못했습니다."
        case .resolved(.temporarilyUnavailable, _):
            "iCloud 서비스가 잠시 사용할 수 없는 상태입니다."
        case .resolved(_, _):
            "알 수 없는 iCloud 상태입니다."
        case .failed:
            "iCloud 상태 확인 중 오류가 발생했습니다."
        }
    }

    var detail: String {
        switch self {
        case .failed(let message, _):
            message
        default:
            summary
        }
    }

    var explanation: String {
        switch self {
        case .checking:
            "상태 확인이 끝나면 이 화면에 현재 iCloud 사용 가능 여부가 표시됩니다."
        case .resolved(.available, _):
            "TaskBell은 CloudKit의 Private Database를 사용합니다. 데이터는 현재 Apple 계정의 개인 iCloud 영역에 저장되며, 같은 앱과 같은 iCloud 계정을 사용하는 기기 사이에서 동기화됩니다."
        case .resolved(.noAccount, _):
            "이 기기에 iCloud 계정이 설정되어 있지 않습니다. iOS 설정 앱에서 Apple 계정으로 로그인한 뒤 iCloud Drive가 켜져 있는지 확인해 주세요."
        case .resolved(.restricted, _):
            "스크린 타임, 관리형 기기 정책, 보호자 제한 등으로 iCloud 접근이 막혀 있을 수 있습니다. 기기 설정의 제한 항목을 확인해 주세요."
        case .resolved(.couldNotDetermine, _):
            "현재 네트워크 상태나 iCloud 서비스 응답 때문에 계정 상태를 판별하지 못했습니다. 잠시 후 다시 확인해 주세요."
        case .resolved(.temporarilyUnavailable, _):
            "iCloud가 일시적으로 사용할 수 없는 상태입니다. 네트워크 연결과 Apple 시스템 상태를 확인한 뒤 다시 시도해 주세요."
        case .resolved(_, _):
            "시스템에서 예상하지 못한 iCloud 상태를 반환했습니다. 앱을 다시 실행하거나 잠시 후 다시 확인해 주세요."
        case .failed(let message, _):
            "CloudKit 상태 확인 요청이 실패했습니다. 오류 메시지: \(message)"
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
