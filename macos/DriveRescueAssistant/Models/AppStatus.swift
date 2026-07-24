enum DriveHealthStatus: String {
    case canExtract = "Can extract"
    case readOnly = "Read-only"
    case notMounted = "Not mounted"
    case timeMachine = "Time Machine"
    case locked = "Locked"
    case unknown = "Unknown"
}

enum ExtractionMode {
    case idle
    case previewing
    case extracting
    case cancelling
    case complete
    case cancelled
    case failed
}

struct ExtractionSummary: Equatable {
    var status: String = "idle"
    var filesSeen: Int = 0
    var filesMatched: Int = 0
    var filesFiltered: Int = 0
    var filesCopied: Int = 0
    var filesSkipped: Int = 0
    var filesFailed: Int = 0
    var bytesPlanned: Int64 = 0
    var bytesCopied: Int64 = 0
    var compressed: Bool = false
    var dryRun: Bool = false
    var archivePath: String?
    var reportPath: String?
    var failures: [String] = []

    var fileCountSummary: String {
        if dryRun {
            return "Previewed \(filesMatched) matched file\(filesMatched == 1 ? "" : "s")."
        }
        return "Copied \(filesCopied) file\(filesCopied == 1 ? "" : "s")."
    }

    var failureSummary: String {
        guard filesFailed > 0 else { return "No file failures." }
        return "\(filesFailed) file\(filesFailed == 1 ? "" : "s") could not be read. Other readable files were kept."
    }
}

struct ExtractionProgressState: Equatable {
    var phase: String = "idle"
    var currentFile: String?
    var filesCompleted: Int = 0
    var filesTotal: Int = 0
    var bytesCompleted: Int64 = 0
    var bytesTotal: Int64 = 0

    var fractionCompleted: Double? {
        if bytesTotal > 0 {
            return min(max(Double(bytesCompleted) / Double(bytesTotal), 0), 1)
        }
        if filesTotal > 0 {
            return min(max(Double(filesCompleted) / Double(filesTotal), 0), 1)
        }
        return nil
    }
}

struct PreviewFile: Identifiable, Hashable {
    let path: String
    let sizeBytes: Int64

    var id: String { path }
}

enum WorkflowMode: String, CaseIterable, Identifiable {
    case driveRescue = "External Drive Rescue"
    case macTransfer = "Move From This Mac"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .driveRescue:
            return "externaldrive"
        case .macTransfer:
            return "macbook.and.arrow.down"
        }
    }
}
