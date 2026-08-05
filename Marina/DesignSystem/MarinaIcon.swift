import AppKit
import SwiftUI

enum MarinaMenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            let side = min(rect.width, rect.height)
            let xOffset = rect.minX + (rect.width - side) / 2
            let yOffset = rect.minY + (rect.height - side) / 2
            let point: (CGFloat, CGFloat) -> NSPoint = { x, y in
                NSPoint(x: xOffset + side * x, y: yOffset + side * y)
            }

            let path = NSBezierPath()
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.appendOval(
                in: NSRect(
                    x: xOffset + side * 0.405,
                    y: yOffset + side * 0.04,
                    width: side * 0.19,
                    height: side * 0.19
                )
            )
            path.move(to: point(0.5, 0.23))
            path.line(to: point(0.5, 0.69))
            path.move(to: point(0.29, 0.37))
            path.line(to: point(0.71, 0.37))
            path.move(to: point(0.5, 0.69))
            path.curve(
                to: point(0.15, 0.57),
                controlPoint1: point(0.40, 0.88),
                controlPoint2: point(0.22, 0.82)
            )
            path.move(to: point(0.5, 0.69))
            path.curve(
                to: point(0.85, 0.57),
                controlPoint1: point(0.60, 0.88),
                controlPoint2: point(0.78, 0.82)
            )
            path.move(to: point(0.15, 0.57))
            path.line(to: point(0.18, 0.73))
            path.move(to: point(0.15, 0.57))
            path.line(to: point(0.29, 0.61))
            path.move(to: point(0.85, 0.57))
            path.line(to: point(0.82, 0.73))
            path.move(to: point(0.85, 0.57))
            path.line(to: point(0.71, 0.61))

            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

struct MarinaIcon: View {
    var size: CGFloat = 24

    var body: some View {
        MarinaAnchorSymbol()
            .frame(width: size * 0.62, height: size * 0.62)
            .foregroundStyle(.blue)
            .frame(width: size, height: size)
            .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct MarinaAnchorSymbol: View {
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let xOffset = (size.width - side) / 2
            let yOffset = (size.height - side) / 2
            let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
                CGPoint(x: xOffset + side * x, y: yOffset + side * y)
            }
            let strokeStyle = StrokeStyle(
                lineWidth: max(1.2, side * 0.075),
                lineCap: .round,
                lineJoin: .round
            )

            var path = Path()
            path.addEllipse(
                in: CGRect(
                    x: xOffset + side * 0.405,
                    y: yOffset + side * 0.04,
                    width: side * 0.19,
                    height: side * 0.19
                )
            )
            path.move(to: point(0.5, 0.23))
            path.addLine(to: point(0.5, 0.69))
            path.move(to: point(0.29, 0.37))
            path.addLine(to: point(0.71, 0.37))
            path.move(to: point(0.5, 0.69))
            path.addCurve(
                to: point(0.15, 0.57),
                control1: point(0.40, 0.88),
                control2: point(0.22, 0.82)
            )
            path.move(to: point(0.5, 0.69))
            path.addCurve(
                to: point(0.85, 0.57),
                control1: point(0.60, 0.88),
                control2: point(0.78, 0.82)
            )
            path.move(to: point(0.15, 0.57))
            path.addLine(to: point(0.18, 0.73))
            path.move(to: point(0.15, 0.57))
            path.addLine(to: point(0.29, 0.61))
            path.move(to: point(0.85, 0.57))
            path.addLine(to: point(0.82, 0.73))
            path.move(to: point(0.85, 0.57))
            path.addLine(to: point(0.71, 0.61))

            context.stroke(path, with: .foreground, style: strokeStyle)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
