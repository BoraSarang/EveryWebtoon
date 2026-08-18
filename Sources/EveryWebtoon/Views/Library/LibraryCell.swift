import SwiftUI

struct LibraryCell: View {
    let webtoon: Webtoon
    let subtitle: String
    var newCount: Int? = nil
    var collectionName: String? = nil
    var onCheckUpdates: (() -> Void)? = nil

    @ObservedObject private var collections = CollectionsManager.shared
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: webtoon.thumbnailUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                }
                .frame(height: 190)
                .cornerRadius(8)
                .clipped()
                .shadow(
                    color: .black.opacity(isHovering ? 0.14 : 0.08),
                    radius: isHovering ? 8 : 4,
                    y: isHovering ? 3 : 2
                )
                .scaleEffect(isHovering ? 1.02 : 1)

                if let newCount, newCount > 0 {
                    Text("+\(newCount)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                        .padding(6)
                        .help("새 회차 \(newCount)개")
                }
            }
            .animation(.easeOut(duration: 0.12), value: isHovering)

            Text(webtoon.title)
                .font(.subheadline.bold())
                .lineLimit(1)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.green)
        }
        .frame(maxWidth: .infinity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            if let name = collectionName {
                Button("\(name)에서 제거", systemImage: "folder.badge.minus") {
                    collections.toggle(webtoon.id, in: name)
                }
            }
            Menu("모음에 추가") {
                CollectionAddMenu(webtoonId: webtoon.id)
            }
            if let onCheckUpdates {
                Button("업데이트 확인", systemImage: "arrow.clockwise") {
                    onCheckUpdates()
                }
            }
            if let url = webtoon.pageURL {
                Button("공식 사이트에서 보기", systemImage: "safari") {
                    openExternalURL(url)
                }
            }
        }
    }
}