import SwiftUI

/// Whisper-quiet hint shown above the bottom bar **before** the
/// user has selected anything. Replaces the empty void that
/// used to sit where `SymptomSelectedStrip` lives once a
/// symptom is toggled — gives the user a soft cue that
/// tapping a card will populate that strip, instead of
/// leaving the first selection feel like a surprise.
///
/// Visual register: caps eyebrow at 11pt, soft secondary ink,
/// centred. Quiet on purpose — once content lands, this
/// disappears with a fade and the strip slides in from the
/// bottom in its place.
struct SymptomSelectionPlaceholder: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.55))

            Text("TAP A SYMPTOM TO START LOGGING")
                .font(.raleway("Bold", size: 10, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(DesignColors.textSecondary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        // Soft warm capsule so the hint reads as its own
        // surface instead of overlaying the last grid row.
        // Without this, the symptom cards behind it bled
        // through the placeholder copy.
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(Color.white.opacity(0.55))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            DesignColors.accentWarm.opacity(0.16),
                            lineWidth: 0.5
                        )
                }
        }
        .shadow(color: DesignColors.accentWarm.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}
