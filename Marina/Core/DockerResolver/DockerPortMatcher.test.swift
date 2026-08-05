import XCTest
@testable import Marina

final class DockerPortMatcherTests: XCTestCase {
    func test_HostPortとプロトコルが一致するコンテナを紐付ける() {
        let listener = makeListener(port: 3_000, addresses: ["*"])
        let matching = makeContainer(id: String(repeating: "a", count: 64), name: "web", port: 3_000, protocolName: "tcp")
        let udpOnly = makeContainer(id: String(repeating: "b", count: 64), name: "dns", port: 3_000, protocolName: "udp")

        let result = DockerPortMatcher().match(listeners: [listener], containers: [matching, udpOnly])

        XCTAssertEqual(result[listener.id]?.map(\.name), ["web"])
    }

    func test_同一ホストポートの複数候補を保持する() {
        let listener = makeListener(port: 5_432, addresses: ["0.0.0.0"])
        let first = makeContainer(id: String(repeating: "a", count: 64), name: "db-a", port: 5_432, protocolName: "tcp")
        let second = makeContainer(id: String(repeating: "b", count: 64), name: "db-b", port: 5_432, protocolName: "tcp")

        let result = DockerPortMatcher().match(listeners: [listener], containers: [first, second])

        XCTAssertEqual(result[listener.id]?.count, 2)
    }

    private func makeListener(port: UInt16, addresses: [String]) -> ListeningPort {
        ListeningPort(
            process: ProcessIdentity(pid: 10, name: "com.docker.backend", user: "me", command: nil, executablePath: nil, parentPID: nil, workingDirectory: nil),
            port: port,
            bindAddresses: addresses,
            ipFamilies: [.ipv4],
            transportProtocol: "tcp"
        )
    }

    private func makeContainer(id: String, name: String, port: UInt16, protocolName: String) -> DockerContainer {
        DockerContainer(
            id: id,
            name: name,
            image: "image:latest",
            status: "running",
            compose: DockerComposeIdentity(project: nil, service: nil, containerNumber: nil, workingDirectory: nil, configFiles: nil),
            portMappings: [DockerPortMapping(hostIP: "0.0.0.0", hostPort: port, containerPort: port, protocolName: protocolName)]
        )
    }
}
