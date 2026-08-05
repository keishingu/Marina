import Foundation

enum PortActionError: LocalizedError, Equatable, Sendable {
    case processChanged
    case processUnavailable
    case dockerUnavailable
    case invalidContainerID
    case containerChanged

    var errorDescription: String? {
        switch self {
        case .processChanged: "The PID now belongs to a different process. Nothing was terminated."
        case .processUnavailable: "The process is no longer running."
        case .dockerUnavailable: "Docker CLI is not available."
        case .invalidContainerID: "The container identifier is invalid."
        case .containerChanged: "The container identity changed. No action was performed."
        }
    }
}

struct PortActionController: Sendable {
    private let runner: any CommandRunning
    private let dockerExecutableURL: URL?

    init(runner: any CommandRunning, dockerExecutableURL: URL?) {
        self.runner = runner
        self.dockerExecutableURL = dockerExecutableURL
    }

    func terminate(_ process: ProcessIdentity, force: Bool = false) async throws {
        let verification: CommandOutput
        do {
            verification = try await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/ps"),
                arguments: ["-p", String(process.pid), "-o", "comm="]
            )
        } catch {
            throw PortActionError.processUnavailable
        }
        let currentName = URL(fileURLWithPath: verification.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)).lastPathComponent
        guard currentName.caseInsensitiveCompare(process.name) == .orderedSame ||
                process.name.localizedCaseInsensitiveContains(currentName) ||
                currentName.localizedCaseInsensitiveContains(process.name) else {
            throw PortActionError.processChanged
        }
        _ = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/kill"),
            arguments: [force ? "-KILL" : "-TERM", String(process.pid)]
        )
    }

    func stop(_ container: DockerContainer) async throws {
        try await performDockerAction("stop", container: container)
    }

    func restart(_ container: DockerContainer) async throws {
        try await performDockerAction("restart", container: container)
    }

    private func performDockerAction(_ action: String, container: DockerContainer) async throws {
        guard let dockerExecutableURL else { throw PortActionError.dockerUnavailable }
        guard DockerResolver.isValidContainerID(container.id) else { throw PortActionError.invalidContainerID }
        let verification = try await runner.run(
            executableURL: dockerExecutableURL,
            arguments: ["inspect", "--format", "{{.Id}}", container.id]
        )
        let currentID = verification.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentID == container.id || currentID.hasPrefix(container.id) else {
            throw PortActionError.containerChanged
        }
        _ = try await runner.run(executableURL: dockerExecutableURL, arguments: [action, container.id])
    }
}
