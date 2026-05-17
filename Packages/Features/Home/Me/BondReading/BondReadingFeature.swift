import ComposableArchitecture
import Foundation

// MARK: - Bond Reading Feature
//
// Walks the user through the bond interpretation one theme at a
// time. `currentIndex` points into `bond.themes`; the view switches
// on it with a direction-aware slide. `nextTapped` past the last
// theme dismisses the flow; `previousTapped` from the first theme
// also dismisses, so back arrow and close X behave consistently
// for navigation versus flow exit.

@Reducer
public struct BondReadingFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var bond: Bond
        public var currentIndex: Int = 0
        public var lastNavigation: NavigationDirection = .forward

        public init(bond: Bond, currentIndex: Int = 0) {
            self.bond = bond
            self.currentIndex = currentIndex
        }

        public enum NavigationDirection: Equatable, Sendable {
            case forward
            case backward
        }

        public var isAtFirst: Bool { currentIndex <= 0 }
        public var isAtLast: Bool { currentIndex >= bond.themes.count - 1 }

        public var currentTheme: BondTheme? {
            guard bond.themes.indices.contains(currentIndex) else { return nil }
            return bond.themes[currentIndex]
        }
    }

    public enum Action: Sendable {
        case nextTapped
        case previousTapped
        case closeTapped
    }

    public init() {}

    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nextTapped:
                if state.isAtLast {
                    return .run { _ in await dismiss() }
                }
                state.lastNavigation = .forward
                state.currentIndex += 1
                return .none

            case .previousTapped:
                if state.isAtFirst {
                    return .run { _ in await dismiss() }
                }
                state.lastNavigation = .backward
                state.currentIndex -= 1
                return .none

            case .closeTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
