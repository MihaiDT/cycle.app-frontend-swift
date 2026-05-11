import SwiftUI

// MARK: - Body Signals Detail
//
// Full-screen detail reached from the "See full charts" footer on the
// Cycle Stats Body Signals card. This view is pushed onto the parent
// `NavigationStack` (the one driven by `historyPath` in
// `CycleInsightsView`) — *not* presented as a sheet — so the back
// chevron and nav bar inherit the rest of the stats flow's chrome
// instead of competing with a separate sheet stack.
//
// The shell only wires scroll + nav and orders the top-level pieces;
// every section (hero, wrist temp, HRV, RHR) and every chart ships
// in its own file under `BodySignals/`.

public struct BodySignalsDetailView: View {
    public let snapshot: BodySignalsSnapshot
    /// When set, the screen renders ONLY the matching metric's
    /// section + hero — the user tapped a specific tile and
    /// expects a focused view, not the full body-signals screen
    /// scrolled to the right place. Nil shows the full screen
    /// (hero + all three sections), matching the behaviour for
    /// taps on the card header / chevron.
    public let focusedMetric: BodySignalMetric.Kind?

    public init(
        snapshot: BodySignalsSnapshot,
        focusedMetric: BodySignalMetric.Kind? = nil
    ) {
        self.snapshot = snapshot
        self.focusedMetric = focusedMetric
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background { AppleHealthBackground() }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Renders only the focused section when `focusedMetric` is
    /// set; otherwise the full overview (hero + three sections).
    /// The hero is intentionally dropped on focused screens — it
    /// renders the same phase indicator regardless of which metric
    /// the user landed on, so showing it on every focused detail
    /// reads as repeated chrome rather than per-screen context.
    @ViewBuilder
    private var content: some View {
        switch focusedMetric {
        case .wristTemperature:
            WristTempSection(metric: snapshot.wristTemperature)
        case .hrv:
            HRVPhaseSection(metric: snapshot.hrv, phase: snapshot.phase)
        case .restingHR:
            RestingHRSection(metric: snapshot.restingHR)
        case .none:
            BodySignalsHero(phase: snapshot.phase)
            WristTempSection(metric: snapshot.wristTemperature)
            HRVPhaseSection(metric: snapshot.hrv, phase: snapshot.phase)
            RestingHRSection(metric: snapshot.restingHR)
        }
    }

    /// Title swaps to the focused metric's display name when one
    /// is set, so the user lands on a screen titled "Wrist
    /// temperature" / "Heart rate variability" / "Resting heart
    /// rate" instead of a generic "Your body" header that no
    /// longer matches the focused content.
    private var navigationTitle: String {
        switch focusedMetric {
        case .wristTemperature: return "Wrist temperature"
        case .hrv:              return "Heart rate variability"
        case .restingHR:        return "Resting heart rate"
        case .none:             return "Your body"
        }
    }
}
