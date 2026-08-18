import SwiftUI

@main
struct EveryWebtoonApp: App {
    @StateObject private var discoverVM = DiscoverViewModel()
    @StateObject private var downloadVM = DownloadViewModel.shared
    @StateObject private var settings = AppSettings.shared
    @AppStorage("sidebarVisible") private var sidebarVisible = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(discoverVM)
                .environmentObject(downloadVM)
                .preferredColorScheme(settings.theme.colorScheme)
                .frame(minWidth: 1000, minHeight: 640)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    setupNotificationHandlers()
                    #if DEBUG
                    DebugLogger.shared.push(.SYSTEM, category: "App",
                        message: "앱 실행됨 — Cmd+Shift+D 로그패널")
                    #endif
                }
        }
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("백업 생성…") {
                    BackupAction.performBackup()
                }
                .keyboardShortcut("s", modifiers: .command)
                Button("백업에서 복원…") {
                    BackupAction.performRestore()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Button("사이드바 토글") {
                    sidebarVisible.toggle()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                Button("검색") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                Button("명령 팔레트…") {
                    CommandPaletteManager.shared.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
                Divider()
                Picker("테마", selection: $settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)
                #if DEBUG
                Divider()
                Button("Show/Hide Debug Panel") {
                    DebugPanelWindowManager.shared.toggle()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Copy Selection") {
                    NotificationCenter.default.post(name: .copyDebugSelection, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Copy All for Agent") {
                    NotificationCenter.default.post(name: .copyDebugAll, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                Button("Clear Logs") {
                    DebugLogger.shared.clear()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                Button("Auto Scroll (📌)") {
                    NotificationCenter.default.post(name: .toggleAutoScroll, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                #endif
            }
        }
        Settings {
            SettingsView()
        }
        .defaultSize(width: 600, height: 480)
    }

    private func setupNotificationHandlers() {
        #if DEBUG
        NotificationCenter.default.addObserver(
            forName: .toggleDebugPanel, object: nil, queue: .main
        ) { _ in
            DebugPanelWindowManager.shared.toggle()
        }
        #endif
    }
}

extension Notification.Name {
    static let toggleDebugPanel = Notification.Name("toggleDebugPanel")
    static let copyDebugSelection = Notification.Name("copyDebugSelection")
    static let copyDebugAll = Notification.Name("copyDebugAll")
    static let toggleAutoScroll = Notification.Name("toggleAutoScroll")
    static let focusSearch = Notification.Name("focusSearch")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let navigateSidebar = Notification.Name("navigateSidebar")
}
