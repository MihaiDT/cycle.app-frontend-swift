import ComposableArchitecture
import Foundation

// MARK: - EditCycleFeature (menu)
//
// Parent screen for cycle metadata. Shows current values for Cycle
// length and Period length as summary rows; tapping a row pushes the
// matching editor sub-screen. Reloads its summary on appear AND each
// time a sub-editor finishes (so the row reflects the new value
// without a manual pull).

@Reducer
public struct EditCycleFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var cycleLength: Int = 28
        public var periodLength: Int = 5
        public var showOvulation: Bool = true
        public var showFertileWindow: Bool = true

        @Presents public var cycleLengthEditor: CycleLengthEditorFeature.State?
        @Presents public var periodLengthEditor: PeriodLengthEditorFeature.State?

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case dataLoaded(Int, Int, Bool, Bool)
        case cycleLengthRowTapped
        case periodLengthRowTapped
        case showOvulationToggled(Bool)
        case showFertileWindowToggled(Bool)
        case cycleLengthEditor(PresentationAction<CycleLengthEditorFeature.Action>)
        case periodLengthEditor(PresentationAction<PeriodLengthEditorFeature.Action>)
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
                return loadEffect()

            case let .dataLoaded(cycleLen, periodLen, showOv, showFert):
                state.cycleLength = cycleLen
                state.periodLength = periodLen
                state.showOvulation = showOv
                state.showFertileWindow = showFert
                return .none

            case .cycleLengthRowTapped:
                state.cycleLengthEditor = CycleLengthEditorFeature.State()
                return .none

            case .periodLengthRowTapped:
                state.periodLengthEditor = PeriodLengthEditorFeature.State()
                return .none

            case let .showOvulationToggled(value):
                state.showOvulation = value
                return .run { [menstrualLocal] send in
                    try? await menstrualLocal.setShowOvulation(value)
                    await send(.delegate(.didSave))
                }

            case let .showFertileWindowToggled(value):
                state.showFertileWindow = value
                return .run { [menstrualLocal] send in
                    try? await menstrualLocal.setShowFertileWindow(value)
                    await send(.delegate(.didSave))
                }

            case .cycleLengthEditor(.presented(.delegate(.didSave))):
                state.cycleLengthEditor = nil
                return .merge(
                    loadEffect(),
                    .send(.delegate(.didSave))
                )

            case .periodLengthEditor(.presented(.delegate(.didSave))):
                state.periodLengthEditor = nil
                return .merge(
                    loadEffect(),
                    .send(.delegate(.didSave))
                )

            case .cycleLengthEditor, .periodLengthEditor:
                return .none
            }
        }
        .ifLet(\.$cycleLengthEditor, action: \.cycleLengthEditor) {
            CycleLengthEditorFeature()
        }
        .ifLet(\.$periodLengthEditor, action: \.periodLengthEditor) {
            PeriodLengthEditorFeature()
        }
    }

    private func loadEffect() -> Effect<Action> {
        .run { [menstrualLocal] send in
            // Effective getters return the value currently in use
            // (manual pin OR recomputed recommended), bypassing any
            // stale `profile.avgCycleLength` left from earlier saves.
            let cycleLen = (try? await menstrualLocal.getEffectiveCycleLength()) ?? 28
            let periodLen = (try? await menstrualLocal.getEffectivePeriodLength()) ?? 5
            let showOv = (try? await menstrualLocal.getShowOvulation()) ?? true
            let showFert = (try? await menstrualLocal.getShowFertileWindow()) ?? true
            await send(.dataLoaded(cycleLen, periodLen, showOv, showFert))
        }
    }
}
