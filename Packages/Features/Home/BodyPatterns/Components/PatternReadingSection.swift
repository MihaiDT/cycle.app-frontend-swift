import SwiftUI

// MARK: - Pattern Reading Section
//
// Section on `PatternDetailScreen`, sitting after the `Highlights`
// 2×2 stat tile grid and before the `NOT A MEDICAL DEVICE` footer.
//
// Job: turn the per-pattern stats above (Hits hardest, Intensity,
// Appears with, Next likely) into a synthesised editorial reading
// of THIS specific pattern. The Highlights tiles answer "what?";
// the Reading section answers "what does it mean across cycles?".
//
// Surface treatment matches the rest of the detail screen:
//   • `widgetCardStyle(cornerRadius: 28)` – same surface as
//     individual Highlights tiles, just full-width.
//   • Section header "Reading" rendered above (matches the
//     "Highlights" pattern label) – Raleway SemiBold 22, no eyebrow.
//   • One Text node, sentence-line-broken – same cadence as the
//     phase editorial under the title at the top of the screen
//     ("Inward days. Energy at its lowest, body asking for rest.").
//     The phase editorial sets emotional tone; the Reading adds
//     personal data narrative.
//
// Composition (host adds the section header outside the card):
//
//   VStack(alignment: .leading, spacing: 14) {
//       Text("Reading")
//           .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
//       PatternReadingSection(reading: store.reading)
//   }
//
// Wiring (future): `PatternDetailFeature.State.reading: PatternReading?`
// computed from `MenstrualLocalClient.patternMetrics()` over the
// 12-month window. Renders only when there are ≥ 2 cycles' worth
// of data – sparse logs fall back to "Reading is still gathering."

struct PatternReadingSection: View {
    let reading: PatternReading

    var body: some View {
        Text(formatted(reading.copy))
            .font(.raleway("SemiBold", size: 18, relativeTo: .body))
            .tracking(-0.15)
            .foregroundStyle(DesignColors.text)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetCardStyle(cornerRadius: 28)
    }

    private func formatted(_ copy: String) -> String {
        copy
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "? ", with: "?\n")
            .replacingOccurrences(of: "! ", with: "!\n")
    }
}

// MARK: - Mock fixtures (per-pattern readings)

extension PatternReading {
    /// Bloating in menstrual – names the count, the day, the
    /// co-occurrence, the severity arc. Reads the Highlights tiles
    /// aloud as a paragraph.
    static let mockReadingBloatingMenstrual = PatternReading(
        copy: "You log this in 4 of 7 cycles, almost always day 1. Cramps come along 3 of those times. Severity sits at moderate – never above a 4.",
        phase: .menstrual
    )

    /// Cramps in menstrual – adds a temporal arc ("severity has
    /// eased lately"), the kind of read the stats grid can't show.
    static let mockReadingCrampsMenstrual = PatternReading(
        copy: "Day 1, day 2, sometimes day 3. Five cycles in a row. Severity has eased recently – fives in autumn, threes in spring.",
        phase: .menstrual
    )

    /// Bloating in luteal – focuses on the rhythm, no co-occurring
    /// pattern.
    static let mockReadingBloatingLuteal = PatternReading(
        copy: "Bloating shows up in your luteal again – fifth cycle in a row. Same days, same severity. The body has a rhythm here, even if it's an uncomfortable one.",
        phase: .luteal
    )

    /// Sparse fallback – when the pattern has just appeared and
    /// there's not enough to read yet.
    static let mockReadingGathering = PatternReading(
        copy: "Reading is still gathering. One more cycle of logs and we'll have something to say.",
        phase: nil
    )
}

// MARK: - Previews

#Preview("Bloating menstrual – primary") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        VStack(alignment: .leading, spacing: 14) {
            Text("Reading")
                .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                .foregroundStyle(DesignColors.text)
            PatternReadingSection(reading: .mockReadingBloatingMenstrual)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Cramps menstrual – temporal arc") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        VStack(alignment: .leading, spacing: 14) {
            Text("Reading")
                .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                .foregroundStyle(DesignColors.text)
            PatternReadingSection(reading: .mockReadingCrampsMenstrual)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Bloating luteal – rhythm") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        VStack(alignment: .leading, spacing: 14) {
            Text("Reading")
                .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                .foregroundStyle(DesignColors.text)
            PatternReadingSection(reading: .mockReadingBloatingLuteal)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("Gathering – sparse") {
    ZStack {
        AppleHealthBackground().ignoresSafeArea()
        VStack(alignment: .leading, spacing: 14) {
            Text("Reading")
                .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                .foregroundStyle(DesignColors.text)
            PatternReadingSection(reading: .mockReadingGathering)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
    }
}

#Preview("In screen context – Pattern Detail bottom") {
    ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            // Mock header (eyebrow + title + lede) – minimal so the
            // focus stays on the new Reading section.
            VStack(alignment: .leading, spacing: 8) {
                Text("MENSTRUAL PHASE")
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary)
                Text("Bloating")
                    .font(.raleway("SemiBold", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(DesignColors.text)
                Text("Inward days. Energy at its lowest, body asking for rest.")
                    .font(.raleway("Medium", size: 16, relativeTo: .body))
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.top, 2)
            }

            // Mock heatmap placeholder
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignColors.text.opacity(0.04))
                .frame(height: 130)

            // Mock highlights placeholder
            VStack(alignment: .leading, spacing: 12) {
                Text("Highlights")
                    .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 22)
                            .fill(DesignColors.text.opacity(0.05))
                            .frame(height: 110)
                    }
                }
            }

            // The new Reading section
            VStack(alignment: .leading, spacing: 14) {
                Text("Reading")
                    .font(.raleway("SemiBold", size: 22, relativeTo: .title2))
                    .foregroundStyle(DesignColors.text)
                PatternReadingSection(reading: .mockReadingBloatingMenstrual)
            }
            .padding(.top, 4)

            // Mock disclaimer
            HStack(spacing: 6) {
                Text("NOT A MEDICAL DEVICE")
                    .font(.raleway("SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(1.2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(DesignColors.textSecondary.opacity(0.8))
            .padding(.top, 8)
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
        .padding(.top, 60)
        .padding(.bottom, 60)
    }
    .background(AppleHealthBackground().ignoresSafeArea())
}
