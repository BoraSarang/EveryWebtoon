import SwiftUI

struct SearchRecentsView: View {
    @ObservedObject var searchVM: SearchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("최근 검색어")
                    .font(.title3.bold())
                Spacer()
                if !searchVM.recentQueries.isEmpty {
                    Button("지우기") {
                        searchVM.clearRecents()
                    }
                    .font(.callout)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            if searchVM.recentQueries.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("최근 검색어가 없습니다")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("검색 결과를 열면 자동으로 저장됩니다")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(searchVM.recentQueries, id: \.self) { query in
                            Button {
                                searchVM.updateQuery(query)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    Text(query)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("최근 검색어")
    }
}
