import SwiftUI

struct StatusIndicator: View {
    enum Status {
        case listening
        case warning
        case error

        var color: Color {
            switch self {
            case .listening: .green
            case .warning: .orange
            case .error: .red
            }
        }

        var label: String {
            switch self {
            case .listening: "Listening"
            case .warning: "Warning"
            case .error: "Error"
            }
        }
    }

    let status: Status

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 0.5))
            .accessibilityLabel(status.label)
    }
}
