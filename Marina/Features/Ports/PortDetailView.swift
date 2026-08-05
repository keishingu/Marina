import SwiftUI

struct PortDetailView: View {
    let port: ResolvedPort
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ServiceIcon(kind: port.service.kind, isDocker: !port.dockerCandidates.isEmpty)
                VStack(alignment: .leading, spacing: 2) {
                    Text(port.displayName).font(.title3.weight(.semibold))
                    Text("TCP :\(port.listener.port)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                detailRow("Process", port.listener.process.name)
                detailRow("PID", String(port.listener.process.pid))
                detailRow("User", port.listener.process.user)
                detailRow("Parent PID", port.listener.process.parentPID.map(String.init))
                detailRow("Bind", port.listener.bindAddresses.joined(separator: ", "))
                detailRow("IP family", port.listener.ipFamilies.map(\.rawValue).sorted().joined(separator: ", "))
                detailRow("Command", port.listener.process.command)
                detailRow("Executable", port.listener.process.executablePath)
                detailRow("Working directory", port.listener.process.workingDirectory)
            }

            if !port.dockerCandidates.isEmpty {
                Divider()
                Text(port.dockerCandidates.count == 1 ? "Docker container" : "Possible Docker containers")
                    .font(.headline)
                ForEach(port.dockerCandidates) { container in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(container.compose.service ?? container.name).font(.subheadline.weight(.semibold))
                        Text("\(container.name) · \(container.image)")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(container.portMappings.map {
                            "\($0.hostIP):\($0.hostPort) → :\($0.containerPort)/\($0.protocolName)"
                        }.joined(separator: ", "))
                        .font(.caption.monospacedDigit())
                        .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            GridRow {
                Text(label).foregroundStyle(.secondary)
                Text(value).textSelection(.enabled)
            }
        }
    }
}
