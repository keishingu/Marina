import AppKit
import SwiftUI

struct PortListView: View {
    @ObservedObject var viewModel: PortListViewModel
    @ObservedObject var settings: MarinaSettings
    @Environment(\.openSettings) private var openSettings
    @State private var selectedPort: ResolvedPort?
    @State private var confirmation: Confirmation?
    @State private var searchText = ""
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        Group {
            if let selectedPort {
                PortDetailView(port: selectedPort, onDone: showPortList)
            } else {
                portList
            }
        }
        .frame(width: 420)
        .frame(maxHeight: 680)
        .background(.regularMaterial)
        .onAppear {
            viewModel.startMonitoring()
            focusSearch()
        }
        .onDisappear {
            selectedPort = nil
            searchText = ""
            searchIsFocused = false
            viewModel.stopMonitoring()
        }
        .onChange(of: settings.refreshInterval) { _, _ in viewModel.restartMonitoring() }
        .alert(item: $confirmation, content: confirmationAlert)
        .alert("Action failed", isPresented: actionErrorIsPresented) {
            Button("OK") { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "The action could not be completed.")
        }
    }

    @ViewBuilder
    private var portList: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                portListContent
            }
        } else {
            portListContent
        }
#else
        portListContent
#endif
    }

    private var portListContent: some View {
        VStack(spacing: 0) {
            header
            searchField
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
    }

    private var visiblePorts: [ResolvedPort] { viewModel.filteredPorts(matching: searchText) }
    private var unsearchedPorts: [ResolvedPort] { viewModel.filteredPorts() }

    private var header: some View {
        HStack(spacing: 10) {
            MarinaIcon(size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Marina").font(.headline)
                Text(portCountSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            headerActions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private var headerActions: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            HStack(spacing: 6) {
                refreshButton
                marinaMenu(systemImage: "ellipsis").menuStyle(.button)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        } else {
            HStack(spacing: 10) {
                refreshButton.buttonStyle(.plain)
                marinaMenu(systemImage: "ellipsis.circle").menuStyle(.borderlessButton)
            }
        }
#else
        HStack(spacing: 10) {
            refreshButton.buttonStyle(.plain)
            marinaMenu(systemImage: "ellipsis.circle").menuStyle(.borderlessButton)
        }
#endif
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .frame(width: 24, height: 24)
        }
        .disabled(viewModel.isRefreshing)
        .keyboardShortcut("r", modifiers: .command)
        .help("Refresh ports (⌘R)")
        .accessibilityLabel(viewModel.isRefreshing ? "Refreshing ports" : "Refresh ports")
    }

    private func marinaMenu(systemImage: String) -> some View {
        Menu {
            Button {
                showSettings()
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Marina", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Marina menu")
        .accessibilityLabel("Marina menu")
    }

    @ViewBuilder
    private var searchField: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            searchFieldContent
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        } else {
            searchFieldContent
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
#else
        searchFieldContent
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
#endif
    }

    private var searchFieldContent: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Filter ports and services", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchIsFocused)
                .onExitCommand { searchText = "" }
                .accessibilityLabel("Filter listening ports")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchIsFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear filter")
                .accessibilityLabel("Clear filter")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
    }

    private var portCountSummary: String {
        if searchText.isEmpty {
            return "\(visiblePorts.count) listening · \(viewModel.dockerContainerCount) containers"
        }
        return "\(visiblePorts.count) of \(unsearchedPorts.count) listening · \(viewModel.dockerContainerCount) containers"
    }

    @ViewBuilder
    private var content: some View {
        if visiblePorts.isEmpty && !searchText.isEmpty && viewModel.scanError == nil {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("No matching services").font(.headline)
                Text("Try another port, process, or service name.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Clear Filter") {
                    searchText = ""
                    searchIsFocused = true
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .padding(24)
        } else if visiblePorts.isEmpty && viewModel.scanError == nil && !viewModel.isRefreshing {
            VStack(spacing: 10) {
                MarinaAnchorSymbol()
                    .frame(width: 30, height: 30)
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
            .frame(maxHeight: 550)
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

    private func focusSearch() {
        Task { @MainActor in
            await Task.yield()
            guard selectedPort == nil else { return }
            searchIsFocused = true
        }
    }

    private func showSettings() {
        NSApplication.shared.activate()
        openSettings()
        DispatchQueue.main.async {
            NSApplication.shared.activate()
        }
    }

    private func showPortList() {
        selectedPort = nil
        focusSearch()
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
