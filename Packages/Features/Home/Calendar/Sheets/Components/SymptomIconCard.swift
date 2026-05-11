import SwiftUI

/// Tappable symptom tile rendered inside the grid. Surface is a
/// plain translucent white material with a tint that scales with
/// severity (1 / 3 / 5).
///
/// Interactions:
///   * **Tap** — toggle on (severity defaults to 3 / Moderate)
///     or off if already selected.
///   * **Long-press** — opens the severity menu so the user can
///     dial Mild / Moderate / Severe. Discoverable via the
///     standard iOS long-press haptic.
///
/// Visual cue for severity: the tint opacity scales with the
/// stored level so a Severe symptom reads visibly stronger than
/// a Mild one even at a glance — no extra dots or glyphs needed.
struct SymptomIconCard: View {
    let symptom: SymptomType
    /// 0 when not selected; 1 / 3 / 5 once selected.
    let severity: Int
    let tintColor: Color
    let onTap: () -> Void
    let onLongPress: () -> Void

    private var isSelected: Bool { severity > 0 }

    /// Maps the severity level to a tint opacity. The values are
    /// chosen so Mild reads as a soft hint, Moderate matches the
    /// previous flat selection state, and Severe lands clearly
    /// stronger without going saturated.
    private var tintOpacity: Double {
        switch severity {
        case 1: return 0.12
        case 3: return 0.22
        case 5: return 0.34
        default: return 0.0
        }
    }

    private var corner: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: AppLayout.cornerRadiusL,
            style: .continuous
        )
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                symptomIcon(for: symptom, size: 30)
                    .foregroundStyle(isSelected ? tintColor : DesignColors.accentWarm)

                label
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 8)
            .background(surface)
            .scaleEffect(isSelected ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: severity)
        .onLongPressGesture(minimumDuration: 0.4) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPress()
        }
    }

    @ViewBuilder
    private var surface: some View {
        // Always render a visible container — the previous
        // pure-white-on-white treatment made cards read as
        // floating glyphs rather than tappable tiles. The
        // unselected state is a soft warm wash with a warm
        // border + subtle drop shadow. Selection escalates
        // through fill + border opacity so the change is
        // felt rather than read.
        //
        // Fill values were bumped after the audit pass:
        //   * 0.05 → 0.09 unselected — the card surface now
        //     reads on a white sheet without competing with
        //     the icon weight.
        //   * 0.16 → 0.22 border — same reason.
        corner
            .fill(
                isSelected
                    ? tintColor.opacity(tintOpacity)
                    : DesignColors.accentWarm.opacity(0.09)
            )
            .overlay {
                corner
                    .strokeBorder(
                        isSelected
                            ? tintColor.opacity(0.55)
                            : DesignColors.accentWarm.opacity(0.22),
                        lineWidth: isSelected ? 1.2 : 0.7
                    )
            }
            .shadow(
                color: DesignColors.accentWarm.opacity(isSelected ? 0.20 : 0.10),
                radius: isSelected ? 10 : 6,
                x: 0,
                y: isSelected ? 5 : 3
            )
    }

    private var label: some View {
        Text(symptom.displayName)
            .font(.raleway("SemiBold", size: 13, relativeTo: .subheadline))
            .foregroundStyle(isSelected ? DesignColors.text : DesignColors.textSecondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .frame(height: 32)
    }
}
