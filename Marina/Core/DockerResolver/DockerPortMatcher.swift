import Foundation

struct DockerPortMatcher: Sendable {
    func match(
        listeners: [ListeningPort],
        containers: [DockerContainer]
    ) -> [String: [DockerContainer]] {
        Dictionary(uniqueKeysWithValues: listeners.map { listener in
            let matches = containers.filter { container in
                container.portMappings.contains { mapping in
                    mapping.hostPort == listener.port &&
                        mapping.protocolName.caseInsensitiveCompare(listener.transportProtocol) == .orderedSame &&
                        isHostCompatible(mapping.hostIP, listener.bindAddresses)
                }
            }
            return (listener.id, matches.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        })
    }

    private func isHostCompatible(_ hostIP: String, _ listenerAddresses: [String]) -> Bool {
        let wildcardAddresses: Set<String> = ["", "*", "0.0.0.0", "::"]
        if wildcardAddresses.contains(hostIP) { return true }
        if listenerAddresses.contains(where: wildcardAddresses.contains) { return true }
        return listenerAddresses.contains(hostIP)
    }
}
