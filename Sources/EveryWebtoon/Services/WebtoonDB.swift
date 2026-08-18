import Foundation
import SQLite3

final class WebtoonDB {
    static let shared = WebtoonDB()

    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "everywebtoon.db")

    private var dbPath: String {
        return "\(AppPaths.basePath)/webtoons.db"
    }

    private init() {
        queue.sync {
            open()
            createSchema()
            migrateFromMetadata()
        }
    }

    // MARK: - Write

    func upsert(_ webtoons: [Webtoon], weekday: String? = nil) {
        guard !webtoons.isEmpty else { return }
        queue.async { [weak self] in
            self?.upsertSync(webtoons, weekday: weekday)
        }
    }

    func setEpisodeCount(id: String, count: Int) {
        queue.async { [weak self] in
            guard let self, let db = self.db else { return }
            let sql = "UPDATE webtoons SET episode_count = ? WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, Int64(count))
            sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Read

    func search(_ query: String, limit: Int = 200) -> [Webtoon] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let pattern = "%\(escapeLike(trimmed))%"
        return queue.sync {
            select(
                sql: "SELECT \(selectColumns) FROM webtoons WHERE title LIKE ?1 ESCAPE '\\' OR author LIKE ?1 ESCAPE '\\' ORDER BY last_seen_at DESC LIMIT ?2",
                bind: { stmt in
                    sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int64(stmt, 2, Int64(limit))
                }
            )
        }
    }

    func allWebtoons(limit: Int = 500) -> [Webtoon] {
        queue.sync {
            select(
                sql: "SELECT \(selectColumns) FROM webtoons ORDER BY last_seen_at DESC LIMIT ?1",
                bind: { stmt in
                    sqlite3_bind_int64(stmt, 1, Int64(limit))
                }
            )
        }
    }

    func find(ids: Set<String>) -> [Webtoon] {
        guard !ids.isEmpty else { return [] }
        return queue.sync {
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")
            return select(
                sql: "SELECT \(selectColumns) FROM webtoons WHERE id IN (\(placeholders))",
                bind: { stmt in
                    for (i, id) in ids.enumerated() {
                        sqlite3_bind_text(stmt, Int32(i + 1), (id as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    }
                }
            )
        }
    }

    func count() -> Int {
        queue.sync {
            guard let db = db else { return 0 }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM webtoons", -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int64(stmt, 0))
        }
    }

    // MARK: - Internal

    private let selectColumns = """
    id, platform, platform_id, title, author, thumbnail_url, star_score,
    genre, description, is_adult, is_finished, is_new, episode_count, update_date
    """

    private func open() {
        let dir = (dbPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            DebugLogger.shared.push(.ERROR, category: "WebtoonDB", message: "open failed: \(dbPath)")
            return
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
    }

    private func createSchema() {
        guard let db = db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS webtoons (
          id TEXT PRIMARY KEY,
          platform TEXT NOT NULL,
          platform_id TEXT NOT NULL,
          title TEXT NOT NULL,
          author TEXT DEFAULT '',
          thumbnail_url TEXT DEFAULT '',
          star_score REAL DEFAULT 0,
          genre TEXT DEFAULT '',
          description TEXT DEFAULT '',
          is_adult INTEGER DEFAULT 0,
          is_finished INTEGER DEFAULT 0,
          is_new INTEGER DEFAULT 0,
          episode_count INTEGER,
          update_date TEXT,
          weekday TEXT,
          first_seen_at REAL,
          last_seen_at REAL,
          updated_at REAL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_platform_id ON webtoons(platform, platform_id);
        CREATE INDEX IF NOT EXISTS idx_title ON webtoons(title);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            DebugLogger.shared.push(.ERROR, category: "WebtoonDB", message: sqliteError())
        }
        migrateAddUpdateDate()
    }

    private func migrateAddUpdateDate() {
        guard let db = db else { return }
        var stmt: OpaquePointer?
        let check = "SELECT COUNT(*) FROM pragma_table_info('webtoons') WHERE name='update_date'"
        guard sqlite3_prepare_v2(db, check, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, sqlite3_column_int64(stmt, 0) == 0 else { return }
        sqlite3_exec(db, "ALTER TABLE webtoons ADD COLUMN update_date TEXT;", nil, nil, nil)
    }

    private func upsertSync(_ webtoons: [Webtoon], weekday: String?) {
        guard let db = db else { return }
        let now = Date().timeIntervalSince1970
        let sql = """
        INSERT INTO webtoons (id, platform, platform_id, title, author, thumbnail_url, star_score,
                              genre, description, is_adult, is_finished, is_new, episode_count, update_date, weekday,
                              first_seen_at, last_seen_at, updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(platform, platform_id) DO UPDATE SET
          title=excluded.title,
          author=excluded.author,
          thumbnail_url=excluded.thumbnail_url,
          star_score=excluded.star_score,
          genre=excluded.genre,
          description=excluded.description,
          is_adult=excluded.is_adult,
          is_finished=excluded.is_finished,
          is_new=excluded.is_new,
          episode_count=CASE WHEN excluded.episode_count IS NOT NULL THEN excluded.episode_count ELSE webtoons.episode_count END,
          update_date=CASE WHEN excluded.update_date IS NOT NULL THEN excluded.update_date ELSE webtoons.update_date END,
          weekday=CASE WHEN excluded.weekday IS NOT NULL THEN excluded.weekday ELSE webtoons.weekday END,
          last_seen_at=excluded.last_seen_at,
          updated_at=excluded.updated_at
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            DebugLogger.shared.push(.ERROR, category: "WebtoonDB", message: sqliteError())
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_exec(db, "BEGIN;", nil, nil, nil)
        for w in webtoons {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, (w.id as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (w.platform.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, (w.platformId as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, (w.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, (w.author as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 6, (w.thumbnailUrl as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 7, w.starScore)
            sqlite3_bind_text(stmt, 8, (w.genre as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 9, (w.description as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 10, w.isAdult ? 1 : 0)
            sqlite3_bind_int64(stmt, 11, w.isFinished ? 1 : 0)
            sqlite3_bind_int64(stmt, 12, w.isNew ? 1 : 0)
            if let count = w.episodeCount {
                sqlite3_bind_int64(stmt, 13, Int64(count))
            } else {
                sqlite3_bind_null(stmt, 13)
            }
            if let updateDate = w.updateDate {
                sqlite3_bind_text(stmt, 14, (updateDate as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 14)
            }
            if let weekday {
                sqlite3_bind_text(stmt, 15, (weekday as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 15)
            }
            sqlite3_bind_double(stmt, 16, now)
            sqlite3_bind_double(stmt, 17, now)
            sqlite3_bind_double(stmt, 18, now)
            sqlite3_step(stmt)
        }
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }

    private func select(sql: String, bind: (OpaquePointer?) -> Void) -> [Webtoon] {
        guard let db = db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            DebugLogger.shared.push(.ERROR, category: "WebtoonDB", message: sqliteError())
            return []
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)

        var result: [Webtoon] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let platformStr = columnText(stmt, 1),
                  let platform = Platform(rawValue: platformStr),
                  let platformId = columnText(stmt, 2),
                  let title = columnText(stmt, 3) else { continue }
            result.append(Webtoon(
                id: columnText(stmt, 0) ?? "\(platformStr)-\(platformId)",
                platform: platform,
                platformId: platformId,
                title: title,
                author: columnText(stmt, 4) ?? "",
                thumbnailUrl: columnText(stmt, 5) ?? "",
                starScore: sqlite3_column_double(stmt, 6),
                genre: columnText(stmt, 7) ?? "",
                description: columnText(stmt, 8) ?? "",
                isAdult: sqlite3_column_int64(stmt, 9) != 0,
                isFinished: sqlite3_column_int64(stmt, 10) != 0,
                isNew: sqlite3_column_int64(stmt, 11) != 0,
                episodeCount: sqlite3_column_type(stmt, 12) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 12)),
                updateDate: columnText(stmt, 13),
                isUpdated: false
            ))
        }
        return result
    }

    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: c)
    }

    private func escapeLike(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private func sqliteError() -> String {
        guard let db = db, let c = sqlite3_errmsg(db) else { return "unknown" }
        return String(cString: c)
    }

    // MARK: - Migration (_metadata/*.json → DB, 1회)

    private func migrateFromMetadata() {
        let migratedKey = "webtoonDB.migrated.v1"
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        UserDefaults.standard.set(true, forKey: migratedKey)

        let dir = "\(AppPaths.basePath)/_metadata"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
        var imported: [Webtoon] = []
        for name in files where name.hasSuffix(".json") {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(dir)/\(name)")),
                  let webtoon = try? JSONDecoder().decode(Webtoon.self, from: data) else { continue }
            imported.append(webtoon)
        }
        if !imported.isEmpty {
            upsertSync(imported, weekday: nil)
            DebugLogger.shared.push(.INFO, category: "WebtoonDB",
                message: "migrated \(imported.count) webtoons from _metadata")
        }
        try? FileManager.default.removeItem(atPath: dir)
    }
}
