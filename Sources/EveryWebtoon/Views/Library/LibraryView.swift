import SwiftUI

enum LibrarySort: String, CaseIterable {
    case recentAdd = "최근 추가"
    case title = "제목순"
    case episodeCount = "회차 수"
    case recentRead = "최근 읽음"
}

enum PlatformFilter: String, CaseIterable {
    case all = "전체"
    case naver = "네이버"
    case kakao = "카카오"
}

enum StatusFilter: String, CaseIterable {
    case all = "전체"
    case ongoing = "연재 중"
    case finished = "완결"
}

struct LibraryView: View {
    let item: SidebarItem
    var onSelect: ((Webtoon) -> Void)? = nil

    @ObservedObject private var history = ReadHistoryManager.shared
    @ObservedObject private var collections = CollectionsManager.shared
    @EnvironmentObject private var downloadVM: DownloadViewModel
    @StateObject private var checker = UpdateChecker.shared
    @State private var webtoons: [Webtoon] = []
    @State private var episodeCounts: [String: Int] = [:]
    @State private var sortOrder: LibrarySort = .recentAdd
    @State private var platformFilter: PlatformFilter = .all
    @State private var statusFilter: StatusFilter = .all

    private var isRecent: Bool { item.id == "recent" }
    private var collectionName: String? {
        let prefix = "collection-"
        return item.id.hasPrefix(prefix) ? String(item.id.dropFirst(prefix.count)) : nil
    }
    private var isLibrary: Bool { !isRecent && collectionName == nil }

    private var displayWebtoons: [Webtoon] {
        var list = webtoons
        if platformFilter != .all {
            list = list.filter { $0.platform.rawValue == platformFilter.rawValue }
        }
        switch statusFilter {
        case .all: break
        case .ongoing: list = list.filter { !$0.isFinished }
        case .finished: list = list.filter { $0.isFinished }
        }
        switch sortOrder {
        case .recentAdd:
            break
        case .title:
            list.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .episodeCount:
            list.sort { episodeCounts[$0.title, default: 0] > episodeCounts[$1.title, default: 0] }
        case .recentRead:
            list.sort { (history.lastReadAt[$0.id] ?? 0) > (history.lastReadAt[$1.id] ?? 0) }
        }
        return list
    }

    var body: some View {
        content
            .navigationTitle(
                collectionName ?? (isRecent ? "최근 본 웹툰" : "내 보관함")
            )
            .onAppear { reload() }
            .onChange(of: history.lastReadAt) { _, _ in
                if isRecent { reload() }
            }
            .onChange(of: history.positions) { _, _ in
                if isRecent { reload() }
            }
            .onChange(of: collections.collections) { _, _ in
                if collectionName != nil { reload() }
            }
            .onChange(of: downloadVM.doneCount) { _, _ in
                if isLibrary { refreshEpisodeCounts() }
            }
            .task {
                if isLibrary {
                    await checker.checkIfNeeded()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if webtoons.isEmpty {
            emptyView
        } else {
            grid
        }
    }

    private var grid: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 155, maximum: 185), spacing: 14)],
                    spacing: 24
                ) {
                    ForEach(displayWebtoons) { webtoon in
                        Button {
                            onSelect?(webtoon)
                        } label: {
                            LibraryCell(
                                webtoon: webtoon,
                                subtitle: subtitle(for: webtoon),
                                newCount: checker.newEpisodeCount(webtoonId: webtoon.id),
                                collectionName: collectionName,
                                onCheckUpdates: {
                                    Task { await checker.checkAll() }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Text(collectionName ?? (isRecent ? "최근 본 웹툰" : "내 보관함"))
                .font(.title3.bold())
            if let error = checker.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
            Spacer()
            if isLibrary {
                Picker("", selection: $sortOrder) {
                    ForEach(LibrarySort.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("정렬")

                Picker("", selection: $platformFilter) {
                    ForEach(PlatformFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("플랫폼 필터")

                Picker("", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("상태 필터")

                if checker.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("업데이트 확인", systemImage: "arrow.clockwise") {
                        Task { await checker.checkAll() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: isRecent
                ? "clock.arrow.circlepath"
                : collectionName != nil ? "folder" : "books.vertical")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(isRecent
                ? "최근 본 웹툰이 없습니다"
                : collectionName != nil ? "모음이 비어있습니다" : "내 보관함이 비어있습니다")
                .font(.title3)
                .foregroundColor(.secondary)
            Text(isRecent
                ? "웹툰을 감상하면 여기에 표시됩니다"
                : collectionName != nil
                ? "웹툰 상세에서 '모음에 추가'로 담을 수 있습니다"
                : "웹툰을 다운로드하면 여기에 표시됩니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func subtitle(for webtoon: Webtoon) -> String {
        if isRecent {
            if let progress = history.lastReadProgress(webtoonId: webtoon.id) {
                if progress.percent >= 90 {
                    return "\(progress.episodeNo)화까지 봄"
                }
                return "\(progress.episodeNo)화 · \(progress.percent)%까지 봄"
            }
        }
        if collectionName != nil, !LocalWebtoonManager.shared.hasAnyDownload(webtoonTitle: webtoon.title) {
            return "모음에 추가됨"
        }
        return "내려받음"
    }

    private func reload() {
        let saved = LocalWebtoonManager.shared.savedWebtoons()
        if let name = collectionName {
            webtoons = saved.filter { collections.ids(in: name).contains($0.id) }
        } else if isRecent {
            let savedMap = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
            webtoons = history.recentWebtoonIds.compactMap { savedMap[$0] }
        } else {
            webtoons = saved.filter { LocalWebtoonManager.shared.hasAnyDownload(webtoonTitle: $0.title) }
        }
        refreshEpisodeCounts()
    }

    private func refreshEpisodeCounts() {
        episodeCounts = LocalWebtoonManager.shared.localEpisodeCounts(for: webtoons.map(\.title))
    }
}
