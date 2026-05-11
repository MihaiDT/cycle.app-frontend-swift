import SwiftUI

// MARK: - Glass Toolbar modifier
//
// Deliberate no-op ViewBuilder. Kept as a hook so existing call sites that wrap
// toolbar items in `.glassToolbar()` stay valid while iOS 26's Liquid Glass
// rolls out — when we add the `if #available(iOS 26, *) { .glassEffect(...) }`
// path here, every callsite picks it up automatically. Until then it just
// passes the view through unchanged.

public extension View {
    @ViewBuilder
    func glassToolbar() -> some View {
        self
    }
}
