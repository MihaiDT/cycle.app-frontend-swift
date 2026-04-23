import ComposableArchitecture
import SwiftUI

// MARK: - Profile Feature (Me tab — placeholder)
//
// The real Me screen is being built on another branch. Until that lands,
// this tab only exposes a single "Reset App" action that wipes all local
// data and drops the user back into onboarding. Reusing the existing
// logout flow: `delegate(.didLogout)` is what HomeFeature already listens
// for, and its handler clears every SwiftData model + chat session.

@Reducer
public struct ProfileFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var isConfirmingReset: Bool = false
        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case resetAppTapped
        case resetConfirmed
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            /// Fired after the user confirms reset. HomeFeature listens
            /// for this and performs the data wipe + navigation.
            case didLogout
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .resetAppTapped:
                state.isConfirmingReset = true
                return .none

            case .resetConfirmed:
                state.isConfirmingReset = false
                return .send(.delegate(.didLogout))

            case .binding, .delegate:
                return .none
            }
        }
    }
}
