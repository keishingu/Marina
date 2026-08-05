import Foundation

@MainActor
final class PortListViewModel: ObservableObject {
    @Published private(set) var ports: [ResolvedPort] = []
    @Published private(set) var dockerAvailability: DockerAvailability = .available
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var scanError: String?
    @Published private(set) var warnings: [String] = []
    @Published var actionError: String?

    private let settings: MarinaSettings
    private let portScanner: any PortScanning
    private let dockerResolver: any DockerResolving
    private let serviceResolver: ServiceResolver
    private let matcher: DockerPortMatcher
    private let actionController: PortActionController
    private var lastKnownContainers: [DockerContainer] = []
    private var monitoringTask: Task<Void, Never>?

    init(
        settings: MarinaSettings,
        portScanner: any PortScanning,
        dockerResolver: any DockerResolving,
        serviceResolver: ServiceResolver = ServiceResolver(),
        matcher: DockerPortMatcher = DockerPortMatcher(),
        actionController: PortActionController
    ) {
        self.settings = settings
        self.portScanner = portScanner
        self.dockerResolver = dockerResolver
        self.serviceResolver = serviceResolver
        self.matcher = matcher
        self.actionController = actionController
    }

    var dockerContainerCount: Int { lastKnownContainers.count }

    func filteredPorts(matching searchText: String = "") -> [ResolvedPort] {
        ports.filter { port in
            let isSystem = port.listener.process.user == "root" ||
                port.listener.process.executablePath?.hasPrefix("/System/") == true ||
                port.listener.process.executablePath?.hasPrefix("/usr/sbin/") == true
            return (settings.showSystemServices || !isSystem) &&
                (!settings.showLoopbackOnly || port.listener.isLoopbackOnly) &&
                port.matches(searchText: searchText)
        }
    }

    func startMonitoring() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            await refresh()
            while !Task.isCancelled {
                guard let duration = settings.refreshInterval.duration else { break }
                do {
                    try await Task.sleep(for: duration)
                } catch {
                    break
                }
                await refresh()
            }
            monitoringTask = nil
        }
    }

    func restartMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        startMonitoring()
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let portResult = capturePortScan()
        async let dockerResult = dockerResolver.fetchContainers()
        let (scan, docker) = await (portResult, dockerResult)

        dockerAvailability = docker.availability
        if docker.availability == .available {
            lastKnownContainers = docker.containers
        }

        switch scan {
        case .success(let snapshot):
            let matches = matcher.match(listeners: snapshot.listeners, containers: lastKnownContainers)
            ports = snapshot.listeners.map { listener in
                let candidates = matches[listener.id] ?? []
                return ResolvedPort(
                    listener: listener,
                    service: serviceResolver.resolve(listener: listener, dockerCandidates: candidates),
                    dockerCandidates: candidates
                )
            }
            warnings = snapshot.warnings
            scanError = nil
            lastUpdated = Date()
        case .failure(let error):
            scanError = error.localizedDescription
        }
    }

    func terminate(_ port: ResolvedPort, force: Bool = false) async {
        await performAction { try await actionController.terminate(port.listener.process, force: force) }
    }

    func stop(_ container: DockerContainer) async {
        await performAction { try await actionController.stop(container) }
    }

    func restart(_ container: DockerContainer) async {
        await performAction { try await actionController.restart(container) }
    }

    private func capturePortScan() async -> Result<PortScanSnapshot, Error> {
        do { return .success(try await portScanner.scan()) }
        catch { return .failure(error) }
    }

    private func performAction(_ action: () async throws -> Void) async {
        do {
            try await action()
            actionError = nil
            await refresh()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
