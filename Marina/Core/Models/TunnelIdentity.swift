import Foundation

enum TunnelProvider: String, Codable, Hashable, Sendable {
    case ngrok
    case cloudflare

    var displayName: String {
        switch self {
        case .ngrok: "ngrok"
        case .cloudflare: "Cloudflare"
        }
    }

    var assetName: String {
        switch self {
        case .ngrok: "ServiceLogoNgrok"
        case .cloudflare: "ServiceLogoCloudflare"
        }
    }

    var dashboardURL: URL {
        switch self {
        case .ngrok: URL(string: "https://dashboard.ngrok.com/")!
        case .cloudflare: URL(string: "https://dash.cloudflare.com/")!
        }
    }

    var localInterfaceActionTitle: String? {
        switch self {
        case .ngrok: "Open Traffic Inspector"
        case .cloudflare: nil
        }
    }
}

struct TunnelIdentity: Identifiable, Codable, Hashable, Sendable {
    let provider: TunnelProvider
    let processID: Int32
    let command: String
    let originHost: String
    let originPort: UInt16
    let localInterfacePort: UInt16?

    var id: String { "\(provider.rawValue)-\(processID)-\(originPort)" }

    var originAddress: String { "\(originHost):\(originPort)" }

    var processIdentity: ProcessIdentity {
        ProcessIdentity(
            pid: processID,
            name: provider == .ngrok ? "ngrok" : "cloudflared",
            user: nil,
            command: command,
            executablePath: nil,
            parentPID: nil,
            workingDirectory: nil
        )
    }

    var localInterfaceURL: URL? {
        guard let localInterfacePort else { return nil }
        return URL(string: "http://localhost:\(localInterfacePort)")
    }
}
