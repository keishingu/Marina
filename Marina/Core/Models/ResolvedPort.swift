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

    func matches(searchText: String) -> Bool {
        let terms = searchText
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !terms.isEmpty else { return true }

        let process = listener.process
        var searchableValues = [
            String(listener.port),
            ":\(listener.port)",
            displayName,
            service.displayName,
            process.name,
            process.user,
            process.command,
            process.executablePath,
            process.workingDirectory,
            listener.transportProtocol,
            listener.bindAddresses.joined(separator: " "),
            listener.ipFamilies.map(\.rawValue).joined(separator: " ")
        ].compactMap { $0 }

        for container in dockerCandidates {
            searchableValues.append(contentsOf: [
                container.id,
                container.name,
                container.image,
                container.status,
                container.compose.project,
                container.compose.service
            ].compactMap { $0 })

            for mapping in container.portMappings {
                searchableValues.append(contentsOf: [
                    mapping.hostIP,
                    String(mapping.hostPort),
                    String(mapping.containerPort),
                    mapping.protocolName
                ])
            }
        }

        let searchableText = searchableValues.joined(separator: " ")
        return terms.allSatisfy { searchableText.localizedStandardContains($0) }
    }
}
