import SwiftUI

public extension Font {
    /// Raleway font with Dynamic Type scaling.
    /// - Parameters:
    ///   - weight: Raleway weight name (e.g. "Bold", "SemiBold", "Medium", "Regular", "Black")
    ///   - size: base point size at default text size
    ///   - relativeTo: text style for Dynamic Type scaling (default `.body`)
    static func raleway(_ weight: String, size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        .custom("Raleway-\(weight)", size: size, relativeTo: style)
    }
}
