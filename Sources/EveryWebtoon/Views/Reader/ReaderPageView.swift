import SwiftUI
import AppKit

struct ReaderPageView: View {
    let path: String
    let fitWidth: Bool
    var brightness: Double = 0
    var contrast: Double = 1
    var magnifierEnabled = false

    @State private var image: NSImage?
    @State private var hoverLocation: CGPoint?
    @State private var pageSize: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fitWidth ? .fit : .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .brightness(brightness)
                        .contrast(contrast)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .aspectRatio(0.75, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            }

            if magnifierEnabled, let image, let hoverLocation, pageSize != .zero {
                magnifier(image: image, at: hoverLocation)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { pageSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in
                        pageSize = newSize
                    }
            }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
            case .ended:
                hoverLocation = nil
            }
        }
        .task(id: path) {
            if let cached = ReaderImageCache.shared.image(for: path) {
                image = cached
                return
            }
            let loaded = await Task.detached(priority: .userInitiated) {
                ReaderPageView.loadImage(at: path)
            }.value
            if let loaded {
                ReaderImageCache.shared.set(loaded, for: path)
                image = loaded
            }
        }
    }

    private nonisolated static func loadImage(at path: String) -> NSImage? {
        NSImage(contentsOfFile: path)
    }

    private func renderRect(in size: CGSize, imageSize: CGSize, fill: Bool) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = fill
            ? max(size.width / imageSize.width, size.height / imageSize.height)
            : min(size.width / imageSize.width, size.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private func magnifier(image: NSImage, at location: CGPoint) -> some View {
        let rect = renderRect(in: pageSize, imageSize: image.size, fill: !fitWidth)
        guard rect.contains(location) else { return AnyView(EmptyView()) }

        let lensSize: CGFloat = 170
        let lensScale: CGFloat = 2.4
        let displaySize = CGSize(width: rect.width * lensScale, height: rect.height * lensScale)
        let offsetX = (rect.midX - location.x) * lensScale
        let offsetY = (rect.midY - location.y) * lensScale
        let lensX = min(max(location.x + 28, 0), max(0, pageSize.width - lensSize))
        let lensY = max(0, location.y - lensSize - 20)

        return AnyView(
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: displaySize.width, height: displaySize.height)
                .brightness(brightness)
                .contrast(contrast)
                .offset(x: offsetX, y: offsetY)
                .frame(width: lensSize, height: lensSize)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                .shadow(color: .black.opacity(0.5), radius: 6)
                .position(x: lensX + lensSize / 2, y: lensY + lensSize / 2)
                .allowsHitTesting(false)
        )
    }
}