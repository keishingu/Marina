import Foundation

actor MockCommandRunner: CommandRunning {
    struct Invocation: Equatable, Sendable {
        let executableURL: URL
        let arguments: [String]
    }

    private var results: [Result<CommandOutput, Error>]
    private(set) var invocations: [Invocation] = []

    init(results: [Result<CommandOutput, Error>]) {
        self.results = results
    }

    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput {
        invocations.append(Invocation(executableURL: executableURL, arguments: arguments))
        guard !results.isEmpty else {
            throw CommandRunnerError.launchFailed("No fixture result was configured.")
        }
        return try results.removeFirst().get()
    }
}
