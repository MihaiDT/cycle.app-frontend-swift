import SwiftUI

// MARK: - Hero
//
// Editorial top of the Body Signals detail sheet. Reads the user's
// current phase and picks a contextual line that tells the story of
// what's happening in the body right now — softer entry than leading
// with numbers.

struct BodySignalsHero: View {
    let phase: CyclePhase?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let phase {
                phaseEyebrow(phase)
            }

            Text(contextualLine)
                .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                .foregroundStyle(DesignColors.text)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .tracking(-0.3)

            Text("All readings come from Apple Health and stay on your device.")
                .font(.raleway("Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textSecondary.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    // MARK: - Phase eyebrow

    private func phaseEyebrow(_ phase: CyclePhase) -> some View {
        HStack(spacing: 6) {
            // Same glossy ink as the YOUR BODY badge and the per-day
            // dots on the Cycle History bar — keeps the menstrual /
            // fertile / ovulatory vocabulary consistent everywhere
            // the phase shows up.
            PhaseGlossyDot(tint: phase.orbitColor, size: 8)
            Text(phase.displayName.uppercased())
                .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.6)
                .foregroundStyle(DesignColors.text)
        }
    }

    // MARK: - Copy

    /// One-line narrative that changes with the current phase. Short
    /// enough to fit in two display-weight lines; editorial instead
    /// of clinical.
    private var contextualLine: String {
        switch phase {
        case .menstrual:
            return "Your body is resetting. Temp drops, HRV tends to rise as hormones settle."
        case .follicular:
            return "Energy rises with estrogen. Lower wrist temp, higher HRV – a recovery window."
        case .ovulatory:
            return "The shift is close. Watch wrist temperature for a small rise right before."
        case .luteal:
            return "Progesterone is climbing. Expect HRV to dip and wrist temperature to sit higher."
        case .late, .none:
            return "Your body's signals across this cycle, pulled from Apple Health."
        }
    }
}
