import SwiftUI

// MARK: - Crescent Icon
//
// Stylised crescent moon used as the top glyph of the Daily Insight
// card. Drawn from two arcs so the bite stays clean at any scale —
// works at 32pt without aliasing the inner curve.

public struct CrescentIcon: View {
    public let fillColor: Color

    public init(fillColor: Color = DesignColors.text) {
        self.fillColor = fillColor
    }

    public var body: some View {
        CrescentShape()
            .fill(fillColor)
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct CrescentShape: Shape {
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let outerRadius = size * 0.46
        let innerRadius = size * 0.40
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let innerCenter = CGPoint(x: center.x + size * 0.18, y: center.y - size * 0.04)

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(40),
            endAngle: .degrees(320),
            clockwise: false
        )
        path.addArc(
            center: innerCenter,
            radius: innerRadius,
            startAngle: .degrees(320),
            endAngle: .degrees(40),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 30) {
        CrescentIcon()
            .frame(width: 32, height: 32)
        CrescentIcon(fillColor: DesignColors.accentWarmText)
            .frame(width: 48, height: 48)
    }
    .padding(40)
    .background(DesignColors.background)
}
