import ComposableArchitecture
import SwiftUI

// MARK: - Daily Check-In Feature

@Reducer
public struct DailyCheckInFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var energyLevel: Double = 3
        public var stressLevel: Double = 3
        public var sleepQuality: Double = 3
        public var moodLevel: Double = 3
        public var notes: String = ""
        public var isSubmitting: Bool = false
        public var error: String?

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case submitTapped
        case submitResponse(Result<DailyReportResponse, Error>)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didCompleteCheckIn(DailyReportResponse)
        }
    }

    @Dependency(\.hbiLocal) var hbiLocal
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                state.isSubmitting = true
                state.error = nil
                let request = DailyReportRequest(
                    energyLevel: Int(state.energyLevel),
                    stressLevel: Int(state.stressLevel),
                    sleepQuality: Int(state.sleepQuality),
                    moodLevel: Int(state.moodLevel),
                    notes: state.notes.isEmpty ? nil : state.notes
                )
                return .run { send in
                    let result = await Result {
                        try await hbiLocal.submitDailyReport(request)
                    }
                    await send(.submitResponse(result))
                }

            case .submitResponse(.success(let response)):
                state.isSubmitting = false
                return .run { send in
                    await send(.delegate(.didCompleteCheckIn(response)))
                    await dismiss()
                }

            case .submitResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error.localizedDescription
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }
}

// MARK: - Daily Check-In View

public struct DailyCheckInView: View {
    @Bindable var store: StoreOf<DailyCheckInFeature>

    public init(store: StoreOf<DailyCheckInFeature>) {
        self.store = store
    }

    public var body: some View {
        DailyCheckInRitualView(store: store)
            .background(DesignColors.background.ignoresSafeArea())
    }
}


