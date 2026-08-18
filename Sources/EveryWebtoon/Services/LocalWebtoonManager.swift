import Foundation

final class LocalWebtoonManager {
    static let shared = LocalWebtoonManager()

    private let fileManager = FileManager.default
    private let documentsPath: String

    init() {
        documentsPath = AppPaths.basePath
    }

    var downloadBasePath: String { documentsPath }

    func saveWebtoon(_ webtoon: Webtoon) {
        WebtoonDB.shared.upsert([webtoon])
    }

    func savedWebtoons() -> [Webtoon] {
        WebtoonDB.shared.allWebtoons()
    }

    func localWebtoons() -> [String] {
        guard let items = try? fileManager.contentsOfDirectory(atPath: documentsPath) else {
            return []
        }
        return items.filter { name in
            var isDir: ObjCBool = false
            let path = "\(documentsPath)/\(name)"
            fileManager.fileExists(atPath: path, isDirectory: &isDir)
            return isDir.boolValue && name != "_metadata"
        }
    }

    static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    func hasAnyDownload(webtoonTitle: String) -> Bool {
        let dir = "\(documentsPath)/\(Self.sanitize(webtoonTitle))"
        guard let items = try? fileManager.contentsOfDirectory(atPath: dir) else { return false }
        return items.contains { name in
            guard let episodeNo = Int(name) else { return false }
            return isEpisodeDownloaded(webtoonTitle: webtoonTitle, episodeNo: episodeNo)
        }
    }

    func localEpisodes(for webtoonTitle: String) -> [Int] {
        let dir = "\(documentsPath)/\(Self.sanitize(webtoonTitle))"
        guard let items = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }
        return items.compactMap { Int($0) }.sorted()
    }

    func localEpisodeCounts(for webtoonTitles: [String]) -> [String: Int] {
        webtoonTitles.reduce(into: [:]) { result, title in
            result[title] = localEpisodes(for: title).count
        }
    }

    func isDownloadIncomplete(webtoonTitle: String, episodeNo: Int) -> Bool {
        fileManager.fileExists(atPath: "\(episodePath(webtoonTitle: webtoonTitle, episodeNo: episodeNo))/.partial")
    }

    func isEpisodeDownloaded(webtoonTitle: String, episodeNo: Int) -> Bool {
        let dir = episodePath(webtoonTitle: webtoonTitle, episodeNo: episodeNo)
        if fileManager.fileExists(atPath: "\(dir)/.done") {
            return true
        }
        guard !pagePaths(webtoonTitle: webtoonTitle, episodeNo: episodeNo).isEmpty else {
            return false
        }
        return !fileManager.fileExists(atPath: "\(dir)/.partial")
    }

    func episodePath(webtoonTitle: String, episodeNo: Int) -> String {
        "\(documentsPath)/\(Self.sanitize(webtoonTitle))/\(String(format: "%03d", episodeNo))"
    }

    func pagePaths(webtoonTitle: String, episodeNo: Int) -> [String] {
        let dir = episodePath(webtoonTitle: webtoonTitle, episodeNo: episodeNo)
        guard let items = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }
        return items
            .filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg") || $0.hasSuffix(".png") }
            .sorted()
            .map { "\(dir)/\($0)" }
    }
}
