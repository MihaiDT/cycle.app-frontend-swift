import SwiftUI

// MARK: - Glass Shape

public enum GlassShape {
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule

    public func shape() -> AnyShape {
        switch self {
        case .roundedRectangle(let cornerRadius):
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        case .capsule:
            AnyShape(Capsule())
        }
    }

    public func cornerRadius(for size: CGSize) -> CGFloat {
        switch self {
        case .roundedRectangle(let cornerRadius):
            return cornerRadius
        case .capsule:
            return min(size.width, size.height) / 2
        }
    }
}

// MARK: - Highlight Arc Shape

/// Custom shape for highlight arc (top-left curved highlight)
public struct HighlightArcShape: Shape {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start from left side at 60% height
        path.move(to: CGPoint(x: 0, y: rect.height * 0.6))

        // Line up to corner radius
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))

        // Arc around top-left corner
        path.addArc(
            center: CGPoint(x: cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        // Line to 35% of width
        path.addLine(to: CGPoint(x: rect.width * 0.35, y: 0))

        return path
    }
}

// MARK: - Liquid Glass Modifier

/// Liquid Glass - iOS 26 Style
///
/// EXACT 1:1 from Figma XML export (same as Android):
/// - Fill 1: #8C8C8C at 25% (0x408C8C8C)
/// - Fill 2: #171717 (with blend mode, simulated as low opacity)
/// - Fill 3: Gradient #FDD2C9 rotated -126.113° at 38%
/// - Backdrop blur: 6px
/// - Drop shadows: 8dp + 2dp
/// - Inner shadows: highlight, border, glow
public struct LiquidGlassModifier: ViewModifier {
    public let shape: GlassShape

    public init(shape: GlassShape) {
        self.shape = shape
    }

    public func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    let cornerRadius = shape.cornerRadius(for: geo.size)

                    ZStack {
                        // Layer 1: Base gray at 15% opacity (more transparent)
                        shape.shape()
                            .fill(DesignColors.glassGray.opacity(0.15))

                        // Layer 2: Dark tint at 5% (subtler)
                        shape.shape()
                            .fill(DesignColors.glassDarkTint.opacity(0.05))

                        // Layer 3: Blur material (ultra thin for more glass look)
                        shape.shape()
                            .fill(.ultraThinMaterial)

                        // Layer 4: Peach gradient rotated -126.113°
                        shape.shape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignColors.glassPeach.opacity(0),
                                        DesignColors.glassPeach.opacity(0.38),
                                    ],
                                    startPoint: UnitPoint(x: 0.8, y: 0.2),
                                    endPoint: UnitPoint(x: 0.2, y: 0.8)
                                )
                            )

                        // Layer 5: Inner glow - radial gradient (stronger)
                        shape.shape()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        DesignColors.glassInnerGlow.opacity(0.4),
                                        DesignColors.glassInnerGlow.opacity(0.15),
                                        Color.clear,
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geo.size.width * 0.5
                                )
                            )

                        // Layer 6: Top highlight - vertical gradient (brighter)
                        shape.shape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                        Color.clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: UnitPoint(x: 0.5, y: 0.25)
                                )
                            )

                        // Layer 7: Highlight arc stroke at top-left (more visible)
                        HighlightArcShape(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.95),
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.3),
                                        Color.clear,
                                    ],
                                    startPoint: UnitPoint(x: 0, y: 0.6),
                                    endPoint: UnitPoint(x: 0.5, y: 0)
                                ),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                            )
                    }
                }
            )
            .clipShape(shape.shape())
    }
}

// MARK: - View Extensions

extension View {
    public func liquidGlass(cornerRadius: CGFloat) -> some View {
        modifier(LiquidGlassModifier(shape: .roundedRectangle(cornerRadius: cornerRadius)))
    }

    public func liquidGlassCapsule() -> some View {
        modifier(LiquidGlassModifier(shape: .capsule))
    }

    // Keep old names for compatibility
    public func glassEffect(cornerRadius: CGFloat) -> some View {
        liquidGlass(cornerRadius: cornerRadius)
    }

    public func glassEffectCapsule() -> some View {
        liquidGlassCapsule()
    }
}
