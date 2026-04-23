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

    public init(cornerRadius: CGFloat = 22) {
        self.cornerRadius = cornerRadius
    }

    // Diagnostic mode: plain white card, no glass or material. Used to
    // isolate whether the Liquid Glass/material passes were the real
    // scroll cost or a red herring. Flip the `#if` block below back to
    // the glass/material path once the diagnosis is complete.
    public func body(content: Content) -> some View {
        // Rasterize the card's inner content into a Metal bitmap so
        // scroll only translates one texture per cell (the main reason
        // `.drawingGroup(opaque: false)` was applied per-card before).
        // The shadow is then added on the Shape of the *outer*
        // background, so it stays a layer-level shadow with the
        // correct rounded silhouette instead of being baked into the
        // bitmap and clipped to the view's rectangular bounds.
        content
            .drawingGroup(opaque: false)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)
            }
    }
}

public extension View {
    /// Apply the shared card surface (Liquid Glass on iOS 26+, frosted
    /// material + soft shadow below). Owns fill, clip, and shadow — do
    /// not pair with `.background(.ultraThinMaterial)` or an outer
    /// `.clipShape`.
    func widgetCardStyle(cornerRadius: CGFloat = 22) -> some View {
        modifier(WidgetCardStyleModifier(cornerRadius: cornerRadius))
    }
}
