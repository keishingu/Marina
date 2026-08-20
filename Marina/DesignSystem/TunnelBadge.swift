import SwiftUI

struct TunnelBadge: View {
    let tunnel: TunnelIdentity

    var body: some View {
        HStack(spacing: 4) {
            Image(tunnel.provider.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
            Text("\(tunnel.provider.displayName) tunnel")
                .lineLimit(1)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 8, weight: .bold))
                .accessibilityHidden(true)
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
        .accessibilityLabel(
            "\(tunnel.provider.displayName) tunnel publishes \(tunnel.originAddress)"
        )
    }
}
