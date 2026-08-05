import Foundation

enum ServiceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case nextJS
    case nodeJS
    case vite
    case python
    case uvicorn
    case django
    case ruby
    case rails
    case postgreSQL
    case mySQL
    case redis
    case nginx
    case caddy
    case java
    case go
    case docker
    case unknown

    var displayName: String {
        switch self {
        case .nextJS: "Next.js"
        case .nodeJS: "Node.js"
        case .vite: "Vite"
        case .python: "Python"
        case .uvicorn: "uvicorn"
        case .django: "Django"
        case .ruby: "Ruby"
        case .rails: "Rails"
        case .postgreSQL: "PostgreSQL"
        case .mySQL: "MySQL"
        case .redis: "Redis"
        case .nginx: "nginx"
        case .caddy: "Caddy"
        case .java: "Java"
        case .go: "Go"
        case .docker: "Docker"
        case .unknown: "Unknown"
        }
    }

    var isHTTPService: Bool {
        switch self {
        case .nextJS, .nodeJS, .vite, .uvicorn, .django, .rails, .nginx, .caddy, .java, .go:
            true
        default:
            false
        }
    }
}

struct ServiceIdentity: Codable, Hashable, Sendable {
    enum Confidence: String, Codable, Hashable, Sendable {
        case high
        case medium
        case low
    }

    let kind: ServiceKind
    let confidence: Confidence

    var displayName: String { kind.displayName }
}
