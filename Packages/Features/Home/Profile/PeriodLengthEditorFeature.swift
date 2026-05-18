import ComposableArchitecture
import Foundation

private let lastManualPeriodKey = "ProfileLastManualPeriodLength"

// MARK: - PeriodLengthEditorFeature
//
// Twin of `CycleLengthEditorFeature` for the period (bleeding) length.
// Recommended = auto-mean from confirmed periods; Manual = pinned
// value the Live reconcile loop won't overwrite.

@Reducer
public struct PeriodLengthEditorFeature: Sendable {

    public enum Mode: String, Equatable, Sendable, CaseIterable {
        case recommended
        case manual
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var mode: Mode = .recommended
        public var manualValue: Int = 5
        public var computedValue: Int = 5
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
        case loaded(currentAverage: Int?, override: Int?)
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
                    let override = try? await menstrualLocal.getPeriodLengthOverride()
                    let recommended = (try? await menstrualLocal.getRecommendedPeriodLength()) ?? 5
                    await send(.loaded(currentAverage: recommended, override: override))
                }

            case let .loaded(currentAverage, override):
                let recommended = currentAverage ?? 5
                state.computedValue = recommended
                let stored = UserDefaults.standard.integer(forKey: lastManualPeriodKey)
                let lastManual = (1...10).contains(stored) ? stored : (override ?? 5)
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
                state.manualValue = max(1, min(10, value))
                UserDefaults.standard.set(state.manualValue, forKey: lastManualPeriodKey)
                return .none

            case .saveTapped:
                state.isSaving = true
                let override: Int? = state.mode == .manual ? state.manualValue : nil
                return .run { [menstrualLocal] send in
                    try? await menstrualLocal.setPeriodLengthOverride(override)
                    // Regenerate predictions so the calendar reflects
                    // the new period span immediately instead of
                    // waiting for the next cycle confirmation.
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
