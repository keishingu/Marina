import SwiftUI

struct ServiceIcon: View {
    let kind: ServiceKind
    let isDocker: Bool

    var body: some View {
        Group {
            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(7)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isDocker ? Color.blue : Color.primary)
            }
        }
            .frame(width: 34, height: 34)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if isDocker {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(.blue, in: Circle())
                        .offset(x: 3, y: 3)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("\(kind.displayName) service")
    }

    private var assetName: String? {
        switch kind {
        case .nextJS: "ServiceLogoNextJS"
        case .nodeJS: "ServiceLogoNodeJS"
        case .vite: "ServiceLogoVite"
        case .python, .uvicorn: "ServiceLogoPython"
        case .django: "ServiceLogoDjango"
        case .ruby: "ServiceLogoRuby"
        case .rails: "ServiceLogoRails"
        case .postgreSQL: "ServiceLogoPostgreSQL"
        case .mySQL: "ServiceLogoMySQL"
        case .redis: "ServiceLogoRedis"
        case .nginx: "ServiceLogoNGINX"
        case .caddy: "ServiceLogoCaddy"
        case .java: "ServiceLogoJava"
        case .go: "ServiceLogoGo"
        case .docker: "ServiceLogoDocker"
        case .unknown: nil
        }
    }

    private var symbolName: String {
        switch kind {
        case .nextJS, .vite, .nginx, .caddy: "globe"
        case .nodeJS: "hexagon"
        case .python, .uvicorn, .django, .ruby, .rails, .java, .go:
            "chevron.left.forwardslash.chevron.right"
        case .postgreSQL, .mySQL: "cylinder"
        case .redis: "square.stack.3d.up"
        case .docker: "shippingbox"
        case .unknown: "terminal"
        }
    }

}
