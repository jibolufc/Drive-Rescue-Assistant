import AppKit
import Foundation
import Observation

@Observable
final class DriveStore {
    var drives: [Drive] = []
    var workflow: WorkflowMode = .driveRescue
    var selectedDriveID: Drive.ID?
    var sourcePath: String = ""
    var destinationPath: String = ""
    var extractionScope: ExtractionScope = .all
    var compressOutput = false
    var activityLog: String = "Connect or select a drive to begin."
    var extractionMode: ExtractionMode = .idle
    var isRefreshing = false
    var isRepairActionRunning = false

    private let cli: DriveRescueCLI

    init(projectRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.cli = DriveRescueCLI(projectRoot: projectRoot)
    }

    var selectedDrive: Drive? {
        guard let selectedDriveID else { return drives.first }
        return drives.first { $0.id == selectedDriveID }
    }

    @MainActor
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let scanned = try await cli.scan()
            drives = scanned
            if selectedDriveID == nil || !scanned.contains(where: { $0.id == selectedDriveID }) {
                selectedDriveID = scanned.first?.id
            }
            activityLog = scanned.isEmpty ? "No mounted or visible external drives found." : "Found \(scanned.count) drive\(scanned.count == 1 ? "" : "s")."
        } catch {
            activityLog = error.localizedDescription
        }
    }

    @MainActor
    func chooseSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        panel.message = "Choose the folder on this Mac that should be copied."

        if panel.runModal() == .OK, let url = panel.url {
            sourcePath = url.path
        }
    }

    @MainActor
    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose where recovered files should be copied."

        if panel.runModal() == .OK, let url = panel.url {
            destinationPath = url.path
        }
    }

    @MainActor
    func tryReadOnlyMount() async {
        guard let deviceID = selectedDrive?.deviceID else {
            activityLog = "Select a drive with a device identifier first."
            return
        }

        isRepairActionRunning = true
        activityLog = "Trying read-only mount..."
        defer { isRepairActionRunning = false }

        do {
            let output = try await runDiskutil(["mount", "readOnly", deviceID])
            activityLog = output.isEmpty ? "Read-only mount command completed. Refreshing drives..." : output
            await refresh()
        } catch {
            activityLog = error.localizedDescription
        }
    }

    @MainActor
    func openDiskUtility() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Disk Utility.app")
        NSWorkspace.shared.open(url)
        activityLog = "Opened Disk Utility. Select the drive and try Mount or First Aid."
    }

    @MainActor
    func copyTerminalCommands() {
        guard let drive = selectedDrive, let deviceID = drive.deviceID else {
            activityLog = "Select a drive with a device identifier first."
            return
        }

        let commands = [
            "diskutil info \(deviceID)",
            "diskutil mount readOnly \(deviceID)",
            "diskutil verifyVolume \(deviceID)"
        ].joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(commands, forType: .string)
        activityLog = "Copied safe diagnostic commands for \(drive.name). Run verify before any repair."
    }

    @MainActor
    func previewExtraction() async {
        await runDriveExtraction(dryRun: true)
    }

    @MainActor
    func extractFiles() async {
        await runDriveExtraction(dryRun: false)
    }

    @MainActor
    func previewTransfer() async {
        await runTransferExtraction(dryRun: true)
    }

    @MainActor
    func transferFiles() async {
        await runTransferExtraction(dryRun: false)
    }

    @MainActor
    private func runDriveExtraction(dryRun: Bool) async {
        guard let drive = selectedDrive else {
            activityLog = "Select a drive first."
            return
        }
        guard let source = drive.mountPath else {
            activityLog = "Drive is visible but not mounted. Extraction is unavailable until it is mounted."
            return
        }
        guard !destinationPath.isEmpty else {
            activityLog = "Choose a destination folder first."
            return
        }

        await runExtraction(source: source, dryRun: dryRun)
    }

    @MainActor
    private func runTransferExtraction(dryRun: Bool) async {
        guard !sourcePath.isEmpty else {
            activityLog = "Choose a source folder on this Mac first."
            return
        }
        guard !destinationPath.isEmpty else {
            activityLog = "Choose an external destination folder first."
            return
        }

        await runExtraction(source: sourcePath, dryRun: dryRun)
    }

    @MainActor
    private func runExtraction(source: String, dryRun: Bool) async {
        guard !isDestinationInsideSource(source: source, destination: destinationPath) else {
            activityLog = "Choose a destination outside the source folder."
            return
        }

        extractionMode = dryRun ? .previewing : .extracting
        activityLog = dryRun ? "Previewing files..." : "Copying files..."

        do {
            let output = try await cli.extract(
                source: source,
                destination: destinationPath,
                dryRun: dryRun,
                scope: extractionScope,
                compress: compressOutput
            )
            extractionMode = .complete
            activityLog = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            extractionMode = .failed
            activityLog = error.localizedDescription
        }
    }

    private func isDestinationInsideSource(source: String, destination: String) -> Bool {
        let sourcePath = NSString(string: source).standardizingPath
        let destinationPath = NSString(string: destination).standardizingPath
        return destinationPath == sourcePath || destinationPath.hasPrefix(sourcePath + "/")
    }

    private func runDiskutil(_ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let combined = [output, error]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")

                if process.terminationStatus == 0 {
                    continuation.resume(returning: combined)
                } else {
                    continuation.resume(throwing: DiskUtilityError.failed(combined.isEmpty ? "diskutil command failed." : combined))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private enum DiskUtilityError: Error, LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}
