import Foundation

struct DockerComposeIdentity: Codable, Hashable, Sendable {
    let project: String?
    let service: String?
    let containerNumber: String?
    let workingDirectory: String?
    let configFiles: String?
}

struct DockerContainer: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let image: String
    let status: String
    let compose: DockerComposeIdentity
    let portMappings: [DockerPortMapping]
}

enum DockerAvailability: Equatable, Sendable {
    case available
    case cliNotInstalled
    case desktopStopped(String)
    case permissionDenied(String)
    case invalidJSON(String)
    case failed(String)

    var message: String? {
        switch self {
        case .available: nil
        case .cliNotInstalled: "Docker CLI was not found."
        case .desktopStopped(let detail): "Docker Desktop is not running. \(detail)"
        case .permissionDenied(let detail): "Docker access was denied. \(detail)"
        case .invalidJSON(let detail): "Docker returned invalid JSON. \(detail)"
        case .failed(let detail): "Docker could not be inspected. \(detail)"
        }
    }
}

struct DockerSnapshot: Equatable, Sendable {
    let containers: [DockerContainer]
    let availability: DockerAvailability
}
