import Foundation

enum ProjectPaths {
    static var projectRoot: URL {
        if let override = ProcessInfo.processInfo.environment["DRIVE_RESCUE_PROJECT_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        if let resourceURL = Bundle.main.resourceURL,
           FileManager.default.fileExists(atPath: resourceURL.appendingPathComponent("src/drive_rescue").path) {
            return resourceURL
        }

        var candidate = Bundle.main.bundleURL
        while candidate.path != "/" {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("src/drive_rescue").path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
