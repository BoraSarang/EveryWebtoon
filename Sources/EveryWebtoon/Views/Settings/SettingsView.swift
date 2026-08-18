import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var isMovingData = false
    @State private var moveMessage: String?

    private let ttlOptions: [(Int, String)] = [
        (1, "1시간"), (6, "6시간"), (12, "12시간"), (24, "24시간"), (0, "사용 안 함")
    ]

    private let intervalOptions: [(Int, String)] = [
        (60, "1분"), (300, "5분"), (600, "10분"), (1800, "30분"), (0, "수동으로만")
    ]

    var body: some View {
        Form {
            Section("저장 위치") {
                LabeledContent("현재 위치") {
                    Text(currentPath).font(.caption).lineLimit(2)
                }
                HStack {
                    Button("폴더 선택…") { chooseFolder() }
                    Button("기본 위치로 재설정") { resetPath() }
                        .disabled(settings.storageBasePath == nil)
                }
                if settings.storageBasePath != nil {
                    Text("변경 사항은 앱을 다시 실행한 후 적용됩니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button("기존 데이터 이동…") { moveData() }
                        .disabled(isMovingData || !DownloadViewModel.shared.activeTasks.isEmpty)
                    if isMovingData {
                        ProgressView().controlSize(.small)
                    }
                }
                if let moveMessage {
                    Text(moveMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("캐시") {
                Picker("디스커버리 캐시 유효기간", selection: $settings.cacheTTLHours) {
                    ForEach(ttlOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
            }

            Section("신규 회차") {
                Picker("자동 확인 주기", selection: $settings.updateCheckInterval) {
                    ForEach(intervalOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                Toggle("새 회차 알림센터 알림", isOn: $settings.newEpisodeAlerts)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, idealWidth: 600)
        .padding()
    }

    private var currentPath: String {
        settings.storageBasePath ?? "~/Documents/EveryWebtoon"
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "선택"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.storageBasePath = url.path
    }

    private func resetPath() {
        settings.storageBasePath = nil
    }

    private func moveData() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "이동할 폴더"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isMovingData = true
        moveMessage = nil
        let source = AppPaths.basePath
        let target = url.path
        DispatchQueue.global(qos: .userInitiated).async {
            let result = DataMigrator.copyContents(from: source, to: target)
            DispatchQueue.main.async {
                isMovingData = false
                if result == nil {
                    settings.storageBasePath = target
                    moveMessage = "복사 완료 — 앱을 다시 실행하면 새 위치를 사용합니다."
                } else {
                    moveMessage = "이동 실패: \(result!)"
                }
            }
        }
    }
}

enum DataMigrator {
    static func copyContents(from source: String, to target: String) -> String? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source) else { return "원본 폴더가 없습니다" }
        guard source != target, !target.hasPrefix(source + "/") else { return "올바르지 않은 대상 폴더입니다" }
        do {
            try fm.createDirectory(atPath: target, withIntermediateDirectories: true)
        } catch {
            return error.localizedDescription
        }
        guard let items = try? fm.contentsOfDirectory(atPath: source) else {
            return "원본 폴더를 읽을 수 없습니다"
        }
        for item in items {
            let src = "\(source)/\(item)"
            let dst = "\(target)/\(item)"
            if fm.fileExists(atPath: dst) { continue }
            do {
                try fm.copyItem(atPath: src, toPath: dst)
            } catch {
                return "\(item) 복사 실패: \(error.localizedDescription)"
            }
        }
        return nil
    }
}
