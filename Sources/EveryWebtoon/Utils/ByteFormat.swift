import Foundation

enum ByteFormat {
    static func string(bytes: Int64) -> String {
        let units = ["KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = -1
        repeat {
            value /= 1024
            unitIndex += 1
        } while value >= 1024 && unitIndex < units.count - 1

        if unitIndex < 0 { return "0 KB" }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    static func string(bytes: Int) -> String {
        string(bytes: Int64(bytes))
    }
}