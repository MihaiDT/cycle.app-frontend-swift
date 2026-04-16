# Challenge Journey Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fragmented challenge modal flow with a single full-screen continuous journey (timer → camera → validation → celebration) that never bounces to Home.

**Architecture:** New `ChallengeJourneyFeature` TCA reducer acts as a state machine driving 4 steps. Presented as a single `fullScreenCover` from `DailyChallengeFeature`. Each step is a separate SwiftUI view composed inside `ChallengeJourneyView`. Camera/gallery use existing `UIViewControllerRepresentable` wrappers. Live Activity via ActivityKit shows timer in Dynamic Island.

**Tech Stack:** Swift 6, SwiftUI, TCA 1.17+, ActivityKit, Raleway font, DesignColors palette. Flat compilation — no internal module imports.

**Spec:** `docs/superpowers/specs/2026-04-16-challenge-flow-redesign.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `Packages/Features/Home/Glow/ChallengeJourneyFeature.swift` | Create | TCA reducer — state machine for 4 journey steps |
| `Packages/Features/Home/Glow/ChallengeJourneyView.swift` | Create | Main full-screen view — switches on step, hosts camera/gallery |
| `Packages/Features/Home/Glow/ChallengeTimerView.swift` | Create | Step 1: countdown timer + read-only tips |
| `Packages/Features/Home/Glow/ChallengeProofView.swift` | Create | Step 2: photo preview + submit/retake (inline, no separate modal) |
| `Packages/Features/Home/Glow/ChallengeValidatingView.swift` | Create | Step 3: pulsing Aria animation |
| `Packages/Features/Home/Glow/ChallengeCelebrationView.swift` | Create | Step 4: celebration card + gamification placeholder |
| `Packages/Features/Home/Glow/DailyChallengeFeature.swift` | Modify | Present journey as fullScreenCover, handle .completed/.cancelled delegates |
| `Packages/Features/Home/TodayFeature.swift` | Modify | Add journey fullScreenCover to DailyGlowPresentations modifier |
| `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift` | Modify | Add `.startChallenge` delegate (replaces .openCamera/.openGallery) |
| `CycleApp/CycleAppLiveActivity/ChallengeActivityBundle.swift` | Create | Widget extension entry point |
| `CycleApp/CycleAppLiveActivity/ChallengeActivityAttributes.swift` | Create | ActivityKit attributes + content state |
| `CycleApp/CycleAppLiveActivity/ChallengeActivityView.swift` | Create | Dynamic Island + Lock Screen views |
| `Packages/Features/Home/Glow/ChallengeActivityBridge.swift` | Create | Start/update/end Live Activity from app |
| `project.yml` | Modify | Add widget extension target |

---

## Phase 1: Core Journey Flow

### Task 1: ChallengeJourneyFeature Reducer

**Files:**
- Create: `Packages/Features/Home/Glow/ChallengeJourneyFeature.swift`

- [ ] **Step 1: Create the reducer with state machine**

```swift
// Packages/Features/Home/Glow/ChallengeJourneyFeature.swift

import ComposableArchitecture
import Foundation

@Reducer
struct ChallengeJourneyFeature: Sendable {

    // MARK: - State

    @ObservableState
    struct State: Equatable, Sendable {
        let challenge: ChallengeSnapshot
        var step: Step = .timer
        
        // Timer
        var timerSecondsRemaining: Int
        let timerDurationTotal: Int
        
        // Photo
        var capturedFullSize: Data?
        var capturedThumbnail: Data?
        var isShowingCamera = false
        var isShowingGallery = false
        
        // Validation
        var validationState: ValidationState = .idle
        
        // Celebration
        var celebrationFeedback: String = ""
        var celebrationRating: String = ""
        var celebrationXP: Int = 0

        enum Step: Equatable, Sendable {
            case timer
            case proof
            case validating
            case celebration
        }

        enum ValidationState: Equatable, Sendable {
            case idle
            case loading
            case success
            case failure(String)
        }

        init(challenge: ChallengeSnapshot) {
            self.challenge = challenge
            let minutes = Self.durationMinutes(for: challenge.challengeCategory)
            self.timerDurationTotal = minutes * 60
            self.timerSecondsRemaining = minutes * 60
        }

        static func durationMinutes(for category: String) -> Int {
            switch category.lowercased() {
            case "creative", "nutrition": return 15
            case "movement": return 10
            default: return 5
            }
        }
        
