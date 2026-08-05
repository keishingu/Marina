import Foundation

struct ProcessResolution: Sendable {
    let identities: [Int32: ProcessIdentity]
    let warnings: [String]
}

protocol ProcessResolving: Sendable {
    func resolve(_ processes: [ProcessIdentity]) async -> ProcessResolution
}

struct DefaultProcessResolver: ProcessResolving {
    private let runner: any CommandRunning

    init(runner: any CommandRunning) {
        self.runner = runner
    }

    func resolve(_ processes: [ProcessIdentity]) async -> ProcessResolution {
        let unique = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        return await withTaskGroup(of: (Int32, ProcessIdentity, [String]).self) { group in
            for process in unique.values {
                group.addTask { await resolve(process) }
            }

            var identities: [Int32: ProcessIdentity] = [:]
            var warnings: [String] = []
            for await (pid, identity, processWarnings) in group {
                identities[pid] = identity
                warnings.append(contentsOf: processWarnings)
            }
            return ProcessResolution(identities: identities, warnings: warnings.sorted())
        }
    }

    private func resolve(_ base: ProcessIdentity) async -> (Int32, ProcessIdentity, [String]) {
        var command: String?
        var parentPID: Int32?
        var executablePath: String?
        var workingDirectory: String?
        var warnings: [String] = []

        do {
            let output = try await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/ps"),
                arguments: ["-p", String(base.pid), "-o", "ppid=", "-o", "command="]
            ).stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = output.split(maxSplits: 1, whereSeparator: \Character.isWhitespace)
            parentPID = parts.first.flatMap { Int32($0) }
            command = parts.count > 1 ? String(parts[1]) : nil
        } catch {
            warnings.append("PID \(base.pid) command details: \(error.localizedDescription)")
        }

        do {
            let output = try await runner.run(
                executableURL: URL(fileURLWithPath: "/usr/sbin/lsof"),
                arguments: ["-a", "-p", String(base.pid), "-d", "txt", "-Fn"]
            ).stdoutString
            executablePath = firstNameField(in: output)
        } catch {
            warnings.append("PID \(base.pid) executable path: \(error.localizedDescription)")
        }

        do {
            let output = try await runner.run(
                executableURL: URL(fileURLWithPath: "/usr/sbin/lsof"),
                arguments: ["-a", "-p", String(base.pid), "-d", "cwd", "-Fn"]
            ).stdoutString
            workingDirectory = firstNameField(in: output)
        } catch {
            warnings.append("PID \(base.pid) working directory: \(error.localizedDescription)")
        }

        let identity = ProcessIdentity(
            pid: base.pid,
            name: base.name,
            user: base.user,
            command: command,
            executablePath: executablePath,
            parentPID: parentPID,
            workingDirectory: workingDirectory
        )
        return (base.pid, identity, warnings)
    }

    private func firstNameField(in output: String) -> String? {
        output.components(separatedBy: CharacterSet(charactersIn: "\0\n"))
            .first { $0.hasPrefix("n") }
            .map { String($0.dropFirst()) }
    }
}
