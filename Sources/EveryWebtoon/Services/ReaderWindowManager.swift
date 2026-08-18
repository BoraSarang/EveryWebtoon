import SwiftUI
import AppKit

final class ReaderWindowManager {
    static let shared = ReaderWindowManager()
    private var window: NSWindow?

    func show(webtoon: Webtoon, episodes: [Episode], startEpisode: Int) {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 910),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.center()
            win.minSize = NSSize(width: 360, height: 760)
            win.aspectRatio = NSSize(width: 390, height: 844)
            win.isReleasedWhenClosed = false
            win.isMovableByWindowBackground = true
            win.backgroundColor = NSColor.black
            self.window = win
        }

        let reader = ReaderView(webtoon: webtoon, episodes: episodes, startEpisode: startEpisode) { [weak self] in
            self?.window?.orderOut(nil)
        }
        window?.contentView = NSHostingView(rootView: reader)
        window?.title = "\(webtoon.title) - \(startEpisode)화"
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateTitle(_ title: String) {
        window?.title = title
    }
}
