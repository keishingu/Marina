import Foundation

struct LsofParser: Sendable {
    func parse(_ data: Data) -> [ListeningPort] {
        let output = String(decoding: data, as: UTF8.self)
        let fields = output.components(separatedBy: CharacterSet(charactersIn: "\0\n"))

        var process: ProcessIdentity?
        var socket = SocketFields()
        var listeners: [ListeningPort] = []

        func makeListener() -> ListeningPort? {
            guard
                let process,
                socket.state == nil || socket.state == "LISTEN",
                socket.protocolName?.uppercased() == "TCP",
                let endpoint = socket.endpoint,
                let parsedEndpoint = parseEndpoint(endpoint)
            else {
                return nil
            }

            return ListeningPort(
                process: process,
                port: parsedEndpoint.port,
                bindAddresses: [parsedEndpoint.address],
                ipFamilies: [socket.family ?? .unknown],
                transportProtocol: "tcp"
            )
        }

        func parseEndpoint(_ rawValue: String) -> (address: String, port: UInt16)? {
            let value = rawValue.replacingOccurrences(of: " (LISTEN)", with: "")
            guard let separator = value.lastIndex(of: ":") else { return nil }
            let portText = value[value.index(after: separator)...]
            guard let port = UInt16(portText), port > 0 else { return nil }
            var address = String(value[..<separator])
            if address.hasPrefix("[") && address.hasSuffix("]") {
                address.removeFirst()
                address.removeLast()
            }
            return (address.isEmpty ? "*" : address, port)
        }

        for field in fields where !field.isEmpty {
            guard let identifier = field.first else { continue }
            let value = String(field.dropFirst())
            switch identifier {
            case "p":
                if let listener = makeListener() { listeners.append(listener) }
                socket = SocketFields()
                guard let pid = Int32(value) else {
                    process = nil
                    continue
                }
                process = ProcessIdentity(
                    pid: pid,
                    name: "Unknown",
                    user: nil,
                    command: nil,
                    executablePath: nil,
                    parentPID: nil,
                    workingDirectory: nil
                )
            case "c":
                guard let existing = process else { continue }
                process = ProcessIdentity(
                    pid: existing.pid,
                    name: value,
                    user: existing.user,
                    command: existing.command,
                    executablePath: existing.executablePath,
                    parentPID: existing.parentPID,
                    workingDirectory: existing.workingDirectory
                )
            case "L", "u":
                guard let existing = process else { continue }
                process = ProcessIdentity(
                    pid: existing.pid,
                    name: existing.name,
                    user: value,
                    command: existing.command,
                    executablePath: existing.executablePath,
                    parentPID: existing.parentPID,
                    workingDirectory: existing.workingDirectory
                )
            case "f":
                if let listener = makeListener() { listeners.append(listener) }
                socket = SocketFields()
            case "t":
                socket.family = switch value {
                case "IPv4": .ipv4
                case "IPv6": .ipv6
                default: .unknown
                }
            case "P":
                socket.protocolName = value
            case "T":
                if value.hasPrefix("ST=") { socket.state = String(value.dropFirst(3)) }
            case "n":
                socket.endpoint = value
            default:
                continue
            }
        }

        if let listener = makeListener() { listeners.append(listener) }
        return normalize(listeners)
    }

    func normalize(_ listeners: [ListeningPort]) -> [ListeningPort] {
        let grouped = Dictionary(grouping: listeners) {
            "\($0.process.pid)-\($0.port)-\($0.transportProtocol.lowercased())"
        }

        return grouped.values.compactMap { matches in
            guard let first = matches.first else { return nil }
            let addresses = Set(matches.flatMap(\.bindAddresses)).sorted()
            let families = Set(matches.flatMap(\.ipFamilies))
            return ListeningPort(
                process: first.process,
                port: first.port,
                bindAddresses: addresses,
                ipFamilies: families,
                transportProtocol: first.transportProtocol.lowercased()
            )
        }
        .sorted {
            if $0.port != $1.port { return $0.port < $1.port }
            let nameComparison = $0.process.name.localizedStandardCompare($1.process.name)
            if nameComparison != .orderedSame { return nameComparison == .orderedAscending }
            return $0.process.pid < $1.process.pid
        }
    }

    private struct SocketFields {
        var family: IPFamily?
        var protocolName: String?
        var state: String?
        var endpoint: String?
    }
}
