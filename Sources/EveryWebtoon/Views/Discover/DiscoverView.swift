import SwiftUI

struct DiscoverView: View {
    @StateObject private var discoverVM = DiscoverViewModel()
    let item: SidebarItem
    var onSelect: ((Webtoon) -> Void)? = nil

    @State private var hasAppeared = false

    private var title: String {
        item.title
    }

    var body: some View {
        listContent
        .navigationTitle(item.title)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task { await discoverVM.load(item: item) }
            }
        }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            if discoverVM.isLoading && discoverVM.webtoons.isEmpty {
                loadingView
            } else if let error = discoverVM.errorMessage, discoverVM.webtoons.isEmpty {
                errorView(error)
            } else if discoverVM.webtoons.isEmpty && !discoverVM.isLoading {
                emptyView
            } else {
                contentView
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("웹툰 목록 불러오는 중...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            Text("데이터 로드 실패")
                .font(.headline)
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("다시 시도") {
                Task { await discoverVM.refresh() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("표시할 웹툰이 없습니다")
                .font(.headline)
            Button("새로고침") {
                Task { await discoverVM.refresh() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.largeTitle.bold())
                    Text("\(discoverVM.webtoons.count)")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("새로고침", systemImage: "arrow.clockwise") {
                        Task { await discoverVM.refresh() }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 5)
                .padding(.bottom, 12)

                if !discoverVM.topWebtoons.isEmpty {
                    topSection
                }
                bottomSection
            }
        }
    }

    private var topSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text(discoverVM.topTitle)
                    .font(.title3.bold())
            }
            .padding(.horizontal, 20)

            topRow(discoverVM.topWebtoons, platform: .naver)

            if !discoverVM.kakaoTopWebtoons.isEmpty {
                topRow(discoverVM.kakaoTopWebtoons, platform: .kakao)
            }
        }
        .padding(.bottom, 20)
    }

    private func topRow(_ webtoons: [Webtoon], platform: Platform) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                PlatformBadge(platform: platform)
                Text(platform == .naver ? "네이버" : "카카오")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(webtoons) { webtoon in
                        Button {
                            onSelect?(webtoon)
                        } label: {
                            WebtoonGridCell(webtoon: webtoon)
                                .frame(width: 155)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("전체 웹툰")
                    .font(.title3.bold())
                Text("\(discoverVM.webtoons.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !discoverVM.orderOptions.isEmpty {
                    Picker("정렬", selection: orderBinding) {
                        ForEach(discoverVM.orderOptions) { option in
                            Text(option.title).tag(option.key)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .help("정렬 방식")
                }
            }
            .padding(.horizontal, 20)

            WebtoonGrid(webtoons: discoverVM.webtoons) { webtoon in
                onSelect?(webtoon)
            }
            .padding(.horizontal, 16)
        }
    }

    private var orderBinding: Binding<String> {
        Binding(
            get: { discoverVM.selectedOrder },
            set: { newOrder in
                if newOrder != discoverVM.selectedOrder {
                    Task { await discoverVM.changeOrder(newOrder) }
                }
            }
        )
    }
}
