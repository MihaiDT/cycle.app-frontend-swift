import SwiftUI

// MARK: - Story Illustration
//
// Two abstract silhouettes facing each other with an outstretched
// hand reaching across the gap. Drawn as a single Path so the
// stroke colour and weight are easy to tune. Rendered against a
// dark cocoa gradient inside StoryHeroCard.

public struct StoryIllustration: View {
    public let strokeColor: Color
    public let lineWidth: CGFloat

    public init(
        strokeColor: Color = Color(hex: 0xFDFCF7),
        lineWidth: CGFloat = 1.4
    ) {
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let scale = size / 80

            ZStack {
                StorySilhouetteShape(facingRight: true)
                    .stroke(strokeColor, style: stroke)
                    .frame(width: 30 * scale, height: 56 * scale)
                    .offset(x: -16 * scale, y: 2 * scale)

                StorySilhouetteShape(facingRight: false)
                    .stroke(strokeColor, style: stroke)
                    .frame(width: 30 * scale, height: 56 * scale)
                    .offset(x: 16 * scale, y: 2 * scale)

                ConnectingHandPath()
                    .stroke(strokeColor.opacity(0.85), style: stroke)
                    .frame(width: 30 * scale, height: 10 * scale)
                    .offset(y: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }
}

private struct StorySilhouetteShape: Shape {
    let facingRight: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // Head (circle approximation via arc)
        let headRadius = w * 0.28
        let headCenter = CGPoint(x: rect.midX, y: rect.minY + headRadius + 2)
        path.addEllipse(in: CGRect(
            x: headCenter.x - headRadius,
            y: headCenter.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))

        // Shoulders + torso outline
        let shoulderY = headCenter.y + headRadius + 6
        let waistY = h * 0.78
        let baseY = h
        let leftX = rect.minX + w * 0.10
        let rightX = rect.maxX - w * 0.10

        path.move(to: CGPoint(x: leftX, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: leftX + w * 0.08, y: waistY),
            control: CGPoint(x: leftX + w * 0.02, y: (shoulderY + waistY) / 2)
        )
        path.addLine(to: CGPoint(x: leftX + w * 0.18, y: baseY))

        path.move(to: CGPoint(x: rightX, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: rightX - w * 0.08, y: waistY),
            control: CGPoint(x: rightX - w * 0.02, y: (shoulderY + waistY) / 2)
        )
        path.addLine(to: CGPoint(x: rightX - w * 0.18, y: baseY))

        // Arm extending toward the centre (the "reaching" gesture)
        let armStartX = facingRight ? rightX : leftX
        let armEndX = facingRight ? rect.maxX - 2 : rect.minX + 2
        let armY = shoulderY + h * 0.18
        path.move(to: CGPoint(x: armStartX, y: shoulderY + 4))
        path.addQuadCurve(
            to: CGPoint(x: armEndX, y: armY),
            control: CGPoint(
                x: (armStartX + armEndX) / 2,
                y: shoulderY + h * 0.04
            )
        )

        return path
    }
}

private struct ConnectingHandPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}

#Preview {
    StoryIllustration()
        .frame(width: 120, height: 168)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x5C4A3B), Color(hex: 0x3A2D24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
}
