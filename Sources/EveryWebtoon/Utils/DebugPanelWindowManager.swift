import SwiftUI
import AppKit

#if DEBUG

final class DebugPanelWindowManager: ObservableObject {
    static let shared = DebugPanelWindowManager()

    private var window: NSWindow?
    private var popoverToClose: NSPopover?

    private init() {}

    func setPopover(_ popover: NSPopover) {
        popoverToClose = popover
    }

    func toggle() {
        popoverToClose?.performClose(nil)
        if let win = window, win.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.center()
            win.minSize = NSSize(width: 420, height: 240)
            win.maxSize = NSSize(width: 2000, height: 1200)
            win.level = .floating + 100
            win.isReleasedWhenClosed = false
            win.isMovableByWindowBackground = true
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.title = "Debug Logs"
            let hosting = NSHostingView(rootView: DebugPanelView())
            hosting.frame = NSRect(x: 0, y: 0, width: 640, height: 360)
            hosting.autoresizingMask = [.width, .height]
            win.contentView = hosting
            self.window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}

struct DebugPanelView: View {
    @ObservedObject fileprivate var logger = DebugLogger.shared
    @State private var selection = Set<UUID>()
    @State private var lastSelected: UUID?
    @State private var isAutoScroll = true
    @State private var filterText = ""

    private var filteredLogs: [DebugLogEntry] {
        let text = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return logger.logs }
        return logger.logs.filter {
            $0.formatted.localizedCaseInsensitiveContains(text)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredLogs) { entry in
                            logRow(for: entry)
                        }
                    }
                }
                .onChange(of: logger.logs.count) { _, _ in
                    if isAutoScroll && !logger.isAutoScrollPaused, let last = filteredLogs.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: filterText) { _, _ in
                    if isAutoScroll, let last = filteredLogs.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
        )
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: .copyDebugSelection, object: nil, queue: .main
            ) { _ in copySelection() }
            NotificationCenter.default.addObserver(
                forName: .copyDebugAll, object: nil, queue: .main
            ) { _ in copyAll() }
            NotificationCenter.default.addObserver(
                forName: .toggleAutoScroll, object: nil, queue: .main
            ) { _ in isAutoScroll.toggle() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "ant")
                .font(.body)
                .foregroundColor(.secondary)

            Text("Debug Logs [\(filteredLogs.count)/\(logger.logs.count)]")
                .font(.caption.bold())
                .foregroundColor(.primary)

            TextField("필터…", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .frame(width: 160)

            Spacer()

            toolbarButton(
                icon: isAutoScroll ? "arrow.down.to.line.circle.fill" : "arrow.down.to.line.circle",
                help: "자동 스크롤 토글"
            ) {
                isAutoScroll.toggle()
            }

            toolbarButton(
                icon: "doc.on.doc",
                help: "선택한 줄 복사",
                disabled: selection.isEmpty
            ) {
                copySelection()
            }

            toolbarButton(icon: "doc.on.clipboard", help: "전체 복사") {
                copyAll()
            }

            toolbarButton(icon: "trash", help: "로그 지우기") {
                clear()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func toolbarButton(
        icon: String,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
        .disabled(disabled)
        .help(help)
    }

    private func logRow(for entry: DebugLogEntry) -> some View {
        Text(entry.formatted)
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
            .foregroundColor(textColor(for: entry.level))
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selection.contains(entry.id)
                    ? Color.accentColor.opacity(0.25)
                    : Color.clear
            )
            .onTapGesture { handleTap(entry.id) }
            .id(entry.id)
    }

    private func handleTap(_ id: UUID) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) {
            if let last = lastSelected {
                selectRange(from: last, to: id)
            } else {
                selection = [id]
                lastSelected = id
            }
        } else if flags.contains(.command) {
            if selection.contains(id) {
                selection.remove(id)
            } else {
                selection.insert(id)
            }
            lastSelected = id
        } else {
            selection = [id]
            lastSelected = id
        }
        logger.pauseAutoScroll()
    }

    private func selectRange(from: UUID, to: UUID) {
        let logs = filteredLogs
        guard let fromIndex = logs.firstIndex(where: { $0.id == from }),
              let toIndex = logs.firstIndex(where: { $0.id == to }) else { return }
        let lower = min(fromIndex, toIndex)
        let upper = max(fromIndex, toIndex)
        for i in lower...upper {
            selection.insert(logs[i].id)
        }
    }

    private func copySelection() {
        let texts = filteredLogs
            .filter { selection.contains($0.id) }
            .map { $0.formatted }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texts, forType: .string)
    }

    private func copyAll() {
        let all = logger.formatForAgent(filteredLogs)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(all, forType: .string)
    }

    private func clear() {
        logger.clear()
        selection.removeAll()
        lastSelected = nil
    }

    private func textColor(for level: DebugLogLevel) -> Color {
        switch level {
        case .ERROR: return Color(nsColor: .systemRed)
        case .WARN: return Color(nsColor: .systemYellow)
        case .API_REQ: return Color(nsColor: .systemBlue)
        case .API_RES: return Color(nsColor: .systemGreen)
        case .SYSTEM: return Color(nsColor: .systemPurple)
        case .ACTION: return Color.primary
        case .INFO: return Color.secondary
        }
    }
}

#endif