import ComposableArchitecture
import Foundation

// MARK: - Bond History Feature
//
// Lists every bond the user has saved. State holds a snapshot of
// the parent's `bonds` array (taken at presentation time) — the
// reducer does not own the canonical store. Tapping a row sends a
// `delegate(.openReading)` so `MeFeature` can open the appropriate
// `BondReadingFeature` for that bond. Tapping Add starts the
// AddBond flow via `delegate(.openAddBond)`.

@Reducer
public struct BondHistoryFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var bonds: IdentifiedArrayOf<Bond>

        public init(bonds: IdentifiedArrayOf<Bond> = []) {
            self.bonds = bonds
        }
    }

    public enum Action: Sendable {
        case rowTapped(Bond.ID)
        case addBondTapped
        case backTapped
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case openReading(Bond.ID)
            case openAddBond
        }
    }

    public init() {}

    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .rowTapped(let id):
                return .send(.delegate(.openReading(id)))

            case .addBondTapped:
                return .send(.delegate(.openAddBond))

            case .backTapped:
                return .run { _ in await dismiss() }

            case .delegate:
                return .none
            }
        }
    }
}
