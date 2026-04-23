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

    public init(cornerRadius: CGFloat = 22, rasterize: Bool = true) {
        self.cornerRadius = cornerRadius
        self.rasterize = rasterize
    }

    public func body(content: Content) -> some View {
        Group {
            if rasterize {
                content.drawingGroup(opaque: false)
            } else {
                content
            }
        }
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)
        }
    }
}

public extension View {
    /// Apply the shared card surface (fill + shadow, consistent across
    /// every card on the stats screen). Owns fill, clip, and shadow — do
    /// not pair with `.background(.ultraThinMaterial)` or an outer
    /// `.clipShape`. Pass `rasterize: false` when the card contains
    /// UIKit-backed subviews (native Picker, Swift Charts).
    func widgetCardStyle(cornerRadius: CGFloat = 22, rasterize: Bool = true) -> some View {
        modifier(WidgetCardStyleModifier(cornerRadius: cornerRadius, rasterize: rasterize))
    }
}
