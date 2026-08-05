import Foundation

struct CommandOutput: Equatable, Sendable {
    let standardOutput: Data
    let standardError: Data
    let terminationStatus: Int32

    var stdoutString: String { String(decoding: standardOutput, as: UTF8.self) }
    var stderrString: String { String(decoding: standardError, as: UTF8.self) }
}

enum CommandRunnerError: LocalizedError, Equatable, Sendable {
    case executableNotFound(String)
    case launchFailed(String)
    case nonZeroExit(executable: String, status: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            "Executable was not found at \(path)."
        case .launchFailed(let message):
            "Command could not be launched: \(message)"
        case .nonZeroExit(let executable, let status, let message):
            "\(executable) exited with status \(status): \(message)"
        }
    }
}

protocol CommandRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput
}

struct SystemCommandRunner: CommandRunning {
    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput {
        try await Task.detached(priority: .utility) {
            guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
                throw CommandRunnerError.executableNotFound(executableURL.path)
            }

            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr
            process.standardInput = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                throw CommandRunnerError.launchFailed(error.localizedDescription)
            }

            let stdoutTask = Task { stdout.fileHandleForReading.readDataToEndOfFile() }
            let stderrTask = Task { stderr.fileHandleForReading.readDataToEndOfFile() }
            process.waitUntilExit()
            let output = await stdoutTask.value
            let errorOutput = await stderrTask.value
            try Task.checkCancellation()

            let result = CommandOutput(
                standardOutput: output,
                standardError: errorOutput,
                terminationStatus: process.terminationStatus
            )
            guard result.terminationStatus == 0 else {
                throw CommandRunnerError.nonZeroExit(
                    executable: executableURL.lastPathComponent,
                    status: result.terminationStatus,
                    message: result.stderrString.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            return result
        }.value
    }
}
