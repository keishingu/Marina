import Foundation

enum PortActionError: LocalizedError, Equatable, Sendable {
    case processChanged
    case processUnavailable
    case processStillRunning(name: String, pid: Int32, signal: String)
    case terminationVerificationFailed(String)
    case dockerUnavailable
    case invalidContainerID
    case containerChanged

    var errorDescription: String? {
        switch self {
        case .processChanged: "The PID now belongs to a different process. Nothing was terminated."
        case .processUnavailable: "The process is no longer running."
        case .processStillRunning(let name, let pid, let signal):
            "\(name) (PID \(pid)) is still running after \(signal). Use “Force Quit Process…” if it does not exit."
        case .terminationVerificationFailed(let message):
            "Could not verify whether the process terminated: \(message)"
        case .dockerUnavailable: "Docker CLI is not available."
        case .invalidContainerID: "The container identifier is invalid."
        case .containerChanged: "The container identity changed. No action was performed."
        }
    }
}

struct PortActionController: Sendable {
    private let runner: any CommandRunning
    private let dockerExecutableURL: URL?
    private let terminationGracePeriod: Duration

    init(
        runner: any CommandRunning,
        dockerExecutableURL: URL?,
        terminationGracePeriod: Duration = .milliseconds(500)
    ) {
        self.runner = runner
        self.dockerExecutableURL = dockerExecutableURL
        self.terminationGracePeriod = terminationGracePeriod
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
        guard isSameProcessName(currentName, process.name) else {
            throw PortActionError.processChanged
        }
        let signal = force ? "SIGKILL" : "SIGTERM"
        _ = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/kill"),
            arguments: [force ? "-KILL" : "-TERM", String(process.pid)]
        )
        try await Task.sleep(for: terminationGracePeriod)
        try await verifyProcessTerminated(process, signal: signal)
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

    private func verifyProcessTerminated(_ process: ProcessIdentity, signal: String) async throws {
        let verification: CommandOutput
        do {
            verification = try await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/ps"),
                arguments: ["-p", String(process.pid), "-o", "comm="]
            )
        } catch CommandRunnerError.nonZeroExit(_, let status, _) where status == 1 {
            return
        } catch {
            throw PortActionError.terminationVerificationFailed(error.localizedDescription)
        }

        let currentName = URL(
            fileURLWithPath: verification.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
        ).lastPathComponent
        guard isSameProcessName(currentName, process.name) else { return }
        throw PortActionError.processStillRunning(name: process.name, pid: process.pid, signal: signal)
    }

    private func isSameProcessName(_ currentName: String, _ expectedName: String) -> Bool {
        currentName.caseInsensitiveCompare(expectedName) == .orderedSame ||
            expectedName.localizedCaseInsensitiveContains(currentName) ||
            currentName.localizedCaseInsensitiveContains(expectedName)
    }
}
