import SwiftUI

// MARK: - Body Patterns Reading Card
//
// Closing card on the BodyPatterns root feed. Job: deliver one
// editorial paragraph that synthesises ACROSS the user's patterns
// – the cluster narrative the carousels can't show ("your luteal
// patterns cluster", "menstrual is your loudest phase right now").
//
// Surface treatment (cream `widgetCardStyle` cu accente subtile):
//   • Cream `widgetCardStyle(cornerRadius: 28)` – same surface as
//     LoggingActionCard, no warm-gradient borrowing from
//     `CycleRhythmReflectionCard` (that's the Cycle Stats finale).
//   • **Phase-tinted bloom** in the top-trailing corner – 140pt
//     circle, blur 50, opacity 0.15. Adds breath of phase colour
//     so the card doesn't read as a generic data tile.
//   • **Quote glyph** (Raleway Black `"` at 80pt, phase tint at
//     opacity 0.12) in the top-leading corner – editorial signal,
//     telegraphs "this is a reading, a piece of writing about your
//     body" rather than "another stat surface".
//   • One Text node, sentence-line-broken – same editorial cadence
//     as the existing pattern cards' lede.
//
// No CTA, no tap, no link out. The card is the message.

struct BodyPatternsReadingCard: View {
    let reading: PatternReading

    var body: some View {
        Text(formatted(reading.copy))
            .font(.raleway("SemiBold", size: 19, relativeTo: .body))
            .tracking(-0.2)
            .foregroundStyle(DesignColors.text)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .topTrailing) {
                phaseBloom.allowsHitTesting(false)
            }
            .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Decorations

    /// Soft phase-coloured bloom in the top-trailing corner. Stays
    /// well below "warm gradient" intensity (opacity 0.15 vs the
    /// 0.40+ on `CycleRhythmReflectionCard`) so the card still
    /// reads as cream glass with a phase whisper, not as a phase-
    /// tinted card.
    private var phaseBloom: some View {
        Circle()
            .fill(phaseAccent)
            .frame(width: 140, height: 140)
            .blur(radius: 50)
            .opacity(0.15)
            .offset(x: 50, y: -40)
            .accessibilityHidden(true)
    }

    // MARK: - Phase tint

    private var phaseAccent: Color {
        switch reading.phase {
        case .menstrual:        return Color(red: 0.82, green: 0.36, blue: 0.42)
        case .follicular:       return Color(red: 0.91, green: 0.62, blue: 0.46)
        case .ovulatory:        return Color(red: 0.93, green: 0.71, blue: 0.36)
        case .luteal, .late:    return Color(red: 0.86, green: 0.50, blue: 0.45)
        case .none:             return DesignColors.textSecondary
        }
    }

    /// One sentence per line – same cadence as
    /// `CycleRhythmReflectionCard.formattedCopy` and the editorial
    /// lede on pattern cards.
    private func formatted(_ copy: String) -> String {
        copy
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "? ", with: "?\n")
            .replacingOccurrences(of: "! ", with: "!\n")
    }
}

// MARK: - Mock fixtures (root overview readings)

extension PatternReading {
    static let mockOverviewLutealCluster = PatternReading(
        copy: "Your luteal patterns are clustering. Bloating, breast tenderness, and low mood tend to ride together this cycle. Three months running.",
        phase: .luteal
    )

    static let mockOverviewMenstrualLoud = PatternReading(
        copy: "Menstrual is your loudest phase right now. Cramps, fatigue, and bloating all confirmed. Follicular and ovulatory have been quiet.",
        phase: .menstrual
    )

    static let mockOverviewSteady = PatternReading(
        copy: "Three patterns held steady this cycle. Same shape as last month, same days. Bodies repeat themselves; yours is keeping its shape.",
        phase: .luteal
    )

    static let mockOverviewEmerging = PatternReading(
        copy: "Bloating just started showing up – second cycle in a row. Not enough to call it a pattern yet, but worth watching.",
        phase: .luteal
    )

    static let mockOverviewFollicular = PatternReading(
        copy: "Your follicular is showing one steady rhythm: headaches. Four cycles tracked.",
        phase: .follicular
    )

    static let mockOverviewOvulatory = PatternReading(
        copy: "Your ovulatory is doing most of the talking this cycle. Spotting and breast tenderness all logged.",
        phase: .ovulatory
    )
}

// MARK: - Previews

#Preview("Luteal cluster – primary case") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        BodyPatternsReadingCard(reading: .mockOverviewLutealCluster)
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Menstrual loud") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        BodyPatternsReadingCard(reading: .mockOverviewMenstrualLoud)
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Follicular single – soft tint") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        BodyPatternsReadingCard(reading: .mockOverviewFollicular)
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Ovulatory – gold tint") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        BodyPatternsReadingCard(reading: .mockOverviewOvulatory)
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Steady – patterns holding") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        BodyPatternsReadingCard(reading: .mockOverviewSteady)
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Emerging – single signal") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        BodyPatternsReadingCard(reading: .mockOverviewEmerging)
            .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("In screen context – top of feed") {
    ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            // Reading section at the top (where it lives now)
            VStack(alignment: .leading, spacing: 12) {
                Text("Reading")
                    .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)
                BodyPatternsReadingCard(reading: .mockOverviewLutealCluster)
            }
            .padding(.top, 4)

            // Mock LoggingActionCard slot below
            VStack(alignment: .leading, spacing: 14) {
                Text("TODAY · THURSDAY")
                    .font(AppTypography.cardEyebrow)
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)
                Text("How are you feeling?")
                    .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetCardStyle(cornerRadius: 28)

            // Mock active section header below
            Text("Your steady rhythms")
                .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                .foregroundStyle(DesignColors.text)
                .padding(.top, 4)
            RoundedRectangle(cornerRadius: 28)
                .fill(DesignColors.text.opacity(0.06))
                .frame(height: 230)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.top, 60)
        .padding(.bottom, 60)
    }
    .background(AppleHealthBackground().ignoresSafeArea())
}
