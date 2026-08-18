import SwiftUI

struct WebtoonGridCell: View {
    let webtoon: Webtoon

    @State private var thumbnailRatio: CGFloat?
    @State private var cellWidth: CGFloat = 160
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(
                        url: webtoon.thumbnailUrl
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.4)
                            }
                    } onImageSize: { size in
                        guard size.width > 0 else { return }
                        thumbnailRatio = size.height / size.width
                    }
                    .frame(height: geo.size.width * (thumbnailRatio ?? 1.35))
                    .clipped()
                    .cornerRadius(8)
                    .shadow(
                        color: .black.opacity(isHovering ? 0.14 : 0.08),
                        radius: isHovering ? 8 : 4,
                        y: isHovering ? 3 : 2
                    )
                    .scaleEffect(isHovering ? 1.02 : 1)

                    PlatformBadge(platform: webtoon.platform)
                        .padding(6)
                }
                .onAppear {
                    cellWidth = geo.size.width
                }
            }
            .frame(height: cellWidth * (thumbnailRatio ?? 1.35))
            .animation(.easeOut(duration: 0.12), value: isHovering)

            Text(webtoon.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.yellow)
                Text(String(format: "%.1f", webtoon.starScore))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                if webtoon.isUpdated {
                    Text("UP")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(2)
                }

                if webtoon.isNew {
                    Text("NEW")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(2)
                }

                Spacer()

                if let episodeCount = webtoon.episodeCount {
                    Text("\(episodeCount)화")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                if let updateDate = webtoon.updateDate {
                    Text(shortDate(updateDate))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Menu("모음에 추가") {
                CollectionAddMenu(webtoonId: webtoon.id)
            }
            if let url = webtoon.pageURL {
                Button("공식 사이트에서 보기", systemImage: "safari") {
                    openExternalURL(url)
                }
            }
        }
    }

    private func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count == 3 else { return date }
        return "\(parts[1]).\(parts[2])"
    }
}
