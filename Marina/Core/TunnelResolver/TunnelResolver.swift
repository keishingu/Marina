import Foundation

struct TunnelResolution: Sendable {
    let tunnelsByListenerID: [String: [TunnelIdentity]]
    let linkedListenerIDs: Set<String>
    let warnings: [String]
}

struct TunnelResolver: Sendable {
    func resolve(listeners: [ListeningPort]) -> TunnelResolution {
        let tunnelProcesses = Dictionary(
            listeners.compactMap { listener in
                provider(for: listener.process).map { (listener.process.pid, ($0, listener.process)) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        var tunnelsByListenerID: [String: [TunnelIdentity]] = [:]
        var linkedListenerIDs: Set<String> = []
        var warnings: [String] = []

        for (processID, providerAndProcess) in tunnelProcesses {
            let (provider, process) = providerAndProcess
            guard let command = process.command, !command.isEmpty,
                  let origin = origin(for: provider, command: command) else {
                warnings.append(
                    "\(provider.displayName) tunnel (PID \(processID)) origin could not be determined from its command. The tunnel was not linked to a local port."
                )
                continue
            }

            let originListeners = listeners.filter {
                matches($0, origin: origin, excluding: processID)
            }
            guard !originListeners.isEmpty else {
                warnings.append(
                    "\(provider.displayName) tunnel (PID \(processID)) points to \(origin.host):\(origin.port), but that local address is not listening. The tunnel was not linked."
                )
                continue
            }

            let tunnelListeners = listeners.filter {
                $0.process.pid == processID && $0.port != origin.port
            }
            let localInterfacePort = provider == .ngrok
                ? tunnelListeners.first(where: { $0.port == 4_040 })?.port
                    ?? tunnelListeners.first(where: \.isLoopbackOnly)?.port
                : nil
            let tunnel = TunnelIdentity(
                provider: provider,
                processID: processID,
                command: command,
                originHost: origin.host,
                originPort: origin.port,
                localInterfacePort: localInterfacePort
            )
            for originListener in originListeners {
                tunnelsByListenerID[originListener.id, default: []].append(tunnel)
            }
            linkedListenerIDs.formUnion(tunnelListeners.map(\.id))
        }

        return TunnelResolution(
            tunnelsByListenerID: tunnelsByListenerID.mapValues {
                $0.sorted { ($0.provider.rawValue, $0.processID) < ($1.provider.rawValue, $1.processID) }
            },
            linkedListenerIDs: linkedListenerIDs,
            warnings: warnings.sorted()
        )
    }

    private func matches(
        _ listener: ListeningPort,
        origin: Origin,
        excluding processID: Int32
    ) -> Bool {
        guard listener.port == origin.port, listener.process.pid != processID else {
            return false
        }

        let addresses = Set(listener.bindAddresses.map { $0.lowercased() })
        let matchesIPv4Wildcard = addresses.contains("0.0.0.0") ||
            (addresses.contains("*") && listener.ipFamilies.contains(.ipv4))
        let matchesIPv6Wildcard = addresses.contains("::") ||
            (addresses.contains("*") && listener.ipFamilies.contains(.ipv6))

        switch origin.host {
        case "localhost":
            return matchesIPv4Wildcard || matchesIPv6Wildcard ||
                !addresses.isDisjoint(with: ["localhost", "127.0.0.1", "::1"])
        case "127.0.0.1":
            return matchesIPv4Wildcard || !addresses.isDisjoint(with: ["localhost", "127.0.0.1"])
        case "::1":
            return matchesIPv6Wildcard || !addresses.isDisjoint(with: ["localhost", "::1"])
        case "0.0.0.0":
            return matchesIPv4Wildcard
        default:
            return false
        }
    }

    private func provider(for process: ProcessIdentity) -> TunnelProvider? {
        let executableName = process.executablePath.map {
            URL(fileURLWithPath: $0).lastPathComponent.lowercased()
        }
        let processName = process.name.lowercased()

        if executableName == "ngrok" || processName == "ngrok" {
            return .ngrok
        }
        if executableName == "cloudflared" || processName == "cloudflared" {
            return .cloudflare
        }
        return nil
    }

    private func origin(for provider: TunnelProvider, command: String) -> Origin? {
        let tokens = command
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }

        switch provider {
        case .ngrok:
            guard let httpIndex = tokens.firstIndex(where: { $0.lowercased() == "http" }) else {
                return nil
            }
            return tokens[tokens.index(after: httpIndex)...]
                .lazy
                .filter { !$0.hasPrefix("-") }
                .compactMap(parseOrigin)
                .first
        case .cloudflare:
            for (index, token) in tokens.enumerated() {
                if token == "--url", tokens.indices.contains(index + 1) {
                    return parseOrigin(tokens[index + 1])
                }
                if token.hasPrefix("--url=") {
                    return parseOrigin(String(token.dropFirst("--url=".count)))
                }
            }
            return nil
        }
    }

    private func parseOrigin(_ value: String) -> Origin? {
        if let port = UInt16(value) {
            return Origin(host: "localhost", port: port)
        }

        let urlValue = value.contains("://") ? value : "http://\(value)"
        guard let components = URLComponents(string: urlValue),
              let host = components.host?.lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]")),
              Self.localHosts.contains(host) else {
            return nil
        }
        let port = components.port ?? (components.scheme?.lowercased() == "https" ? 443 : 80)
        guard let port = UInt16(exactly: port) else { return nil }
        return Origin(host: host, port: port)
    }

    private static let localHosts: Set<String> = [
        "localhost",
        "127.0.0.1",
        "::1",
        "0.0.0.0"
    ]

    private struct Origin {
        let host: String
        let port: UInt16
    }
}
