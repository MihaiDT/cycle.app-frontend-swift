import ComposableArchitecture
import SwiftData
import SwiftUI

// MARK: - Today › Symptoms Section (extracted from TodayFeatureView)

extension TodayView {
    // MARK: - Log Symptoms Pill
    //
    // Temporary home for the "Log Symptoms" quick action — used to live
    // on the calendar's floating bottom bar. Tapping opens the calendar
    // overlay and immediately surfaces today's symptom sheet.

    // MARK: - Symptom Pattern Section
    //
    // Editorial "what your body's been saying" block under the widget
    // carousel. Pairs a short AI-flavoured pattern hint with the Log
    // Symptoms CTA — gives symptom tracking its own home on Today
    // rather than a floating pill above everything.

    @ViewBuilder
    var symptomPatternSection: some View {
        VStack(alignment: .leading, spacing: AppLayout.spacingM) {
            // Section header — labels the card as today's logging
            // entry, distinct from the Body Patterns tile in the
            // Journey carousel above (which routes to the patterns
            // destination screen).
            HStack(alignment: .firstTextBaseline) {
                Text("Today's symptoms")
                    .font(AppTypography.cardTitleSecondary)
                    .tracking(AppTypography.cardTitleSecondaryTracking)
                    .foregroundStyle(DesignColors.text)

                Spacer()
            }

            // Logging card — full surface tappable, opens the
            // calendar symptom sheet for today. Same destination as
            // the legacy "Log Symptoms" pill so the entry point is a
            // single recognisable target.
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.send(.logSymptomsTapped, animation: .appBalanced)
            } label: {
                HStack(alignment: .center, spacing: AppLayout.spacingM) {
                    // Plus glyph in a soft pill — communicates "add"
                    // without competing with the chevron drill-in
                    // language used elsewhere on Today.
                    ZStack {
                        Circle()
                            .fill(DesignColors.accentWarm.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignColors.accentWarmText)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log how you're feeling")
                            .font(.raleway("SemiBold", size: 15, relativeTo: .headline))
                            .foregroundStyle(DesignColors.text)

                        Text("Cramps, mood, sleep — anything that shows up today.")
                            .font(.raleway("Regular", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(DesignColors.textSecondary)
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignColors.text.opacity(0.45))
                }
                .padding(AppLayout.spacingL)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                        .strokeBorder(DesignColors.accentWarm.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .contentShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log today's symptoms")
            .accessibilityHint("Opens the symptom logging sheet")
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
    }

}
