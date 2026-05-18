import ComposableArchitecture
import Foundation

private let lastManualCycleKey = "ProfileLastManualCycleLength"

// MARK: - CycleLengthEditorFeature
//
// Recommended (auto-mean from observed cycles) vs Manual (user-pinned,
// exempt from the Live reconcile overwrite). Mirrors Clue's "Cycle
// length predictions" picker. Save writes through
// `menstrualLocal.setCycleLengthOverride` + bumps `avgCycleLength` on
// the profile so the next read reflects the choice immediately.

@Reducer
public struct CycleLengthEditorFeature: Sendable {

    public enum Mode: String, Equatable, Sendable, CaseIterable {
        case recommended
        case manual
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var mode: Mode = .recommended
        public var manualValue: Int = 28
        public var computedValue: Int = 28
        public var regularity: String = "unknown"
        public var isSaving: Bool = false
        public var loaded: Bool = false

        public init() {}

        public var displayedValue: Int {
            switch mode {
            case .recommended: computedValue
            case .manual: manualValue
            }
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case profileLoaded(MenstrualProfileInfo?, Int?, Int)
        case modeChanged(Mode)
        case manualValueChanged(Int)
        case saveTapped
        case saved
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didSave
        }
    }

    @Dependency(\.menstrualLocal) var menstrualLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding, .delegate:
                return .none

            case .onAppear:
                guard !state.loaded else { return .none }
                return .run { [menstrualLocal] send in
                    let profile = try? await menstrualLocal.getProfile()
                    let override = try? await menstrualLocal.getCycleLengthOverride()
                    let recommended = (try? await menstrualLocal.getRecommendedCycleLength()) ?? 28
                    await send(.profileLoaded(profile, override, recommended))
                }

            case let .profileLoaded(profile, override, recommended):
                state.computedValue = recommended
                state.regularity = profile?.cycleRegularity ?? "unknown"
                // The picker always shows the last value the user
                // explicitly pinned, whether or not the override is
                // currently active. Stored in UserDefaults so a
                // round-trip through Recommended doesn't erase it.
                let stored = UserDefaults.standard.integer(forKey: lastManualCycleKey)
                let lastManual = (10...90).contains(stored) ? stored : (override ?? 28)
                if let override {
                    state.mode = .manual
                    state.manualValue = override
                } else {
                    state.mode = .recommended
                    state.manualValue = lastManual
                }
                state.loaded = true
                return .none

            case let .modeChanged(mode):
                state.mode = mode
                return .none

            case let .manualValueChanged(value):
                state.manualValue = max(10, min(90, value))
                // Persist the user's last manual selection so the
                // picker resumes there next time, even if they save
                // Recommended in between.
                UserDefaults.standard.set(state.manualValue, forKey: lastManualCycleKey)
                return .none

            case .saveTapped:
                state.isSaving = true
                let override: Int? = state.mode == .manual ? state.manualValue : nil
                return .run { [menstrualLocal] send in
                    try? await menstrualLocal.setCycleLengthOverride(override)
                    // Predictions are cached against the previous
                    // avgCycleLength, so the calendar would keep
                    // showing stale period/fertile runs until the
                    // next cycle confirmation. Force a fresh regen
                    // here so the new length is reflected immediately.
                    try? await menstrualLocal.generatePrediction()
                    try? await Task.sleep(for: .milliseconds(450))
                    await send(.saved)
                }

            case .saved:
                state.isSaving = false
                return .send(.delegate(.didSave))
            }
        }
    }
}
