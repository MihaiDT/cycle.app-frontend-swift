import SwiftUI

// MARK: - Widget Card Style
//
// Unified card surface used by the Home widget carousel (Rhythm, Journey,
// and future slides) + the ritual tiles. Matches the look of the cycle
// recap cards: white fill, soft dual-pass shadow, no stroked border. On
// iOS 26+ uses the new Liquid Glass effect; falls back to a plain white
// rounded rect elsewhere.

public struct WidgetCardStyleModifier: ViewModifier {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 22) {
        self.cornerRadius = cornerRadius
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

public extension View {
    /// Apply the shared recap-style card surface (white fill + soft dual
    /// shadow, or Liquid Glass on iOS 26+). Corner radius defaults to 22
    /// to match the Home widget language.
    func widgetCardStyle(cornerRadius: CGFloat = 22) -> some View {
        modifier(WidgetCardStyleModifier(cornerRadius: cornerRadius))
    }
}
