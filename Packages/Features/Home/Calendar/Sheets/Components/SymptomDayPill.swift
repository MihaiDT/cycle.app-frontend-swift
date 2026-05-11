import SwiftUI

/// Single day chip rendered inside `SymptomDaySelector`.
/// Tappable. Active state uses a soft warm fill + warm ink
/// instead of cocoa-solid + white text — single emphasis
/// (colour) rather than double emphasis (colour + weight),
/// so the selected day reads as a focused option rather than
/// an alert badge.
struct SymptomDayPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                // Same medium weight in both states. Selection
                // is signalled through fill + ink colour, not
                // by bumping the weight to bold (which combined
                // with cocoa-solid felt like a forced anchor).
                .font(.raleway("Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(
                    isSelected
                        ? DesignColors.accentWarmText
                        : DesignColors.text
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(
                            isSelected
                                ? DesignColors.accentWarm.opacity(0.24)
                                : Color.white
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected
                                        ? DesignColors.accentWarm.opacity(0.60)
                                        : DesignColors.text.opacity(0.10),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isSelected
                                ? DesignColors.accentWarm.opacity(0.16)
                                : .clear,
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                }
        }
        .buttonStyle(.plain)
    }
}
