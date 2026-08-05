import SwiftUI

struct MarinaIcon: View {
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: "sailboat.fill")
            .font(.system(size: size * 0.58, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.blue)
            .frame(width: size, height: size)
            .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}
