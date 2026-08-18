import Foundation
import AppKit

func openExternalURL(_ url: URL) {
    NSWorkspace.shared.open(url)
}

func presentExportResult(fmt: String, path: String) {
    let alert = NSAlert()
    alert.messageText = "\(fmt) 내보내기 완료"
    alert.informativeText = path
    alert.addButton(withTitle: "Finder에서 보기")
    alert.addButton(withTitle: "닫기")
    if alert.runModal() == .alertFirstButtonReturn {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

func presentExportFailure(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = "내보내기 실패"
    alert.informativeText = error.localizedDescription
    alert.runModal()
}
