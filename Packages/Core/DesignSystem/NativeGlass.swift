import SwiftUI

// MARK: - Native Liquid Glass Helper
//
// Thin wrapper over Apple's iOS 26 `.glassEffect(_:in:)` API with
// an iOS 17–25 fallback that approximates the system look using
// `.ultraThinMaterial` plus a subtle rim highlight + drop shadow.
//
// Use this when you want native system glass — discs, chips,
// capsules in toolbars, close buttons, action buttons. Use the
// existing `liquidGlass(cornerRadius:)` / `liquidGlassCapsule()`
// modifiers when you specifically want the in-house Figma-derived
// gradient stack (peach + highlight arc) — they are not the same
// look and they should not be mixed within a single feature.
//
// Fallback rationale: `.ultraThinMaterial` is the closest iOS 17
// surface to system glass; the white rim and drop shadow give it
// enough physical separation from the canvas that buttons read
// as tappable chrome rather than flat surfaces.

extension View {
    /// Native iOS 26 glass with an iOS 17–25 fallback.
    ///
    /// - Parameters:
    ///   - shape: The shape to clip and stroke. `Circle()` for
    ///     icon discs, `Capsule()` for pill buttons,
    ///     `RoundedRectangle(cornerRadius:)` for cards.
    ///   - tint: Optional tint color layered on top of the glass.
    ///     Use sparingly — system guidance is to reserve tint for
    ///     state changes (e.g. a saved success state) rather than
    ///     decoration.
    ///   - interactive: When true, `.glassEffect(.regular.interactive())`
    ///     is applied on iOS 26 so the surface visually responds
    ///     to touch / hover. Pass `false` for static chrome.
    @ViewBuilder
    public func nativeGlass<S: InsettableShape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = true,
        dropShadow: Bool = true
    ) -> some View {
        if #available(iOS 26, macOS 26, *) {
            switch (tint, interactive) {
            case (.some(let tint), true):
                self.glassEffect(.regular.tint(tint).interactive(), in: shape)
            case (.some(let tint), false):
                self.glassEffect(.regular.tint(tint), in: shape)
            case (.none, true):
                self.glassEffect(.regular.interactive(), in: shape)
            case (.none, false):
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    if let tint {
                        shape.fill(tint)
                    }
                }
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                }
                .shadow(
                    color: dropShadow ? .black.opacity(0.05) : .clear,
                    radius: dropShadow ? 3 : 0,
                    x: 0,
                    y: dropShadow ? 1 : 0
                )
        }
    }
}
