import SwiftUI
import AppKit

// MARK: - ⌘K 커맨드 팔레트 (Raycast/Linear 스타일)

struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let keywords: String
    let shortcutHint: String?
    let action: () -> Void

    init(id: String, title: String, symbol: String, keywords: String = "",
         shortcutHint: String? = nil, action: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.keywords = keywords
        self.shortcutHint = shortcutHint
        self.action = action
    }
}

@MainActor
final class CommandPaletteStore: ObservableObject {
    @Published var query = ""
    @Published var selectedIndex = 0

    let commands: [PaletteCommand]

    init(commands: [PaletteCommand]) {
        self.commands = commands
    }

    var filteredCommands: [PaletteCommand] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return commands }
        return commands.filter {
            $0.title.lowercased().contains(q) || $0.keywords.lowercased().contains(q)
        }
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }

    func moveSelection(_ delta: Int) {
        let count = filteredCommands.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    func executeSelected() {
        let cmds = filteredCommands
        guard !cmds.isEmpty else { return }
        let idx = min(max(selectedIndex, 0), cmds.count - 1)
        CommandPaletteManager.shared.hide()
        cmds[idx].action()
    }
}

@MainActor
final class CommandPaletteManager: ObservableObject {
    static let shared = CommandPaletteManager()

    private var window: NSPanel?
    @Published private(set) var isVisible = false

    private let store = CommandPaletteStore(commands: CommandPaletteView.makeCommands())

    private init() {}

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        store.reset()
        if window == nil {
            let panel = PalettePanel(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
                styleMask: [.borderless],
                backing: .buffered, defer: false
            )
            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isReleasedWhenClosed = false
            panel.animationBehavior = .utilityWindow
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isMovableByWindowBackground = true
            panel.contentView = NSHostingView(rootView: CommandPaletteView(store: store))
            self.window = panel
        }
        applyAppearance()
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        isVisible = true
    }

    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }

    private func applyAppearance() {
        switch AppSettings.shared.theme {
        case .dark: window?.appearance = NSAppearance(named: .darkAqua)
        case .light: window?.appearance = NSAppearance(named: .aqua)
        case .system: window?.appearance = nil
        }
    }

    private func positionPanel() {
        guard let panel = window,
              let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        let width = panel.frame.width
        let height = panel.frame.height
        let x = vf.midX - width / 2
        let y = vf.maxY - vf.height * 0.35 - height / 2
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }
}

private final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct CommandPaletteView: View {
    @StateObject private var store: CommandPaletteStore
    @FocusState private var searchFocused: Bool
    @State private var eventMonitor: Any?

    init(store: CommandPaletteStore? = nil) {
        _store = StateObject(wrappedValue: store ?? CommandPaletteStore(commands: CommandPaletteView.makeCommands()))
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().opacity(0.4)
            commandList
            Divider().opacity(0.4)
            footer
        }
        .frame(width: 460, height: 320)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onAppear {
            store.reset()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKey(event)
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 125: store.moveSelection(1); return nil
        case 126: store.moveSelection(-1); return nil
        case 36: store.executeSelected(); return nil
        case 53: CommandPaletteManager.shared.hide(); return nil
        default: return event
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)

            TextField("명령 입력…", text: $store.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
                .onChange(of: store.query) { _, _ in
                    store.selectedIndex = 0
                }

            if !store.query.isEmpty {
                Button {
                    store.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            }

            Text("esc")
                .font(.system(size: 11))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var commandList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if store.filteredCommands.isEmpty {
                        Text("명령 없음")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(24)
                    } else {
                        ForEach(Array(store.filteredCommands.enumerated()), id: \.element.id) { index, command in
                            row(index: index, command: command)
                                .id(command.id)
                        }
                    }
                }
                .padding(6)
            }
            .onChange(of: store.selectedIndex) { _, newIndex in
                let cmds = store.filteredCommands
                guard !cmds.isEmpty else { return }
                let idx = min(max(newIndex, 0), cmds.count - 1)
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(cmds[idx].id, anchor: .center)
                }
            }
        }
    }

    private func row(index: Int, command: PaletteCommand) -> some View {
        let isSelected = index == store.selectedIndex
        return Button {
            store.selectedIndex = index
            store.executeSelected()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: command.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .white : .secondary)

                Text(command.title)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                if let hint = command.shortcutHint {
                    Text(hint)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.accentColor : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { store.selectedIndex = index }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(store.filteredCommands.count)개 명령")
            Spacer()
            Text("↑↓ 이동  ·  ↵ 실행")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: 명령 목록

    static func makeCommands() -> [PaletteCommand] {
        let sidebarItems = SidebarItem.all
        var commands: [PaletteCommand] = [
            PaletteCommand(id: "search", title: "검색", symbol: "magnifyingglass",
                keywords: "검색 search find", shortcutHint: "⌘F") {
                NotificationCenter.default.post(name: .focusSearch, object: nil)
            },
            PaletteCommand(id: "toggle-sidebar", title: "사이드바 토글", symbol: "sidebar.left",
                keywords: "사이드바 sidebar toggle", shortcutHint: "⌥⌘S") {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            },
            PaletteCommand(id: "theme-system", title: "테마: 시스템 설정", symbol: "circle.lefthalf.filled",
                keywords: "테마 theme 시스템 system") {
                AppSettings.shared.theme = .system
            },
            PaletteCommand(id: "theme-light", title: "테마: 라이트", symbol: "sun.max",
                keywords: "테마 theme 라이트 light 밝게") {
                AppSettings.shared.theme = .light
            },
            PaletteCommand(id: "theme-dark", title: "테마: 다크", symbol: "moon.stars",
                keywords: "테마 theme 다크 dark 어둡게") {
                AppSettings.shared.theme = .dark
            },
            PaletteCommand(id: "settings", title: "설정 열기", symbol: "gearshape",
                keywords: "설정 settings 환경설정 환경", shortcutHint: "⌘,") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            },
        ]

        for item in sidebarItems {
            commands.append(
                PaletteCommand(id: "nav-\(item.id)", title: item.title, symbol: item.icon,
                    keywords: "이동 navigate \(item.title)") {
                    NotificationCenter.default.post(name: .navigateSidebar, object: item)
                }
            )
        }

        #if DEBUG
        commands.append(contentsOf: [
            PaletteCommand(id: "debug-panel", title: "디버그 패널", symbol: "ladybug",
                keywords: "디버그 debug 로그 log", shortcutHint: "⌘⇧D") {
                DebugPanelWindowManager.shared.toggle()
            },
            PaletteCommand(id: "clear-logs", title: "로그 지우기", symbol: "trash",
                keywords: "로그 clear 지우기 삭제", shortcutHint: "⌘⇧K") {
                DebugLogger.shared.clear()
            },
        ])
        #endif

        return commands
    }
}