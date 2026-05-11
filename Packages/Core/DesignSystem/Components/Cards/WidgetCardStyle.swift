import SwiftUI

// MARK: - Widget Card Style
//
// Unified card surface used by the Home widget carousel + cycle stats/
// history/details cards. Owns the full surface (fill + clip + shadow)
// so call sites don't need to stack their own `.background(material)` +
// `.clipShape(...)` — doing that on iOS 26 produced two overlapping
// glass passes per card (material fill + Liquid Glass), which profiling
// showed as the dominant scroll cost: each visible card ran *two*
// GlassEntryView/GlassEffectView updates per frame.
//
// Contract: call `.widgetCardStyle(cornerRadius:)` and stop. No extra
// `.background` or `.clipShape` needed.

public struct WidgetCardStyleModifier: ViewModifier {
    public let cornerRadius: CGFloat
    /// When true (default), rasterizes the card into a Metal bitmap so
    /// scroll translates one texture per cell. Set false on cards that
    /// embed UIKit-backed views (`Picker(.segmented)`, Swift Charts,
    /// `UIViewRepresentable`) — Metal flattening can't render those
    /// subtrees and the runtime falls back to a broken yellow placeholder.
    public let rasterize: Bool
    /// When true, the iOS 26 glass surface uses `.interactive()` so
    /// touches drive a press-style ripple. Defaults to true so taps
    /// on a card surface get the first-party bounce affordance. Opt
    /// out on cards where the ripple competes with internal motion
    /// (charts, bar selections, sliding detail blocks) — the touch
    /// shader runs every frame the finger is on the card and reads
    /// as extra noise on top of the chart's own animation.
    public let interactive: Bool

    public init(
        cornerRadius: CGFloat = 22,
        rasterize: Bool = true,
        interactive: Bool = true
    ) {
        self.cornerRadius = cornerRadius
        self.rasterize = rasterize
        self.interactive = interactive
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, macOS 26.0, *) {
            if interactive {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            Group {
                if rasterize {
                    content.drawingGroup(opaque: false)
                } else {
                    content
                }
            }
            .background(Color.white)
            .clipShape(shape)
        }
    }
}

public extension View {
    /// Apply the shared card surface (fill + shadow, consistent across
    /// every card on the stats screen). Owns fill, clip, and shadow — do
    /// not pair with `.background(.ultraThinMaterial)` or an outer
    /// `.clipShape`. Pass `rasterize: false` when the card contains
    /// UIKit-backed subviews (native Picker, Swift Charts).
    func widgetCardStyle(
        cornerRadius: CGFloat = 22,
        rasterize: Bool = true,
        interactive: Bool = true
    ) -> some View {
        modifier(WidgetCardStyleModifier(
            cornerRadius: cornerRadius,
            rasterize: rasterize,
            interactive: interactive
        ))
    }
}
