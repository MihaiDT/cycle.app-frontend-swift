import SwiftUI

// MARK: - Body Patterns Empty Widget
//
// Editorial empty state for the Body Patterns surface. The card
// has one job: tell the user the system needs more data and
// offer the single action that produces it. Anything else is
// noise.
//
// Layout: tracked-caps eyebrow ("NO PATTERNS YET" in warm ink)
// → 22pt SemiBold title → short body line → primary warm CTA.
// No status pill, no inline history strip, no decorative water
// fill — those distract from the call-to-action and were the
// reasons the previous version read as four ideas in one card.
//
// "Logged recently" lives in `RecentLogsSection` next to this
// widget, not inside it. Splitting the two halves stops the
// card from contradicting itself ("you have no data" + "here's
// the data you logged").

struct BodyPatternsEmptyWidget: View {
    let onLogSymptomsTapped: () -> Void

    /// Number of recent symptom logs the user already has. Drives
    /// the water fill so the card visually fills slightly as the
    /// user logs more — a quiet promise that the system is
    /// gathering signal even before any pattern threshold is hit.
    var logsCount: Int = 0

    /// Maps log count to a `WaterFillBackdrop.fillRatio`. Caps at
    /// `0.18` so the empty card *never* visually approaches the
    /// 0.5+ fill of a real pattern card; it's a teaser, not a
    /// fake progress bar.
    private var fillRatio: CGFloat {
        let bounded = CGFloat(min(logsCount, 30)) / 30.0
        return bounded * 0.18
    }

    /// Once the user has logged enough symptom rows that a
    /// pattern is *plausibly* about to surface, switch the
    /// copy from "we don't have your data yet" to "we're
    /// almost there". Threshold is intentionally a soft
    /// signal, not the actual detector threshold (the
    /// detector needs 2+ cycles in the same phase, which we
    /// can't infer from raw count alone) — but past ~12 raw
    /// logs the user should feel acknowledged rather than
    /// nudged for more.
    private var isWarmedUp: Bool { logsCount >= 12 }

    private var eyebrowText: String {
        isWarmedUp ? "ALMOST THERE" : "NO PATTERNS YET"
    }

    private var titleText: String {
        isWarmedUp
            ? "We're spotting your rhythm"
            : "Log a few more cycles"
    }

    private var bodyText: String {
        isWarmedUp
            ? "A few more matching cycles will confirm a pattern."
            : "Three cycles with similar signals confirm a pattern. Two unlock an early hint."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                eyebrow

                Text(titleText)
                    .font(.raleway("SemiBold", size: 22, relativeTo: .title3))
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)

                Text(bodyText)
                    .font(.raleway("Regular", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                    .contentTransition(.opacity)
            }

            logSymptomsButton
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            WaterFillBackdrop(
                fillRatio: fillRatio,
                color: DesignColors.accent,
                glow: DesignColors.accent.opacity(0.20)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(DesignColors.accentWarm.opacity(0.16), lineWidth: 0.6)
        }
        .shadow(color: DesignColors.accentWarm.opacity(0.10), radius: 22, x: 0, y: 14)
    }

    // MARK: - Eyebrow

    /// Caps eyebrow in warm ink. Same vocabulary as the screen-
    /// level eyebrow on `AppScreenHeader` ("LAST 12 MONTHS") so
    /// the empty state inherits the editorial register instead
    /// of badging itself like an alert.
    private var eyebrow: some View {
        Text(eyebrowText)
            .font(.raleway("Bold", size: 11, relativeTo: .caption))
            .tracking(1.2)
            .foregroundStyle(DesignColors.accentWarm)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.32), value: eyebrowText)
    }

    // MARK: - Primary CTA

    /// Filled warm pill. The user is in empty state — there's
    /// exactly one thing to do, so the button reads as primary,
    /// not as a secondary ghost. Drops the dated "+" prefix in
    /// favour of clean lower-case copy.
    private var logSymptomsButton: some View {
        Button(action: onLogSymptomsTapped) {
            Text("Log symptoms")
                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignColors.accentWarm,
                                    DesignColors.accentSecondary,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: DesignColors.accentWarm.opacity(0.32),
                            radius: 10,
                            x: 0,
                            y: 4
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log symptoms for today")
    }
}
