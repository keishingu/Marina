import Foundation

struct ResolvedPort: Identifiable, Hashable, Sendable {
    let listener: ListeningPort
    let service: ServiceIdentity
    let dockerCandidates: [DockerContainer]

    var id: String { listener.id }

    var primaryDockerContainer: DockerContainer? {
        dockerCandidates.count == 1 ? dockerCandidates.first : nil
    }

    var displayName: String {
        if let serviceName = primaryDockerContainer?.compose.service, !serviceName.isEmpty {
            return serviceName
        }
        return service.displayName
    }
}
