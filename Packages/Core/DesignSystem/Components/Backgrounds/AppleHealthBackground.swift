import SwiftUI

// MARK: - Apple Health Background
//
// Single morphing peach lens anchored at the top of the screen,
// fading through its own gradient to white. The lens is one
// continuous shape — not waves, not blobs — but its width,
// height, and position breathe slowly so the visible bottom
// curve actively morphs (like the Apple Fitness Endurance/Focus
// header where you can see the warm dome change shape between
// states).

public struct AppleHealthBackground: View {

    public let accent: Color

    public init(accent: Color = Color(red: 1.00, green: 0.66, blue: 0.55)) {
        self.accent = accent
    }

    public var body: some View {
        // Static render — single canvas snapshot, single GPU blur
        // pass, no TimelineView. The ambient morph used to live
        // here but it cost a continuous Metal pass per screen and
        // showed up as push lag when screens stacked. The canvas
        // function still takes a `time` parameter so the morph can
        // be reintroduced (re-wrap in TimelineView) without
        // rewriting the geometry math.
        GeometryReader { proxy in
            AppleHealthBackground.canvas(
                size: proxy.size,
                time: 0,
                accent: accent
            )
            .drawingGroup()
            .blur(radius: 14)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    static func canvas(size: CGSize, time: TimeInterval, accent: Color) -> some View {
        // Slow ambient oscillators — periods 15-22s so the morph
        // reads as ambient breathing, never as restless motion.
        let widthPhase = sin(time * 0.40)          // ~15s
        let heightPhase = sin(time * 0.35 + 1.4)   // ~18s
        let xPhase = sin(time * 0.30 + 0.7)        // ~21s
        let yPhase = sin(time * 0.40 + 2.1)        // ~16s

        let altWidthPhase = sin(time * 0.45 + 1.9) // ~14s
        let altXPhase = sin(time * 0.28 + 0.4)     // ~22s
        let altYPhase = sin(time * 0.42 + 2.6)     // ~15s

        // Lens curve tucked into the upper portion of the
        // screen — sized so the visible bottom arc never
        // bleeds far past the header chrome into card
        // territory. Tightened from the original (0.62 / 0.48
        // height; -0.13 / -0.06 y) so the warm dome reads as a
        // header tint rather than a half-screen wash.
        let primaryW = size.width * CGFloat(1.55 + widthPhase * 0.30)
        let primaryH = size.height * CGFloat(0.45 + heightPhase * 0.12)
        let primaryX = size.width * 0.5 + size.width * CGFloat(xPhase) * 0.22
        // Lens centred just above the top edge — most of it
        // sits *inside* the screen, only a thin sliver crests
        // off the top. Earlier value (-0.20) parked the
        // centre well above the screen, which hid more than
        // half the dome.
        let primaryY = -size.height * 0.05 + size.height * CGFloat(yPhase) * 0.05

        let altW = size.width * CGFloat(1.25 + altWidthPhase * 0.25)
        let altH = size.height * CGFloat(0.32 + heightPhase * 0.10)
        let altX = size.width * 0.5 + size.width * CGFloat(altXPhase) * 0.28
        let altY = -size.height * 0.02 + size.height * CGFloat(altYPhase) * 0.06

        ZStack {
            // 1. White base.
            Color.white

            // 2. PRIMARY lens — single ellipse anchored above the
            //    top of the screen, filled with a vertical
            //    gradient inside its own bounds. Top of the
            //    ellipse is full peach, bottom of the ellipse is
            //    clear. The visible bottom-arc curve IS the warm
            //    field's edge, and it morphs as the ellipse's
            //    width/height/position oscillate.
            Ellipse()
                .fill(
                    LinearGradient(
                        stops: [
                            // Top of the lens used to fully saturate
                            // the status-bar zone (alpha 1.0 → 0.95)
                            // which competed with the editorial
                            // header for attention. Audit pass 2
                            // dropped this further (0.70 → 0.50)
                            // because the warm tint was still
                            // visibly tinting the clock + dynamic
                            // island. The bottom roll-off is
                            // unchanged so the dome's curve still
                            // reads as the canonical Apple-Health
                            // arc.
                            .init(color: accent.opacity(0.32), location: 0.00),
                            .init(color: accent.opacity(0.36), location: 0.40),
                            .init(color: accent.opacity(0.32), location: 0.65),
                            .init(color: accent.opacity(0.14), location: 0.85),
                            .init(color: .clear,               location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: primaryW, height: primaryH)
                .position(x: primaryX, y: primaryY)

            // 3. SECONDARY lens — smaller, offset, drifts on its
            //    own phase. Its overlap with the primary lens
            //    distorts the visible curve so the bottom edge
            //    isn't a clean ellipse arc but a morphing
            //    organic silhouette.
            Ellipse()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: accent.opacity(0.65), location: 0.00),
                            .init(color: accent.opacity(0.50), location: 0.40),
                            .init(color: accent.opacity(0.25), location: 0.70),
                            .init(color: .clear,               location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: altW, height: altH)
                .position(x: altX, y: altY)
        }
    }
}

#if DEBUG
#Preview("Apple Health Background") {
    AppleHealthBackground()
}
#endif
