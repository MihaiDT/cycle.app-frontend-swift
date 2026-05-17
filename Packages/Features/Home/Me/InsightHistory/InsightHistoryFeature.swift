import ComposableArchitecture
import Foundation

// MARK: - Insight History Feature
//
// Lists every daily insight the user has saved (hearted). State
// holds a snapshot of the parent's `savedInsights` array taken at
// presentation time — the reducer does not own the canonical store.
// Tapping the back chip pops the overlay; tapping the heart on a
// tile sends `unlike(id)` so the parent can drop it from the
// canonical collection.

@Reducer
public struct InsightHistoryFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var insights: IdentifiedArrayOf<DailyInsightItem>
        /// Insight the user tapped to view full-screen + share.
        /// Driven through SwiftUI's `.fullScreenCover(item:)`, so
        /// non-nil = sheet up, nil = back on the grid.
        public var selectedInsight: DailyInsightItem?

        public init(
            insights: IdentifiedArrayOf<DailyInsightItem> = [],
            selectedInsight: DailyInsightItem? = nil
        ) {
            self.insights = insights
            self.selectedInsight = selectedInsight
        }
    }

    public enum Action: BindableAction, Sendable {
        case backTapped
        case unlikeTapped(DailyInsightItem.ID)
        case tileTapped(DailyInsightItem.ID)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case unliked(DailyInsightItem.ID)
        }
    }

    public init() {}

    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .backTapped:
                return .run { _ in await dismiss() }

            case .unlikeTapped(let id):
                state.insights.remove(id: id)
                // If the user just unliked the insight that's
                // currently presented in the share screen, drop
                // the share screen too — keeping it up after the
                // card has been removed feels haunted.
                if state.selectedInsight?.id == id {
                    state.selectedInsight = nil
                }
                return .send(.delegate(.unliked(id)))

            case .tileTapped(let id):
                state.selectedInsight = state.insights[id: id]
                return .none

            case .binding:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
