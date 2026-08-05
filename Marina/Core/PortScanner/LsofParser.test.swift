import XCTest
@testable import Marina

final class LsofParserTests: XCTestCase {
    func test_機械可読出力からPIDとポートを取得する() {
        let data = fixture([
            "p48291", "cnode", "Lalice", "f19", "tIPv4", "PTCP", "n127.0.0.1:3000", "TST=LISTEN"
        ])

        let ports = LsofParser().parse(data)

        XCTAssertEqual(ports.count, 1)
        XCTAssertEqual(ports[0].process.pid, 48_291)
        XCTAssertEqual(ports[0].process.name, "node")
        XCTAssertEqual(ports[0].process.user, "alice")
        XCTAssertEqual(ports[0].port, 3_000)
        XCTAssertEqual(ports[0].bindAddresses, ["127.0.0.1"])
    }

    func test_IPv4とIPv6の同一リスナーを正規化する() {
        let data = fixture([
            "p99", "cserver", "f8", "tIPv4", "PTCP", "n*:8080", "TST=LISTEN",
            "f9", "tIPv6", "PTCP", "n[::]:8080", "TST=LISTEN"
        ])

        let ports = LsofParser().parse(data)

        XCTAssertEqual(ports.count, 1)
        XCTAssertEqual(ports[0].port, 8_080)
        XCTAssertEqual(ports[0].ipFamilies, [.ipv4, .ipv6])
        XCTAssertEqual(Set(ports[0].bindAddresses), ["*", "::"])
    }

    func test_空出力は空配列として扱う() {
        XCTAssertTrue(LsofParser().parse(Data()).isEmpty)
    }

    func test_ポートでないエンドポイントを無視する() {
        let data = fixture(["p1", "cbad", "f1", "tIPv4", "PTCP", "n*:invalid", "TST=LISTEN"])
        XCTAssertTrue(LsofParser().parse(data).isEmpty)
    }

    private func fixture(_ fields: [String]) -> Data {
        Data((fields.joined(separator: "\0") + "\0").utf8)
    }
}
