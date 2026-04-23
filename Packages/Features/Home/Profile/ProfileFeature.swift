import ComposableArchitecture
import SwiftUI

// MARK: - Profile Feature

@Reducer
public struct ProfileFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var user: User?
        public var menstrualStatus: MenstrualStatusResponse?
        public var hbiDashboard: HBIDashboardResponse?
        public var glowProfile: GlowProfileSnapshot?

        public init(
            user: User? = nil,
            menstrualStatus: MenstrualStatusResponse? = nil,
            hbiDashboard: HBIDashboardResponse? = nil
        ) {
            self.user = user
            self.menstrualStatus = menstrualStatus
            self.hbiDashboard = hbiDashboard
        }

        // MARK: - Computed

        var cyclePhase: CyclePhase? {
            guard let phase = menstrualStatus?.currentCycle.phase else { return nil }
            return CyclePhase(rawValue: phase)
        }

        var memberSinceFormatted: String? {
            guard let user else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: user.createdAt)
        }

        var trackingSinceFormatted: String? {
            guard let date = menstrualStatus?.profile.trackingSince else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }

        var cycleRegularityDisplay: String {
            guard let reg = menstrualStatus?.profile.cycleRegularity else { return "Unknown" }
            switch reg {
            case "regular": return "Regular"
            case "somewhat_regular": return "Somewhat Regular"
            case "irregular": return "Irregular"
            default: return reg.capitalized
            }
        }

        var hbiScore: Int? {
            hbiDashboard?.today?.hbiAdjusted
        }

        var hbiTrend: String? {
            hbiDashboard?.today?.trendDirection
        }
    }

    public enum Action: Sendable {
        case loadGlowProfile
        case glowProfileLoaded(GlowProfileSnapshot)
        case logoutTapped
        case deleteChatDataTapped
        case chatDataDeleted
        case resetAnonymousIDTapped
        case anonymousIDReset
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case didLogout
        }
    }

    @Dependency(\.anonymousID) var anonymousID
    @Dependency(\.glowLocal) var glowLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadGlowProfile:
                return .run { [glowLocal] send in
                    let profile = try await glowLocal.getProfile()
                    await send(.glowProfileLoaded(profile))
                }

            case let .glowProfileLoaded(profile):
                state.glowProfile = profile
                return .none

            case .logoutTapped:
                return .send(.delegate(.didLogout))

            case .deleteChatDataTapped:
                let id = anonymousID.getID()
                return .run { send in
                    // Call server to delete all anonymous data
                    let url = URL(string: "https://dth-backend-277319586889.us-central1.run.app/anonymous/\(id)/all")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "DELETE"
                    _ = try? await URLSession.shared.data(for: request)
                    await send(.chatDataDeleted)
                }

            case .chatDataDeleted:
                return .none

            case .resetAnonymousIDTapped:
                _ = anonymousID.rotateID()
                return .send(.anonymousIDReset)

            case .anonymousIDReset:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
