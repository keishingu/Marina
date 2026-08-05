import Foundation

enum DockerParsingError: LocalizedError, Equatable, Sendable {
    case invalidJSON(String)
    case invalidPort(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail): "Docker JSON could not be decoded: \(detail)"
        case .invalidPort(let value): "Docker returned an invalid port mapping: \(value)"
        }
    }
}

struct DockerInspectParser: Sendable {
    func parsePSIdentifiers(_ data: Data) throws -> [String] {
        let lines = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \Character.isNewline)
        return try lines.map { line in
            do {
                let row = try JSONDecoder().decode(PSRow.self, from: Data(line.utf8))
                return row.id
            } catch {
                throw DockerParsingError.invalidJSON(error.localizedDescription)
            }
        }
    }

    func parseInspect(_ data: Data) throws -> [DockerContainer] {
        let inspected: [InspectContainer]
        do {
            inspected = try JSONDecoder().decode([InspectContainer].self, from: data)
        } catch {
            throw DockerParsingError.invalidJSON(error.localizedDescription)
        }

        return try inspected.map { item in
            var mappings: [DockerPortMapping] = []
            for (containerEndpoint, bindings) in item.networkSettings.ports {
                let endpointParts = containerEndpoint.split(separator: "/", maxSplits: 1)
                guard
                    endpointParts.count == 2,
                    let containerPort = UInt16(endpointParts[0]),
                    containerPort > 0
                else {
                    throw DockerParsingError.invalidPort(containerEndpoint)
                }
                for binding in bindings ?? [] {
                    guard let hostPort = UInt16(binding.hostPort), hostPort > 0 else {
                        throw DockerParsingError.invalidPort(binding.hostPort)
                    }
                    mappings.append(DockerPortMapping(
                        hostIP: binding.hostIP,
                        hostPort: hostPort,
                        containerPort: containerPort,
                        protocolName: String(endpointParts[1]).lowercased()
                    ))
                }
            }

            let labels = item.configuration.labels ?? [:]
            return DockerContainer(
                id: item.id,
                name: item.name.hasPrefix("/") ? String(item.name.dropFirst()) : item.name,
                image: item.configuration.image,
                status: item.state.status,
                compose: DockerComposeIdentity(
                    project: labels["com.docker.compose.project"],
                    service: labels["com.docker.compose.service"],
                    containerNumber: labels["com.docker.compose.container-number"],
                    workingDirectory: labels["com.docker.compose.project.working_dir"],
                    configFiles: labels["com.docker.compose.project.config_files"]
                ),
                portMappings: mappings.sorted {
                    ($0.hostPort, $0.containerPort, $0.protocolName) < ($1.hostPort, $1.containerPort, $1.protocolName)
                }
            )
        }
    }

    private struct PSRow: Decodable {
        let id: String

        private enum CodingKeys: String, CodingKey { case id = "ID" }
    }

    private struct InspectContainer: Decodable {
        let id: String
        let name: String
        let configuration: Configuration
        let state: State
        let networkSettings: NetworkSettings

        private enum CodingKeys: String, CodingKey {
            case id = "Id"
            case name = "Name"
            case configuration = "Config"
            case state = "State"
            case networkSettings = "NetworkSettings"
        }
    }

    private struct Configuration: Decodable {
        let image: String
        let labels: [String: String]?

        private enum CodingKeys: String, CodingKey {
            case image = "Image"
            case labels = "Labels"
        }
    }

    private struct State: Decodable {
        let status: String
        private enum CodingKeys: String, CodingKey { case status = "Status" }
    }

    private struct NetworkSettings: Decodable {
        let ports: [String: [PortBinding]?]
        private enum CodingKeys: String, CodingKey { case ports = "Ports" }
    }

    private struct PortBinding: Decodable {
        let hostIP: String
        let hostPort: String

        private enum CodingKeys: String, CodingKey {
            case hostIP = "HostIp"
            case hostPort = "HostPort"
        }
    }
}
