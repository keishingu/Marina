import SwiftUI

struct PortDetailView: View {
    let port: ResolvedPort
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ServiceIcon(kind: port.service.kind, isDocker: !port.dockerCandidates.isEmpty)
                VStack(alignment: .leading, spacing: 2) {
                    Text(port.displayName).font(.title3.weight(.semibold))
                    Text("TCP :\(String(port.listener.port))")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done", action: onDone).keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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

                    if !port.tunnels.isEmpty {
                        Divider()
                        Text(port.tunnels.count == 1 ? "Tunnel" : "Tunnels")
                            .font(.headline)
                        ForEach(port.tunnels) { tunnel in
                            VStack(alignment: .leading, spacing: 5) {
                                TunnelBadge(tunnel: tunnel)
                                Text("Publishes \(tunnel.originAddress)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(tunnel.command)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                            }
                        }
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
                                    "\($0.hostIP):\(String($0.hostPort)) → :\(String($0.containerPort))/\($0.protocolName)"
                                }.joined(separator: ", "))
                                .font(.caption.monospacedDigit())
                                .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 460)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            GridRow {
                Text(label).foregroundStyle(.secondary)
                Text(value)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }
}
