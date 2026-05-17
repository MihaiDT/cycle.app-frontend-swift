import ComposableArchitecture
import Foundation

// MARK: - Add Bond Feature
//
// Multi-screen flow for adding a new bond: intro → name → birth date
// → birth time → birth place. State machine is held in `step: Step`
// so the view can switch on it with transitions — no NavigationStack
// for five known steps. Mock-only: on save the bond is forwarded via
// `delegate(.didSave)` to MeFeature, which appends it to its
// in-memory `bonds` array. Reset on cold launch is expected for the
// prototype.
//
// Current iteration implements only the intro step; the remaining
// steps render placeholders so the build stays green while we design
// each screen separately.

@Reducer
public struct AddBondFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var step: Step = .intro

        public var name: String = ""
        public var isAnonymous: Bool = false
        public var birthDate: Date
        public var birthTime: Date
        public var birthPlace: BondBirthPlace?

        /// Constructed bond, held in state while the generating
        /// screen is on so a tap on Discover (or the auto-advance
        /// timer expiring) can finalize it without re-running the
        /// init plumbing.
        public var pendingBond: Bond?

        /// Latest navigation direction — read by the view to pick the
        /// transition (slide-from-trailing on forward, slide-from-leading
        /// on backward). Defaults to `.forward` so the very first
        /// appearance of the flow doesn't feel like a "back" gesture.
        public var lastNavigation: NavigationDirection = .forward

        public init(
            step: Step = .intro,
            name: String = "",
            isAnonymous: Bool = false,
            birthDate: Date? = nil,
            birthTime: Date? = nil,
            birthPlace: BondBirthPlace? = nil
        ) {
            self.step = step
            self.name = name
            self.isAnonymous = isAnonymous
            self.birthDate = birthDate ?? Date(timeIntervalSinceNow: -30 * 365 * 24 * 3600)
            self.birthTime = birthTime ?? Calendar.current.date(
                bySettingHour: 12, minute: 0, second: 0, of: .now
            ) ?? .now
            self.birthPlace = birthPlace
        }

        public enum Step: Equatable, Sendable {
            case intro
            case name
            case birthDate
            case birthTime
            case birthPlace
            case generating
        }

        public enum NavigationDirection: Equatable, Sendable {
            case forward
            case backward
        }
    }

    public enum Action: Sendable, BindableAction {
        case binding(BindingAction<State>)
        case beginTapped
        case nameContinueTapped
        case birthDateContinueTapped
        case birthTimeContinueTapped
        case birthPlaceContinueTapped
        case discoverTapped
        case backTapped
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didSave(Bond)
            case didCancel
        }
    }

    public init() {}

    @Dependency(\.dismiss) var dismiss

    /// Cancel IDs for in-flight effects. Keeps a stale generation
    /// task from racing a re-entered flow if `birthPlaceContinueTapped`
    /// is somehow triggered twice (e.g. via state restoration).
    private enum CancelID: Hashable, Sendable {
        case generation
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .beginTapped:
                state.lastNavigation = .forward
                state.step = .name
                return .none

            case .nameContinueTapped:
                // Anonymous mode wipes any half-typed name so a later
                // toggle-off doesn't resurrect stale input from the
                // text field.
                if state.isAnonymous {
                    state.name = ""
                }
                state.lastNavigation = .forward
                state.step = .birthDate
                return .none

            case .birthDateContinueTapped:
                state.lastNavigation = .forward
                state.step = .birthTime
                return .none

            case .birthTimeContinueTapped:
                state.lastNavigation = .forward
                state.step = .birthPlace
                return .none

            case .birthPlaceContinueTapped:
                // Advance to the generating screen — interactive
                // blob scene with cycling status stages. The bond is
                // built once and parked in `pendingBond`; finalization
                // is gated entirely on the user tapping Discover so
                // the experience never short-circuits past the scene.
                guard let place = state.birthPlace else { return .none }
                state.lastNavigation = .forward
                state.step = .generating
                state.pendingBond = Bond(
                    name: state.name,
                    isAnonymous: state.isAnonymous,
                    birthDate: state.birthDate,
                    birthTime: state.birthTime,
                    birthPlace: place
                )
                return .none

            case .discoverTapped:
                // Fires only from the Discover button after the
                // status stages finish cycling. Ships the delegate,
                // then waits 360ms for the parent's BondReading
                // overlay (zIndex 7) to slide in over this one
                // (zIndex 6) before tearing down — otherwise the
                // user sees a flash of Home between the two.
                guard let bond = state.pendingBond else { return .none }
                return .run { send in
                    await send(.delegate(.didSave(bond)))
                    try? await Task.sleep(for: .milliseconds(360))
                    await dismiss()
                }
                .cancellable(id: CancelID.generation, cancelInFlight: true)

            case .backTapped:
                // Step-by-step back navigation. On intro there's
                // nowhere further to retreat so the whole flow
                // dismisses — same teardown path as `cancelTapped`.
                // On `.generating` we ignore back: the loading
                // sequence is intentionally non-interruptible so
                // the user can't bail half-way through the mock
                // generation and end up with a partial state.
                state.lastNavigation = .backward
                switch state.step {
                case .intro:
                    return .run { _ in await dismiss() }
                case .name:
                    state.step = .intro
                case .birthDate:
                    state.step = .name
                case .birthTime:
                    state.step = .birthDate
                case .birthPlace:
                    state.step = .birthTime
                case .generating:
                    return .none
                }
                return .none

            case .cancelTapped:
                // No delegate send — parent doesn't need to react
                // to cancel, and double-cleanup (parent niling state
                // + child dismissing) races on the same presentation
                // and freezes the back gesture. dismiss() alone is
                // the canonical TCA teardown path.
                return .run { _ in await dismiss() }

            case .binding, .delegate:
                return .none
            }
        }
    }
}
