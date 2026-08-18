import SwiftUI

struct SearchResultsView: View {
    @ObservedObject var searchVM: SearchViewModel
    var onSelect: ((Webtoon) -> Void)? = nil

    var body: some View {
        Group {
            if searchVM.results.isEmpty {
                emptyView
            } else {
                resultsGrid
            }
        }
        .navigationTitle("검색 결과")
    }

    private var resultsGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("검색 결과")
                        .font(.title3.bold())
                    Text("\(searchVM.results.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)

                WebtoonGrid(webtoons: searchVM.results) { webtoon in
                    searchVM.recordQuery(searchVM.query)
                    onSelect?(webtoon)
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("'\(searchVM.query.trimmingCharacters(in: .whitespacesAndNewlines))' 검색 결과가 없습니다")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("아직 이 작품이 내 카탈로그에 없을 수 있습니다.\n목록을 탐색하면 자동으로 저장됩니다.")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)

            if !searchVM.recentQueries.isEmpty {
                Divider()
                    .frame(width: 320)
                    .padding(.top, 8)

                HStack {
                    Text("최근 검색어")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("지우기") {
                        searchVM.clearRecents()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .frame(width: 320)

                ForEach(searchVM.recentQueries, id: \.self) { query in
                    Button {
                        searchVM.updateQuery(query)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(query)
                                .font(.callout)
                                .lineLimit(1)
                            Spacer()
                        }
                        .frame(width: 320)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
