import SwiftUI

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "시스템 설정"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let themeKey = "app_theme"
    private let storageKey = "storage_base_path"
    private let cacheTTLKey = "cache_ttl_hours"
    private let checkIntervalKey = "update_check_interval"
    private let alertsKey = "new_episode_alerts"

    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
        }
    }

    /// 저장 폴더 커스텀 경로 (nil = 기본 위치), 재시작 후 적용
    @Published var storageBasePath: String? {
        didSet {
            if let storageBasePath {
                UserDefaults.standard.set(storageBasePath, forKey: storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: storageKey)
            }
        }
    }

    /// 디스커버리 캐시 유효시간(시간), 0 = 캐시 안 함
    @Published var cacheTTLHours: Int {
        didSet {
            UserDefaults.standard.set(cacheTTLHours, forKey: cacheTTLKey)
        }
    }

    /// 신규 회차 자동 확인 간격(초), 0 = 수동만
    @Published var updateCheckInterval: Int {
        didSet {
            UserDefaults.standard.set(updateCheckInterval, forKey: checkIntervalKey)
        }
    }

    /// 새 회차 알림센터 알림 여부
    @Published var newEpisodeAlerts: Bool {
        didSet {
            UserDefaults.standard.set(newEpisodeAlerts, forKey: alertsKey)
        }
    }

    var cacheTTL: TimeInterval? {
        cacheTTLHours == 0 ? 0 : TimeInterval(cacheTTLHours * 3600)
    }

    private init() {
        let themeRaw = UserDefaults.standard.string(forKey: themeKey) ?? AppTheme.system.rawValue
        theme = AppTheme(rawValue: themeRaw) ?? .system
        storageBasePath = UserDefaults.standard.string(forKey: storageKey)
        let storedTTL = UserDefaults.standard.object(forKey: cacheTTLKey) as? Int
        cacheTTLHours = storedTTL ?? 24
        let storedInterval = UserDefaults.standard.object(forKey: checkIntervalKey) as? Int
        updateCheckInterval = storedInterval ?? 300
        let storedAlerts = UserDefaults.standard.object(forKey: alertsKey) as? Bool
        newEpisodeAlerts = storedAlerts ?? true
    }
}
