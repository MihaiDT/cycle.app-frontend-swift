import SwiftUI

// MARK: - Asymmetric Bottom Curve Shape
//
// Full-bleed rectangle with an organic, asymmetric curve at the bottom
// edge. Two bezier control points let the belly lean one way so it
// reads as a hand-drawn ribbon end rather than a perfect arc — the
// silhouette used on editorial hero images to hand off softly into
// the content below.

public struct AsymmetricBottomCurveShape: Shape {
    /// How far below the flat bottom edge the LEFT anchor drops.
    public var leftDepth: CGFloat
    /// How far below the flat bottom edge the RIGHT anchor drops.
    public var rightDepth: CGFloat
    /// How much the curve's belly bulges below both anchors.
    public var bellyDepth: CGFloat
    /// X position (0…1) of the belly's deepest point. 0.5 centers it;
    /// moving it left or right tilts the curve asymmetrically.
    public var bellyBias: CGFloat

    public init(
        leftDepth: CGFloat = 28,
        rightDepth: CGFloat = 12,
        bellyDepth: CGFloat = 28,
        bellyBias: CGFloat = 0.35
    ) {
        self.leftDepth = leftDepth
        self.rightDepth = rightDepth
        self.bellyDepth = bellyDepth
        self.bellyBias = bellyBias
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - rightDepth))
        // Cubic bezier gives us two handles — the second one biased
        // toward `bellyBias` lets the curve dip lower on one side.
        let bellyX = rect.width * max(0, min(1, bellyBias))
        path.addCurve(
            to: CGPoint(x: 0, y: rect.height - leftDepth),
            control1: CGPoint(x: rect.width * 0.75, y: rect.height + bellyDepth * 0.55),
            control2: CGPoint(x: bellyX, y: rect.height + bellyDepth)
        )
        path.closeSubpath()
        return path
    }
}
