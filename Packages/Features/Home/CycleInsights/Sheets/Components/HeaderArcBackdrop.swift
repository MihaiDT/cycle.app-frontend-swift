import SwiftUI

// MARK: - Header Arc Backdrop
//
// Flat top + sides, gentle convex bottom arc that tucks under the
// content below. Apple uses the same shape on Health, Fitness, News
// feature headers — reads as a confident "cupped" plate instead of a
// hard rectangle, and gives the illustration its own surface without
// needing a colored card.

struct HeaderArcShape: Shape {
    /// How far below the nominal rect the arc's belly hangs. 32–40pt
    /// reads as a confident curve without feeling gimmicky.
    var arcDepth: CGFloat = 36

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Flat top, straight sides flush to the bottom corners, and
        // the belly hangs BELOW the corners via a quad curve. Anchors
        // at the corners (not above them) so content placed immediately
        // after the plate has no side-gap leaking through.
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height),
            control: CGPoint(x: rect.width / 2, y: rect.height + arcDepth * 2)
        )
        path.closeSubpath()
        return path
    }
}

/// Convenience wrapper that applies the shape as a backdrop in the
/// app's off-white surface, with a soft lift shadow so the edge reads
/// over the animated JourneyAnimatedBackground underneath.
struct HeaderArcBackdrop: View {
    var arcDepth: CGFloat = 40
    var fill: Color = DesignColors.background

    var body: some View {
        HeaderArcShape(arcDepth: arcDepth)
            .fill(fill)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
            .accessibilityHidden(true)
    }
}
