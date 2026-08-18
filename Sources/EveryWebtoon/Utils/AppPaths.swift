import Foundation

enum AppPaths {
    static var documentsPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents").path
    }

    static var basePath: String {
        let path = AppSettings.shared.storageBasePath ?? "\(documentsPath)/EveryWebtoon"
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        return path
    }
}