        var timerProgress: Double {
            guard timerDurationTotal > 0 else { return 0 }
            return 1.0 - Double(timerSecondsRemaining) / Double(timerDurationTotal)
        }
        
        var timerDisplayString: String {
            let m = timerSecondsRemaining / 60
            let s = timerSecondsRemaining % 60
            return String(format: "%d:%02d", m, s)
        }
    }

    // MARK: - Action

    enum Action: Sendable {
        // Timer
        case timerTick
        case imDoneTapped
        
        // Proof
        case openCameraTapped
        case openGalleryTapped
        case photoCaptured(Data)
        case photoCancelled
        case retakeTapped
        case submitPhotoTapped
        
        // Validation
        case validationResponse(Result<ChallengeValidationResponse, Error>)
        
        // Celebration
        case backToMyDayTapped
        
        // Navigation
        case closeTapped
        
        // Delegate
        case delegate(Delegate)
        
        enum Delegate: Sendable, Equatable {
            case completed(
                photoData: Data, thumbnailData: Data,
                xpEarned: Int, rating: String, feedback: String
            )
            case cancelled
        }
    }

    // MARK: - Dependencies

    @Dependency(\.continuousClock) var clock
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.anonymousID) var anonymousID

    // MARK: - Body

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            // MARK: Timer

            case .timerTick:
                guard state.step == .timer, state.timerSecondsRemaining > 0 else {
                    return .none
                }
                state.timerSecondsRemaining -= 1
                return .none

            case .imDoneTapped:
                state.step = .proof
                state.isShowingCamera = true
                return .cancel(id: CancelID.timer)

            // MARK: Proof

            case .openCameraTapped:
                state.isShowingCamera = true
                return .none

            case .openGalleryTapped:
                state.isShowingGallery = true
                return .none

            case let .photoCaptured(data):
                state.isShowingCamera = false
                state.isShowingGallery = false
                guard let processed = PhotoProcessor.process(data) else { return .none }
                state.capturedFullSize = processed.fullSize
                state.capturedThumbnail = processed.thumbnail
                return .none

            case .photoCancelled:
                state.isShowingCamera = false
                state.isShowingGallery = false
                return .none

            case .retakeTapped:
                state.capturedFullSize = nil
                state.capturedThumbnail = nil
                state.isShowingCamera = true
                return .none

            case .submitPhotoTapped:
                guard let photoData = state.capturedFullSize else { return .none }
                state.step = .validating
                state.validationState = .loading
                let challenge = state.challenge
                let anonId = anonymousID.getID()
                return .run { send in
                    let base64 = photoData.base64EncodedString()
                    let request = ChallengeValidationRequest(
                        anonymousId: anonId,
                        challengeType: challenge.templateId,
                        challengeDescription: challenge.challengeDescription,
                        goldHint: challenge.goldHint,
                        imageBase64: base64
                    )
                    let endpoint = Endpoint.validateChallenge(body: request)
                    do {
                        let response: ChallengeValidationResponse = try await apiClient.send(endpoint)
                        await send(.validationResponse(.success(response)))
                    } catch {
                        await send(.validationResponse(.failure(error)))
                    }
                }

            // MARK: Validation

            case let .validationResponse(.success(response)):
                let xp = Int(Double(GlowConstants.baseXP) * response.xpMultiplier)
                if response.valid {
                    state.validationState = .success
                    state.celebrationFeedback = response.feedback
                    state.celebrationRating = response.rating
                    state.celebrationXP = xp
                    state.step = .celebration
                } else {
                    state.validationState = .failure(response.feedback)
                }
                return .none

            case .validationResponse(.failure):
                state.validationState = .failure("Something went wrong. Try again?")
                return .none

            // MARK: Celebration

            case .backToMyDayTapped:
                guard let fullSize = state.capturedFullSize,
                      let thumbnail = state.capturedThumbnail else { return .none }
                return .send(.delegate(.completed(
                    photoData: fullSize,
                    thumbnailData: thumbnail,
                    xpEarned: state.celebrationXP,
                    rating: state.celebrationRating,
                    feedback: state.celebrationFeedback
                )))

            // MARK: Navigation

            case .closeTapped:
                return .send(.delegate(.cancelled))

            case .delegate:
                return .none
            }
        }
    }

    private enum CancelID { case timer }
}
```

- [ ] **Step 2: Add timer effect startup**

The timer needs to start ticking when the feature appears. Add an `.onAppear` action and the timer effect:

Add to the Action enum:
```swift
case appeared
```

Add to the reducer body, inside the switch:
```swift
case .appeared:
    return .run { send in
        for await _ in self.clock.timer(interval: .seconds(1)) {
            await send(.timerTick)
        }
    }
    .cancellable(id: CancelID.timer)
