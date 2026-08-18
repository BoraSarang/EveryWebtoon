import Foundation

enum EpisodeSortOrder: String, CaseIterable {
    case latestFirst = "최신화부터"
    case oldestFirst = "1화부터"
}

@MainActor
final class WebtoonDetailViewModel: ObservableObject {
    @Published var webtoon: Webtoon?
    @Published var episodes: [Episode] = []
    @Published var sortOrder: EpisodeSortOrder = .latestFirst
    @Published var isLoading = false
    @Published var errorMessage: String?

    var displayEpisodes: [Episode] {
        sortOrder == .latestFirst ? episodes : episodes.reversed()
    }

    func refresh() async {
        guard let webtoon else { return }
        let cacheKey = "episodes-\(webtoon.platform.rawValue)-\(webtoon.platformId)"
        await DiscoveryCache.shared.clear(prefix: cacheKey)
        await load(webtoon: webtoon)
    }

    func load(webtoon: Webtoon) async {
        self.webtoon = webtoon
        isLoading = true
        errorMessage = nil

        let cacheKey = "episodes-\(webtoon.platform.rawValue)-\(webtoon.platformId)"
        if let cached: [Episode] = await DiscoveryCache.shared.getEpisodes(key: cacheKey) {
            episodes = cached
            isLoading = false
            return
        }

        do {
            let result = try await PythonBridge.shared.call(
                action: "get_episodes",
                params: [
                    "platform": webtoon.platform.rawValue,
                    "title_id": webtoon.platformId,
                ]
            )

            if let items = result as? [[String: Any]] {
                episodes = items.compactMap {
                    Episode.from(dict: $0, webtoonId: webtoon.platformId, webtoonPlatform: webtoon.platform.rawValue)
                }
                var updatedWebtoon = webtoon
                if let latestDate = episodes.compactMap({ $0.date }).filter({ !$0.isEmpty }).max(),
                   latestDate != webtoon.updateDate {
                    updatedWebtoon = webtoon.with(updateDate: latestDate)
                    self.webtoon = updatedWebtoon
                }
                WebtoonDB.shared.upsert([updatedWebtoon])
                if !episodes.isEmpty {
                    WebtoonDB.shared.setEpisodeCount(id: webtoon.id, count: episodes.count)
                    await DiscoveryCache.shared.setEpisodes(key: cacheKey, list: episodes)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
