import SwiftUI

// MARK: - Symptom Chip

struct SymptomChip: View {
    let symptom: SymptomType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let customIcon = symptom.customIcon {
                    Image(customIcon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: symptom.sfSymbol)
                        .font(.system(size: 20))
                        .accessibilityHidden(true)
                }
                Text(symptom.displayName)
                    .font(.raleway("Medium", size: 14, relativeTo: .body))
            }
            .foregroundColor(isSelected ? DesignColors.text : DesignColors.text.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .strokeBorder(
                        isSelected ? DesignColors.accentWarm : DesignColors.accentSecondary.opacity(0.4),
                        lineWidth: isSelected ? 1.5 : 1
                    )
                    .background(
                        Capsule()
                            .fill(isSelected ? DesignColors.accentWarm.opacity(0.15) : Color.white.opacity(0.5))
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symptom.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
