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

    public init(snapshot: BodySignalsSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                BodySignalsHero(phase: snapshot.phase)
                WristTempSection(metric: snapshot.wristTemperature)
                HRVPhaseSection(metric: snapshot.hrv, phase: snapshot.phase)
                RestingHRSection(metric: snapshot.restingHR)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background { AppleHealthBackground() }
        .navigationTitle("Your body")
        .navigationBarTitleDisplayMode(.inline)
    }
}
