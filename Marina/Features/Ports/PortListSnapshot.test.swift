import AppKit
import SwiftUI
import XCTest
@testable import Marina

@MainActor
final class PortListSnapshotTests: XCTestCase {
    func test_一覧パネルをREADME用画像として描画する() async throws {
        let documentationDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "docs")

        let defaults = try XCTUnwrap(UserDefaults(suiteName: "MarinaSnapshotTests"))
        defaults.removePersistentDomain(forName: "MarinaSnapshotTests")
        let settings = MarinaSettings(defaults: defaults)
        let runner = MockCommandRunner(results: [])
        let viewModel = PortListViewModel(
            settings: settings,
            portScanner: SnapshotPortScanner(),
            dockerResolver: SnapshotDockerResolver(),
            actionController: PortActionController(runner: runner, dockerExecutableURL: nil)
        )
        await viewModel.refresh()

        let darkSize = try render(
            PortListView(viewModel: viewModel, settings: settings).preferredColorScheme(.dark),
            to: documentationDirectory.appending(path: "marina-panel.png")
        )
        let lightSize = try render(
            PortListView(viewModel: viewModel, settings: settings).preferredColorScheme(.light),
            to: documentationDirectory.appending(path: "marina-panel-light.png")
        )
        XCTAssertGreaterThan(darkSize, 10_000)
        XCTAssertGreaterThan(lightSize, 10_000)
    }

    func test_詳細を同じパネル幅で描画する() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "MarinaDetailSnapshotTests"))
        defaults.removePersistentDomain(forName: "MarinaDetailSnapshotTests")
        let settings = MarinaSettings(defaults: defaults)
        let runner = MockCommandRunner(results: [])
        let viewModel = PortListViewModel(
            settings: settings,
            portScanner: SnapshotPortScanner(),
            dockerResolver: SnapshotDockerResolver(),
            actionController: PortActionController(runner: runner, dockerExecutableURL: nil)
        )
        await viewModel.refresh()
        let port = try XCTUnwrap(viewModel.filteredPorts().first)
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "marina-detail.png")

        let size = try render(
            PortDetailView(port: port, onDone: {})
                .frame(width: 420)
                .background(Color.white)
                .preferredColorScheme(.light),
            to: outputURL,
            height: 560
        )

        XCTAssertGreaterThan(size, 10_000)
    }

    private func render<Content: View>(
        _ content: Content,
        to outputURL: URL,
        height: CGFloat = 650
    ) throws -> Int {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 420, height: height)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Marina"
        window.contentView = hostingView
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()

        let representation = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        try png.write(to: outputURL, options: .atomic)
        return png.count
    }
}

private struct SnapshotPortScanner: PortScanning {
    func scan() async throws -> PortScanSnapshot {
        PortScanSnapshot(listeners: [
            listener(pid: 48_291, name: "node", command: "next dev", port: 3_000, address: "127.0.0.1"),
            listener(pid: 40_000, name: "ruby", command: "bin/rails server -p 4000", port: 4_000, address: "127.0.0.1"),
            listener(pid: 51_730, name: "node", command: "vite --host 127.0.0.1", port: 5_173, address: "127.0.0.1"),
            listener(pid: 910, name: "com.docker.backend", command: nil, port: 5_432, address: "0.0.0.0"),
            listener(pid: 63_790, name: "redis-server", command: "redis-server *:6379", port: 6_379, address: "127.0.0.1"),
            listener(pid: 8_000, name: "Python", command: "uvicorn main:app", port: 8_000, address: "127.0.0.1"),
            listener(pid: 8_001, name: "python", command: "python manage.py runserver 8001", port: 8_001, address: "127.0.0.1"),
            listener(pid: 8_080, name: "nginx", command: "nginx -g daemon off;", port: 8_080, address: "0.0.0.0")
        ], warnings: [])
    }

    private func listener(pid: Int32, name: String, command: String?, port: UInt16, address: String) -> ListeningPort {
        ListeningPort(
            process: ProcessIdentity(
                pid: pid,
                name: name,
                user: "developer",
                command: command,
                executablePath: "/usr/local/bin/\(name)",
                parentPID: 1,
                workingDirectory: "/Users/developer/Projects/marina"
            ),
            port: port,
            bindAddresses: [address],
            ipFamilies: [.ipv4],
            transportProtocol: "tcp"
        )
    }
}

private struct SnapshotDockerResolver: DockerResolving {
    func fetchContainers() async -> DockerSnapshot {
        DockerSnapshot(
            containers: [
                DockerContainer(
                    id: String(repeating: "a", count: 64),
                    name: "marina-db-1",
                    image: "postgres:17",
                    status: "running",
                    compose: DockerComposeIdentity(
                        project: "marina",
                        service: "db",
                        containerNumber: "1",
                        workingDirectory: "/Users/developer/Projects/marina",
                        configFiles: "compose.yml"
                    ),
                    portMappings: [
                        DockerPortMapping(hostIP: "0.0.0.0", hostPort: 5_432, containerPort: 5_432, protocolName: "tcp")
                    ]
                )
            ],
            availability: .available
        )
    }
}
