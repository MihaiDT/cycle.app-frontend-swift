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
        CycleRhythmReflectionCard(
            copy: store.rhythmReflectionCopy,
            phase: currentCyclePhase,
            onShare: { isShareReflectionVisible = true }
        )
    }

    /// Resolve the user's current cycle phase from the cached cycle
    /// context. `CycleContext.currentPhase` is already strongly
    /// typed; we just unwrap. Falls back to nil when the user has no
    /// logged cycles yet — the card uses a neutral peach palette in
    /// that case.
    private var currentCyclePhase: CyclePhase? {
        store.cycleContext?.currentPhase
    }

    // MARK: - Customize layout plumbing
    //
    // The stats screen renders its cards by iterating over the user's
    // `CycleStatsLayout`. `statsCardView(for:)` is the single switch
    // that maps each enum case to its concrete component, so adding
    // or removing a card is a single-case edit here plus a matching
    // entry in `CycleStatsCard`.

}
