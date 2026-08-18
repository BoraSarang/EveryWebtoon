import SwiftUI

struct WebtoonGrid: View {
    let webtoons: [Webtoon]
    var onSelect: ((Webtoon) -> Void)? = nil
    let columns = [GridItem(.adaptive(minimum: 170, maximum: 200), spacing: 14)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(webtoons) { webtoon in
                Button {
                    onSelect?(webtoon)
                } label: {
                    WebtoonGridCell(webtoon: webtoon)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
