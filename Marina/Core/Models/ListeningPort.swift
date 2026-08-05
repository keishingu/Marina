import Foundation

enum IPFamily: String, Codable, CaseIterable, Hashable, Sendable {
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"
    case unknown = "IP"
}

struct ListeningPort: Identifiable, Codable, Hashable, Sendable {
    let process: ProcessIdentity
    let port: UInt16
    let bindAddresses: [String]
    let ipFamilies: Set<IPFamily>
    let transportProtocol: String

    var id: String { "\(process.pid)-\(port)-\(transportProtocol.lowercased())" }

    var primaryBindAddress: String {
        bindAddresses.sorted(by: Self.addressSort).first ?? "—"
    }

    var isLoopbackOnly: Bool {
        !bindAddresses.isEmpty && bindAddresses.allSatisfy {
            $0 == "127.0.0.1" || $0 == "::1" || $0.lowercased() == "localhost"
        }
    }

    private static func addressSort(_ lhs: String, _ rhs: String) -> Bool {
        let rank: (String) -> Int = { address in
            switch address {
            case "127.0.0.1", "::1", "localhost": 0
            case "*", "0.0.0.0", "::": 2
            default: 1
            }
        }
        return (rank(lhs), lhs) < (rank(rhs), rhs)
    }
}
