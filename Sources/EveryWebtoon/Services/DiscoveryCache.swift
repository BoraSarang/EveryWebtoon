import Foundation

final class DiscoveryCache {
    static let shared = DiscoveryCache()

    private let fileManager = FileManager.default
    private let cacheDir: String
    private let webtoonTTL: TimeInterval = 86400
    private let episodeTTL: TimeInterval = 86400
    private let ioQueue = DispatchQueue(label: "com.borasarang.everywebtoon.discovery-cache", qos: .utility, attributes: .concurrent)

    private struct Payload<T: Codable>: Codable {
        let timestamp: Date
        let value: T
    }

    private init() {
        cacheDir = "\(AppPaths.basePath)/_cache"
    }

    private func effectiveTTL(_ defaultTTL: TimeInterval) -> TimeInterval {
        if let configured = AppSettings.shared.cacheTTL {
            return configured
        }
        return defaultTTL
    }

    // MARK: - Webtoon lists

    func get(key: String) async -> [Webtoon]? {
        await get(key: key, ttl: effectiveTTL(webtoonTTL))
    }

    func set(key: String, list: [Webtoon]) async {
        await set(key: key, value: list, ttl: effectiveTTL(webtoonTTL))
    }

    // MARK: - Episode lists

    func getEpisodes(key: String) async -> [Episode]? {
        await get(key: key, ttl: effectiveTTL(episodeTTL))
    }

    func setEpisodes(key: String, list: [Episode]) async {
        await set(key: key, value: list, ttl: effectiveTTL(episodeTTL))
    }

    // MARK: - Generic

    private func get<T: Codable>(key: String, ttl: TimeInterval) async -> T? {
        let path = cachePath(key)
        let data = await readData(atPath: path)
        guard let data else { return nil }
        guard let payload = try? JSONDecoder().decode(Payload<T>.self, from: data) else {
            await removeItem(atPath: path)
            return nil
        }
        guard Date().timeIntervalSince(payload.timestamp) < ttl else {
            await removeItem(atPath: path)
            return nil
        }
        return payload.value
    }

    private func set<T: Codable>(key: String, value: T, ttl: TimeInterval) async {
        let payload = Payload(timestamp: Date(), value: value)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ioQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                try? self.fileManager.createDirectory(atPath: self.cacheDir, withIntermediateDirectories: true)
                try? data.write(to: URL(fileURLWithPath: self.cachePath(key)))
                continuation.resume()
            }
        }
    }

    func clear(prefix: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ioQueue.async { [weak self] in
                defer { continuation.resume() }
                guard let self,
                      let files = try? self.fileManager.contentsOfDirectory(atPath: self.cacheDir) else { return }
                for file in files where file.hasPrefix(prefix) {
                    try? self.fileManager.removeItem(atPath: "\(self.cacheDir)/\(file)")
                }
            }
        }
    }

    private func readData(atPath path: String) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            var resumed = false
            let workItem = DispatchWorkItem {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: try? Data(contentsOf: URL(fileURLWithPath: path)))
            }
            ioQueue.async(execute: workItem)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: nil)
            }
        }
    }

    private func removeItem(atPath path: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ioQueue.async {
                try? FileManager.default.removeItem(atPath: path)
                continuation.resume()
            }
        }
    }

    private func cachePath(_ key: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let safe = key.components(separatedBy: invalid).joined(separator: "_")
        return "\(cacheDir)/\(safe).json"
    }
}