import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Webtoon] = []
    @Published var isSearching = false
    @Published private(set) var recentQueries: [String] = []

    private var debounceTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let recentKey = "search_recent_queries"

    init() {
        recentQueries = defaults.stringArray(forKey: recentKey) ?? []
    }

    func recordQuery(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentQueries.removeAll { $0 == trimmed }
        recentQueries.insert(trimmed, at: 0)
        if recentQueries.count > 10 {
            recentQueries = Array(recentQueries.prefix(10))
        }
        defaults.set(recentQueries, forKey: recentKey)
    }

    func clearRecents() {
        recentQueries = []
        defaults.removeObject(forKey: recentKey)
    }

    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updateQuery(_ newQuery: String) {
        query = newQuery
        debounceTask?.cancel()
        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            let found = await Task.detached(priority: .userInitiated) {
                WebtoonDB.shared.search(trimmed)
            }.value
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }

    func clear() {
        debounceTask?.cancel()
        query = ""
        results = []
        isSearching = false
    }
}
