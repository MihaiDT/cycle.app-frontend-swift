import SwiftUI

/// Renders the right glyph for a symptom — custom asset when one
/// exists in `Assets.xcassets/Symptoms/`, SF Symbol fallback
/// otherwise. Single source of truth used by every component
/// that paints a symptom (icon card, summary pill, etc.).
@ViewBuilder
func symptomIcon(for symptom: SymptomType, size: CGFloat) -> some View {
    if let customIcon = symptom.customIcon {
        Image(customIcon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    } else {
        Image(systemName: symptom.sfSymbol)
            .font(.system(size: size * 0.85, weight: .medium))
    }
}
