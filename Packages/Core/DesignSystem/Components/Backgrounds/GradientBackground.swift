import SwiftUI

// MARK: - Gradient Background

/// Custom gradient background matching the Figma design
/// Completely vector-based, no PNG required
public struct GradientBackground: View {
    // Base gradient colors - from Figma
    public let baseGradientStart: Color
    public let baseGradientMiddle: Color
    public let baseGradientEnd: Color

    // Blob colors - from Figma
    public let blobColor1: Color
    public let blobColor2: Color
    public let blobColor3: Color

    // Options
    public let showNoise: Bool
    public let noiseOpacity: Double

    public init(
        baseGradientStart: Color = Color(hex: 0xFEFCF7),  // Cream white
        baseGradientMiddle: Color = Color(hex: 0xEBCFC3),  // Light peachy
        baseGradientEnd: Color = Color(hex: 0xD8D3CB),  // Dusty gray-pink
        blobColor1: Color = Color(hex: 0xEBCFC3),  // Light peach
        blobColor2: Color = Color(hex: 0xD6A59A),  // Medium rose
        blobColor3: Color = Color(hex: 0xC18F7D),  // Darker terracotta
        showNoise: Bool = true,
        noiseOpacity: Double = 0.04
    ) {
        self.baseGradientStart = baseGradientStart
        self.baseGradientMiddle = baseGradientMiddle
        self.baseGradientEnd = baseGradientEnd
        self.blobColor1 = blobColor1
        self.blobColor2 = blobColor2
        self.blobColor3 = blobColor3
        self.showNoise = showNoise
        self.noiseOpacity = noiseOpacity
    }

    public init(theme: BackgroundTheme, showNoise: Bool = true, noiseOpacity: Double = 0.04) {
        self.baseGradientStart = theme.baseGradientStart
        self.baseGradientMiddle = theme.baseGradientMiddle
        self.baseGradientEnd = theme.baseGradientEnd
        self.blobColor1 = theme.blobColor1
        self.blobColor2 = theme.blobColor2
        self.blobColor3 = theme.blobColor3
        self.showNoise = showNoise
        self.noiseOpacity = noiseOpacity
    }

    public var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height

            // 1. Base gradient (155.673° angle from Figma)
            let angleRad = 155.673 * .pi / 180
            let gradientStart = CGPoint(
                x: width / 2 - cos(angleRad) * width,
                y: height / 2 - sin(angleRad) * height
            )
            let gradientEnd = CGPoint(
                x: width / 2 + cos(angleRad) * width,
                y: height / 2 + sin(angleRad) * height
            )

            let baseGradient = Gradient(stops: [
                .init(color: baseGradientStart, location: 0.0015),
                .init(color: baseGradientMiddle, location: 0.45),
                .init(color: baseGradientEnd, location: 0.998),
            ])

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    baseGradient,
                    startPoint: gradientStart,
                    endPoint: gradientEnd
                )
            )

            // 2. Draw organic blob shapes
            // Blob 1 - Top area, lighter
            drawBlob(
                in: &context,
                centerX: width * 0.3,
                centerY: height * 0.15,
                radiusX: width * 0.8,
                radiusY: height * 0.35,
                color: blobColor1.opacity(0.6),
                rotation: -20
            )

            // Blob 2 - Middle-right, medium color
            drawBlob(
                in: &context,
                centerX: width * 0.7,
                centerY: height * 0.45,
                radiusX: width * 0.6,
                radiusY: height * 0.4,
                color: blobColor2.opacity(0.4),
                rotation: 15
            )

            // Blob 3 - Bottom area, darker
            drawBlob(
                in: &context,
                centerX: width * 0.4,
                centerY: height * 0.75,
                radiusX: width * 0.9,
                radiusY: height * 0.35,
                color: blobColor3.opacity(0.35),
                rotation: -10
            )

            // 3. Noise texture overlay
            if showNoise {
                drawNoise(in: &context, size: size, opacity: noiseOpacity)
            }
        }
        .ignoresSafeArea()
    }

    /// Draw an organic blob shape using bezier curves
    private func drawBlob(
        in context: inout GraphicsContext,
        centerX: CGFloat,
        centerY: CGFloat,
        radiusX: CGFloat,
        radiusY: CGFloat,
        color: Color,
        rotation: CGFloat
    ) {
        let angleRad = rotation * .pi / 180
        let cosA = cos(angleRad)
        let sinA = sin(angleRad)

        // Create organic blob with 6 control points
        let pointCount = 6
        var controlPoints: [CGPoint] = []

        for i in 0..<pointCount {
            let angle = CGFloat(2 * .pi * Double(i) / Double(pointCount))
            // Add some variation to make it organic (use rotation in degrees like Kotlin)
            let variation = 0.8 + 0.4 * sin(angle * 2 + rotation)
            let x = centerX + cos(angle) * radiusX * variation
            let y = centerY + sin(angle) * radiusY * variation

            // Apply rotation
            let rotatedX = centerX + (x - centerX) * cosA - (y - centerY) * sinA
            let rotatedY = centerY + (x - centerX) * sinA + (y - centerY) * cosA

            controlPoints.append(CGPoint(x: rotatedX, y: rotatedY))
        }

        // Build smooth blob path using quadratic bezier curves
        var path = Path()

        guard !controlPoints.isEmpty else { return }

        path.move(to: controlPoints[0])

        for i in 0..<controlPoints.count {
            let current = controlPoints[i]
            let next = controlPoints[(i + 1) % controlPoints.count]

            let midX = (current.x + next.x) / 2
            let midY = (current.y + next.y) / 2

            path.addQuadCurve(
                to: CGPoint(x: midX, y: midY),
                control: current
            )
        }

        path.closeSubpath()

        // Draw with radial gradient for softer look
        let maxRadius = max(radiusX, radiusY)
        let gradient = Gradient(colors: [
            color,
            color.opacity(0.5),
            Color.clear,
        ])

        context.fill(
            path,
            with: .radialGradient(
                gradient,
                center: CGPoint(x: centerX, y: centerY),
                startRadius: 0,
                endRadius: maxRadius
            )
        )
    }

    /// Draw noise texture overlay
    private func drawNoise(in context: inout GraphicsContext, size: CGSize, opacity: Double) {
        // Use a seeded random for consistency
        var rng = SeededRandomNumberGenerator(seed: 42)

        let density: CGFloat = 0.003
        let count = Int(size.width * size.height * density).clamped(to: 1000...15000)

        let noiseColor = Color.black.opacity(opacity)

        for _ in 0..<count {
            let x = CGFloat.random(in: 0...size.width, using: &rng)
            let y = CGFloat.random(in: 0...size.height, using: &rng)

            let circle = Path(ellipseIn: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1))
            context.fill(circle, with: .color(noiseColor))
        }
    }
}

