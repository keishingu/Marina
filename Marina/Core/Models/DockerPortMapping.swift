import Foundation

struct DockerPortMapping: Identifiable, Codable, Hashable, Sendable {
    let hostIP: String
    let hostPort: UInt16
    let containerPort: UInt16
    let protocolName: String

    var id: String { "\(hostIP)-\(hostPort)-\(containerPort)-\(protocolName)" }
}
