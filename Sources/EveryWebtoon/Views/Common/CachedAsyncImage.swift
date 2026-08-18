import SwiftUI
import CryptoKit

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let fileManager = FileManager.default
    private let cacheDir: String
    private let memory = NSCache<NSString, NSData>()

    private init() {
        cacheDir = "\(AppPaths.basePath)/_cache/images"
        memory.countLimit = 300
    }

    func data(for url: String) -> Data? {
        if let cached = memory.object(forKey: url as NSString) {
            return cached as Data
        }
        let path = filePath(for: url)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        memory.setObject(data as NSData, forKey: url as NSString)
        return data
    }

    func set(_ data: Data, for url: String) {
        memory.setObject(data as NSData, forKey: url as NSString)
        try? fileManager.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: filePath(for: url)))
    }

    private func filePath(for url: String) -> String {
        let digest = SHA256.hash(data: Data(url.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined().prefix(32)
        let ext = (url as NSString).pathExtension.isEmpty ? "jpg" : (url as NSString).pathExtension
        return "\(cacheDir)/\(hex).\(ext)"
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    var onImageSize: ((CGSize) -> Void)? = nil

    @State private var imageData: Data?
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if let data = imageData, let made = makeImage(from: data) {
                content(made.image)
                    .onAppear {
                        onImageSize?(made.size)
                    }
            } else {
                placeholder()
                    .onAppear {
                        guard !hasLoaded else { return }
                        hasLoaded = true
                        loadImage()
                    }
            }
        }
    }

    private func makeImage(from data: Data) -> (image: Image, size: CGSize)? {
        guard let ns = NSImage(data: data) else { return nil }
        return (Image(nsImage: ns), ns.size)
    }

    private func loadImage() {
        loadImageRetry(times: 2)
    }

    private func loadImageRetry(times: Int) {
        guard times > 0 else { return }
        guard let url = URL(string: url) else { return }
        let key = url.absoluteString

        if let cached = ThumbnailCache.shared.data(for: key) {
            imageData = cached
            return
        }

        var req = URLRequest(url: url)
        if url.host?.contains("pstatic.net") == true {
            req.setValue("https://comic.naver.com", forHTTPHeaderField: "Referer")
        } else if url.host?.contains("kakao") == true {
            req.setValue("https://page.kakao.com/", forHTTPHeaderField: "Referer")
        }
        req.timeoutInterval = 15

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let data, error == nil {
                ThumbnailCache.shared.set(data, for: key)
                DispatchQueue.main.async {
                    self.imageData = data
                }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.loadImageRetry(times: times - 1)
            }
        }
        .resume()
    }
}
