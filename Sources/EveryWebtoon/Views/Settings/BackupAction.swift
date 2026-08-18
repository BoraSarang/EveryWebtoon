import AppKit

enum BackupAction {
    @MainActor
    static func performBackup() {
        let panel = NSSavePanel()
        panel.title = "백업 저장"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "EveryWebtoon-backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let count = try BackupManager.backup(to: url)
            DebugLogger.shared.push(.ACTION, category: "Backup",
                message: "백업 완료",
                meta: ["file": url.lastPathComponent, "webtoons": count])
            showAlert(title: "백업 완료",
                message: "웹툰 \(count)개와 읽기 이력이 저장되었습니다:\n\(url.path)")
        } catch {
            showAlert(title: "백업 실패", message: error.localizedDescription)
        }
    }

    @MainActor
    static func performRestore() {
        let panel = NSOpenPanel()
        panel.title = "백업 파일 선택"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let confirm = NSAlert()
        confirm.messageText = "백업에서 복원"
        confirm.informativeText = "보관함과 읽기 이력이 백업 데이터와 병합됩니다. 계속할까요?"
        confirm.addButton(withTitle: "복원")
        confirm.addButton(withTitle: "취소")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        do {
            let count = try BackupManager.restore(from: url)
            DebugLogger.shared.push(.ACTION, category: "Backup",
                message: "복원 완료",
                meta: ["file": url.lastPathComponent, "webtoons": count])
            showAlert(title: "복원 완료",
                message: "웹툰 \(count)개와 읽기 이력이 복원되었습니다.")
        } catch {
            showAlert(title: "복원 실패", message: error.localizedDescription)
        }
    }

    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}