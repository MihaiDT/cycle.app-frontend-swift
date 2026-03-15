import SwiftUI

// MARK: - Arrow Icon (Custom SVG)

private struct ArrowIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 22.0
        let scaleY = rect.height / 8.0

        var path = Path()

        // Arrow head
        path.move(to: CGPoint(x: 21.3536 * scaleX, y: 4.03568 * scaleY))
        path.addCurve(
            to: CGPoint(x: 21.3536 * scaleX, y: 3.32858 * scaleY),
            control1: CGPoint(x: 21.5488 * scaleX, y: 3.84042 * scaleY),
            control2: CGPoint(x: 21.5488 * scaleX, y: 3.52384 * scaleY)
        )
        path.addLine(to: CGPoint(x: 18.1716 * scaleX, y: 0.146595 * scaleY))
        path.addCurve(
            to: CGPoint(x: 17.4645 * scaleX, y: 0.146595 * scaleY),
            control1: CGPoint(x: 17.9763 * scaleX, y: -0.0486672 * scaleY),
            control2: CGPoint(x: 17.6597 * scaleX, y: -0.0486672 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 17.4645 * scaleX, y: 0.853702 * scaleY),
            control1: CGPoint(x: 17.2692 * scaleX, y: 0.341857 * scaleY),
            control2: CGPoint(x: 17.2692 * scaleX, y: 0.65844 * scaleY)
        )
        path.addLine(to: CGPoint(x: 20.2929 * scaleX, y: 3.68213 * scaleY))
        path.addLine(to: CGPoint(x: 17.4645 * scaleX, y: 6.51056 * scaleY))
        path.addCurve(
            to: CGPoint(x: 17.4645 * scaleX, y: 7.21766 * scaleY),
            control1: CGPoint(x: 17.2692 * scaleX, y: 6.70582 * scaleY),
            control2: CGPoint(x: 17.2692 * scaleX, y: 7.0224 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 18.1716 * scaleX, y: 7.21766 * scaleY),
            control1: CGPoint(x: 17.6597 * scaleX, y: 7.41293 * scaleY),
            control2: CGPoint(x: 17.9763 * scaleX, y: 7.41293 * scaleY)
        )
        path.addLine(to: CGPoint(x: 21.3536 * scaleX, y: 4.03568 * scaleY))
        path.closeSubpath()

        // Line
        path.move(to: CGPoint(x: 0, y: 3.68213 * scaleY))
        path.addLine(to: CGPoint(x: 0, y: 4.18213 * scaleY))
        path.addLine(to: CGPoint(x: 21 * scaleX, y: 4.18213 * scaleY))
        path.addLine(to: CGPoint(x: 21 * scaleX, y: 3.68213 * scaleY))
        path.addLine(to: CGPoint(x: 21 * scaleX, y: 3.18213 * scaleY))
        path.addLine(to: CGPoint(x: 0, y: 3.18213 * scaleY))
        path.addLine(to: CGPoint(x: 0, y: 3.68213 * scaleY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Glass Button (Reusable)

public struct GlassButton: View {
    public let title: String
    public let showArrow: Bool
    public let width: CGFloat
    public let height: CGFloat
    public let action: () -> Void

    public init(
        _ title: String,
        showArrow: Bool = false,
        width: CGFloat = 203,
        height: CGFloat = 55,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.showArrow = showArrow
        self.width = width
        self.height = height
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignColors.text)

                if showArrow {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignColors.text)
                }
            }
            .frame(width: width, height: height)
            .glassEffectCapsule()
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Convenience Factories

extension GlassButton {
    /// Creates a "Begin" button with arrow icon
    public static func begin(action: @escaping () -> Void) -> GlassButton {
        GlassButton("Begin", showArrow: true, action: action)
    }

    /// Creates a "Continue" button with arrow icon
    public static func `continue`(action: @escaping () -> Void) -> GlassButton {
        GlassButton("Continue", showArrow: true, action: action)
    }

    /// Creates a "Next" button without arrow
    public static func next(action: @escaping () -> Void) -> GlassButton {
        GlassButton("Next", showArrow: false, action: action)
    }

    /// Creates a "Done" button without arrow
    public static func done(action: @escaping () -> Void) -> GlassButton {
        GlassButton("Done", showArrow: false, action: action)
    }
}

// MARK: - Glass Back Button (Round)

public struct GlassBackButton: View {
    public let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignColors.text)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.5),
                                            Color.white.opacity(0.1),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                }
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Begin Button") {
    ZStack {
        LinearGradient(
            colors: [.white, Color(red: 0.85, green: 0.75, blue: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassButton.begin {}
            GlassButton.continue {}
            GlassButton.next {}
            GlassButton.done {}
            GlassButton("Custom", showArrow: true) {}
        }
    }
}
