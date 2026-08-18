import Foundation

final class ReadHistoryManager: ObservableObject {
    static let shared = ReadHistoryManager()

    private let defaults = UserDefaults.standard
    private let lastKey = "read_history_last"
    private let viewedKey = "read_history_viewed"
    private let lastAtKey = "read_history_last_at"
    private let positionKey = "read_history_position"

    @Published private(set) var lastRead: [String: Int] = [:]
    @Published private(set) var viewed: [String: [Int]] = [:]
    @Published private(set) var lastReadAt: [String: TimeInterval] = [:]
    @Published private(set) var positions: [String: Double] = [:]

    private init() {
        lastRead = defaults.dictionary(forKey: lastKey) as? [String: Int] ?? [:]
        viewed = defaults.dictionary(forKey: viewedKey) as? [String: [Int]] ?? [:]
        lastReadAt = defaults.dictionary(forKey: lastAtKey) as? [String: TimeInterval] ?? [:]
        positions = defaults.dictionary(forKey: positionKey) as? [String: Double] ?? [:]
    }

    func recordPosition(webtoonId: String, episodeNo: Int, fraction: Double) {
        positions[positionKey(webtoonId: webtoonId, episodeNo: episodeNo)] = fraction
        defaults.set(positions, forKey: positionKey)
        DebugLogger.shared.push(.INFO, category: "ReadHistory", message: "recordPosition \(episodeNo)화", meta: "fraction=\(fraction)")
    }

    func lastPosition(webtoonId: String, episodeNo: Int) -> Double? {
        positions[positionKey(webtoonId: webtoonId, episodeNo: episodeNo)]
    }

    func lastReadProgress(webtoonId: String) -> (episodeNo: Int, percent: Int)? {
        guard let no = lastRead[webtoonId] else { return nil }
        let fraction = positions[positionKey(webtoonId: webtoonId, episodeNo: no)] ?? 0
        return (no, min(99, Int(fraction * 100)))
    }

    private func positionKey(webtoonId: String, episodeNo: Int) -> String {
        "\(webtoonId)|\(episodeNo)"
    }

    func record(webtoonId: String, episodeNo: Int) {
        lastRead[webtoonId] = episodeNo
        lastReadAt[webtoonId] = Date().timeIntervalSince1970
        var seen = viewed[webtoonId] ?? []
        if !seen.contains(episodeNo) {
            seen.append(episodeNo)
        }
        viewed[webtoonId] = seen
        defaults.set(lastRead, forKey: lastKey)
        defaults.set(viewed, forKey: viewedKey)
        defaults.set(lastReadAt, forKey: lastAtKey)
    }

    var recentWebtoonIds: [String] {
        lastReadAt
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }

    func lastEpisode(webtoonId: String) -> Int? {
        lastRead[webtoonId]
    }

    func isViewed(webtoonId: String, episodeNo: Int) -> Bool {
        viewed[webtoonId]?.contains(episodeNo) ?? false
    }

    func restore(from history: BackupHistory) {
        lastRead.merge(history.lastRead) { _, new in new }
        lastReadAt.merge(history.lastReadAt) { _, new in new }
        positions.merge(history.positions) { _, new in new }
        for (webtoonId, episodes) in history.viewed {
            let merged = Array(Set((viewed[webtoonId] ?? []) + episodes)).sorted()
            viewed[webtoonId] = merged
        }
        defaults.set(lastRead, forKey: lastKey)
        defaults.set(viewed, forKey: viewedKey)
        defaults.set(lastReadAt, forKey: lastAtKey)
        defaults.set(positions, forKey: positionKey)
    }
}
