import Foundation

struct PortScanSnapshot: Sendable {
    let listeners: [ListeningPort]
    let warnings: [String]
}

protocol PortScanning: Sendable {
    func scan() async throws -> PortScanSnapshot
}

struct LsofPortScanner: PortScanning {
    private let runner: any CommandRunning
    private let processResolver: any ProcessResolving
    private let parser: LsofParser

    init(
        runner: any CommandRunning,
        processResolver: any ProcessResolving,
        parser: LsofParser = LsofParser()
    ) {
        self.runner = runner
        self.processResolver = processResolver
        self.parser = parser
    }

    func scan() async throws -> PortScanSnapshot {
        let data: Data
        do {
            data = try await runner.run(
                executableURL: URL(fileURLWithPath: "/usr/sbin/lsof"),
                arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-F0pcuLftnPT"]
            ).standardOutput
        } catch CommandRunnerError.nonZeroExit(_, let status, let message)
            where status == 1 && message.isEmpty {
            data = Data()
        }

        let parsed = parser.parse(data)
        guard !parsed.isEmpty else {
            return PortScanSnapshot(listeners: [], warnings: [])
        }

        let resolution = await processResolver.resolve(parsed.map(\.process))
        let enriched = parsed.map { listener in
            guard let process = resolution.identities[listener.process.pid] else { return listener }
            return ListeningPort(
                process: process,
                port: listener.port,
                bindAddresses: listener.bindAddresses,
                ipFamilies: listener.ipFamilies,
                transportProtocol: listener.transportProtocol
            )
        }
        return PortScanSnapshot(listeners: enriched, warnings: resolution.warnings)
    }
}
