import SwiftUI

struct SidebarView: View {
    @Bindable var store: DriveStore

    var body: some View {
        List(selection: $store.selectedDriveID) {
            Section("Workflow") {
                Picker("Workflow", selection: $store.workflow) {
                    ForEach(WorkflowMode.allCases) { workflow in
                        Label(workflow.rawValue, systemImage: workflow.iconName)
                            .tag(workflow)
                    }
                }
                .labelsHidden()
                .pickerStyle(.inline)
                .onChange(of: store.workflow) { _, workflow in
                    switch workflow {
                    case .driveRescue:
                        store.activityLog = store.drives.isEmpty
                            ? "No external drives detected. Connect a drive, then refresh."
                            : "Select a connected drive to begin."
                    case .macTransfer:
                        store.activityLog = "Choose a source folder and destination to begin."
                    }
                }
            }

            Section("Connected Drives") {
                if store.drives.isEmpty {
                    Text("No external drives detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.drives) { drive in
                        DriveRow(drive: drive)
                            .tag(drive.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: store.selectedDriveID) { _, _ in
            store.clearPreview()
        }
    }
}

private struct DriveRow: View {
    let drive: Drive

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(drive.name)
                    .lineLimit(1)
                Text(status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(statusColor)
        }
    }

    private var status: DriveHealthStatus {
        if drive.mountPath == nil { return .notMounted }
        if drive.isTimeMachine { return .timeMachine }
        if drive.isEncrypted == true { return .locked }
        if drive.isWritable == false { return .readOnly }
        return .canExtract
    }

    private var iconName: String {
        switch status {
        case .notMounted:
            return "externaldrive.badge.questionmark"
        case .readOnly:
            return "externaldrive.badge.exclamationmark"
        case .timeMachine:
            return "clock.arrow.circlepath"
        case .locked:
            return "externaldrive.badge.lock"
        default:
            return "externaldrive"
        }
    }

    private var statusColor: Color {
        switch status {
        case .canExtract:
            return .green
        case .readOnly, .notMounted, .timeMachine:
            return .orange
        case .locked:
            return .red
        case .unknown:
            return .secondary
        }
    }
}
