import Foundation

enum Platform: String, Codable, CaseIterable {
    case naver = "naver"
    case kakao = "kakao"

    var displayName: String {
        switch self {
        case .naver: return "Naver"
        case .kakao: return "Kakao"
        }
    }

    var badgeColor: String {
        switch self {
        case .naver: return "#1EC800"
        case .kakao: return "#FAE100"
        }
    }
}

enum DownloadStatus: String, Codable {
    case none
    case downloading
    case done
    case failed
    case paused
}

struct Webtoon: Identifiable, Codable, Hashable {
    let id: String
    let platform: Platform
    let platformId: String
    let title: String
    let author: String
    let thumbnailUrl: String
    let starScore: Double
    let genre: String
    let description: String
    let isAdult: Bool
    let isFinished: Bool
    let isNew: Bool
    let episodeCount: Int?
    let updateDate: String?
    let isUpdated: Bool

    var pageURL: URL? {
        switch platform {
        case .naver:
            return URL(string: "https://comic.naver.com/webtoon/list?titleId=\(platformId)")
        case .kakao:
            return URL(string: "https://page.kakao.com/content/\(platformId)")
        }
    }
}

struct WebtoonDetail: Identifiable, Codable {
    let id: String
    let webtoon: Webtoon
    let episodes: [Episode]
    var downloadedEpisodes: [Int]
}

extension Webtoon {
    /// 저장된 DB 값(s)로 누락 필드만 채워 반환 (id/platform/platformId는 유지)
    func merged(with saved: Webtoon?) -> Webtoon {
        guard let s = saved else { return self }
        return Webtoon(
            id: id, platform: platform, platformId: platformId,
            title: title, author: author, thumbnailUrl: thumbnailUrl,
            starScore: starScore, genre: genre, description: description,
            isAdult: isAdult, isFinished: isFinished, isNew: isNew,
            episodeCount: episodeCount ?? s.episodeCount,
            updateDate: updateDate ?? s.updateDate,
            isUpdated: isUpdated || s.isUpdated
        )
    }

    /// 업데이트일만 바꾼 복사본 (같은 필드는 유지)
    func with(updateDate: String) -> Webtoon {
        Webtoon(
            id: id, platform: platform, platformId: platformId,
            title: title, author: author, thumbnailUrl: thumbnailUrl,
            starScore: starScore, genre: genre, description: description,
            isAdult: isAdult, isFinished: isFinished, isNew: isNew,
            episodeCount: episodeCount, updateDate: updateDate,
            isUpdated: isUpdated
        )
    }

    static func from(dict: [String: Any]) -> Webtoon? {
        guard
            let platformStr = dict["platform"] as? String,
            let platform = Platform(rawValue: platformStr),
            let platformId = (dict["platform_id"] ?? dict["platformId"]) as? String,
            let title = dict["title"] as? String
        else { return nil }

        let starScore: Double
        if let s = dict["star_score"] as? Double { starScore = s }
        else if let s = dict["starScore"] as? Double { starScore = s }
        else if let s = dict["star_score"] as? Int { starScore = Double(s) }
        else if let s = dict["starScore"] as? Int { starScore = Double(s) }
        else { starScore = 0 }

        return Webtoon(
            id: "\(platformStr)-\(platformId)",
            platform: platform,
            platformId: platformId,
            title: title,
            author: dict["author"] as? String ?? "",
            thumbnailUrl: (dict["thumbnail_url"] ?? dict["thumbnailUrl"]) as? String ?? "",
            starScore: starScore,
            genre: dict["genre"] as? String ?? "",
            description: dict["description"] as? String ?? "",
            isAdult: (dict["is_adult"] ?? dict["isAdult"]) as? Bool ?? false,
            isFinished: (dict["is_finished"] ?? dict["isFinished"]) as? Bool ?? false,
            isNew: (dict["is_new"] ?? dict["isNew"]) as? Bool ?? false,
            episodeCount: (dict["episode_count"] ?? dict["episodeCount"]) as? Int,
            updateDate: {
                let d = (dict["update_date"] ?? dict["updateDate"]) as? String ?? ""
                return d.isEmpty ? nil : d
            }(),
            isUpdated: (dict["is_updated"] ?? dict["isUpdated"]) as? Bool ?? false
        )
    }
}
