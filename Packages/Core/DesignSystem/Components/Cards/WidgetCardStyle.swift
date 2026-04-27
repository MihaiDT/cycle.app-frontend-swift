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
    /// touches drive a press-style ripple. Default false because the
    /// interactive variant runs a touch-tracking shader on every
    /// visible card every frame during scroll — that was the
    /// dominant scroll cost on the stats screen. Opt in only on
    /// cards that are wrapped in a `Button`, where the bounce is
    /// part of the tap affordance.
    public let interactive: Bool

    public init(
        cornerRadius: CGFloat = 22,
        rasterize: Bool = true,
        interactive: Bool = false
    ) {
        self.cornerRadius = cornerRadius
        self.rasterize = rasterize
        self.interactive = interactive
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, macOS 26.0, *) {
            // Native Liquid Glass with interactive press feedback by
            // default — taps anywhere on the card surface get the
            // first-party bounce animation. The per-frame touch
            // shader cost was previously the suspected scroll bottle-
            // neck, but profiling pinned the real culprit elsewhere
            // (CloudKit recovery loop on mismatched encryption +
            // unstable closure identity feeding `UIHostingConfiguration`),
            // so the visual is back on by default.
            content.glassEffect(.regular.interactive(), in: shape)
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
        interactive: Bool = false
    ) -> some View {
        modifier(WidgetCardStyleModifier(
            cornerRadius: cornerRadius,
            rasterize: rasterize,
            interactive: interactive
        ))
    }
}
