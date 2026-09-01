import SwiftUI

struct WebtoonDetailView: View {
    let webtoon: Webtoon
    @StateObject private var viewModel = WebtoonDetailViewModel()
    @EnvironmentObject private var downloadVM: DownloadViewModel
    @ObservedObject private var history = ReadHistoryManager.shared
    @ObservedObject private var collections = CollectionsManager.shared
    @State private var showRangePopover = false
    @State private var rangeStart = 1
    @State private var rangeEnd = 10

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                episodeList
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .navigationTitle(webtoon.title)
        .onAppear {
            Task { await viewModel.load(webtoon: webtoon) }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 20) {
            CachedAsyncImage(url: webtoon.thumbnailUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
            }
            .frame(width: 160, height: 210)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 8) {
                Text(webtoon.title)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                Text(webtoon.author)
                    .font(.body)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Label(String(format: "%.2f", webtoon.starScore),
                          systemImage: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.subheadline)

                    PlatformBadge(platform: webtoon.platform)

                    if webtoon.isAdult {
                        Text("19")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }

                    if webtoon.isFinished {
                        Label("완결", systemImage: "checkmark.circle")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                }

                if !webtoon.description.isEmpty {
                    Text(webtoon.description)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                let defaultName = collections.ensureDefaultCollection()
                collections.toggle(webtoon.id, in: defaultName)
            } label: {
                let inDefault = collections.isIn(webtoon.id, name: collections.defaultCollectionName)
                Label(inDefault ? "담음" : "담기", systemImage: inDefault ? "star.fill" : "star")
            }
            .buttonStyle(.bordered)
            .help("'\(collections.defaultCollectionName)' 모음에 담기/빼기")

            Menu {
                CollectionAddMenu(webtoonId: webtoon.id)
            } label: {
                Image(systemName: "folder")
                    .foregroundColor(collections.isInAny(webtoon.id) ? .yellow : .secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("모음 선택/관리")

            Menu {
                Button("최근 10화 다운로드") {
                    downloadRange(viewModel.episodes.prefix(10).map { $0.episodeNo })
                }
                Button("전체 다운로드") {
                    downloadRange(viewModel.episodes.map { $0.episodeNo })
                }
                Divider()
                Button("범위 선택…") {
                    showRangePopover.toggle()
                }
            } label: {
                Label("다운로드", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .popover(isPresented: $showRangePopover, arrowEdge: .bottom) {
                rangePopover
            }

            if let latest = viewModel.episodes.first {
                Button {
                    openReader(latest.episodeNo)
                } label: {
                    Label("최신 회차 보기", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
            }

            if let oldest = viewModel.episodes.last {
                Button {
                    openReader(oldest.episodeNo)
                } label: {
                    Label("1회부터 보기", systemImage: "play.circle")
                }
                .buttonStyle(.bordered)
            }

            if let lastViewed = history.lastEpisode(webtoonId: webtoon.id) {
                Button {
                    openReader(lastViewed)
                } label: {
                    Label("\(lastViewed)회부터 이어보기", systemImage: "arrow.uturn.forward.circle")
                }
                .buttonStyle(.bordered)
            }

            if let url = webtoon.pageURL {
                Link(destination: url) {
                    Label("공식 사이트에서 보기", systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func openReader(_ episodeNo: Int) {
        ReaderWindowManager.shared.show(
            webtoon: webtoon,
            episodes: viewModel.episodes,
            startEpisode: episodeNo
        )
    }

    private func downloadRange(_ episodeNos: [Int]) {
        downloadVM.startDownload(webtoon: webtoon, episodeNos: episodeNos)
    }

    private var rangeBounds: ClosedRange<Int> {
        guard let latest = viewModel.episodes.first?.episodeNo,
              let oldest = viewModel.episodes.last?.episodeNo,
              oldest <= latest else { return 1...1 }
        return oldest...latest
    }

    private var rangePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("범위 다운로드")
                .font(.headline)
            Stepper(value: $rangeStart, in: rangeBounds) {
                Text("시작: \(rangeStart)화")
            }
            Stepper(value: $rangeEnd, in: rangeBounds) {
                Text("끝: \(rangeEnd)화")
            }
            HStack {
                Spacer()
                Button("다운로드 시작") {
                    let bounds = rangeBounds
                    let nos = Array(max(rangeStart, bounds.lowerBound)...min(rangeEnd, bounds.upperBound))
                    downloadRange(nos)
                    showRangePopover = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(rangeStart > rangeEnd)
            }
        }
        .padding(16)
        .frame(width: 260)
        .onAppear {
            let bounds = rangeBounds
            rangeStart = bounds.lowerBound
            rangeEnd = min(bounds.lowerBound + 9, bounds.upperBound)
        }
    }

    private var episodeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("회차 목록")
                    .font(.title3.bold())
                + Text(" \(viewModel.episodes.count)화")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Spacer()

                Button("새로고침", systemImage: "arrow.clockwise") {
                    Task { await viewModel.refresh() }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("회차 목록 갱신")

                Picker("정렬", selection: $viewModel.sortOrder) {
                    ForEach(EpisodeSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("회차 정렬")
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            } else if let error = viewModel.errorMessage {
                episodeListError(error)
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.displayEpisodes) { episode in
                        EpisodeRow(webtoon: webtoon, episode: episode) { episodeNo in
                            openReader(episodeNo)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func episodeListError(_ message: String) -> some View {
        let isAdultGate = message.contains("AdultVerification")
        return VStack(spacing: 10) {
            Image(systemName: isAdultGate
                ? "person.crop.circle.badge.exclamationmark"
                : "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(isAdultGate ? .orange : .yellow)

            Text(isAdultGate
                ? "성인 콘텐츠입니다"
                : "회차 목록을 불러오지 못했습니다")
                .font(.headline)

            Text(isAdultGate
                ? "연령 인증이 필요해 회차 목록을 표시할 수 없습니다.\n공식 사이트에서 보세요."
                : message)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if isAdultGate, let url = webtoon.pageURL {
                Button {
                    openExternalURL(url)
                } label: {
                    Label("공식 사이트에서 보기", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
