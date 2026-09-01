import Foundation

struct OrderOption: Identifiable {
    let key: String
    let title: String
    var id: String { key }
}

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published var topWebtoons: [Webtoon] = []
    @Published var kakaoTopWebtoons: [Webtoon] = []
    @Published var webtoons: [Webtoon] = []
    @Published var topTitle = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedOrder = "user"

    private var currentItem: SidebarItem?
    private let cache = DiscoveryCache.shared

    static let weekKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    static let weekTitles = ["월", "화", "수", "목", "금", "토", "일"]

    var orderOptions: [OrderOption] {
        guard let item = currentItem else { return [] }
        if item.platform == "kakao" {
            if item.category == "ranking" || item.category == "genre" {
                return [
                    OrderOption(key: "hourly", title: "실시간"),
                    OrderOption(key: "daily", title: "일간"),
                    OrderOption(key: "weekly", title: "주간"),
                    OrderOption(key: "monthly", title: "월간"),
                ]
            }
            return []
        }
        if item.category == "ranking" {
            return []
        }
        if item.category == "best_challenge" {
            return [
                OrderOption(key: "update", title: "최신순"),
                OrderOption(key: "view", title: "조회순"),
            ]
        }
        return [
            OrderOption(key: "user", title: "인기순"),
            OrderOption(key: "star", title: "별점순"),
            OrderOption(key: "update", title: "업데이트순"),
            OrderOption(key: "view", title: "조회순"),
        ]
    }

    var selectedOrderDefault: String {
        guard let item = currentItem else { return "user" }
        if item.platform == "kakao", item.category == "ranking" || item.category == "genre" {
            return "hourly"
        }
        return "user"
    }

    func load(item: SidebarItem) async {
        currentItem = item
        selectedOrder = selectedOrderDefault
        await performLoad()
    }

    func changeOrder(_ order: String) async {
        guard currentItem != nil, selectedOrder != order else { return }
        selectedOrder = order
        await performLoad()
    }

    func refresh() async {
        guard let item = currentItem else { return }
        await cache.clear(prefix: item.id)
        await performLoad()
    }

    private func performLoad() async {
        guard let item = currentItem else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if item.id == "all" {
            await loadAllView(item)
        } else if item.platform != nil, item.isGroup {
            await loadPlatformView(item)
        } else if item.platform == "naver", item.category == "weekday" {
            await loadWeekdayView(item)
        } else {
            await loadSingleList(item)
        }
    }

    private func loadPlatformView(_ item: SidebarItem) async {
        let platform = item.platform ?? item.id
        topWebtoons = []
        kakaoTopWebtoons = []
        topTitle = ""

        let bottomKey = "\(item.id)-bottom-\(selectedOrder)"
        if let cached = await cachedList(bottomKey) {
            webtoons = cached
        } else {
            var merged: [Webtoon] = []
            var seen = Set<String>()
            await withTaskGroup(of: [Webtoon].self) { group in
                for (index, day) in Self.weekKeys.enumerated() {
                    group.addTask {
                        let weekParam = platform == "naver" ? day : String(index + 1)
                        let list = await self.discover(category: "weekday", platform: platform,
                                                       params: ["week": weekParam])
                        WebtoonDB.shared.upsert(list, weekday: day)
                        return list
                    }
                }
                for await result in group {
                    for w in result where seen.insert(w.id).inserted {
                        merged.append(w)
                    }
                }
            }
            webtoons = merged
            await saveCache(bottomKey, webtoons)
        }
    }

    private func loadAllView(_ item: SidebarItem) async {
        let today = todayWeekKey()
        let todayTitle = todayTitle(today)
        topTitle = "오늘의 웹툰 (\(todayTitle)요일)"

        let topKey = "\(item.id)-top-\(today)-star"
        if let cached = await cachedList(topKey) {
            topWebtoons = cached
        } else {
            let result = await discover(category: "weekday", platform: "naver",
                                        params: ["week": today, "order": "star"])
            let updatedFirst = result.sorted {
                ($0.isUpdated ? 0 : 1) < ($1.isUpdated ? 0 : 1)
            }
            topWebtoons = Array(updatedFirst.prefix(10))
            WebtoonDB.shared.upsert(topWebtoons, weekday: today)
            await saveCache(topKey, topWebtoons)
        }

        let kakaoTopKey = "\(item.id)-top-\(today)-kakao"
        if let cached = await cachedList(kakaoTopKey) {
            kakaoTopWebtoons = cached
        } else {
            let todayIndex = Self.weekKeys.firstIndex(of: today) ?? 0
            let kakaoResult = await discover(category: "weekday", platform: "kakao",
                                             params: ["week": String(todayIndex + 1)])
            kakaoTopWebtoons = Array(kakaoResult.prefix(10))
            WebtoonDB.shared.upsert(kakaoTopWebtoons, weekday: today)
            await saveCache(kakaoTopKey, kakaoTopWebtoons)
        }

        let bottomKey = "\(item.id)-bottom-\(selectedOrder)"
        if let cached = await cachedList(bottomKey) {
            webtoons = cached
        } else {
            var merged: [Webtoon] = []
            var seen = Set<String>()

            await withTaskGroup(of: [Webtoon].self) { group in
                for (index, day) in Self.weekKeys.enumerated() {
                    group.addTask {
                        var list: [Webtoon] = []
                        let naver = await self.discover(category: "weekday", platform: "naver",
                                                        params: ["week": day, "order": self.selectedOrder])
                        WebtoonDB.shared.upsert(naver, weekday: day)
                        list.append(contentsOf: naver)
                        let kakao = await self.discover(category: "weekday", platform: "kakao",
                                                        params: ["week": String(index + 1)])
                        WebtoonDB.shared.upsert(kakao, weekday: day)
                        list.append(contentsOf: kakao)
                        return list
                    }
                }
                for await result in group {
                    for w in result where seen.insert(w.id).inserted {
                        merged.append(w)
                    }
                }
            }
            webtoons = merged
            await saveCache(bottomKey, webtoons)
        }
    }

    private func loadWeekdayView(_ item: SidebarItem) async {
        let week = item.params["week"] ?? "mon"
        topTitle = "추천 웹툰"
        kakaoTopWebtoons = []

        let topKey = "\(item.id)-top-star"
        if let cached = await cachedList(topKey) {
            topWebtoons = cached
        } else {
            let result = await discover(category: "weekday", platform: "naver",
                                        params: ["week": week, "order": "star"])
            topWebtoons = Array(result.prefix(10))
            WebtoonDB.shared.upsert(topWebtoons, weekday: week)
            await saveCache(topKey, topWebtoons)
        }

        let bottomKey = "\(item.id)-bottom-\(selectedOrder)"
        if let cached = await cachedList(bottomKey) {
            webtoons = cached
        } else {
            webtoons = await discover(category: "weekday", platform: "naver",
                                      params: ["week": week, "order": selectedOrder])
            WebtoonDB.shared.upsert(webtoons, weekday: week)
            await saveCache(bottomKey, webtoons)
        }
    }

    private func loadSingleList(_ item: SidebarItem) async {
        var params = item.params

        if item.platform == "kakao" {
            kakaoTopWebtoons = []
            if item.category == "ranking" || item.category == "genre" {
                params["rank_type"] = selectedOrder

                let key = cacheKey(item, params)
                if let cached = await cachedList(key) {
                    webtoons = cached
                } else {
                    let result = await discoverWithTop(category: item.category, platform: "kakao", params: params)
                    if !result.top.isEmpty {
                        topWebtoons = result.top
                        topTitle = "추천 웹툰"
                    } else {
                        topWebtoons = []
                        topTitle = ""
                    }
                    webtoons = result.main
                    WebtoonDB.shared.upsert(result.top)
                    WebtoonDB.shared.upsert(result.main)
                    await saveCache(key, webtoons)
                }
                return
            }

            topWebtoons = []
            topTitle = ""
            let key = cacheKey(item, params)
            if let cached = await cachedList(key) {
                webtoons = cached
            } else {
                webtoons = await discover(category: item.category, platform: item.platform, params: params)
                WebtoonDB.shared.upsert(webtoons)
                await saveCache(key, webtoons)
            }
            return
        }

        topWebtoons = []
        kakaoTopWebtoons = []
        topTitle = ""

        if item.category == "genre" {
            let topKey = "\(item.id)-top-star"
            if let cached = await cachedList(topKey) {
                topWebtoons = cached
            } else {
                var topParams = item.params
                topParams["order"] = "star"
                let topList = await discover(category: item.category, platform: item.platform, params: topParams)
                topWebtoons = Array(topList.prefix(10))
                WebtoonDB.shared.upsert(topWebtoons)
                await saveCache(topKey, topWebtoons)
            }
            topTitle = "인기 웹툰"
        }

        let order: String
        if item.category == "best_challenge", selectedOrder == "user" {
            order = "update"
        } else {
            order = selectedOrder
        }
        params["order"] = order

        let key = cacheKey(item, params)
        if let cached = await cachedList(key) {
            webtoons = cached
        } else {
            webtoons = await discover(category: item.category, platform: item.platform, params: params)
            WebtoonDB.shared.upsert(webtoons)
            await saveCache(key, webtoons)
        }
    }

    private func cacheKey(_ item: SidebarItem, _ params: [String: String]) -> String {
        let query = params.sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        return "\(item.id)-\(query)"
    }

    private func discoverWithTop(category: String?, platform: String?, params: [String: String]) async -> (top: [Webtoon], main: [Webtoon]) {
        do {
            var requestParams: [String: Any] = [:]
            requestParams["category"] = category ?? "weekday"
            requestParams["platform"] = platform ?? "naver"
            for (key, value) in params {
                requestParams[key] = value
            }
            let result = try await PythonBridge.shared.call(action: "discover", params: requestParams)
            if let dict = result as? [String: Any] {
                let topList = (dict["top"] as? [[String: Any]]) ?? []
                let mainList = (dict["list"] as? [[String: Any]]) ?? []
                return (topList.compactMap { Webtoon.from(dict: $0) },
                        mainList.compactMap { Webtoon.from(dict: $0) })
            }
            return ([], [])
        } catch {
            errorMessage = error.localizedDescription
            DebugLogger.shared.push(.ERROR, category: "Discover",
                message: "Failed: \(error.localizedDescription)")
            return ([], [])
        }
    }

    private func discover(category: String?, platform: String?, params: [String: String]) async -> [Webtoon] {
        do {
            var requestParams: [String: Any] = [:]
            requestParams["category"] = category ?? "weekday"
            requestParams["platform"] = platform ?? "naver"
            for (key, value) in params {
                requestParams[key] = value
            }
            let result = try await PythonBridge.shared.call(action: "discover", params: requestParams)
            if let items = result as? [[String: Any]] {
                if items.isEmpty {
                    DebugLogger.shared.push(.WARN, category: "Discover",
                        message: "빈 결과: \(platform ?? "")/\(category ?? "")",
                        meta: params)
                }
                return enrich(items.compactMap { Webtoon.from(dict: $0) })
            }
            return []
        } catch {
            errorMessage = error.localizedDescription
            DebugLogger.shared.push(.ERROR, category: "Discover",
                message: "Failed: \(error.localizedDescription)")
            return []
        }
    }

    private func cachedList(_ key: String) async -> [Webtoon]? {
        guard let cached = await cache.get(key: key) else { return nil }
        return enrich(cached)
    }

    private func enrich(_ list: [Webtoon]) -> [Webtoon] {
        guard !list.isEmpty else { return [] }
        let targetIDs = Set(list.map { $0.id })
        let saved = WebtoonDB.shared.find(ids: targetIDs)
        var map: [String: Webtoon] = [:]
        for w in saved { map[w.id] = w }
        return list.map { $0.merged(with: map[$0.id]) }
    }

    private func saveCache(_ key: String, _ list: [Webtoon]) async {
        guard !list.isEmpty else { return }
        await cache.set(key: key, list: list)
    }

    private func todayWeekKey() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let index = weekday == 1 ? 6 : weekday - 2
        return Self.weekKeys[index]
    }

    private func todayTitle(_ key: String) -> String {
        guard let index = Self.weekKeys.firstIndex(of: key) else { return "" }
        return Self.weekTitles[index]
    }
}
