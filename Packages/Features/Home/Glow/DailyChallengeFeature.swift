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

        public enum ChallengeState: Equatable, Sendable {
            case idle
            case available
            case skipped
            case completed
        }

        // Photo capture — simple flags, not @Presents (UIKit wrappers)
        public var isShowingCamera: Bool = false
        public var isShowingGallery: Bool = false

        // TCA child features
        @Presents public var acceptSheet: ChallengeAcceptFeature.State?
        @Presents public var photoReview: PhotoReviewFeature.State?
        @Presents public var validation: ValidationFeature.State?
        @Presents public var levelUp: LevelUpFeature.State?

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)

        // Challenge lifecycle
        case selectChallenge(phase: String, energyLevel: Int)
        case challengeLoaded(ChallengeSnapshot?)
        case challengeSelected(ChallengeSnapshot)
        case doItTapped
        case skipTapped
        case maybeLaterTapped

        // Photo capture (from view layer)
        case photoCaptured(Data)
        case photoCancelled

        // Profile
        case profileLoaded(GlowProfileSnapshot)

        // Level up trigger (from .run after XP added)
        case levelUpTriggered(level: Int, title: String, emoji: String, unlock: String)

        // Child feature presentations
        case acceptSheet(PresentationAction<ChallengeAcceptFeature.Action>)
        case photoReview(PresentationAction<PhotoReviewFeature.Action>)
        case validation(PresentationAction<ValidationFeature.Action>)
        case levelUp(PresentationAction<LevelUpFeature.Action>)

        // Delegate to parent
        case delegate(Delegate)
        public enum Delegate: Sendable {
            case challengeStateChanged(ChallengeSnapshot?)
        }
    }

    @Dependency(\.glowLocal) var glowLocal

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
                    switch s.status {
                    case .completed: state.challengeState = .completed
                    case .skipped: state.challengeState = .skipped
                    case .available: state.challengeState = .available
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
                state.challengeState = .available
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
                state.acceptSheet = ChallengeAcceptFeature.State(challenge: challenge)
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

            // MARK: - Accept Sheet Delegates

            case .acceptSheet(.presented(.delegate(.openCamera))):
                state.acceptSheet = nil
                state.isShowingCamera = true
                return .none

            case .acceptSheet(.presented(.delegate(.openGallery))):
                state.acceptSheet = nil
                state.isShowingGallery = true
                return .none

            case .acceptSheet:
                return .none

            // MARK: - Photo Capture

            case let .photoCaptured(data):
                state.isShowingCamera = false
                state.isShowingGallery = false
                guard let processed = PhotoProcessor.process(data) else { return .none }
                state.photoReview = PhotoReviewFeature.State(
                    imageData: processed.fullSize,
                    thumbnailData: processed.thumbnail
                )
                return .none

            case .photoCancelled:
                state.isShowingCamera = false
                state.isShowingGallery = false
                return .none

            // MARK: - Photo Review Delegates

            case let .photoReview(.presented(.delegate(.submit(fullSize, thumbnail)))):
                state.photoReview = nil
                guard let challenge = state.challenge else { return .none }
                let totalXP = state.profile?.totalXP ?? 0
                state.validation = ValidationFeature.State(
                    challenge: challenge,
                    photoData: fullSize,
                    thumbnailData: thumbnail,
                    profileTotalXP: totalXP
                )
                return .none

            case .photoReview(.presented(.delegate(.retake))):
                state.photoReview = nil
                state.isShowingCamera = true
                return .none

            case .photoReview:
                return .none

            // MARK: - Validation Delegates

            case let .validation(.presented(.delegate(.completed(photoData, thumbnailData, xpEarned, rating, feedback)))):
                state.validation = nil
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
                return .run { [glowLocal] send in
                    try await glowLocal.completeChallenge(
                        challengeId, photoData, thumbnailData, rating, feedback, xpEarned
                    )
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

            case .validation(.presented(.delegate(.tryAgain))):
                state.validation = nil
                state.isShowingCamera = true
                return .none

            case .validation(.presented(.delegate(.skipForToday))):
                state.validation = nil
                return .send(.skipTapped)

            case .validation:
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

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$acceptSheet, action: \.acceptSheet) { ChallengeAcceptFeature() }
        .ifLet(\.$photoReview, action: \.photoReview) { PhotoReviewFeature() }
        .ifLet(\.$validation, action: \.validation) { ValidationFeature() }
        .ifLet(\.$levelUp, action: \.levelUp) { LevelUpFeature() }
    }
}
