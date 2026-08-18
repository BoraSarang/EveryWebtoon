import Foundation

struct BackupData: Codable {
    var app: String = "EveryWebtoon"
    var version: Int = 1
    var createdAt: Date
    var webtoons: [Webtoon]
    var history: BackupHistory
}

struct BackupHistory: Codable {
    var lastRead: [String: Int]
    var viewed: [String: [Int]]
    var lastReadAt: [String: TimeInterval]
    var positions: [String: Double]
}

enum BackupManager {
    static func backup(to url: URL) throws -> Int {
        let webtoons = WebtoonDB.shared.allWebtoons()
        let data = BackupData(
            createdAt: Date(),
            webtoons: webtoons,
            history: BackupHistory(
                lastRead: ReadHistoryManager.shared.lastRead,
                viewed: ReadHistoryManager.shared.viewed,
                lastReadAt: ReadHistoryManager.shared.lastReadAt,
                positions: ReadHistoryManager.shared.positions
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(data).write(to: url)
        return webtoons.count
    }

    static func restore(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)
        guard backup.app == "EveryWebtoon" else { throw BackupError.notBackup }
        guard backup.version == 1 else { throw BackupError.unsupportedVersion(backup.version) }

        WebtoonDB.shared.upsert(backup.webtoons)
        ReadHistoryManager.shared.restore(from: backup.history)
        return backup.webtoons.count
    }

    enum BackupError: LocalizedError {
        case notBackup
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .notBackup: return "EveryWebtoon 백업 파일이 아닙니다"
            case .unsupportedVersion(let v): return "지원하지 않는 백업 버전입니다 (\(v))"
            }
        }
    }
}
