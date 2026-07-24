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
    var extractionSummary = ExtractionSummary()
    var extractionProgress = ExtractionProgressState()
    var previewFiles: [PreviewFile] = []
    var selectedPreviewPaths: Set<String> = []
    var extractionStartedAt: Date?
    var extractionElapsedSeconds: TimeInterval = 0
    var isRefreshing = false
    var isRepairActionRunning = false
    var isCancellingExtraction = false
    var destinationFreeBytes: Int64?
    var extractionErrorMessage: String?

    private let cli: DriveRescueCLI
    private var extractionRunner: DriveRescueCLI.ProcessRunner?
    private var extractionTimer: Timer?

    init(projectRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.cli = DriveRescueCLI(projectRoot: projectRoot)
    }

    var selectedDrive: Drive? {
        guard let selectedDriveID else { return drives.first }
        return drives.first { $0.id == selectedDriveID }
    }

    var isExtractionActive: Bool {
        extractionMode == .previewing || extractionMode == .extracting || extractionMode == .cancelling
    }

    var hasPreviewSelection: Bool {
        !previewFiles.isEmpty && !selectedPreviewPaths.isEmpty
    }

    var previewSelectionSummary: String {
        let selected = previewFiles.filter { selectedPreviewPaths.contains($0.path) }
        let bytes = selected.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return "\(selected.count) selected, \(ByteFormatter.string(bytes))"
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
            clearPreview()
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
            destinationFreeBytes = availableCapacity(at: url)
        }
    }

    @MainActor
    func cancelExtraction() {
        guard let runner = extractionRunner, extractionMode == .previewing || extractionMode == .extracting else {
            return
        }

        isCancellingExtraction = true
        extractionMode = .cancelling
        activityLog = "Cancelling current operation..."
        runner.cancel()
    }

    @MainActor
    func clearPreview() {
        previewFiles = []
        selectedPreviewPaths = []
    }

    @MainActor
    func selectAllPreviewFiles() {
        selectedPreviewPaths = Set(previewFiles.map(\.path))
    }

    @MainActor
    func clearPreviewSelection() {
        selectedPreviewPaths = []
    }

    @MainActor
    func setPreviewFile(_ path: String, selected: Bool) {
        if selected {
            selectedPreviewPaths.insert(path)
        } else {
            selectedPreviewPaths.remove(path)
        }
    }

    @MainActor
    func openReport() {
        guard let reportPath = extractionSummary.reportPath else {
            activityLog = "No report is available yet."
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: reportPath))
    }

    @MainActor
    func revealReport() {
        guard let reportPath = extractionSummary.reportPath else {
            activityLog = "No report is available yet."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: reportPath)])
    }

    @MainActor
    func exportReport() {
        guard let reportPath = extractionSummary.reportPath else {
            activityLog = "No report is available yet."
            return
        }

        let sourceURL = URL(fileURLWithPath: reportPath)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = sourceURL.lastPathComponent
        panel.canCreateDirectories = true
        panel.message = "Save a copy of the local extraction report."

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }
        do {
            let reportData = try Data(contentsOf: sourceURL)
            try reportData.write(to: destinationURL, options: .atomic)
            activityLog = "Report exported to \(destinationURL.path)."
        } catch {
            activityLog = "The report could not be exported: \(error.localizedDescription)"
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
        if !dryRun && selectedPreviewPaths.isEmpty {
            activityLog = "Preview the source and select at least one file before copying."
            return
        }
        extractionMode = dryRun ? .previewing : .extracting
        isCancellingExtraction = false
        extractionSummary = ExtractionSummary(compressed: compressOutput, dryRun: dryRun)
        extractionProgress = ExtractionProgressState(phase: dryRun ? "planning" : "preparing")
        extractionErrorMessage = nil
        if dryRun {
            clearPreview()
        }
        extractionStartedAt = Date()
        extractionElapsedSeconds = 0
        startExtractionTimer()
        activityLog = dryRun ? "Previewing files..." : "Copying files..."

        var selectionFile: URL?
        do {
            if !dryRun {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("drive-rescue-selection-\(UUID().uuidString).json")
                let payload = try JSONEncoder().encode(selectedPreviewPaths.sorted())
                try payload.write(to: url, options: .atomic)
                selectionFile = url
            }
            defer {
                if let selectionFile {
                    try? FileManager.default.removeItem(at: selectionFile)
                }
            }

            let runner = try cli.makeExtractionRunner(
                source: source,
                destination: destinationPath,
                dryRun: dryRun,
                scope: extractionScope,
                compress: compressOutput,
                selectionFile: selectionFile
            )
            extractionRunner = runner
            let output = try await runner.run { [weak self] line in
                Task { @MainActor in
                    self?.handleCLIEvent(line)
                }
            }
            extractionRunner = nil
            stopExtractionTimer()
            extractionSummary = Self.parseExtractionSummary(from: output, compressed: compressOutput, dryRun: dryRun)
            if dryRun {
                previewFiles = Self.parsePreviewFiles(from: output)
                selectAllPreviewFiles()
            }
            if isCancellingExtraction || extractionSummary.status == "cancelled" {
                extractionMode = .cancelled
                activityLog = Self.buildCancellationMessage(summary: extractionSummary, elapsed: extractionElapsedSeconds)
                isCancellingExtraction = false
            } else {
                extractionMode = .complete
                activityLog = Self.buildCompletionMessage(summary: extractionSummary, elapsed: extractionElapsedSeconds)
            }
        } catch {
            extractionRunner = nil
            stopExtractionTimer()
            if isCancellingExtraction {
                extractionMode = .cancelled
                activityLog = "Extraction cancelled."
                isCancellingExtraction = false
            } else {
                extractionMode = .failed
                activityLog = error.localizedDescription
            }
        }
    }

    private func isDestinationInsideSource(source: String, destination: String) -> Bool {
        let sourcePath = NSString(string: source).standardizingPath
        let destinationPath = NSString(string: destination).standardizingPath
        return destinationPath == sourcePath || destinationPath.hasPrefix(sourcePath + "/")
    }

    private func availableCapacity(at url: URL) -> Int64? {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            return nil
        }
    }

    private func startExtractionTimer() {
        stopExtractionTimer()
        extractionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.extractionStartedAt else { return }
                self.extractionElapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopExtractionTimer() {
        extractionTimer?.invalidate()
        extractionTimer = nil
    }

    @MainActor
    private func handleCLIEvent(_ line: String) {
        guard line.hasPrefix("DRA_EVENT ") else { return }
        let json = String(line.dropFirst("DRA_EVENT ".count))
        guard let event = try? JSONDecoder().decode(DriveRescueCLIEvent.self, from: Data(json.utf8)) else { return }

        switch event.event {
        case "progress":
            extractionProgress = ExtractionProgressState(
                phase: event.phase ?? extractionProgress.phase,
                currentFile: event.currentPath,
                filesCompleted: event.filesCompleted ?? extractionProgress.filesCompleted,
                filesTotal: event.filesTotal ?? extractionProgress.filesTotal,
                bytesCompleted: event.bytesCompleted ?? extractionProgress.bytesCompleted,
                bytesTotal: event.bytesTotal ?? extractionProgress.bytesTotal
            )
            if let total = event.bytesTotal {
                extractionSummary.bytesPlanned = total
            }
        case "summary":
            applySummaryEvent(event)
        case "error":
            extractionErrorMessage = event.message
            if event.code == "insufficient_space" {
                extractionSummary.bytesPlanned = event.requiredBytes ?? extractionSummary.bytesPlanned
                destinationFreeBytes = event.availableBytes ?? destinationFreeBytes
            }
        default:
            break
        }
    }

    @MainActor
    private func applySummaryEvent(_ event: DriveRescueCLIEvent) {
        extractionSummary.status = event.status ?? extractionSummary.status
        extractionSummary.filesSeen = event.filesSeen ?? extractionSummary.filesSeen
        extractionSummary.filesMatched = event.filesMatched ?? extractionSummary.filesMatched
        extractionSummary.filesFiltered = event.filesFiltered ?? extractionSummary.filesFiltered
        extractionSummary.filesCopied = event.filesCopied ?? extractionSummary.filesCopied
        extractionSummary.filesSkipped = event.filesSkipped ?? extractionSummary.filesSkipped
        extractionSummary.filesFailed = event.filesFailed ?? extractionSummary.filesFailed
        extractionSummary.bytesPlanned = event.bytesPlanned ?? extractionSummary.bytesPlanned
        extractionSummary.bytesCopied = event.bytesCopied ?? extractionSummary.bytesCopied
        extractionSummary.archivePath = event.archivePath
        extractionSummary.reportPath = event.reportPath
    }

    private static func parsePreviewFiles(from output: String) -> [PreviewFile] {
        var files: [PreviewFile] = []
        for rawLine in output.split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("DRA_EVENT "),
                  let event = try? JSONDecoder().decode(
                      DriveRescueCLIEvent.self,
                      from: Data(line.dropFirst("DRA_EVENT ".count).utf8)
                  ),
                  event.event == "progress",
                  event.phase == "preview_item",
                  let path = event.currentPath else {
                continue
            }
            files.append(PreviewFile(path: path, sizeBytes: event.currentSize ?? 0))
        }
        return files
    }

    private static func parseExtractionSummary(from output: String, compressed: Bool, dryRun: Bool) -> ExtractionSummary {
        var summary = ExtractionSummary(compressed: compressed, dryRun: dryRun)
        for rawLine in output.split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("DRA_EVENT "),
               let event = try? JSONDecoder().decode(
                   DriveRescueCLIEvent.self,
                   from: Data(line.dropFirst("DRA_EVENT ".count).utf8)
               ),
               event.event == "summary" {
                summary.status = event.status ?? summary.status
                summary.filesSeen = event.filesSeen ?? summary.filesSeen
                summary.filesMatched = event.filesMatched ?? summary.filesMatched
                summary.filesFiltered = event.filesFiltered ?? summary.filesFiltered
                summary.filesCopied = event.filesCopied ?? summary.filesCopied
                summary.filesSkipped = event.filesSkipped ?? summary.filesSkipped
                summary.filesFailed = event.filesFailed ?? summary.filesFailed
                summary.bytesPlanned = event.bytesPlanned ?? summary.bytesPlanned
                summary.bytesCopied = event.bytesCopied ?? summary.bytesCopied
                summary.archivePath = event.archivePath
                summary.reportPath = event.reportPath
            } else if line.hasPrefix("Files seen:") {
                summary.filesSeen = valueAfterColon(line)
            } else if line.hasPrefix("Files matched:") {
                summary.filesMatched = valueAfterColon(line)
            } else if line.hasPrefix("Files filtered out:") {
                summary.filesFiltered = valueAfterColon(line)
            } else if line.hasPrefix("Files copied:") {
                summary.filesCopied = valueAfterColon(line)
            } else if line.hasPrefix("Files planned:") {
                summary.filesCopied = valueAfterColon(line)
            } else if line.hasPrefix("Files skipped:") {
                summary.filesSkipped = valueAfterColon(line)
            } else if line.hasPrefix("Files failed:") {
                summary.filesFailed = valueAfterColon(line)
            } else if line.hasPrefix("Bytes planned:") {
                summary.bytesPlanned = bytesValueAfterColon(line)
            } else if line.hasPrefix("Bytes copied:") {
                summary.bytesCopied = bytesValueAfterColon(line)
            } else if line.hasPrefix("Archive:") {
                summary.archivePath = stringAfterColon(line)
            } else if line.hasPrefix("Report:") {
                summary.reportPath = stringAfterColon(line)
            }
        }
        return summary
    }

    private static func buildCompletionMessage(summary: ExtractionSummary, elapsed: TimeInterval) -> String {
        let elapsedString = Self.formatElapsed(elapsed)
        var lines = [summary.fileCountSummary, summary.failureSummary, "Elapsed: \(elapsedString)"]
        if summary.bytesCopied > 0 {
            lines.append("Bytes copied: \(ByteFormatter.string(summary.bytesCopied))")
        } else if summary.bytesPlanned > 0 {
            lines.append("Bytes planned: \(ByteFormatter.string(summary.bytesPlanned))")
        }
        if let archivePath = summary.archivePath, !archivePath.isEmpty {
            lines.append("Archive: \(archivePath)")
        }
        if let reportPath = summary.reportPath, !reportPath.isEmpty {
            lines.append("Report: \(reportPath)")
        }
        return lines.joined(separator: "\n")
    }

    private static func buildCancellationMessage(summary: ExtractionSummary, elapsed: TimeInterval) -> String {
        var lines = ["Extraction cancelled safely.", "Elapsed: \(formatElapsed(elapsed))"]
        if summary.filesCopied > 0 {
            lines.append("\(summary.filesCopied) completed file\(summary.filesCopied == 1 ? "" : "s") were kept.")
        }
        if summary.compressed {
            lines.append("The incomplete ZIP archive was removed.")
        }
        if let reportPath = summary.reportPath {
            lines.append("Report: \(reportPath)")
        }
        return lines.joined(separator: "\n")
    }

    private static func formatElapsed(_ elapsed: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = elapsed >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        return formatter.string(from: elapsed) ?? "\(Int(elapsed))s"
    }

    private static func valueAfterColon(_ line: String) -> Int {
        let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).dropFirst().first ?? ""
        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static func bytesValueAfterColon(_ line: String) -> Int64 {
        let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).dropFirst().first ?? ""
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = trimmed.split(separator: " ")
        guard let amountString = pieces.first, let amount = Double(amountString), let unit = pieces.dropFirst().first else {
            return Int64(trimmed) ?? 0
        }

        let multiplier: Double
        switch unit.uppercased() {
        case "B":
            multiplier = 1
        case "KB":
            multiplier = 1024
        case "MB":
            multiplier = 1024 * 1024
        case "GB":
            multiplier = 1024 * 1024 * 1024
        case "TB":
            multiplier = 1024 * 1024 * 1024 * 1024
        case "PB":
            multiplier = 1024 * 1024 * 1024 * 1024 * 1024
        default:
            return Int64(amount)
        }
        return Int64(amount * multiplier)
    }

    private static func stringAfterColon(_ line: String) -> String {
        String(line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).dropFirst().first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
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
