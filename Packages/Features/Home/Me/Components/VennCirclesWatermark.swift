import SwiftUI

// MARK: - Venn Circles Watermark
//
// Two overlapping stroked circles used as a decorative watermark in
// the top-right corner of the Bonds empty-state card. The two
// circles offset horizontally so they read as a Venn diagram — the
// metaphor for "the space between you and another".

public struct VennCirclesWatermark: View {
    public let strokeColor: Color
    public let lineWidth: CGFloat
    public let opacity: Double
    public let circleSize: CGFloat
    public let overlap: CGFloat

    public init(
        strokeColor: Color = DesignColors.accentWarm,
        lineWidth: CGFloat = 2.8,
        opacity: Double = 0.3,
        circleSize: CGFloat = 106,
        overlap: CGFloat = 50
    ) {
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.circleSize = circleSize
        self.overlap = overlap
    }

    public var body: some View {
        ZStack {
            Circle()
                .strokeBorder(strokeColor.opacity(opacity), lineWidth: lineWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: -overlap / 2)

            Circle()
                .strokeBorder(strokeColor.opacity(opacity), lineWidth: lineWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: overlap / 2)
        }
        .frame(width: circleSize + overlap, height: circleSize)
        .allowsHitTesting(false)
    }
}

#Preview {
    VennCirclesWatermark()
        .padding(40)
        .background(DesignColors.background)
}
