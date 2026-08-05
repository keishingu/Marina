import SwiftUI

struct ServiceIcon: View {
    let kind: ServiceKind
    let isDocker: Bool

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 14, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isDocker ? Color.blue : Color.primary)
            .frame(width: 30, height: 30)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
