import Foundation
import os

enum DebugLogLevel: String, CaseIterable {
    case ACTION = "ACTION"
    case API_REQ = "API→"
    case API_RES = "API←"
    case INFO = "INFO"
    case WARN = "WARN"
    case ERROR = "ERROR"
    case SYSTEM = "SYSTEM"
}

struct DebugLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: String
    let level: DebugLogLevel
    let platform: String
    let category: String
    let message: String
    let meta: String?

    var formatted: String {
        "[\(timestamp)] [\(level.rawValue)] [\(platform)] [\(category)] \(message)\(meta.map { " | \($0)" } ?? "")"
    }
}

final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()

    @Published var logs: [DebugLogEntry] = []

    private let maxLogs = 5000
    private let osLog: OSLog

    #if DEBUG
    private let isDebug = true
    #else
    private let isDebug = false
    #endif

    private var autoScrollPausedUntil: Date?
    private var autoScrollWorkItem: DispatchWorkItem?

    private init() {
        osLog = OSLog(subsystem: "com.borasarang.everywebtoon", category: "Debug")
    }

    func push(
        _ level: DebugLogLevel,
        platform: String = "MACOS",
        category: String,
        message: String,
        meta: Any? = nil
    ) {
        guard isDebug else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let metaStr = maskSecrets(meta)
        let entry = DebugLogEntry(
            timestamp: timestamp,
            level: level,
            platform: platform,
            category: category,
            message: message,
            meta: metaStr
        )

        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
        }

        print(entry.formatted)
        os_log("%{public}@", log: osLog, type: .debug, entry.formatted)
    }

    private func maskSecrets(_ obj: Any?) -> String? {
        guard let obj else { return nil }
        var str = "\(obj)"
        let sensitiveKeys = ["token", "password", "keystore", "secret", "authorization"]
        if sensitiveKeys.contains(where: { str.lowercased().contains($0) }) {
            return "***MASKED***"
        }
        if str.count > 500 {
            return String(str.prefix(500)) + "...(truncated)"
        }
        return str
    }

    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }

    func formatForAgent(_ entries: [DebugLogEntry]) -> String {
        entries.map { $0.formatted }.joined(separator: "\n")
    }

    func pauseAutoScroll() {
        autoScrollWorkItem?.cancel()
        autoScrollPausedUntil = Date().addingTimeInterval(2)
        autoScrollWorkItem = DispatchWorkItem { [weak self] in
            self?.autoScrollPausedUntil = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: autoScrollWorkItem!)
    }

    var isAutoScrollPaused: Bool {
        guard let pausedUntil = autoScrollPausedUntil else { return false }
        return Date() < pausedUntil
    }
}
