import Foundation

struct DownloadTask: Identifiable {
    let id = UUID()
    let webtoon: Webtoon
    let episodeNo: Int
    var progress: Double
    var currentPage: Int
    var totalPages: Int
    var speed: String
    var eta: String
    var status: DownloadStatus
    var errorMessage: String?
    var currentBytes: Int = 0
    var totalBytes: Int = 0
}

struct DownloadProgress: Codable {
    let taskId: String
    let episodeNo: Int
    let currentPage: Int
    let totalPages: Int
    let speed: String
    let eta: String
    let status: String
    let currentBytes: Int
    let totalBytes: Int
}

extension DownloadTask {
    var sizeText: String {
        let cur = ByteFormat.string(bytes: currentBytes)
        if totalBytes > currentBytes {
            return "\(cur) / \(ByteFormat.string(bytes: totalBytes))"
        }
        return cur
    }

    var pagesText: String {
        totalPages > 0 ? "\(currentPage)/\(totalPages)" : ""
    }
}
