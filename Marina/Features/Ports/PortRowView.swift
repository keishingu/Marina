import AppKit
import SwiftUI

struct PortRowView: View {
    let port: ResolvedPort
    @ObservedObject var settings: MarinaSettings
    let showDetails: () -> Void
    let requestTermination: (Bool) -> Void
    let requestTunnelTermination: (TunnelIdentity, Bool) -> Void
    let requestContainerStop: (DockerContainer) -> Void
    let requestContainerRestart: (DockerContainer) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusIndicator(status: .listening)
                .padding(.top, 11)

            ServiceIcon(kind: port.service.kind, isDocker: !port.dockerCandidates.isEmpty)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(port.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(secondaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !port.tunnels.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(port.tunnels) { tunnel in
                            TunnelBadge(tunnel: tunnel)
                        }
                    }
                }

                if settings.showBindAddress {
                    Label(port.listener.primaryBindAddress, systemImage: "network")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if settings.showWorkingDirectory, let workingDirectory {
                    Label(workingDirectory, systemImage: "folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(workingDirectory)
                }

                if settings.showDockerDetails, let dockerLine {
                    Label(dockerLine, systemImage: "shippingbox")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(":\(String(port.listener.port))")
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                actionsMenu
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: showDetails)
        .contextMenu { actionItems }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Show details", showDetails)
    }

    private var secondaryLine: String {
        if let container = port.primaryDockerContainer {
            let suffix = container.compose.project == nil ? "Docker" : "Docker Compose"
            return "\(container.name) · \(suffix)"
        }
        if settings.showPID {
            return "\(port.listener.process.name) · PID \(port.listener.process.pid)"
        }
        return port.listener.process.name
    }

    private var dockerLine: String? {
        if port.dockerCandidates.count > 1 {
            return "\(port.dockerCandidates.count) possible container matches"
        }
        guard let container = port.primaryDockerContainer else { return nil }
        let mappings = container.portMappings.filter {
            $0.hostPort == port.listener.port && $0.protocolName == port.listener.transportProtocol
        }
        guard let mapping = mappings.first else { return container.image }
        return "→ container :\(mapping.containerPort) · \(container.image)"
    }

    private var workingDirectory: String? {
        if let composeDirectory = port.primaryDockerContainer?.compose.workingDirectory,
           !composeDirectory.isEmpty {
            return composeDirectory
        }
        return port.listener.process.workingDirectory
    }

    private var actionsMenu: some View {
        Menu {
            actionItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.semibold))
                .frame(width: 24, height: 18)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Actions for port \(port.listener.port)")
    }

    @ViewBuilder
    private var actionItems: some View {
        Button("Copy Port", systemImage: "number") { copy(String(port.listener.port)) }
        Button("Copy localhost Address", systemImage: "doc.on.doc") {
            copy("localhost:\(port.listener.port)")
        }
        if port.service.kind.isHTTPService {
            Button("Open in Browser", systemImage: "safari") { openInBrowser() }
        }
        Button("Show Process Details", systemImage: "info.circle", action: showDetails)
        Button("Open Activity Monitor", systemImage: "waveform.path.ecg") { openActivityMonitor() }

        if !port.tunnels.isEmpty {
            Divider()
            ForEach(port.tunnels) { tunnel in
                tunnelMenu(tunnel)
            }
        }

        if let container = port.primaryDockerContainer {
            Divider()
            Button("Copy Container Name", systemImage: "doc.on.doc") { copy(container.name) }
            Button("Copy Image Name", systemImage: "doc.on.doc") { copy(container.image) }
            Button("Open Docker Desktop", systemImage: "shippingbox") { openDockerDesktop() }
            Divider()
            Button("Restart Container", systemImage: "arrow.clockwise") { requestContainerRestart(container) }
            Button("Stop Container", systemImage: "stop.circle", role: .destructive) { requestContainerStop(container) }
        } else {
            Divider()
            Button("Terminate Process", systemImage: "xmark.circle", role: .destructive) {
                requestTermination(false)
            }
            Button("Force Quit Process…", systemImage: "exclamationmark.octagon", role: .destructive) {
                requestTermination(true)
            }
        }
    }

    private func tunnelMenu(_ tunnel: TunnelIdentity) -> some View {
        Menu {
            if let actionTitle = tunnel.provider.localInterfaceActionTitle,
               let localInterfaceURL = tunnel.localInterfaceURL {
                Button(actionTitle, systemImage: "safari") {
                    NSWorkspace.shared.open(localInterfaceURL)
                }
            }
            Button(
                "Open \(tunnel.provider.displayName) Dashboard",
                systemImage: "arrow.up.right.square"
            ) {
                NSWorkspace.shared.open(tunnel.provider.dashboardURL)
            }
            Button("Copy Tunnel Command", systemImage: "terminal") { copy(tunnel.command) }
            Divider()
            Button("Terminate Tunnel", systemImage: "xmark.circle", role: .destructive) {
                requestTunnelTermination(tunnel, false)
            }
            Button("Force Quit Tunnel…", systemImage: "exclamationmark.octagon", role: .destructive) {
                requestTunnelTermination(tunnel, true)
            }
        } label: {
            Label(
                "\(tunnel.provider.displayName) Tunnel",
                systemImage: "point.3.connected.trianglepath.dotted"
            )
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openInBrowser() {
        guard let url = URL(string: "http://localhost:\(port.listener.port)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }

    private func openDockerDesktop() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Docker.app"))
    }
}
