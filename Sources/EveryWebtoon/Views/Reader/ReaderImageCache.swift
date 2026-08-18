import AppKit

final class ReaderImageCache {
    static let shared = ReaderImageCache()
    private let cache: NSCache<NSString, NSImage>

    private init() {
        cache = NSCache()
        cache.countLimit = 100
        cache.totalCostLimit = 200 * 1024 * 1024
    }

    func image(for path: String) -> NSImage? {
        cache.object(forKey: path as NSString)
    }

    func set(_ image: NSImage, for path: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: path as NSString, cost: cost)
    }
}