```

- [ ] **Step 3: Add retry from failed validation**

Add handling for when validation fails and user wants to retry from proof step:

Add to Action enum:
```swift
case tryAgainTapped
```

Add to reducer:
```swift
case .tryAgainTapped:
    state.step = .proof
    state.capturedFullSize = nil
    state.capturedThumbnail = nil
    state.validationState = .idle
    state.isShowingCamera = true
    return .none
```

- [ ] **Step 4: Verify file compiles**

Run: `cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Packages/Features/Home/Glow/ChallengeJourneyFeature.swift
git commit -m "feat(challenge): add ChallengeJourneyFeature reducer with 4-step state machine"
```

---

### Task 2: ChallengeTimerView (Step 1)

**Files:**
- Create: `Packages/Features/Home/Glow/ChallengeTimerView.swift`

- [ ] **Step 1: Create the timer view**

```swift
// Packages/Features/Home/Glow/ChallengeTimerView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeTimerView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    var body: some View {
        VStack(spacing: 0) {
            topBar
            timerRing
                .padding(.bottom, 16)
            tipsCard
            Spacer(minLength: 14)
            imDoneButton
            timerHint
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { store.send(.closeTapped) } label: {
                ZStack {
                    Circle()
                        .fill(DesignColors.cardWarm)
                        .overlay(
                            Circle().strokeBorder(DesignColors.divider, lineWidth: 1)
                        )
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(store.challenge.challengeTitle)
                .font(.custom("Raleway-Bold", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPrincipal)
                .lineLimit(1)

            Spacer()

            // Balance spacer
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(DesignColors.divider, lineWidth: 3)

            // Progress arc
            Circle()
                .trim(from: 0, to: store.timerProgress)
                .stroke(
                    DesignColors.accentWarm,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 2) {
                Text(store.timerDisplayString)
                    .font(.custom("Raleway-Black", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(DesignColors.text)
                    .monospacedDigit()

                Text("remaining")
                    .font(.custom("Raleway-SemiBold", size: 11, relativeTo: .caption))
                    .foregroundStyle(DesignColors.textPlaceholder)
            }
        }
        .frame(width: 140, height: 140)
        .background(
            Circle().fill(DesignColors.cardWarm)
        )
    }

    // MARK: - Tips Card

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to")
                .font(.custom("Raleway-Bold", size: 11, relativeTo: .caption))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.accentWarm)

            ForEach(Array(store.challenge.tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(DesignColors.accentWarm.opacity(0.12))
                        Text("\(index + 1)")
                            .font(.custom("Raleway-Bold", size: 10, relativeTo: .caption))
                            .foregroundStyle(DesignColors.accentWarm)
                    }
                    .frame(width: 20, height: 20)

                    Text(tip)
                        .font(.custom("Raleway-Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textPrincipal)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glowCardBackground(tint: .neutral)
    }

    // MARK: - Button

    private var imDoneButton: some View {
        Button { store.send(.imDoneTapped) } label: {
            Text("I'm done")
                .font(.custom("Raleway-Bold", size: 15, relativeTo: .body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DesignColors.accentWarm)
                )
                .shadow(color: DesignColors.text.opacity(0.22), radius: 10, x: 0, y: 4)
                .shadow(color: DesignColors.text.opacity(0.10), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var timerHint: some View {
        Text("Timer continues in Dynamic Island")
            .font(.custom("Raleway-Medium", size: 10, relativeTo: .caption))
            .foregroundStyle(DesignColors.textPlaceholder)
            .padding(.top, 8)
    }
}
```

- [ ] **Step 2: Verify file compiles, commit**

```bash
git add Packages/Features/Home/Glow/ChallengeTimerView.swift
git commit -m "feat(challenge): add ChallengeTimerView — countdown timer with read-only tips"
```

---

### Task 3: ChallengeProofView (Step 2)

**Files:**
- Create: `Packages/Features/Home/Glow/ChallengeProofView.swift`

- [ ] **Step 1: Create the proof view with inline photo preview**

```swift
// Packages/Features/Home/Glow/ChallengeProofView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeProofView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if let photoData = store.capturedFullSize,
               let uiImage = UIImage(data: photoData) {
                photoPreview(uiImage)
            } else {
                waitingForPhoto
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { store.send(.closeTapped) } label: {
                ZStack {
                    Circle()
                        .fill(DesignColors.cardWarm)
                        .overlay(Circle().strokeBorder(DesignColors.divider, lineWidth: 1))
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Show Aria")
                .font(.custom("Raleway-Bold", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPrincipal)

            Spacer()

            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Waiting State

    private var waitingForPhoto: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Take a photo to show Aria")
                .font(.custom("Raleway-Medium", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.textPlaceholder)

            Text(store.challenge.validationPrompt)
                .font(.custom("Raleway-SemiBold", size: 13, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignColors.cardWarm)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(DesignColors.divider, lineWidth: 1)
                        )
                )

            Spacer()

            HStack(spacing: 20) {
                Button { store.send(.openCameraTapped) } label: {
                    Text("Camera")
                        .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        )
                        .shadow(color: DesignColors.text.opacity(0.22), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                Button { store.send(.openGalleryTapped) } label: {
                    Text("Gallery")
                        .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.textPrincipal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.cardWarm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(DesignColors.structure, lineWidth: 1.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Photo Preview

    private func photoPreview(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: DesignColors.text.opacity(0.12), radius: 12, x: 0, y: 4)

            Text("Aria will check if it matches your challenge")
                .font(.custom("Raleway-Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPlaceholder)

            Spacer(minLength: 0)

            Button { store.send(.submitPhotoTapped) } label: {
                Text("Submit")
                    .font(.custom("Raleway-Bold", size: 15, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignColors.accentWarm)
                    )
                    .shadow(color: DesignColors.text.opacity(0.22), radius: 10, x: 0, y: 4)
                    .shadow(color: DesignColors.text.opacity(0.10), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)

            Button { store.send(.retakeTapped) } label: {
                Text("Retake")
                    .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.textPlaceholder)
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 2: Verify file compiles, commit**

```bash
git add Packages/Features/Home/Glow/ChallengeProofView.swift
git commit -m "feat(challenge): add ChallengeProofView — inline photo preview with submit/retake"
```

---

### Task 4: ChallengeValidatingView (Step 3)

**Files:**
- Create: `Packages/Features/Home/Glow/ChallengeValidatingView.swift`

- [ ] **Step 1: Create the validating view**

```swift
// Packages/Features/Home/Glow/ChallengeValidatingView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeValidatingView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    @State private var isPulsing = false

    var body: some View {
        switch store.validationState {
        case .loading, .idle:
            loadingContent
        case let .failure(message):
            failureContent(message)
        case .success:
            // Transition handled by parent — step changes to .celebration
            EmptyView()
        }
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: 6) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DesignColors.accent, DesignColors.accent.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 36
                        )
                    )
                    .frame(width: 64, height: 64)
                    .scaleEffect(isPulsing ? 1.12 : 1.0)
                    .opacity(isPulsing ? 1.0 : 0.85)

                Circle()
                    .fill(DesignColors.accentWarm)
                    .frame(width: 24, height: 24)
            }
            .padding(.bottom, 14)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }

            Text("Aria is checking...")
                .font(.custom("Raleway-Bold", size: 18, relativeTo: .title3))
                .foregroundStyle(DesignColors.text)

            Text("Matching your photo\nwith the challenge")
                .font(.custom("Raleway-Medium", size: 13, relativeTo: .body))
                .foregroundStyle(DesignColors.textPlaceholder)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
        }
    }

    // MARK: - Failure

    private func failureContent(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(message)
                .font(.custom("Raleway-Medium", size: 16, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                Button { store.send(.tryAgainTapped) } label: {
                    Text("Try again")
                        .font(.custom("Raleway-Bold", size: 15, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        )
                }
                .buttonStyle(.plain)

                Button { store.send(.closeTapped) } label: {
                    Text("Skip for today")
                        .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .body))
                        .foregroundStyle(DesignColors.textPlaceholder)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }
}
```

- [ ] **Step 2: Verify file compiles, commit**

```bash
git add Packages/Features/Home/Glow/ChallengeValidatingView.swift
git commit -m "feat(challenge): add ChallengeValidatingView — pulsing Aria check animation"
```

---

### Task 5: ChallengeCelebrationView (Step 4)

**Files:**
- Create: `Packages/Features/Home/Glow/ChallengeCelebrationView.swift`

- [ ] **Step 1: Create the celebration view**

```swift
// Packages/Features/Home/Glow/ChallengeCelebrationView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeCelebrationView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    @State private var showCard = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            celebrationCard
                .scaleEffect(showCard ? 1.0 : 0.9)
                .opacity(showCard ? 1.0 : 0)

            Spacer()

            Button { store.send(.backToMyDayTapped) } label: {
                Text("Back to my day")
                    .font(.custom("Raleway-Bold", size: 15, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignColors.accentWarm)
                    )
                    .shadow(color: DesignColors.text.opacity(0.22), radius: 10, x: 0, y: 4)
                    .shadow(color: DesignColors.text.opacity(0.10), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 16)

            Text("New challenge tomorrow")
                .font(.custom("Raleway-Medium", size: 11, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPlaceholder)
                .padding(.top, 8)
                .opacity(showButton ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                showCard = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(1.2)) {
                showButton = true
            }
        }
    }

    // MARK: - Card

    private var celebrationCard: some View {
        VStack(spacing: 16) {
            Text("Beautiful!")
                .font(.custom("Raleway-Black", size: 24, relativeTo: .title))
                .foregroundStyle(DesignColors.text)

            Text(store.celebrationFeedback)
                .font(.custom("Raleway-Medium", size: 13, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 4)

            Text("Challenge complete")
                .font(.custom("Raleway-Bold", size: 13, relativeTo: .caption))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(DesignColors.accentWarm)
                )

            // Gamification placeholder — will be redesigned
            gamificationPlaceholder
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glowCardBackground(tint: .rose)
    }

    private var gamificationPlaceholder: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.custom("Raleway-Bold", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.accentWarm)
                    Spacer()
                    Text("4 of 7")
                        .font(.custom("Raleway-Medium", size: 11, relativeTo: .caption))
                        .foregroundStyle(DesignColors.textPlaceholder)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(DesignColors.text.opacity(0.06))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 0.57)
                    }
                }
                .frame(height: 5)
            }

            Text("4 day streak")
                .font(.custom("Raleway-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(DesignColors.accentWarm.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(DesignColors.accentWarm.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
}
```

- [ ] **Step 2: Verify file compiles, commit**

```bash
git add Packages/Features/Home/Glow/ChallengeCelebrationView.swift
git commit -m "feat(challenge): add ChallengeCelebrationView — animated celebration card"
```

---

### Task 6: ChallengeJourneyView (Container)

**Files:**
- Create: `Packages/Features/Home/Glow/ChallengeJourneyView.swift`

- [ ] **Step 1: Create the main journey container view**

```swift
// Packages/Features/Home/Glow/ChallengeJourneyView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeJourneyView: View {
    @Bindable var store: StoreOf<ChallengeJourneyFeature>

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.bottom, 14)

            stepContent
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColors.background.ignoresSafeArea())
        .onAppear { store.send(.appeared) }
        // Camera
        .fullScreenCover(isPresented: Binding(
            get: { store.isShowingCamera },
            set: { if !$0 { store.send(.photoCancelled) } }
        )) {
            CameraPickerRepresentable(
                onCapture: { data in store.send(.photoCaptured(data)) },
                onCancel: { store.send(.photoCancelled) }
            )
            .ignoresSafeArea()
        }
        // Gallery
        .fullScreenCover(isPresented: Binding(
            get: { store.isShowingGallery },
            set: { if !$0 { store.send(.photoCancelled) } }
        )) {
            GalleryPickerRepresentable(
                onPick: { data in store.send(.photoCaptured(data)) },
                onCancel: { store.send(.photoCancelled) }
            )
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                let stepIndex = stepToIndex(store.step)
                if index < stepIndex {
                    // Done
                    Capsule()
                        .fill(DesignColors.accentWarm)
                        .frame(width: 6, height: 6)
                } else if index == stepIndex {
                    // Active
                    Capsule()
                        .fill(DesignColors.accentWarm)
                        .frame(width: 20, height: 6)
                } else {
                    // Upcoming
                    Capsule()
                        .fill(DesignColors.divider)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: store.step)
    }

    private func stepToIndex(_ step: ChallengeJourneyFeature.State.Step) -> Int {
        switch step {
        case .timer: return 0
        case .proof: return 1
        case .validating, .celebration: return 2
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch store.step {
        case .timer:
            ChallengeTimerView(store: store)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .proof:
            ChallengeProofView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .validating:
            ChallengeValidatingView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))

        case .celebration:
            ChallengeCelebrationView(store: store)
                .transition(.opacity)
        }
    }
}
```

- [ ] **Step 2: Wrap stepContent in animation**

Add `.animation(.spring(response: 0.45, dampingFraction: 0.9), value: store.step)` to the stepContent VStack in body. This ensures smooth transitions between steps.

- [ ] **Step 3: Verify file compiles, commit**

```bash
git add Packages/Features/Home/Glow/ChallengeJourneyView.swift
git commit -m "feat(challenge): add ChallengeJourneyView — container with step transitions"
```

---

### Task 7: Integration — DailyChallengeFeature + ChallengeAcceptFeature

**Files:**
- Modify: `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift`
- Modify: `Packages/Features/Home/Glow/DailyChallengeFeature.swift`
- Modify: `Packages/Features/Home/TodayFeature.swift`

- [ ] **Step 1: Add .startChallenge delegate to ChallengeAcceptFeature**

In `ChallengeAcceptFeature.swift`, add a new delegate case and a new action:

Add to `Delegate` enum:
```swift
case startChallenge
```

Add new action:
```swift
case startChallengeTapped
```

Add to reducer body:
```swift
case .startChallengeTapped:
    return .send(.delegate(.startChallenge))
```

- [ ] **Step 2: Update ChallengeAcceptView button**

Find the "Start challenge" button in ChallengeAcceptView (in the same file, around line 243) and change its action from `.openCameraTapped` to `.startChallengeTapped`.

- [ ] **Step 3: Add journey state to DailyChallengeFeature**

In `DailyChallengeFeature.swift`, add to State:

```swift
@Presents public var journey: ChallengeJourneyFeature.State?
```

Add to Action:
```swift
case journey(PresentationAction<ChallengeJourneyFeature.Action>)
```

Add to reducer body composition (after existing .ifLet chains):
```swift
.ifLet(\.$journey, action: \.journey) { ChallengeJourneyFeature() }
```

- [ ] **Step 4: Handle accept sheet .startChallenge delegate**

In DailyChallengeFeature reducer, add handling for the new delegate:

```swift
case .acceptSheet(.presented(.delegate(.startChallenge))):
    state.acceptSheet = nil
    guard let challenge = state.challenge else { return .none }
    state.journey = ChallengeJourneyFeature.State(challenge: challenge)
    return .none
```

- [ ] **Step 5: Handle journey completion delegate**

In DailyChallengeFeature reducer, add:

```swift
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
    return .run { [glowLocal = self.glowLocal] send in
        try await glowLocal.completeChallenge(
            challengeId, photoData, thumbnailData, rating, feedback, xpEarned
        )
        let (previous, current) = try await glowLocal.addXP(xpEarned, rating)
        if current.currentLevel > previous.currentLevel {
            let info = GlowConstants.levelFor(xp: current.totalXP)
            let unlock = GlowConstants.unlockDescriptions[current.currentLevel] ?? ""
            await send(.levelUpTriggered(
                level: info.level, title: info.title,
                emoji: info.emoji, unlock: unlock
            ))
        }
        await send(.delegate(.challengeStateChanged(challenge)))
    }

case .journey(.presented(.delegate(.cancelled))):
    state.journey = nil
    return .none
```

- [ ] **Step 6: Add journey fullScreenCover to TodayFeature**

In `TodayFeature.swift`, inside the `DailyGlowPresentations` ViewModifier, add after the acceptSheet fullScreenCover:

```swift
// Challenge Journey (full-screen continuous flow)
.fullScreenCover(
    item: $store.scope(
        state: \.dailyChallengeState.journey,
        action: \.dailyChallenge.journey
    )
) { journeyStore in
    ChallengeJourneyView(store: journeyStore)
}
```

- [ ] **Step 7: Build and verify**

Run: `cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add Packages/Features/Home/Glow/ChallengeAcceptFeature.swift \
       Packages/Features/Home/Glow/DailyChallengeFeature.swift \
       Packages/Features/Home/TodayFeature.swift
git commit -m "feat(challenge): integrate ChallengeJourneyFeature into existing flow"
```

---

## Phase 2: Live Activity (ActivityKit)

### Task 8: ActivityKit Attributes + Bridge

**Files:**
- Create: `Packages/Features/Home/Glow/ChallengeActivityBridge.swift`

- [ ] **Step 1: Create the activity bridge**

Note: Live Activities require an App Group and widget extension target. The ActivityAttributes struct must be shared between app and widget. For now, create the bridge in the app target — the widget extension target will be added to project.yml separately.

```swift
// Packages/Features/Home/Glow/ChallengeActivityBridge.swift

import ActivityKit
import Foundation

struct ChallengeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let timerEnd: Date
    }

    let challengeTitle: String
    let cyclePhase: String
    let durationMinutes: Int
}

enum ChallengeActivityBridge {

    @MainActor
    static func start(
        title: String,
        phase: String,
        durationMinutes: Int
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = ChallengeActivityAttributes(
            challengeTitle: title,
            cyclePhase: phase,
            durationMinutes: durationMinutes
        )

        let timerEnd = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        let state = ChallengeActivityAttributes.ContentState(timerEnd: timerEnd)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: timerEnd),
                pushType: nil
            )
        } catch {
            // Silently fail — Live Activity is enhancement, not critical path
        }
    }

    @MainActor
    static func endAll() {
        Task {
            for activity in Activity<ChallengeActivityAttributes>.activities {
                let finalState = ChallengeActivityAttributes.ContentState(timerEnd: .now)
                await activity.end(
                    .init(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
    }
}
```

- [ ] **Step 2: Hook bridge into ChallengeJourneyFeature**

In `ChallengeJourneyFeature.swift`, update the `.appeared` case to also start the Live Activity:

```swift
case .appeared:
    let title = state.challenge.challengeTitle
    let phase = state.challenge.cyclePhase
    let duration = State.durationMinutes(for: state.challenge.challengeCategory)
    return .merge(
        .run { send in
            for await _ in self.clock.timer(interval: .seconds(1)) {
                await send(.timerTick)
            }
        }
        .cancellable(id: CancelID.timer),
        .run { _ in
            await ChallengeActivityBridge.start(
                title: title, phase: phase, durationMinutes: duration
            )
        }
    )
```

Update `.submitPhotoTapped` to end the activity when submitting:

Add at the start of the `.submitPhotoTapped` case, before the API call:
```swift
// End Live Activity — challenge photo is being submitted
return .merge(
    .run { _ in await ChallengeActivityBridge.endAll() },
    // ... existing API call effect
)
```

Also end on `.closeTapped`:
```swift
case .closeTapped:
    return .merge(
        .run { _ in await ChallengeActivityBridge.endAll() },
        .send(.delegate(.cancelled))
    )
```

- [ ] **Step 3: Verify build, commit**

```bash
git add Packages/Features/Home/Glow/ChallengeActivityBridge.swift \
       Packages/Features/Home/Glow/ChallengeJourneyFeature.swift
git commit -m "feat(challenge): add ActivityKit bridge — start/end Live Activity with timer"
```

---

### Task 9: Widget Extension + Live Activity Views

**Files:**
- Create: `CycleApp/CycleAppLiveActivity/ChallengeActivityBundle.swift`
- Create: `CycleApp/CycleAppLiveActivity/ChallengeActivityView.swift`
- Modify: `project.yml`

- [ ] **Step 1: Create widget extension directory**

```bash
mkdir -p CycleApp/CycleAppLiveActivity
```

- [ ] **Step 2: Create the widget bundle entry point**

```swift
// CycleApp/CycleAppLiveActivity/ChallengeActivityBundle.swift

import SwiftUI
import WidgetKit

@main
struct ChallengeActivityBundle: WidgetBundle {
    var body: some Widget {
        ChallengeActivityLiveActivity()
    }
}
```

- [ ] **Step 3: Create the Live Activity views**

```swift
// CycleApp/CycleAppLiveActivity/ChallengeActivityView.swift

import ActivityKit
import SwiftUI
import WidgetKit

struct ChallengeActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChallengeActivityAttributes.self) { context in
            // Lock Screen
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.challengeTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(context.attributes.cyclePhase.capitalized + " phase")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.timerEnd, style: .timer)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Color(red: 193/255, green: 143/255, blue: 125/255))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        timerInterval: Date()...context.state.timerEnd,
                        countsDown: true
                    )
                    .tint(Color(red: 193/255, green: 143/255, blue: 125/255))
                    .padding(.top, 4)
                }
            } compactLeading: {
                Circle()
                    .fill(Color(red: 193/255, green: 143/255, blue: 125/255))
                    .frame(width: 8, height: 8)
            } compactTrailing: {
                Text(context.state.timerEnd, style: .timer)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 193/255, green: 143/255, blue: 125/255))
                    .monospacedDigit()
            } minimal: {
                Circle()
                    .fill(Color(red: 193/255, green: 143/255, blue: 125/255))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<ChallengeActivityAttributes>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("cycle")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color(red: 193/255, green: 143/255, blue: 125/255))
                Text(context.attributes.challengeTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.timerEnd, style: .timer)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("remaining")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(16)
        .background(Color(red: 28/255, green: 24/255, blue: 22/255))
    }
}
```

- [ ] **Step 4: Add widget extension target to project.yml**

Add after the CycleAppTests target:

```yaml
  CycleAppLiveActivity:
    type: app-extension
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: CycleApp/CycleAppLiveActivity
      - path: Packages/Features/Home/Glow/ChallengeActivityBridge.swift
        # Shared: ChallengeActivityAttributes is defined here
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.cycle.ios.live-activity
        INFOPLIST_KEY_NSSupportsLiveActivities: true
        TARGETED_DEVICE_FAMILY: 1
        SWIFT_STRICT_CONCURRENCY: complete
    entitlements:
      path: CycleApp/Resources/CycleApp.entitlements
```

Add the extension as a dependency of CycleApp:

```yaml
    dependencies:
      # ... existing deps ...
      - target: CycleAppLiveActivity
```

- [ ] **Step 5: Regenerate Xcode project and build**

```bash
cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodegen generate
xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add CycleApp/CycleAppLiveActivity/ project.yml
git commit -m "feat(challenge): add Live Activity widget — Dynamic Island + Lock Screen timer"
```

---

## Phase 3: Cleanup

### Task 10: Remove Old Presentation Code

**Files:**
- Modify: `Packages/Features/Home/TodayFeature.swift`
- Modify: `Packages/Features/Home/Glow/DailyChallengeFeature.swift`

- [ ] **Step 1: Remove old camera/gallery/photoReview/validation presentations from TodayFeature**

In `TodayFeature.swift`, inside `DailyGlowPresentations`, remove the fullScreenCover/sheet presentations for:
- `.dailyChallengeState.photoReview` (photoReview fullScreenCover)
- `.dailyChallengeState.validation` (validation sheet)
- `isShowingCamera` binding (camera fullScreenCover)
- `isShowingGallery` binding (gallery fullScreenCover)

Keep:
- `.dailyChallengeState.acceptSheet` (still used to show challenge details before journey)
- `.dailyChallengeState.journey` (new — added in Task 7)
- `.dailyChallengeState.levelUp` (still used for level-up overlay)

- [ ] **Step 2: Remove old accept→camera delegation from DailyChallengeFeature**

In `DailyChallengeFeature.swift`, remove the old flow handlers:
- `.acceptSheet(.presented(.delegate(.openCamera)))` case
- `.acceptSheet(.presented(.delegate(.openGallery)))` case
- `.photoCaptured(Data)` case
- `.photoCancelled` case
- The old `.photoReview(.presented(.delegate(.submit)))` case
- The old `.validation(.presented(.delegate(.completed)))` case
- The old `.validation(.presented(.delegate(.tryAgain)))` case
- The old `.validation(.presented(.delegate(.skipForToday)))` case

Remove from State:
- `isShowingCamera`
- `isShowingGallery`

Remove `@Presents` and `.ifLet` for:
- `photoReview`
- `validation`

Keep `@Presents` for:
- `acceptSheet` (still opens the details)
- `journey` (new)
- `levelUp` (still used)

- [ ] **Step 3: Build and verify**

```bash
cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add Packages/Features/Home/TodayFeature.swift \
       Packages/Features/Home/Glow/DailyChallengeFeature.swift
git commit -m "refactor(challenge): remove old fragmented modal presentations"
```

---

### Task 11: Manual QA

- [ ] **Step 1: Test the full flow on device**

1. Open app → Home → find challenge card
2. Tap "I'm in" → accept sheet opens
3. Tap "Start challenge" → full-screen journey appears with timer
4. Verify timer counts down
5. Verify tips display correctly
6. Verify Dynamic Island shows timer (physical device only)
7. Tap "I'm done" → transitions to proof step
8. Take photo or pick from gallery
9. Verify photo preview shows with Submit/Retake
10. Tap Submit → transitions to validation
11. Verify Aria pulse animation
12. Verify celebration appears with feedback
13. Tap "Back to my day" → returns to Home
14. Verify challenge card shows completed state

- [ ] **Step 2: Test edge cases**

1. Close button at any step → returns to Home, challenge unchanged
2. Retake photo → camera reopens
3. Validation failure → shows retry/skip options
4. Timer reaches 0 → still shows timer view, user can tap "I'm done"
5. Leave app during timer → Dynamic Island visible
6. Return to app → timer screen still active