// MARK: - Seeded Random Number Generator

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // Simple xorshift64 algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Background Theme

public struct BackgroundTheme: Sendable {
    public let baseGradientStart: Color
    public let baseGradientMiddle: Color
    public let baseGradientEnd: Color
    public let blobColor1: Color
    public let blobColor2: Color
    public let blobColor3: Color

    public init(
        baseGradientStart: Color,
        baseGradientMiddle: Color,
        baseGradientEnd: Color,
        blobColor1: Color,
        blobColor2: Color,
        blobColor3: Color
    ) {
        self.baseGradientStart = baseGradientStart
        self.baseGradientMiddle = baseGradientMiddle
        self.baseGradientEnd = baseGradientEnd
        self.blobColor1 = blobColor1
        self.blobColor2 = blobColor2
        self.blobColor3 = blobColor3
    }

    // Default - matches current app design
    public static let `default` = BackgroundTheme(
        baseGradientStart: Color(hex: 0xFEFCF7),
        baseGradientMiddle: Color(hex: 0xEBCFC3),
        baseGradientEnd: Color(hex: 0xD8D3CB),
        blobColor1: Color(hex: 0xEBCFC3),
        blobColor2: Color(hex: 0xD6A59A),
        blobColor3: Color(hex: 0xC18F7D)
    )

    // Sunset - warmer tones
    public static let sunset = BackgroundTheme(
        baseGradientStart: Color(hex: 0xFFF8F0),
        baseGradientMiddle: Color(hex: 0xFFD4B8),
        baseGradientEnd: Color(hex: 0xE8A87C),
        blobColor1: Color(hex: 0xFFE4CC),
        blobColor2: Color(hex: 0xFFB088),
        blobColor3: Color(hex: 0xE07850)
    )

    // Lavender - cooler purple tones
    public static let lavender = BackgroundTheme(
        baseGradientStart: Color(hex: 0xF8F6FF),
        baseGradientMiddle: Color(hex: 0xE8D8F0),
        baseGradientEnd: Color(hex: 0xD0C0E0),
        blobColor1: Color(hex: 0xE8D8F0),
        blobColor2: Color(hex: 0xD0B8E0),
        blobColor3: Color(hex: 0xB098D0)
    )

    // Ocean - blue-green tones
    public static let ocean = BackgroundTheme(
        baseGradientStart: Color(hex: 0xF0F8FF),
        baseGradientMiddle: Color(hex: 0xD0E8F0),
        baseGradientEnd: Color(hex: 0xB0D8E8),
        blobColor1: Color(hex: 0xD0E8F0),
        blobColor2: Color(hex: 0xA0D0E0),
        blobColor3: Color(hex: 0x80B8D0)
    )

    // Midnight - dark mode
    public static let midnight = BackgroundTheme(
        baseGradientStart: Color(hex: 0x1A1A2E),
        baseGradientMiddle: Color(hex: 0x16213E),
        baseGradientEnd: Color(hex: 0x0F0F1A),
        blobColor1: Color(hex: 0x2A2A4E),
        blobColor2: Color(hex: 0x3A3A5E),
        blobColor3: Color(hex: 0x4A4A6E)
    )
}

// MARK: - Comparable Clamping Extension

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview("Default Theme") {
    GradientBackground()
}

#Preview("Sunset Theme") {
    GradientBackground(theme: .sunset)
}

#Preview("Lavender Theme") {
    GradientBackground(theme: .lavender)
}

#Preview("Ocean Theme") {
    GradientBackground(theme: .ocean)
}

#Preview("Midnight Theme") {
    GradientBackground(theme: .midnight)
}

#Preview("No Noise") {
    GradientBackground(showNoise: false)
}
