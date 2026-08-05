import SwiftUI

struct PortListView: View {
    @ObservedObject var viewModel: PortListViewModel
    @ObservedObject var settings: MarinaSettings
    @Environment(\.openSettings) private var openSettings
    @State private var selectedPort: ResolvedPort?
    @State private var confirmation: Confirmation?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let scanError = viewModel.scanError {
                statusBanner(
                    icon: "exclamationmark.octagon.fill",
                    title: "Port scan failed",
                    message: scanError,
                    color: .red
                )
            }

            if let dockerMessage = viewModel.dockerAvailability.message {
                statusBanner(
                    icon: "shippingbox",
                    title: "Docker unavailable",
                    message: dockerMessage,
                    color: .orange
                )
            }

            if !viewModel.warnings.isEmpty {
                statusBanner(
                    icon: "info.circle",
                    title: "Some process details are unavailable",
                    message: viewModel.warnings[0],
                    color: .secondary
                )
            }

            content
            Divider()
            footer
        }
        .frame(width: 420)
        .frame(maxHeight: 560)
        .background(.regularMaterial)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
        .onChange(of: settings.refreshInterval) { _, _ in viewModel.restartMonitoring() }
        .sheet(item: $selectedPort) { PortDetailView(port: $0) }
        .alert(item: $confirmation, content: confirmationAlert)
        .alert("Action failed", isPresented: actionErrorIsPresented) {
            Button("OK") { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "The action could not be completed.")
        }
    }

    private var visiblePorts: [ResolvedPort] { viewModel.filteredPorts() }

    private var header: some View {
        HStack(spacing: 10) {
            MarinaIcon(size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Marina").font(.headline)
                Text("\(visiblePorts.count) listening · \(viewModel.dockerContainerCount) containers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRefreshing)
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh ports (⌘R)")
            .accessibilityLabel(viewModel.isRefreshing ? "Refreshing ports" : "Refresh ports")

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Open Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private var content: some View {
        if visiblePorts.isEmpty && viewModel.scanError == nil && !viewModel.isRefreshing {
            VStack(spacing: 10) {
                Image(systemName: "anchor")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("No services are docked").font(.headline)
                Text("Listening services will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .padding(24)
        } else if visiblePorts.isEmpty && viewModel.isRefreshing {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary)
                        .frame(height: 54)
                }
            }
            .padding(14)
            .frame(height: 300)
            .accessibilityLabel("Loading listening ports")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(visiblePorts.enumerated()), id: \.element.id) { index, port in
                        PortRowView(
                            port: port,
                            settings: settings,
                            showDetails: { selectedPort = port },
                            requestTermination: { force in requestTermination(port, force: force) },
                            requestContainerStop: requestContainerStop,
                            requestContainerRestart: requestContainerRestart
                        )
                        if index < visiblePorts.count - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
            }
            .frame(maxHeight: 430)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if viewModel.isRefreshing {
                ProgressView().controlSize(.mini)
                Text("Refreshing…")
            } else if let date = viewModel.lastUpdated {
                Image(systemName: "checkmark.circle")
                Text("Updated \(date, style: .relative) ago")
            } else {
                Image(systemName: "clock")
                Text("Waiting for first scan")
            }
            Spacer()
            if settings.refreshInterval == .manual {
                Text("Manual")
            } else {
                Text("Every \(Int(settings.refreshInterval.rawValue))s")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private func statusBanner(icon: String, title: String, message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(message).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var actionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )
    }

    private func requestTermination(_ port: ResolvedPort, force: Bool) {
        if force || settings.confirmBeforeTerminating {
            confirmation = Confirmation(kind: .terminate(port, force: force))
        } else {
            Task { await viewModel.terminate(port) }
        }
    }

    private func requestContainerStop(_ container: DockerContainer) {
        if settings.confirmBeforeStopping {
            confirmation = Confirmation(kind: .stop(container))
        } else {
            Task { await viewModel.stop(container) }
        }
    }

    private func requestContainerRestart(_ container: DockerContainer) {
        if settings.confirmBeforeStopping {
            confirmation = Confirmation(kind: .restart(container))
        } else {
            Task { await viewModel.restart(container) }
        }
    }

    private func confirmationAlert(_ confirmation: Confirmation) -> Alert {
        switch confirmation.kind {
        case .terminate(let port, let force):
            let signal = force ? "SIGKILL" : "SIGTERM"
            return Alert(
                title: Text(force ? "Force quit process?" : "Terminate process?"),
                message: Text("\(port.listener.process.name) (PID \(port.listener.process.pid)) will receive \(signal). Its identity will be verified first."),
                primaryButton: .destructive(Text(force ? "Force Quit" : "Terminate")) {
                    Task { await viewModel.terminate(port, force: force) }
                },
                secondaryButton: .cancel()
            )
        case .stop(let container):
            return Alert(
                title: Text("Stop container?"),
                message: Text("\(container.name) will be stopped after its container ID is verified."),
                primaryButton: .destructive(Text("Stop")) { Task { await viewModel.stop(container) } },
                secondaryButton: .cancel()
            )
        case .restart(let container):
            return Alert(
                title: Text("Restart container?"),
                message: Text("\(container.name) will be restarted after its container ID is verified."),
                primaryButton: .default(Text("Restart")) { Task { await viewModel.restart(container) } },
                secondaryButton: .cancel()
            )
        }
    }
}

private struct Confirmation: Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind {
        case terminate(ResolvedPort, force: Bool)
        case stop(DockerContainer)
        case restart(DockerContainer)
    }
}
