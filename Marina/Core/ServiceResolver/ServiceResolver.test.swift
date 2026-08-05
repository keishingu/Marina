import XCTest
@testable import Marina

final class ServiceResolverTests: XCTestCase {
    func test_コマンドラインからNextJSを推測する() {
        let listener = makeListener(command: "node node_modules/.bin/next dev", executable: "/opt/homebrew/bin/node", port: 3_000)
        let service = ServiceResolver().resolve(listener: listener, dockerCandidates: [])
        XCTAssertEqual(service.kind, .nextJS)
        XCTAssertEqual(service.confidence, .medium)
    }

    func test_Dockerイメージをプロセス名より優先する() {
        let listener = makeListener(command: "com.docker.backend", executable: nil, port: 5_432)
        let container = DockerContainer(
            id: String(repeating: "a", count: 64),
            name: "marina-db-1",
            image: "postgres:17",
            status: "running",
            compose: DockerComposeIdentity(project: "marina", service: "db", containerNumber: "1", workingDirectory: nil, configFiles: nil),
            portMappings: []
        )
        let service = ServiceResolver().resolve(listener: listener, dockerCandidates: [container])
        XCTAssertEqual(service.kind, .postgreSQL)
        XCTAssertEqual(service.confidence, .high)
    }

    func test_曖昧な既知ポートはランタイムへフォールバックする() {
        let service = ServiceResolver().resolve(listener: makeListener(command: nil, executable: nil, port: 8_000), dockerCandidates: [])
        XCTAssertEqual(service.kind, .python)
        XCTAssertEqual(service.confidence, .low)
    }

    private func makeListener(command: String?, executable: String?, port: UInt16) -> ListeningPort {
        ListeningPort(
            process: ProcessIdentity(pid: 20, name: "runtime", user: "me", command: command, executablePath: executable, parentPID: 1, workingDirectory: "/tmp"),
            port: port,
            bindAddresses: ["127.0.0.1"],
            ipFamilies: [.ipv4],
            transportProtocol: "tcp"
        )
    }
}
