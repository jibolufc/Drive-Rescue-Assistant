import Foundation

enum ByteFormatter {
    static func string(_ value: Int64?) -> String {
        guard let value else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}

enum PathLabel {
    static func compact(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "Not mounted" }
        return path
    }
}
