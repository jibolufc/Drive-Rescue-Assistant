import SwiftUI

struct DetailView: View {
    @Bindable var store: DriveStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch store.workflow {
            case .driveRescue:
                if let drive = store.selectedDrive {
                    DriveDetailContent(store: store, drive: drive)
                } else {
                    EmptyDriveView()
                }
            case .macTransfer:
                MacTransferContent(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MacTransferContent: View {
    @Bindable var store: DriveStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                safetyNotes
                sourceAndDestination
                options
                actions
                activity
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Move From This Mac")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Spacer()
                StatusBadge(label: canTransfer ? "Ready" : "Choose folders", status: canTransfer ? .canExtract : .unknown)
            }

            Text("Copy selected files from an internal folder to an external destination.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var safetyNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety Notes")
                .font(.headline)
            Label("Preview first, then copy only what you choose.", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
            Label("The source folder is not modified.", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
            Label("Choose an external drive or separate folder as the destination.", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private var sourceAndDestination: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Source and Destination")
                .font(.headline)

            pathChooser(
                title: "Source",
                text: store.sourcePath.isEmpty ? "Choose a folder on this Mac." : store.sourcePath,
                systemImage: "folder",
                isEmpty: store.sourcePath.isEmpty,
                action: store.chooseSourceFolder
            )

            pathChooser(
                title: "Destination",
                text: destinationText,
                systemImage: "externaldrive",
                isEmpty: store.destinationPath.isEmpty,
                action: store.chooseDestination
            )
        }
    }

    private func pathChooser(title: String, text: String, systemImage: String, isEmpty: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isEmpty ? .secondary : .primary)
            }

            Spacer()

            Button(action: action) {
                Label("Choose", systemImage: systemImage)
            }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Copy Options")
                .font(.headline)

            Picker("Files", selection: $store.extractionScope) {
                ForEach(ExtractionScope.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $store.compressOutput) {
                Label("Compress to ZIP", systemImage: "archivebox")
            }
            .toggleStyle(.checkbox)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await store.previewTransfer() }
            } label: {
                Label("Preview", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(!canTransfer)

            if canTransfer {
                Button {
                    Task { await store.transferFiles() }
                } label: {
                    Label("Copy Files", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    store.activityLog = "Choose a source folder and destination first."
                } label: {
                    Label("Copy Files", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(true)
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

    private var destinationText: String {
        if store.destinationPath.isEmpty {
            return "Choose where copied files should go."
        }
        if store.compressOutput {
            return "\(store.destinationPath)  •  ZIP output"
        }
        return store.destinationPath
    }

    private var canTransfer: Bool {
        !store.sourcePath.isEmpty && !store.destinationPath.isEmpty
    }
}

private struct EmptyDriveView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "externaldrive")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Connect or select a drive to begin.")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .padding(32)
    }
}
