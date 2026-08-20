import XCTest
@testable import Marina

final class TunnelResolverTests: XCTestCase {
    func test_ngrokを公開元ポートへ紐づけて管理用ポートを一覧から除外する() throws {
        let origin = listener(pid: 10, name: "node", command: "next dev", port: 3_000)
        let inspector = listener(
            pid: 20,
            name: "ngrok",
            command: "/opt/homebrew/bin/ngrok http 3000",
            port: 4_040
        )

        let resolution = TunnelResolver().resolve(listeners: [origin, inspector])
        let tunnel = try XCTUnwrap(resolution.tunnelsByListenerID[origin.id]?.first)

        XCTAssertEqual(tunnel.provider, .ngrok)
        XCTAssertEqual(tunnel.originAddress, "localhost:3000")
        XCTAssertEqual(tunnel.localInterfacePort, 4_040)
        XCTAssertEqual(tunnel.localInterfaceURL?.absoluteString, "http://localhost:4040")
        XCTAssertEqual(tunnel.processIdentity.pid, 20)
        XCTAssertEqual(tunnel.processIdentity.name, "ngrok")
        XCTAssertEqual(resolution.linkedListenerIDs, [inspector.id])
        XCTAssertTrue(resolution.warnings.isEmpty)
    }

    func test_cloudflaredのURL指定を公開元ポートへ紐づける() throws {
        let origin = listener(pid: 10, name: "ruby", command: "bin/rails server", port: 4_000)
        let metrics = listener(
            pid: 30,
            name: "cloudflared",
            command: "cloudflared tunnel --url http://127.0.0.1:4000",
            port: 20_241
        )

        let resolution = TunnelResolver().resolve(listeners: [origin, metrics])
        let tunnel = try XCTUnwrap(resolution.tunnelsByListenerID[origin.id]?.first)

        XCTAssertEqual(tunnel.provider, .cloudflare)
        XCTAssertEqual(tunnel.originAddress, "127.0.0.1:4000")
        XCTAssertNil(tunnel.localInterfacePort)
        XCTAssertEqual(resolution.linkedListenerIDs, [metrics.id])
        XCTAssertTrue(resolution.warnings.isEmpty)
    }

    func test_公開元ポートが存在しない場合は誤って紐づけず警告する() {
        let inspector = listener(
            pid: 20,
            name: "ngrok",
            command: "ngrok http https://localhost:8443",
            port: 4_040
        )

        let resolution = TunnelResolver().resolve(listeners: [inspector])

        XCTAssertTrue(resolution.tunnelsByListenerID.isEmpty)
        XCTAssertTrue(resolution.linkedListenerIDs.isEmpty)
        XCTAssertEqual(
            resolution.warnings,
            [
                "ngrok tunnel (PID 20) points to localhost:8443, but that local address is not listening. The tunnel was not linked."
            ]
        )
    }

    func test_namedトンネルで公開元を特定できない場合は警告する() {
        let metrics = listener(
            pid: 30,
            name: "cloudflared",
            command: "cloudflared tunnel run marina-dev",
            port: 20_241
        )

        let resolution = TunnelResolver().resolve(listeners: [metrics])

        XCTAssertTrue(resolution.tunnelsByListenerID.isEmpty)
        XCTAssertTrue(resolution.linkedListenerIDs.isEmpty)
        XCTAssertEqual(
            resolution.warnings,
            [
                "Cloudflare tunnel (PID 30) origin could not be determined from its command. The tunnel was not linked to a local port."
            ]
        )
    }

    func test_localhost以外にだけbindした同一ポートへは紐づけない() {
        let origin = listener(
            pid: 10,
            name: "node",
            command: "next dev",
            port: 3_000,
            address: "192.168.1.10"
        )
        let inspector = listener(
            pid: 20,
            name: "ngrok",
            command: "ngrok http 3000",
            port: 4_040
        )

        let resolution = TunnelResolver().resolve(listeners: [origin, inspector])

        XCTAssertTrue(resolution.tunnelsByListenerID.isEmpty)
        XCTAssertTrue(resolution.linkedListenerIDs.isEmpty)
        XCTAssertEqual(resolution.warnings.count, 1)
    }

    func test_角括弧付きIPv6ループバックURLを公開元へ紐づける() throws {
        let origin = listener(
            pid: 10,
            name: "node",
            command: "next dev",
            port: 3_000,
            address: "::1",
            family: .ipv6
        )
        let inspector = listener(
            pid: 20,
            name: "ngrok",
            command: "ngrok http http://[::1]:3000",
            port: 4_040
        )

        let resolution = TunnelResolver().resolve(listeners: [origin, inspector])
        let tunnel = try XCTUnwrap(resolution.tunnelsByListenerID[origin.id]?.first)

        XCTAssertEqual(tunnel.originAddress, "[::1]:3000")
        XCTAssertTrue(resolution.warnings.isEmpty)
    }

    func test_公開元と異なるアドレスファミリのwildcardへは紐づけない() {
        let cases: [(command: String, address: String, family: IPFamily)] = [
            ("ngrok http 127.0.0.1:3000", "::", .ipv6),
            ("ngrok http http://[::1]:3000", "0.0.0.0", .ipv4)
        ]

        for testCase in cases {
            let origin = listener(
                pid: 10,
                name: "node",
                command: "next dev",
                port: 3_000,
                address: testCase.address,
                family: testCase.family
            )
            let inspector = listener(
                pid: 20,
                name: "ngrok",
                command: testCase.command,
                port: 4_040
            )

            let resolution = TunnelResolver().resolve(listeners: [origin, inspector])

            XCTAssertTrue(resolution.tunnelsByListenerID.isEmpty)
            XCTAssertTrue(resolution.linkedListenerIDs.isEmpty)
            XCTAssertEqual(resolution.warnings.count, 1)
        }
    }

    private func listener(
        pid: Int32,
        name: String,
        command: String,
        port: UInt16,
        address: String = "127.0.0.1",
        family: IPFamily = .ipv4
    ) -> ListeningPort {
        ListeningPort(
            process: ProcessIdentity(
                pid: pid,
                name: name,
                user: "developer",
                command: command,
                executablePath: "/opt/homebrew/bin/\(name)",
                parentPID: 1,
                workingDirectory: "/Users/developer/Projects/marina"
            ),
            port: port,
            bindAddresses: [address],
            ipFamilies: [family],
            transportProtocol: "tcp"
        )
    }
}
