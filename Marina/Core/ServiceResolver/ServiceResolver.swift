import Foundation

struct ServiceResolver: Sendable {
    func resolve(listener: ListeningPort, dockerCandidates: [DockerContainer]) -> ServiceIdentity {
        let dockerSources = dockerCandidates.flatMap { container in
            [container.compose.service, Optional(container.image), Optional(container.name)].compactMap { $0 }
        }
        for source in dockerSources {
            if let kind = classify(source) {
                return ServiceIdentity(kind: kind, confidence: .high)
            }
        }

        let processSources = [
            listener.process.command,
            listener.process.executablePath,
            Optional(listener.process.name)
        ].compactMap { $0 }
        for source in processSources {
            if let kind = classify(source) {
                return ServiceIdentity(kind: kind, confidence: .medium)
            }
        }

        if let kind = classify(port: listener.port) {
            return ServiceIdentity(kind: kind, confidence: .low)
        }
        if !dockerCandidates.isEmpty {
            return ServiceIdentity(kind: .docker, confidence: .low)
        }
        return ServiceIdentity(kind: .unknown, confidence: .low)
    }

    private func classify(_ source: String) -> ServiceKind? {
        let value = source.lowercased()
        let rules: [(ServiceKind, [String])] = [
            (.nextJS, ["next dev", "next start", "next-server", "nextjs", "next.js"]),
            (.vite, ["vite"]),
            (.uvicorn, ["uvicorn"]),
            (.django, ["django", "manage.py runserver"]),
            (.rails, ["rails server", "rails s", "puma", "passenger"]),
            (.postgreSQL, ["postgres", "postmaster"]),
            (.mySQL, ["mysql", "mariadb", "mysqld"]),
            (.redis, ["redis-server", "redis"]),
            (.nginx, ["nginx"]),
            (.caddy, ["caddy"]),
            (.nodeJS, ["node", "npm", "pnpm", "yarn"]),
            (.python, ["python", "gunicorn"]),
            (.ruby, ["ruby"]),
            (.java, ["java", "spring"]),
            (.go, ["golang", "go-build"])
        ]
        return rules.first(where: { _, needles in needles.contains(where: value.contains) })?.0
    }

    private func classify(port: UInt16) -> ServiceKind? {
        switch port {
        case 3000: .nodeJS
        case 3306: .mySQL
        case 5432: .postgreSQL
        case 6379: .redis
        case 8000: .python
        case 8080: .java
        default: nil
        }
    }
}
