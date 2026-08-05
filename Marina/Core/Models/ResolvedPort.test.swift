import XCTest
@testable import Marina

final class ResolvedPortTests: XCTestCase {
    func test_ポート番号で検索できる() {
        let port = makePort()

        XCTAssertTrue(port.matches(searchText: "3000"))
        XCTAssertTrue(port.matches(searchText: ":3000"))
        XCTAssertFalse(port.matches(searchText: "5432"))
    }

    func test_サービスとプロセスとDocker情報を大文字小文字を区別せず検索できる() {
        let port = makePort()

        XCTAssertTrue(port.matches(searchText: "NEXT.JS"))
        XCTAssertTrue(port.matches(searchText: "node"))
        XCTAssertTrue(port.matches(searchText: "marina-web"))
        XCTAssertTrue(port.matches(searchText: "web latest"))
    }

    func test_空白だけの検索は一致する() {
        XCTAssertTrue(makePort().matches(searchText: "   "))
    }

    private func makePort() -> ResolvedPort {
        let listener = ListeningPort(
            process: ProcessIdentity(
                pid: 48_291,
                name: "node",
                user: "developer",
                command: "next dev",
                executablePath: "/opt/homebrew/bin/node",
                parentPID: 1,
                workingDirectory: "/Users/developer/Projects/marina"
            ),
            port: 3_000,
            bindAddresses: ["127.0.0.1"],
            ipFamilies: [.ipv4],
            transportProtocol: "tcp"
        )
        let container = DockerContainer(
            id: String(repeating: "a", count: 64),
            name: "marina-web-1",
            image: "marina-web:latest",
            status: "running",
            compose: DockerComposeIdentity(
                project: "marina",
                service: "web",
                containerNumber: "1",
                workingDirectory: nil,
                configFiles: nil
            ),
            portMappings: [
                DockerPortMapping(hostIP: "0.0.0.0", hostPort: 3_000, containerPort: 3_000, protocolName: "tcp")
            ]
        )
        return ResolvedPort(
            listener: listener,
            service: ServiceIdentity(kind: .nextJS, confidence: .high),
            dockerCandidates: [container]
        )
    }
}
