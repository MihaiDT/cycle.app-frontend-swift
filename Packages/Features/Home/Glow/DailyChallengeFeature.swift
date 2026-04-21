import ComposableArchitecture
import Foundation

// MARK: - Daily Challenge Feature

@Reducer
public struct DailyChallengeFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var challenge: ChallengeSnapshot?
        public var profile: GlowProfileSnapshot?
        public var challengeState: ChallengeState = .idle
        /// Latest HBI score — broadcast from TodayFeature after dashboard loads.
        /// Stored here so future challenge re-weighting (e.g. low-energy → gentler)
        /// can key off the freshest value without a separate dependency.
        public var currentHBI: HBIScore?

        public enum ChallengeState: Equatable, Sendable {
            case idle
            case available
            case inProgress(startedAt: Date, timerEndDate: Date)
            case skipped
            case completed
        }

        // TCA child features
        @Presents public var levelUp: LevelUpFeature.State?
        @Presents public var journey: ChallengeJourneyFeature.State?

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)

        // Challenge lifecycle
        case selectChallenge(phase: String, energyLevel: Int)
        case challengeLoaded(ChallengeSnapshot?)
        case challengeSelected(ChallengeSnapshot)
        case doItTapped
        case continueTapped
        case skipTapped
        case maybeLaterTapped

        /// Broadcast from TodayFeature after each dashboard reload (post check-in etc.).
        /// Subscribers store the latest score; no heavy work here yet.
        case hbiUpdated(HBIScore)

        // Profile
        case profileLoaded(GlowProfileSnapshot)

        // Level up trigger (from .run after XP added)
        case levelUpTriggered(level: Int, title: String, emoji: String, unlock: String)

        // Child feature presentations
        case levelUp(PresentationAction<LevelUpFeature.Action>)
        case journey(PresentationAction<ChallengeJourneyFeature.Action>)

        // Delegate to parent
        case delegate(Delegate)
        public enum Delegate: Sendable {
            case challengeStateChanged(ChallengeSnapshot?)
            /// Fires only at the exact transition-to-completed moment (after
            /// validation success), so subscribers like TodayFeature can
            /// reload the dashboard for the moment bump without re-firing
            /// every time an already-completed snapshot is re-loaded at
            /// app launch.
            case challengeJustCompleted
        }
    }

    @Dependency(\.glowLocal) var glowLocal
    @Dependency(\.hbiLocal) var hbiLocal

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            // MARK: - Challenge Selection

            case let .selectChallenge(phase, energyLevel):
                return .run { [glowLocal] send in
                    if let existing = try await glowLocal.getTodayChallenge() {
                        await send(.challengeLoaded(existing))
                        return
                    }
                    let recentIds = try await glowLocal.getRecentCompletedTemplateIds(14)
                    let templates = ChallengeTemplatePool.templates
                    guard let template = ChallengeSelector.select(
                        phase: phase,
                        energyLevel: energyLevel,
                        recentTemplateIds: recentIds,
                        templates: templates
                    ) else {
                        await send(.challengeLoaded(nil))
                        return
                    }
                    let snapshot = ChallengeSnapshot(
                        id: UUID(),
                        date: Date(),
                        templateId: template.id,
                        challengeCategory: template.category,
                        challengeTitle: template.title,
                        challengeDescription: template.description,
                        tips: template.tips,
                        goldHint: template.goldHint,
                        validationPrompt: template.validationPrompt,
                        cyclePhase: phase,
                        cycleDay: 0,
                        energyLevel: energyLevel,
                        status: .available,
                        completedAt: nil,
                        photoThumbnail: nil,
                        validationRating: nil,
                        validationFeedback: nil,
                        xpEarned: 0
                    )
                    try await glowLocal.saveChallenge(snapshot)
                    await send(.challengeSelected(snapshot))
                }

            case let .challengeLoaded(snapshot):
                state.challenge = snapshot
                if let s = snapshot {
                    // Don't overwrite .inProgress — challenge is actively running
                    if case .inProgress = state.challengeState {
                        // keep inProgress
                    } else {
                        switch s.status {
                        case .completed: state.challengeState = .completed
                        case .skipped: state.challengeState = .skipped
                        case .available: state.challengeState = .available
                        }
                    }
                }
                return .merge(
                    .send(.delegate(.challengeStateChanged(snapshot))),
                    .run { [glowLocal] send in
                        let profile = try await glowLocal.getProfile()
                        await send(.profileLoaded(profile))
                    }
                )

            case let .challengeSelected(snapshot):
                state.challenge = snapshot
                if case .inProgress = state.challengeState {
                    // keep inProgress
                } else {
                    state.challengeState = .available
                }
                return .merge(
                    .send(.delegate(.challengeStateChanged(snapshot))),
                    .run { [glowLocal] send in
                        let profile = try await glowLocal.getProfile()
                        await send(.profileLoaded(profile))
                    }
                )

            case let .profileLoaded(profile):
                state.profile = profile
                return .none

            // MARK: - User Actions

            case .doItTapped:
                guard let challenge = state.challenge else { return .none }
                // Open journey directly — accept is the first step inside
                state.journey = ChallengeJourneyFeature.State(challenge: challenge)
                return .none


            case .continueTapped:
                guard let challenge = state.challenge else { return .none }
                var journeyState = ChallengeJourneyFeature.State(challenge: challenge)
                // Skip to proof step — user is done with the activity
                journeyState.step = .proof
                if case let .inProgress(_, timerEndDate) = state.challengeState {
                    journeyState.timerEndDate = timerEndDate
                }
                state.journey = journeyState
                return .none

            case .skipTapped:
                guard let challenge = state.challenge else { return .none }
                state.challengeState = .skipped
                var updated = challenge
                updated.status = .skipped
                state.challenge = updated
                let challengeId = challenge.id
                return .merge(
                    .send(.delegate(.challengeStateChanged(updated))),
                    .run { [glowLocal] _ in try await glowLocal.skipChallenge(challengeId) }
                )

            case .maybeLaterTapped:
                state.challengeState = .available
                if var challenge = state.challenge {
                    challenge.status = .available
                    state.challenge = challenge
                    return .send(.delegate(.challengeStateChanged(challenge)))
                }
                return .none

            // MARK: - HBI Broadcast

            case let .hbiUpdated(score):
                // Store latest score. Future work: re-weight challenge when energy
                // drops significantly after a check-in.
                state.currentHBI = score
                return .none

            // MARK: - Level Up

            case let .levelUpTriggered(level, title, emoji, unlock):
                state.levelUp = LevelUpFeature.State(
                    newLevel: level,
                    levelTitle: title,
                    levelEmoji: emoji,
                    unlockDescription: unlock
                )
                return .none

            case .levelUp(.presented(.delegate(.dismissed))):
                state.levelUp = nil
                return .none

            case .levelUp:
                return .none

            // MARK: - Journey Delegates

            case let .journey(.presented(.delegate(.completed(photoData, thumbnailData, xpEarned, rating, feedback)))):
                state.journey = nil
                guard var challenge = state.challenge else { return .none }
                challenge.status = .completed
                challenge.completedAt = Date()
                challenge.validationRating = rating
                challenge.validationFeedback = feedback
                challenge.xpEarned = xpEarned
                challenge.photoThumbnail = thumbnailData
                state.challenge = challenge
                state.challengeState = .completed
                let challengeId = challenge.id
                let category = challenge.challengeCategory
                return .merge(
                    .send(.delegate(.challengeStateChanged(challenge))),
                    .send(.delegate(.challengeJustCompleted)),
                    .run { [glowLocal, hbiLocal] send in
                        try await glowLocal.completeChallenge(
                            challengeId, photoData, thumbnailData, rating, feedback, xpEarned
                        )
                        // Nudge Wellness — moment's bump lands on today's
                        // HBI components + recomputes adjusted score so the
                        // widget on Home reflects the shift. TodayFeature
                        // reloads the dashboard on challengeStateChanged
                        // so the ring re-animates without a manual refresh.
                        try? await hbiLocal.applyMomentBump(category, rating)

                        let (previous, current) = try await glowLocal.addXP(xpEarned, rating)
                        if current.currentLevel > previous.currentLevel {
                            let info = GlowConstants.levelFor(xp: current.totalXP)
                            let unlock = GlowConstants.unlockDescriptions[current.currentLevel] ?? ""
                            await send(.levelUpTriggered(
                                level: info.level,
                                title: info.title,
                                emoji: info.emoji,
                                unlock: unlock
                            ))
                        }
                    }
                )

            case let .journey(.presented(.delegate(.challengeStarted(timerEndDate)))):
                state.challengeState = .inProgress(startedAt: Date(), timerEndDate: timerEndDate)
                return .none

            case .journey(.presented(.delegate(.cancelled))):
                // If still on accept step (never started), reset to available
                if case .inProgress = state.challengeState {} else {
                    state.journey = nil
                    return .none
                }
                // If in progress, keep state — just dismiss journey
                state.journey = nil
                return .none

            case .journey(.presented(.delegate(.skippedForToday))):
                // User chose "Let it go for today" on the validation failure
                // screen. Mark the challenge as skipped, persist it, dismiss
                // the journey. Card swaps to the "see you tomorrow" state.
                state.journey = nil
                guard var challenge = state.challenge else { return .none }
                challenge.status = .skipped
                state.challenge = challenge
                state.challengeState = .skipped
                let challengeId = challenge.id
                return .merge(
                    .send(.delegate(.challengeStateChanged(challenge))),
                    .run { [glowLocal] _ in try await glowLocal.skipChallenge(challengeId) }
                )

            case .journey:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$levelUp, action: \.levelUp) { LevelUpFeature() }
        .ifLet(\.$journey, action: \.journey) { ChallengeJourneyFeature() }
    }
}
