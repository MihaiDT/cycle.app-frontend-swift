import SwiftUI

// MARK: - Body Signals Card
//
// Thin shell for the "Your body this cycle" teaser on Cycle Stats.
// The view's only job is to pick which state subview to render based
// on authorization + snapshot — every piece of chrome (header, rows,
// skeleton, CTAs) lives in its own file under `BodySignals/`.
//
// Rendering paths (see `RenderingState`):
//   1. Loading     → `BodySignalsLoadingState` (shimmering skeleton
//                    that mirrors the data layout — only shown when
//                    we have nothing yet, never on subsequent
//                    fetches that update an existing snapshot)
//   2. Unavailable → `BodySignalsUnavailableState`
//   3. Needs prompt → `BodySignalsPromptState`
//   4. No data     → `BodySignalsNoDataState` (permission denied)
//   5. Data        → `BodySignalsDataState`

public struct BodySignalsCard: View {
    public let snapshot: BodySignalsSnapshot?
    public let authProbe: BodySignalsAuthProbe?
    public let isLoading: Bool
    public let onEnable: () -> Void
    /// Per-metric tap routing. `nil` opens the detail screen at
    /// the top; a specific `Kind` opens it scrolled to that
    /// section. Each tile in `BodySignalsDataState` calls this
    /// with its own kind so the three tiles route to three
    /// different anchors on the detail screen.
    public let onOpenDetail: (BodySignalMetric.Kind?) -> Void

    @State private var accessFlowMode: BodySignalsAccessFlowMode?

    public init(
        snapshot: BodySignalsSnapshot?,
        authProbe: BodySignalsAuthProbe?,
        isLoading: Bool,
        onEnable: @escaping () -> Void,
        onOpenDetail: @escaping (BodySignalMetric.Kind?) -> Void
    ) {
        self.snapshot = snapshot
        self.authProbe = authProbe
        self.isLoading = isLoading
        self.onEnable = onEnable
        self.onOpenDetail = onOpenDetail
    }

    public var body: some View {
        Group {
            switch renderingState {
            case .data(let s):
                // Data state renders the three metric tiles
                // as **independent cards**. The outer card
                // wrap is dropped so each tile carries its
                // own `widgetCardStyle` from inside
                // `BodySignalsDataState`.
                BodySignalsDataState(snapshot: s, onOpenDetail: onOpenDetail)
            default:
                // Empty / loading / prompt / unavailable
                // states stay as a single full-card surface
                // — there are no per-metric tiles to break
                // out into individual cards.
                Group {
                    switch renderingState {
                    case .loading:
                        BodySignalsLoadingState()
                    case .unavailable:
                        BodySignalsUnavailableState()
                    case .needsPrompt:
                        BodySignalsPromptState(onEnable: { accessFlowMode = .prompt })
                    case .noData:
                        BodySignalsNoDataState(
                            phase: snapshot?.phase,
                            onManage: { accessFlowMode = .denied }
                        )
                    case .data:
                        EmptyView()
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetCardStyle(cornerRadius: 28)
            }
        }
        .accessibilityElement(children: .contain)
        .sheet(item: $accessFlowMode) { mode in
            BodySignalsAccessFlow(
                mode: mode,
                onSync: onEnable,
                permission: snapshot?.permission
            )
        }
    }

    // MARK: - State machine
    //
    // Five exhaustive states. Priority matters: `.unavailable` short-
    // circuits the probe (can't prompt what HealthKit can't see),
    // and `.data` wins over `.noData` whenever we've collected any
    // usable samples. Loading is its own honest state — showing a
    // shimmering skeleton beats lying with "No Data" placeholders
    // while a real fetch is in flight.

    private enum RenderingState {
        case loading
        case unavailable
        case needsPrompt
        case noData
        case data(BodySignalsSnapshot)
    }

    private var renderingState: RenderingState {
        if authProbe == .unavailable { return .unavailable }
        if let snapshot, snapshot.permission == .granted || snapshot.permission == .partial {
            return .data(snapshot)
        }
        if let snapshot, snapshot.permission == .denied {
            return .noData
        }
        if authProbe == .needsPrompt { return .needsPrompt }
        return .loading
    }
}
