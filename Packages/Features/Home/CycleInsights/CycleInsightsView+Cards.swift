import ComposableArchitecture
import SwiftUI

// MARK: - CycleInsightsView › Rhythm Reflection
//
// Editorial closing card — extracted so the main CycleInsightsView.swift
// stays focused on navigation + dispatcher. The trend/chart card lives
// in `Cards/CycleTrendCard.swift` as a standalone component.

extension CycleInsightsView {
    // MARK: - Rhythm reflection
    //
    // Closing editorial paragraph on Cycle Stats. Phrased in cycle.app
    // voice (present tense, no diagnostic tone, no em dashes). Copy
    // adapts to the actual history — a settling rhythm gets the "your
    // body is finding its rhythm" line with real deltas; a steady
    // rhythm gets a quieter affirmation; an early or restless rhythm
    // gets a patient invitation to keep logging.

    @ViewBuilder
    var rhythmReflection: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(store.rhythmReflectionCopy)
                .font(.system(size: 26, weight: .regular, design: .serif))
                .italic()
                .tracking(-0.3)
                .foregroundStyle(DesignColors.accentWarmText)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 26)
                .padding(.vertical, 56)

            Button {
                isShareReflectionVisible = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignColors.accentWarmText)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
            .accessibilityLabel("Share reflection")
        }
        .frame(maxWidth: .infinity)
        .widgetCardStyle(cornerRadius: 28)
    }

    // MARK: - Customize layout plumbing
    //
    // The stats screen renders its cards by iterating over the user's
    // `CycleStatsLayout`. `statsCardView(for:)` is the single switch
    // that maps each enum case to its concrete component, so adding
    // or removing a card is a single-case edit here plus a matching
    // entry in `CycleStatsCard`.

}
