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
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text("Symptom pattern")
                    .font(AppTypography.cardTitleSecondary)
                    .tracking(AppTypography.cardTitleSecondaryTracking)
                    .foregroundStyle(DesignColors.text)

                Spacer()

                Text("Last 7 days".uppercased())
                    .font(.raleway("Medium", size: 10, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(DesignColors.textSecondary.opacity(0.6))
            }

            // Pattern card
            VStack(alignment: .leading, spacing: AppLayout.spacingM) {
                Text("No patterns yet")
                    .font(.raleway("SemiBold", size: 15, relativeTo: .headline))
                    .foregroundStyle(DesignColors.text)

                Text("Log a few symptoms and I'll start noticing how your body shows up across your cycle.")
                    .font(.raleway("Regular", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                logSymptomsPill
                    .padding(.top, AppLayout.spacingS)
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
        }
        .padding(.horizontal, AppLayout.screenHorizontal)
    }

    private var logSymptomsPill: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            store.send(.logSymptomsTapped, animation: .appBalanced)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Log Symptoms")
                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
            }
            .foregroundStyle(DesignColors.text)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .fixedSize()
            .background {
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.9), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(2)
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), DesignColors.accentWarm.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                .shadow(color: DesignColors.accentWarm.opacity(0.12), radius: 8, x: 0, y: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log symptoms for today")
        .accessibilityHint("Opens the symptoms sheet")
    }

}
