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
    case complete
    case failed
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
