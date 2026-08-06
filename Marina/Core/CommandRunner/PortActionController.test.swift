import XCTest
@testable import Marina

final class PortActionControllerTests: XCTestCase {
    func test_SIGTERM後も同じプロセスが残る場合は失敗を返す() async {
        let runner = MockCommandRunner(results: [
            .success(output("/Applications/Electron.app/Contents/MacOS/Electron\n")),
            .success(output()),
            .success(output("/Applications/Electron.app/Contents/MacOS/Electron\n"))
        ])
        let controller = PortActionController(
            runner: runner,
            dockerExecutableURL: nil,
            terminationGracePeriod: .zero
        )

        do {
            try await controller.terminate(process)
            XCTFail("終了していないプロセスを成功扱いしました")
        } catch let error as PortActionError {
            XCTAssertEqual(
                error,
                .processStillRunning(name: "Electron", pid: 30_533, signal: "SIGTERM")
            )
        } catch {
            XCTFail("想定外のエラーです: \(error)")
        }
    }

    func test_SIGTERM後にPIDが消えた場合は成功する() async throws {
        let processMissing = CommandRunnerError.nonZeroExit(
            executable: "ps",
            status: 1,
            message: ""
        )
        let runner = MockCommandRunner(results: [
            .success(output("Electron\n")),
            .success(output()),
            .failure(processMissing)
        ])
        let controller = PortActionController(
            runner: runner,
            dockerExecutableURL: nil,
            terminationGracePeriod: .zero
        )

        try await controller.terminate(process)

        let invocations = await runner.invocations
        XCTAssertEqual(invocations.map(\.executableURL.path), ["/bin/ps", "/bin/kill", "/bin/ps"])
        XCTAssertEqual(invocations[1].arguments, ["-TERM", "30533"])
    }

    func test_SIGTERM後にPIDが別プロセスへ変わった場合は成功する() async throws {
        let runner = MockCommandRunner(results: [
            .success(output("Electron\n")),
            .success(output()),
            .success(output("replacement-process\n"))
        ])
        let controller = PortActionController(
            runner: runner,
            dockerExecutableURL: nil,
            terminationGracePeriod: .zero
        )

        try await controller.terminate(process)
    }

    private var process: ProcessIdentity {
        ProcessIdentity(
            pid: 30_533,
            name: "Electron",
            user: nil,
            command: nil,
            executablePath: nil,
            parentPID: nil,
            workingDirectory: nil
        )
    }

    private func output(_ text: String = "") -> CommandOutput {
        CommandOutput(
            standardOutput: Data(text.utf8),
            standardError: Data(),
            terminationStatus: 0
        )
    }
}
