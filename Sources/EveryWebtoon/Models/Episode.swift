import Foundation

struct Episode: Identifiable, Codable, Hashable {
    let id: String
    let webtoonPlatform: String
    let webtoonId: String
    let episodeNo: Int
    let title: String
    let date: String
    let thumbnailUrl: String
    var downloadStatus: DownloadStatus = .none

    var displayTitle: String {
        title.isEmpty ? "\(episodeNo)화" : title
    }

    enum CodingKeys: String, CodingKey {
        case id, webtoonPlatform, webtoonId, episodeNo, title, date, thumbnailUrl
    }

    static func from(dict: [String: Any], webtoonId: String, webtoonPlatform: String) -> Episode? {
        guard let episodeNo = dict["episode_no"] as? Int else { return nil }
        return Episode(
            id: "\(webtoonPlatform)-\(webtoonId)-\(episodeNo)",
            webtoonPlatform: webtoonPlatform,
            webtoonId: webtoonId,
            episodeNo: episodeNo,
            title: dict["title"] as? String ?? "",
            date: dict["date"] as? String ?? "",
            thumbnailUrl: dict["thumbnail_url"] as? String ?? ""
        )
    }
}
