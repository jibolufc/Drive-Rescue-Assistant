import SwiftUI

struct StatusBadge: View {
    let label: String
    let status: DriveHealthStatus

    var body: some View {
        Label(label, systemImage: iconName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private var iconName: String {
        switch status {
        case .canExtract:
            return "checkmark.circle"
        case .readOnly:
            return "lock"
        case .notMounted:
            return "questionmark.circle"
        case .timeMachine:
            return "clock.arrow.circlepath"
        case .locked:
            return "lock.circle"
        case .unknown:
            return "info.circle"
        }
    }

    private var color: Color {
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
