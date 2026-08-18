import Foundation

final class CollectionsManager: ObservableObject {
    static let shared = CollectionsManager()

    private let defaults = UserDefaults.standard
    private let key = "webtoon_collections"
    private let orderKey = "webtoon_collection_order"
    private let legacyKey = "followed_webtoon_ids"

    @Published private(set) var collections: [String: Set<String>] = [:]
    @Published private(set) var order: [String] = []

    private init() {
        migrateLegacyFollows()
        let stored = (defaults.dictionary(forKey: key) as? [String: [String]]) ?? [:]
        collections = stored.mapValues { Set($0) }
        order = (defaults.stringArray(forKey: orderKey) ?? []).filter { collections[$0] != nil }
        order += collections.keys.filter { !order.contains($0) }.sorted()
        persist()
    }

    private func migrateLegacyFollows() {
        guard let legacy = defaults.stringArray(forKey: legacyKey), !legacy.isEmpty else { return }
        let name = "팔로우"
        var migrated = defaults.dictionary(forKey: key) as? [String: [String]] ?? [:]
        migrated[name, default: []] = Array(Set((migrated[name] ?? []) + legacy))
        defaults.set(migrated, forKey: key)
        defaults.removeObject(forKey: legacyKey)
        if !defaults.stringArray(forKey: orderKey)!.contains(name) {
            var savedOrder = defaults.stringArray(forKey: orderKey) ?? []
            savedOrder.insert(name, at: 0)
            defaults.set(savedOrder, forKey: orderKey)
        }
        DebugLogger.shared.push(.SYSTEM, category: "Collections",
            message: "팔로우 → 모음 마이그레이션",
            meta: "count=\(legacy.count) name=\(name)")
    }

    var names: [String] { order }

    func ids(in name: String) -> Set<String> {
        collections[name] ?? []
    }

    func isIn(_ id: String, name: String) -> Bool {
        collections[name]?.contains(id) ?? false
    }

    func names(containing id: String) -> Set<String> {
        Set(collections.filter { $0.value.contains(id) }.map(\.key))
    }

    func isInAny(_ id: String) -> Bool {
        collections.values.contains { $0.contains(id) }
    }

    var allIds: Set<String> {
        collections.values.reduce(into: Set<String>()) { $0.formUnion($1) }
    }

    func create(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !collections.keys.contains(trimmed) else { return false }
        collections[trimmed] = []
        order.append(trimmed)
        persist()
        return true
    }

    func rename(_ oldName: String, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName, !collections.keys.contains(trimmed) else { return false }
        let ids = collections.removeValue(forKey: oldName) ?? []
        collections[trimmed] = ids
        if let idx = order.firstIndex(of: oldName) {
            order[idx] = trimmed
        }
        persist()
        return true
    }

    func delete(_ name: String) {
        collections.removeValue(forKey: name)
        order.removeAll { $0 == name }
        persist()
    }

    func toggle(_ id: String, in name: String) {
        var ids = collections[name] ?? []
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        collections[name] = ids
        persist()
    }

    private func persist() {
        defaults.set(collections.mapValues { Array($0) }, forKey: key)
        defaults.set(order, forKey: orderKey)
    }
}
