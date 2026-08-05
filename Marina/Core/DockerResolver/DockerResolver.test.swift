import XCTest
@testable import Marina

final class DockerResolverTests: XCTestCase {
    func test_DockerCLI未検出を独立状態として返す() async {
        let runner = MockCommandRunner(results: [])
        let snapshot = await DockerResolver(runner: runner, dockerExecutableURL: nil).fetchContainers()
        XCTAssertEqual(snapshot.availability, .cliNotInstalled)
        XCTAssertTrue(snapshot.containers.isEmpty)
    }

    func test_Docker未起動を独立状態として返す() async {
        let failure = CommandRunnerError.nonZeroExit(executable: "docker", status: 1, message: "Cannot connect to the Docker daemon. Is the docker daemon running?")
        let runner = MockCommandRunner(results: [.failure(failure)])
        let snapshot = await DockerResolver(runner: runner, dockerExecutableURL: URL(fileURLWithPath: "/usr/bin/true")).fetchContainers()
        guard case .desktopStopped = snapshot.availability else {
            return XCTFail("Docker停止状態ではありません: \(snapshot.availability)")
        }
    }

    func test_DockerPS空出力は利用可能な空一覧にする() async {
        let output = CommandOutput(standardOutput: Data(), standardError: Data(), terminationStatus: 0)
        let runner = MockCommandRunner(results: [.success(output)])
        let snapshot = await DockerResolver(runner: runner, dockerExecutableURL: URL(fileURLWithPath: "/usr/bin/true")).fetchContainers()
        XCTAssertEqual(snapshot.availability, .available)
        XCTAssertTrue(snapshot.containers.isEmpty)
    }

    func test_DockerPS不正JSONは解析失敗にする() async {
        let output = CommandOutput(standardOutput: Data("bad-json\n".utf8), standardError: Data(), terminationStatus: 0)
        let runner = MockCommandRunner(results: [.success(output)])
        let snapshot = await DockerResolver(runner: runner, dockerExecutableURL: URL(fileURLWithPath: "/usr/bin/true")).fetchContainers()
        guard case .invalidJSON = snapshot.availability else {
            return XCTFail("JSON解析失敗ではありません: \(snapshot.availability)")
        }
    }

    func test_コマンド失敗をエラー状態として返す() async {
        let failure = CommandRunnerError.nonZeroExit(executable: "docker", status: 125, message: "unexpected failure")
        let runner = MockCommandRunner(results: [.failure(failure)])
        let snapshot = await DockerResolver(runner: runner, dockerExecutableURL: URL(fileURLWithPath: "/usr/bin/true")).fetchContainers()
        guard case .failed = snapshot.availability else {
            return XCTFail("一般エラーではありません: \(snapshot.availability)")
        }
    }
}
