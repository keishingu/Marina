import Foundation

protocol DockerResolving: Sendable {
    func fetchContainers() async -> DockerSnapshot
}

struct DockerResolver: DockerResolving {
    private let runner: any CommandRunning
    private let dockerExecutableURL: URL?
    private let parser: DockerInspectParser

    init(
        runner: any CommandRunning,
        dockerExecutableURL: URL? = DockerResolver.locateDockerExecutable(),
        parser: DockerInspectParser = DockerInspectParser()
    ) {
        self.runner = runner
        self.dockerExecutableURL = dockerExecutableURL
        self.parser = parser
    }

    func fetchContainers() async -> DockerSnapshot {
        guard let dockerExecutableURL else {
            return DockerSnapshot(containers: [], availability: .cliNotInstalled)
        }

        do {
            let ps = try await runner.run(
                executableURL: dockerExecutableURL,
                arguments: ["ps", "--format", "{{json .}}"]
            )
            let identifiers = try parser.parsePSIdentifiers(ps.standardOutput)
            guard !identifiers.isEmpty else {
                return DockerSnapshot(containers: [], availability: .available)
            }
            guard identifiers.allSatisfy(Self.isValidContainerID) else {
                return DockerSnapshot(
                    containers: [],
                    availability: .invalidJSON("A container identifier contained unexpected characters.")
                )
            }

            let inspect = try await runner.run(
                executableURL: dockerExecutableURL,
                arguments: ["inspect"] + identifiers
            )
            let containers = try parser.parseInspect(inspect.standardOutput)
            return DockerSnapshot(containers: containers, availability: .available)
        } catch let error as DockerParsingError {
            return DockerSnapshot(containers: [], availability: .invalidJSON(error.localizedDescription))
        } catch {
            return DockerSnapshot(containers: [], availability: classify(error))
        }
    }

    static func locateDockerExecutable(fileManager: FileManager = .default) -> URL? {
        let candidates = [
            "/opt/homebrew/bin/docker",
            "/usr/local/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker"
        ]
        return candidates.first(where: fileManager.isExecutableFile(atPath:)).map(URL.init(fileURLWithPath:))
    }

    static func isValidContainerID(_ value: String) -> Bool {
        (12...64).contains(value.count) && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private func classify(_ error: Error) -> DockerAvailability {
        let message = error.localizedDescription
        let lowercased = message.lowercased()
        if lowercased.contains("permission denied") || lowercased.contains("operation not permitted") {
            return .permissionDenied(message)
        }
        if lowercased.contains("cannot connect") ||
            lowercased.contains("is the docker daemon running") ||
            lowercased.contains("connection refused") {
            return .desktopStopped(message)
        }
        return .failed(message)
    }
}
