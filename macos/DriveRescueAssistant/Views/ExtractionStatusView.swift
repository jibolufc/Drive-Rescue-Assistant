import SwiftUI

struct PreviewSelectionView: View {
    @Bindable var store: DriveStore

    var body: some View {
        if !store.previewFiles.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Preview Selection")
                            .font(.headline)
                        Text(store.previewSelectionSummary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Select All") {
                        store.selectAllPreviewFiles()
                    }
                    .disabled(store.isExtractionActive)
                    Button("Clear") {
                        store.clearPreviewSelection()
                    }
                    .disabled(store.isExtractionActive || store.selectedPreviewPaths.isEmpty)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(store.previewFiles) { file in
                            Toggle(
                                isOn: Binding(
                                    get: { store.selectedPreviewPaths.contains(file.path) },
                                    set: { store.setPreviewFile(file.path, selected: $0) }
                                )
                            ) {
                                HStack(spacing: 12) {
                                    Text(file.path)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(ByteFormatter.string(file.sizeBytes))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            .toggleStyle(.checkbox)
                            .disabled(store.isExtractionActive)
                            .accessibilityLabel(file.path)
                            .accessibilityValue(ByteFormatter.string(file.sizeBytes))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 120, maxHeight: 260)
            }
        }
    }
}

struct ExtractionStatusView: View {
    @Bindable var store: DriveStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress and Report")
                .font(.headline)

            if store.extractionMode == .idle && !hasSummary {
                Text("No extraction is running.")
                    .foregroundStyle(.secondary)
            } else if store.isExtractionActive {
                HStack(alignment: .center, spacing: 10) {
                    if let fraction = store.extractionProgress.fractionCompleted {
                        ProgressView(value: fraction, total: 1)
                            .frame(width: 160)
                            .accessibilityLabel("Extraction progress")
                            .accessibilityValue("\(Int(fraction * 100)) percent")
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Preparing extraction")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusText)
                            .fontWeight(.medium)
                        Text(timingText)
                            .foregroundStyle(.secondary)
                    }
                }
                if let currentFile = store.extractionProgress.currentFile {
                    Text(currentFile)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Current file")
                        .accessibilityValue(currentFile)
                }
            } else {
                Label(statusText, systemImage: completionSystemImage)
                    .foregroundStyle(completionColor)
                    .fontWeight(.medium)
            }

            if let error = store.extractionErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let warning = lowSpaceWarning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasSummary {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    DetailRow("Files seen", "\(store.extractionSummary.filesSeen)")
                    DetailRow("Matched", "\(store.extractionSummary.filesMatched)")
                    DetailRow("Copied", "\(store.extractionSummary.filesCopied)")
                    DetailRow("Skipped", "\(store.extractionSummary.filesSkipped)")
                    DetailRow("Failed", "\(store.extractionSummary.filesFailed)")
                    DetailRow("Planned", ByteFormatter.string(store.extractionSummary.bytesPlanned))
                    if store.extractionSummary.bytesCopied > 0 {
                        DetailRow("Copied bytes", ByteFormatter.string(store.extractionSummary.bytesCopied))
                    }
                    if let archivePath = store.extractionSummary.archivePath {
                        DetailRow("Archive", archivePath)
                    }
                    if let reportPath = store.extractionSummary.reportPath {
                        DetailRow("Report", reportPath)
                    }
                }

                if store.extractionSummary.filesFailed > 0 {
                    Label(store.extractionSummary.failureSummary, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if store.extractionSummary.reportPath != nil {
                    HStack(spacing: 10) {
                        Button {
                            store.openReport()
                        } label: {
                            Label("Open Report", systemImage: "doc.text")
                        }
                        .help("Open the local JSON extraction report")
                        Button {
                            store.revealReport()
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                        }
                        .help("Reveal the report in Finder")
                        Button {
                            store.exportReport()
                        } label: {
                            Label("Export Copy", systemImage: "square.and.arrow.up")
                        }
                        .help("Save another copy of the report")
                    }
                    .accessibilityElement(children: .contain)
                }
            }
        }
    }

    private var hasSummary: Bool {
        store.extractionSummary.filesSeen > 0 ||
        store.extractionSummary.filesMatched > 0 ||
        store.extractionSummary.filesCopied > 0 ||
        store.extractionSummary.filesFailed > 0 ||
        store.extractionSummary.reportPath != nil
    }

    private var statusText: String {
        switch store.extractionMode {
        case .previewing:
            return "Previewing files before extraction."
        case .extracting:
            return "Copying selected files."
        case .cancelling:
            return "Cancelling extraction."
        case .complete:
            return "Extraction complete."
        case .cancelled:
            return "Extraction cancelled."
        case .failed:
            return "Extraction failed."
        case .idle:
            return "No extraction is running."
        }
    }

    private var elapsedText: String {
        let elapsed = Int(store.extractionElapsedSeconds)
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return "\(seconds)s"
    }

    private var timingText: String {
        guard let remaining = estimatedRemainingText else {
            return "Elapsed \(elapsedText)"
        }
        return "Elapsed \(elapsedText) • About \(remaining) remaining"
    }

    private var estimatedRemainingText: String? {
        guard store.extractionElapsedSeconds >= 2,
              let fraction = store.extractionProgress.fractionCompleted,
              fraction > 0,
              fraction < 1 else {
            return nil
        }
        let remaining = store.extractionElapsedSeconds * (1 - fraction) / fraction
        let seconds = Int(remaining)
        if seconds >= 3600 {
            return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
        }
        if seconds >= 60 {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
        return "\(max(seconds, 1))s"
    }

    private var completionSystemImage: String {
        switch store.extractionMode {
        case .complete:
            return store.extractionSummary.filesFailed > 0 ? "exclamationmark.circle" : "checkmark.circle"
        case .cancelled:
            return "xmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        default:
            return "info.circle"
        }
    }

    private var completionColor: Color {
        switch store.extractionMode {
        case .complete where store.extractionSummary.filesFailed == 0:
            return .green
        case .failed:
            return .red
        default:
            return .secondary
        }
    }

    private var lowSpaceWarning: String? {
        guard let freeBytes = store.destinationFreeBytes else { return nil }
        guard store.extractionSummary.bytesPlanned > 0 else { return nil }
        let planned = store.extractionSummary.bytesPlanned
        guard planned > freeBytes else { return nil }
        return "Destination space looks too small for the planned copy (\(ByteFormatter.string(planned)) planned, \(ByteFormatter.string(freeBytes)) free)."
    }
}
