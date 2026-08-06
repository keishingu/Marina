import XCTest
@testable import Marina

final class PortActionControllerTests: XCTestCase {
    func test_SIGTERM後も同じプロセスが残る場合は失敗を返す() async {
        let runner = MockCommandRunner(results: [
            .success(output("/Applications/Electron.app/Contents/MacOS/Electron\n")),
            .success(output()),
            .success(output("S /Applications/Electron.app/Contents/MacOS/Electron\n")),
            .success(output("S /Applications/Electron.app/Contents/MacOS/Electron\n")),
            .success(output("S /Applications/Electron.app/Contents/MacOS/Electron\n"))
        ])
        let controller = PortActionController(
            runner: runner,
            dockerExecutableURL: nil,
            terminationCheckInterval: .zero,
            terminationCheckAttempts: 3
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

    func test_SIGTERM処理中のプロセスは期限までポーリングする() async throws {
        let runner = MockCommandRunner(results: [
            .success(output("Electron\n")),
            .success(output()),
            .success(output("S Electron\n")),
            .success(output("S Electron\n")),
            .failure(processMissing)
        ])
        let controller = PortActionController(
            runner: runner,
            dockerExecutableURL: nil,
            terminationCheckInterval: .zero,
            terminationCheckAttempts: 3
        )

        try await controller.terminate(process)

        let invocations = await runner.invocations
        XCTAssertEqual(invocations.map(\.executableURL.path), ["/bin/ps", "/bin/kill", "/bin/ps", "/bin/ps", "/bin/ps"])
    }

    func test_SIGTERM後にPIDが消えた場合は成功する() async throws {
        let runner = MockCommandRunner(results: [
            .success(output("Electron\n")),
            .success(output()),
            .failure(processMissing)
        ])
        let controller = PortActionController(
            runner: runner,
            dockerExecutableURL: nil,
            terminationCheckInterval: .zero,
            terminationCheckAttempts: 1
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
            .success(output("S replacement-process\n"))
        ])
        let controller = PortActionController(
            runner: runner,
            dockerExecutableURL: nil,
            terminationCheckInterval: .zero,
            terminationCheckAttempts: 1
        )

        try await controller.terminate(process)
    }

    func test_SIGTERM後のゾンビプロセスは終了済みとして扱う() async throws {
        let runner = MockCommandRunner(results: [
            .success(output("Electron\n")),
            .success(output()),
            .success(output("Z+ Electron\n"))
        ])
        let controller = PortActionController(
            runner: runner,
            dockerExecutableURL: nil,
            terminationCheckInterval: .zero,
            terminationCheckAttempts: 1
        )

        try await controller.terminate(process)
    }

    func test_SIGKILL後も残る場合はActivityMonitorでの確認を案内する() {
        let error = PortActionError.processStillRunning(
            name: "Electron",
            pid: 30_533,
            signal: "SIGKILL"
        )

        XCTAssertEqual(
            error.errorDescription,
            "Electron (PID 30533) is still present after SIGKILL. Check its state in Activity Monitor."
        )
        XCTAssertFalse(error.errorDescription?.contains("Force Quit") == true)
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

    private var processMissing: CommandRunnerError {
        .nonZeroExit(executable: "ps", status: 1, message: "")
    }

    private func output(_ text: String = "") -> CommandOutput {
        CommandOutput(
            standardOutput: Data(text.utf8),
            standardError: Data(),
            terminationStatus: 0
        )
    }
}
