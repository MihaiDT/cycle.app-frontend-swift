import SwiftUI

/// Selected-symptom chip rendered in the summary strip with a
/// trailing remove button. Tapping the X dispatches `onRemove`
/// so the parent can untoggle the symptom in TCA state.
///
/// Visual register matches the active day pill + active
/// category tab — soft warm fill, warm border, warm ink. The
/// previous saturated terracotta + white text read as an alert
/// badge and made the strip dominate the row instead of
/// reading as a peer of the two other pill systems on this
/// screen.
struct SymptomSummaryPill: View {
    let symptom: SymptomType
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            symptomIcon(for: symptom, size: 14)
                .foregroundStyle(DesignColors.accentWarm)
            Text(symptom.displayName)
                .font(.raleway("SemiBold", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.accentWarmText)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignColors.accentWarmText.opacity(0.85))
                    .padding(3)
                    .background {
                        Circle().fill(DesignColors.accentWarm.opacity(0.18))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(DesignColors.accentWarm.opacity(0.24))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            DesignColors.accentWarm.opacity(0.55),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: DesignColors.accentWarm.opacity(0.16),
                    radius: 6,
                    x: 0,
                    y: 2
                )
        }
    }
}
