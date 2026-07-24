import SwiftUI

struct DriveDetailContent: View {
    @Bindable var store: DriveStore
    let drive: Drive

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                safetyNotes
                metadata
                repairOptions
                extraction
                PreviewSelectionView(store: store)
                ExtractionStatusView(store: store)
                activity
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(drive.name)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Spacer()
                StatusBadge(label: status.rawValue, status: status)
            }

            Text(primaryRecommendation)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var safetyNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety Notes")
                .font(.headline)
            ForEach(notes, id: \.self) { note in
                Label(note, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var metadata: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
            DetailRow("Mount", PathLabel.compact(drive.mountPath))
            DetailRow("Device", drive.deviceID ?? "Unknown")
            DetailRow("Format", drive.filesystem?.uppercased() ?? "Unknown")
            DetailRow("Size", ByteFormatter.string(drive.sizeBytes))
            DetailRow("Free", drive.mountPath == nil ? "Unknown" : ByteFormatter.string(drive.freeBytes))
            DetailRow("Writable", writableText)
        }
    }

    private var extraction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extraction")
                .font(.headline)

            Picker("Files", selection: $store.extractionScope) {
                ForEach(ExtractionScope.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!canChooseDestination || store.isExtractionActive)
            .accessibilityLabel("File types to extract")
            .onChange(of: store.extractionScope) { _, _ in
                store.clearPreview()
            }

            Toggle(isOn: $store.compressOutput) {
                Label("Compress to ZIP", systemImage: "archivebox")
            }
            .toggleStyle(.checkbox)
            .disabled(!canChooseDestination || store.isExtractionActive)
            .accessibilityHint("Creates one ZIP archive at the destination")

            HStack(spacing: 10) {
                Text(destinationText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(destinationTextStyle)

                Spacer()

                Button {
                    store.chooseDestination()
                } label: {
                    Label("Choose", systemImage: "folder")
                }
                .disabled(!canChooseDestination || store.isExtractionActive)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await store.previewExtraction() }
                } label: {
                    Label("Preview", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!canExtract || store.isExtractionActive)
                .keyboardShortcut("p", modifiers: [.command, .shift])

                if canExtract {
                    Button {
                        Task { await store.extractFiles() }
                    } label: {
                        Label("Extract Files", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isExtractionActive || !store.hasPreviewSelection)
                    .help(store.hasPreviewSelection ? "Extract the selected preview items" : "Preview and select files first")
                    .keyboardShortcut(.return, modifiers: [.command])
                } else {
                    Button {
                        store.activityLog = extractionBlockedMessage
                    } label: {
                        Label("Extract Files", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                }

                if store.isExtractionActive {
                    Button {
                        store.cancelExtraction()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
    }

    private var repairOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repair Options")
                .font(.headline)

            Text(repairSummary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button {
                    Task { await store.tryReadOnlyMount() }
                } label: {
                    Label("Try Read-Only Mount", systemImage: "externaldrive.badge.plus")
                }
                .disabled(!canAttemptMount || store.isRepairActionRunning)

                Button {
                    store.openDiskUtility()
                } label: {
                    Label("Open Disk Utility", systemImage: "stethoscope")
                }

                Button {
                    store.copyTerminalCommands()
                } label: {
                    Label("Copy Commands", systemImage: "terminal")
                }
                .disabled(drive.deviceID == nil)
            }
        }
    }


    private var activity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity")
                .font(.headline)
            Text(store.activityLog)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var status: DriveHealthStatus {
        if drive.mountPath == nil { return .notMounted }
        if drive.isTimeMachine { return .timeMachine }
        if drive.isEncrypted == true { return .locked }
        if drive.isWritable == false { return .readOnly }
        return .canExtract
    }

    private var notes: [String] {
        if !drive.warnings.isEmpty {
            return drive.warnings + physicalDriveWarning
        }
        switch status {
        case .canExtract:
            return ["Safe to preview extraction."] + physicalDriveWarning
        case .readOnly:
            return ["Read-only drive. Extraction may work, but changes are blocked."] + physicalDriveWarning
        case .notMounted:
            return ["Drive is visible but not mounted. Extraction is unavailable until it is mounted."] + physicalDriveWarning
        case .timeMachine:
            return ["Time Machine backup detected. Copy files out; do not modify the backup."] + physicalDriveWarning
        case .locked:
            return ["Drive appears locked. Unlock it in macOS before extraction."] + physicalDriveWarning
        case .unknown:
            return ["No obvious safety warnings detected."] + physicalDriveWarning
        }
    }

    private var physicalDriveWarning: [String] {
        ["If the drive clicks, grinds, or repeatedly spins down, stop and disconnect it. Software recovery can worsen physical damage."]
    }

    private var primaryRecommendation: String {
        switch status {
        case .canExtract:
            return "Safe to preview extraction."
        case .readOnly:
            return "Read-only drive. Copy files out; avoid changes."
        case .notMounted:
            return "Drive is visible but not mounted."
        case .timeMachine:
            return "Time Machine backup detected. Copy files out first."
        case .locked:
            return "Unlock the drive before extraction."
        case .unknown:
            return "Review the drive details before continuing."
        }
    }

    private var writableText: String {
        guard let isWritable = drive.isWritable else { return "Unknown" }
        return isWritable ? "Yes" : "No"
    }

    private var canExtract: Bool {
        drive.mountPath != nil && !store.destinationPath.isEmpty
    }

    private var canChooseDestination: Bool {
        drive.mountPath != nil
    }

    private var canAttemptMount: Bool {
        drive.mountPath == nil && drive.deviceID != nil
    }

    private var repairSummary: String {
        if drive.mountPath == nil {
            return "Start with read-only mount or Disk Utility. Repair may modify filesystem metadata, so copy readable data first if the drive becomes available."
        }
        return "This drive is mounted. Preview extraction before trying any repair."
    }

    private var destinationText: String {
        if drive.mountPath == nil {
            return "Mount required before extraction."
        }
        if store.destinationPath.isEmpty {
            return "Choose a destination to enable preview and extraction."
        }
        if store.compressOutput {
            return "\(store.destinationPath)  •  ZIP output"
        }
        return store.destinationPath
    }

    private var destinationTextStyle: HierarchicalShapeStyle {
        store.destinationPath.isEmpty || drive.mountPath == nil ? .secondary : .primary
    }

    private var extractionBlockedMessage: String {
        if drive.mountPath == nil {
            return "Drive is visible but not mounted. Extraction is unavailable until it is mounted."
        }
        return "Choose a destination folder first."
    }
}
