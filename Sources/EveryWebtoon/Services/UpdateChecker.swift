import Foundation
import UserNotifications

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var newEpisodeCounts: [String: Int] = [:]
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var errorMessage: String?

    private var autoCheckInterval: TimeInterval {
        let seconds = AppSettings.shared.updateCheckInterval
        return seconds > 0 ? TimeInterval(seconds) : 0
    }

    func newEpisodeCount(webtoonId: String) -> Int? {
        newEpisodeCounts[webtoonId]
    }

    func checkIfNeeded() async {
        if isChecking { return }
        guard autoCheckInterval > 0 else { return }
        if let last = lastCheckedAt, Date().timeIntervalSince(last) < autoCheckInterval {
            return
        }
        await checkAll()
    }

    func checkAll() async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        let webtoons = LocalWebtoonManager.shared.savedWebtoons()
        let results = await withTaskGroup(of: (String, Int?).self) { group in
            for webtoon in webtoons {
                if webtoon.isAdult { continue }
                group.addTask { [weak self] in
                    guard let self else { return (webtoon.id, nil) }
                    let localMax = LocalWebtoonManager.shared.localEpisodes(for: webtoon.title).max()
                    let lastRead = ReadHistoryManager.shared.lastEpisode(webtoonId: webtoon.id) ?? 0
                    let baseline = max(localMax ?? 0, lastRead)
                    guard baseline > 0 else { return (webtoon.id, nil) }
                    let latest = await self.latestEpisodeNo(webtoon: webtoon)
                    if let latest, latest > baseline {
                        return (webtoon.id, latest - baseline)
                    }
                    return (webtoon.id, nil)
                }
            }
            var result: [String: Int] = [:]
            for await (id, count) in group {
                if let count { result[id] = count }
            }
            return result
        }

        newEpisodeCounts = results
        lastCheckedAt = Date()
        if AppSettings.shared.newEpisodeAlerts {
            sendNotifications(results: results, webtoons: webtoons)
        }
        DebugLogger.shared.push(.SYSTEM, category: "UpdateCheck",
            message: "확인 완료",
            meta: ["checked": webtoons.count, "new": results.count])
    }

    private func sendNotifications(results: [String: Int], webtoons: [Webtoon]) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            for webtoon in webtoons {
                guard let count = results[webtoon.id] else { continue }
                let content = UNMutableNotificationContent()
                content.title = webtoon.title
                content.body = "새 회차 \(count)화가 업데이트되었습니다"
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "update-\(webtoon.id)-\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: nil
                )
                center.add(request)
            }
        }
    }

    private struct LatestCacheEntry {
        let episodeNo: Int
        let fetchedAt: Date
    }

    private var latestCache: [String: LatestCacheEntry] = [:]
    private let latestCacheTTL: TimeInterval = 86400

    private func latestEpisodeNo(webtoon: Webtoon) async -> Int? {
        let id = webtoon.id
        if let entry = latestCache[id], Date().timeIntervalSince(entry.fetchedAt) < latestCacheTTL {
            return entry.episodeNo
        }
        let cacheKey = "episodes-\(webtoon.platform.rawValue)-\(webtoon.platformId)"
        if let cached: [Episode] = await DiscoveryCache.shared.getEpisodes(key: cacheKey) {
            return cached.map(\.episodeNo).max()
        }
        do {
            let result = try await PythonBridge.shared.call(
                action: "latest_episode",
                params: [
                    "platform": webtoon.platform.rawValue,
                    "title_id": webtoon.platformId,
                ],
                timeout: 60
            )
            guard let dict = result as? [String: Any],
                  let episodeNo = dict["episode_no"] as? Int else {
                return nil
            }
            latestCache[id] = LatestCacheEntry(episodeNo: episodeNo, fetchedAt: Date())
            return episodeNo
        } catch {
            DebugLogger.shared.push(.WARN, category: "UpdateCheck",
                message: webtoon.title,
                meta: error.localizedDescription)
            return nil
        }
    }
}
