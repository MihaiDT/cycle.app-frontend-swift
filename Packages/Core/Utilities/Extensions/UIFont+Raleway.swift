#if canImport(UIKit)
import UIKit

public extension UIFont {
    /// Raleway UIFont with Dynamic Type scaling via UIFontMetrics.
    /// - Parameters:
    ///   - weight: Raleway weight name (e.g. "Bold", "SemiBold", "Medium", "Regular")
    ///   - size: base point size at default text size
    ///   - textStyle: text style for Dynamic Type scaling (default `.body`)
    static func raleway(_ weight: String, size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
        let base = UIFont(name: "Raleway-\(weight)", size: size) ?? .systemFont(ofSize: size)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }
}
#endif
